"""
FastAPI Main Application - AL-Madhina Wholesale Backend
Gateway between Flutter frontend and hybrid database system (Supabase + MongoDB).

This application:
- Runs on port 8000 for local development
- Connects to Supabase (PostgreSQL) for transactional data (orders, cart)
- Connects to MongoDB for catalog data (products, categories)
- Provides REST API endpoints for the Flutter application
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from datetime import datetime
import logging
import sys
import os

from config import settings
from database.supabase_client import init_supabase_tables, test_supabase_connection
from database.mongodb_client import test_mongo_connection, init_mongo_collections
from routes import inventory, cart, orders, admin
from models import HealthCheckResponse, DatabaseStatus

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown events.
    """
    # Startup
    logger.info("=" * 60)
    logger.info("🚀 AL-Madhina Wholesale Backend Starting Up")
    logger.info("=" * 60)
    
    logger.info(f"Environment: {'Development' if settings.debug else 'Production'}")
    logger.info(f"Host: {settings.host}:{settings.port}")
    
    # Test database connections
    logger.info("\n📊 Testing Database Connections...")
    
    supabase_ok = test_supabase_connection()
    mongo_ok = test_mongo_connection()
    
    if not supabase_ok or not mongo_ok:
        logger.error("❌ Database connection failed! Please check your configuration.")
        logger.error("\nMake sure:")
        logger.error("  1. Supabase is running: supabase start")
        logger.error("  2. MongoDB is running: docker run -p 27017:27017 mongo")
        logger.error("  3. .env file has correct connection strings")
    else:
        logger.info("✅ All database connections successful!")
    
    # Initialize database tables
    logger.info("\n🔧 Initializing Database Schemas...")
    try:
        init_supabase_tables()
        init_mongo_collections()
        logger.info("✅ Database schemas initialized")
    except Exception as e:
        logger.error(f"❌ Error initializing databases: {e}")
    
    logger.info("\n" + "=" * 60)
    logger.info("✅ Backend Ready - Listening on http://{}:{}".format(settings.host, settings.port))
    logger.info("📖 API Docs: http://{}:{}/docs".format(settings.host, settings.port))
    logger.info("=" * 60 + "\n")
    
    yield
    
    # Shutdown
    logger.info("\n🛑 AL-Madhina Wholesale Backend Shutting Down...")
    from database.mongodb_client import close_mongo_connection
    close_mongo_connection()
    logger.info("✅ Cleanup complete. Goodbye!")


# Create FastAPI application
app = FastAPI(
    title="AL-Madhina Wholesale API",
    description="Backend API for AL-Madhina wholesale ordering system. Serves as the gateway between Flutter frontend and hybrid database system (Supabase + MongoDB).",
    version="1.0.0",
    lifespan=lifespan,
    debug=settings.debug
)

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:*",  # Flutter web local
        "http://localhost:*",   # Alternative localhost
        "*"  # Allow all for development (restrict in production)
    ],
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

# Include routers
app.include_router(inventory.router)
app.include_router(cart.router)
app.include_router(orders.router)
app.include_router(admin.router)  # Admin dashboard routes

# Import and include Flutter router
try:
    from routes import flutter
    app.include_router(flutter.router)  # Flutter mobile app routes
    logger.info("✅ Flutter routes registered")
except Exception as e:
    logger.warning(f"⚠️ Flutter routes not available: {e}")


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint - API information."""
    return {
        "name": "AL-Madhina Wholesale API",
        "version": "1.0.0",
        "status": "running",
        "message": "Welcome to AL-Madhina Wholesale Backend API",
        "docs": "/docs",
        "timestamp": datetime.now().isoformat()
    }


# Health check endpoint
@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """
    Health check endpoint.
    Tests connections to both databases and returns status.
    """
    databases = []
    
    # Test Supabase
    supabase_status = DatabaseStatus(
        name="Supabase (PostgreSQL)",
        connected=test_supabase_connection(),
        message="Transactional data (orders, cart)"
    )
    databases.append(supabase_status)
    
    # Test MongoDB
    mongo_status = DatabaseStatus(
        name="MongoDB",
        connected=test_mongo_connection(),
        message="Catalog data (products, categories)"
    )
    databases.append(mongo_status)
    
    # Overall status
    all_healthy = all(db.connected for db in databases)
    
    return HealthCheckResponse(
        status="healthy" if all_healthy else "degraded",
        databases=databases,
        timestamp=datetime.now()
    )


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle uncaught exceptions."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "message": str(exc) if settings.debug else "An error occurred"
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload,
        log_level=settings.log_level.lower()
    )
