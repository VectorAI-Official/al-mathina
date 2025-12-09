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
import uuid
from datetime import datetime

# Import routes
from routes import flutter, user_profile, admin_orders, admin_stores, fcm
from routes import admin_production as admin  # Production admin routes with Cloudinary

# Simple session storage (in production, use Redis or database)
_sessions = {}

def verify_credentials(username: str, password: str) -> bool:
    """Verify admin credentials. Hardcoded for production."""
    return username == "admin" and password == "admin123"

def create_session(username: str) -> str:
    """Create a session token for authenticated admin."""
    session_id = str(uuid.uuid4())
    _sessions[session_id] = {
        "username": username,
        "created_at": datetime.now().isoformat()
    }
    return session_id

def delete_session(session_id: str) -> None:
    """Delete a session token."""
    _sessions.pop(session_id, None)

# Set environment variable to ensure production config is used
os.environ['ENVIRONMENT'] = 'production'

# Force unbuffered output for Docker/Render - CRITICAL for log visibility
import sys

# Method 1: Reconfigure streams (Python 3.7+)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)
else:
    # Method 2: Fallback for older Python
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 1)
    sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', 1)

# Configure root logger for immediate output
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(name)s - %(message)s',
    stream=sys.stderr,
    force=True
)

# Startup log to confirm unbuffered mode
sys.stderr.write("="*80 + "\n")
sys.stderr.write("🚀 AL-Madhina Backend Starting (PRODUCTION)\n")
sys.stderr.write(f"🔧 Python: {sys.version}\n")
sys.stderr.write(f"🔧 Unbuffered I/O: Enabled\n")
sys.stderr.write("="*80 + "\n")
sys.stderr.flush()

# Configure logging with forced flushing
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ],
    force=True
)
logger = logging.getLogger(__name__)

# Print startup banner to verify logs are working
print("=" * 60, flush=True)
print("🚀 AL-MATHINA BACKEND - PRODUCTION MODE", flush=True)
print(f"📅 Starting at: {datetime.now().isoformat()}", flush=True)
print("=" * 60, flush=True)


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
    logger.info(f"✅ Backend Ready - http://localhost:8000")
    logger.info(f"📖 API Docs: http://localhost:8000/docs")
    logger.info(f"🎨 Admin Dashboard: http://localhost:8000/admin")
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
app.include_router(admin_stores.router, tags=["Admin Stores"])
app.include_router(fcm.router, tags=["FCM Notifications"])

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
    with open("static/admin/orders.html", "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/admin/revenue", response_class=HTMLResponse)
async def admin_revenue_page(request: Request):
    """Serve admin revenue management page"""
    with open("static/admin/stores.html", "r", encoding="utf-8") as f:
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
