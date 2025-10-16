"""
AL-Madhina Backend - Local MongoDB Only Version
This version works with local MongoDB without requiring Supabase.
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from contextlib import asynccontextmanager
import logging
import sys
import os

# Import local config (no Supabase)
from config_local import settings
from database.mongodb_client import test_mongo_connection, init_mongo_collections

# Setup logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Runs on startup and shutdown.
    """
    logger.info("🚀 AL-Madhina Backend Starting (Local MongoDB)")
    logger.info("="*60)
    logger.info("📊 Testing Database Connection...")
    
    # Test MongoDB connection
    try:
        if test_mongo_connection():
            logger.info("✓ MongoDB connection successful")
            # Initialize collections with sample data
            init_mongo_collections()
            logger.info("✓ MongoDB collections initialized")
        else:
            logger.warning("⚠ MongoDB connection test failed - continuing anyway")
    except Exception as e:
        logger.error(f"✗ MongoDB error: {e}")
        logger.warning("⚠ Continuing without MongoDB - some features may not work")
    
    logger.info("="*60)
    logger.info(f"✅ Backend Ready - Listening on http://{settings.host}:{settings.port}")
    logger.info(f"📖 API Docs: http://{settings.host}:{settings.port}/docs")
    logger.info(f"🎨 Admin Dashboard: http://{settings.host}:{settings.port}/admin/login")
    logger.info(f"   👤 Username: admin")
    logger.info(f"   🔑 Password: admin123")
    logger.info("="*60)
    
    yield
    
    logger.info("🛑 Shutting down AL-Madhina Backend")


# Create FastAPI application
app = FastAPI(
    title="AL-Madhina Wholesale API (Local MongoDB)",
    description="Backend API for AL-Madhina wholesale ordering system with local MongoDB.",
    version="1.0.0-local",
    lifespan=lifespan,
    debug=settings.debug
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for admin dashboard
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
else:
    logger.warning(f"Static directory not found: {static_dir}")

# Setup templates
templates_dir = os.path.join(os.path.dirname(__file__), "templates")
if os.path.exists(templates_dir):
    templates = Jinja2Templates(directory=templates_dir)
else:
    logger.warning(f"Templates directory not found: {templates_dir}")

# Import routes
try:
    from routes import admin_local
    app.include_router(admin_local.router)
    logger.info("✓ Admin routes loaded (local MongoDB version)")
except Exception as e:
    logger.error(f"✗ Failed to load admin routes: {e}")

# Root endpoint
@app.get("/")
async def root():
    """API information endpoint."""
    return {
        "name": "AL-Madhina Wholesale API",
        "version": "1.0.0-local",
        "status": "running",
        "database": "Local MongoDB",
        "admin_dashboard": "/admin/login",
        "api_docs": "/docs"
    }


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint with database status."""
    try:
        mongo_status = test_mongo_connection()
        return {
            "status": "healthy" if mongo_status else "degraded",
            "database": {
                "mongodb": "connected" if mongo_status else "disconnected"
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main_local:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload,
        log_level=settings.log_level.lower()
    )
