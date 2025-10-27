"""
AL-Madhina Backend - Production Entry Point (Fly.io)
Uses MongoDB Atlas and Cloudinary for cloud deployment
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from config_production import settings
from database.mongodb_client import test_mongodb_connection, initialize_collections, get_mongo_db, close_mongodb_connection

# Import routes
from routes import flutter, user_profile, admin_orders
# Note: We'll need to update admin routes to use Cloudinary

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
    
    # Test MongoDB Atlas connection
    logger.info("📊 Testing MongoDB Atlas Connection...")
    if test_mongodb_connection():
        logger.info("✓ MongoDB Atlas connection successful")
        db = get_mongo_db()
        logger.info(f"✓ Connected to MongoDB database: {settings.mongo_db_name}")
        
        # Initialize collections
        initialize_collections(db)
        logger.info("✓ MongoDB collections initialized")
    else:
        logger.error("✗ Failed to connect to MongoDB Atlas")
        raise Exception("Could not connect to MongoDB Atlas")
    
    logger.info("=" * 60)
    logger.info(f"✅ Backend Ready")
    logger.info(f"📖 API Docs: https://your-app.fly.dev/docs")
    logger.info("=" * 60)
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down AL-Madhina Backend")
    close_mongodb_connection()


# Create FastAPI application
app = FastAPI(
    title="AL-Madhina Wholesale API",
    description="Backend API for AL-Madhina wholesale management system",
    version="2.0.0",
    lifespan=lifespan
)

# CORS configuration (allow your Flutter app domain)
app.add_middleware(
    CORS Middleware,
    allow_origins=[
        "*"  # TODO: Replace with your actual Flutter app domain in production
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
        "version": "2.0.0"
    }

# Include API routes
app.include_router(flutter.router, prefix="/api/flutter", tags=["Flutter API"])
app.include_router(user_profile.router, prefix="/api/flutter/user", tags=["User Profile"])
app.include_router(admin_orders.router, prefix="/api/admin", tags=["Admin Orders"])

# TODO: Include admin routes with Cloudinary integration
# app.include_router(admin_cloudinary.router, prefix="/admin/api", tags=["Admin API"])

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
