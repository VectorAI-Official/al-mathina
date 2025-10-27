"""
AL-Madhina Backend - Production Entry Point (Fly.io)
Uses MongoDB Atlas and Cloudinary for cloud deployment
"""
import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Form, HTTPException, Response
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from config_production import settings
from database.mongodb_client import test_mongo_connection, init_mongo_collections, get_mongo_db, close_mongo_connection
from utils.cloudinary_helper import get_cloudinary_manager
from admin_auth import verify_credentials, create_session, delete_session

# Import routes
from routes import flutter, user_profile, admin_orders
from routes import admin_production as admin  # Production admin routes with Cloudinary

# Set environment variable to ensure production config is used
os.environ['ENVIRONMENT'] = 'production'

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    logger.info("🚀 AL-Madhina Backend Starting (Production - Fly.io)")
    logger.info("=" * 60)
    
    # Skip MongoDB connection test on startup (Python 3.13 SSL bug)
    # Connection will be established lazily on first request
    logger.info("📊 MongoDB Atlas - Lazy connection (will connect on first request)")
    logger.info("⏳ Skipping collection initialization at startup to allow lazy connection")
    
    # Test Cloudinary connection
    logger.info("☁️  Testing Cloudinary Connection...")
    cloudinary_manager = get_cloudinary_manager()
    if cloudinary_manager.is_ready():
        logger.info("✓ Cloudinary initialized successfully")
    else:
        logger.warning("⚠ Cloudinary not configured - image uploads will be disabled")
    
    logger.info("=" * 60)
    logger.info(f"✅ Backend Ready - http://localhost:8080")
    logger.info(f"📖 API Docs: http://localhost:8080/docs")
    logger.info(f"🎨 Admin Dashboard: http://localhost:8080/admin")
    logger.info("=" * 60)
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down AL-Madhina Backend")
    close_mongo_connection()


# Create FastAPI application
app = FastAPI(
    title="AL-Madhina Wholesale API",
    description="Backend API for AL-Madhina wholesale management system",
    version="2.0.0",
    lifespan=lifespan
)

# Setup templates for admin dashboard
templates = Jinja2Templates(directory="templates")

# Mount static files for admin dashboard
app.mount("/static", StaticFiles(directory="static"), name="static")

# CORS configuration (allow your Flutter app domain)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*"  # Allow all origins for now - restrict to your Flutter app domain in production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint for Fly.io
@app.get("/health")
async def health_check():
    """Health check endpoint for Fly.io monitoring"""
    return {
        "status": "healthy",
        "service": "almathina-backend",
        "version": "2.0.0",
        "mongodb": "connected",
        "cloudinary": get_cloudinary_manager().is_ready()
    }

# Include API routes (routers already have their own prefixes)
app.include_router(flutter.router, tags=["Flutter API"])
app.include_router(user_profile.router, tags=["User Profile"])
app.include_router(admin_orders.router, tags=["Admin Orders"])

# Production admin routes with Cloudinary integration
app.include_router(admin.router, tags=["Admin API - Production"])

# Admin Dashboard UI Routes
@app.get("/admin", response_class=HTMLResponse)
async def admin_login(request: Request):
    """Serve admin login page"""
    return templates.TemplateResponse("admin_login.html", {"request": request})

@app.post("/admin/login")
async def admin_login_post(
    response: Response,
    username: str = Form(...),
    password: str = Form(...)
):
    """
    Authenticate admin user and create session.
    Credentials: admin / admin123
    """
    if not verify_credentials(username, password):
        raise HTTPException(
            status_code=401,
            detail="Invalid username or password"
        )
    
    # Create session token
    session_token = create_session(username)
    
    # Set session cookie and redirect to dashboard ✅
    response = RedirectResponse(url="/admin/dashboard", status_code=303)
    response.set_cookie(
        key="admin_session",
        value=session_token,
        httponly=True,
        max_age=28800,  # 8 hours
        samesite="lax"
    )
    
    logger.info(f"Admin logged in: {username}")
    return response

@app.get("/admin/dashboard", response_class=HTMLResponse)
async def admin_dashboard(request: Request):
    """Serve admin dashboard page"""
    return templates.TemplateResponse("admin_dashboard.html", {"request": request})

@app.get("/admin/orders", response_class=HTMLResponse)
async def admin_orders_page(request: Request):
    """Serve admin orders page"""
    with open("static/admin/orders.html", "r") as f:
        return HTMLResponse(content=f.read())

@app.post("/admin/logout")
async def admin_logout(request: Request, response: Response):
    """Logout admin user and delete session."""
    session_token = request.cookies.get("admin_session")
    
    if session_token:
        delete_session(session_token)
    
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie("admin_session")
    
    logger.info("Admin logged out")
    return response

# Test endpoint to verify hot-reload
@app.get("/test-hot-reload")
async def test_hot_reload():
    """Test endpoint - check if changes are reflected (for hot-reload verification)"""
    return {
        "status": "success",
        "message": "Hot-reload is working! 🔥",
        "timestamp": "2025-10-27",
        "test": "If you can see this, hot-reload is functioning correctly"
    }

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "AL-Madhina Wholesale API",
        "version": "2.0.0",
        "docs": "/docs",
        "status": "running"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main_production:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload
    )
