"""
Supabase (PostgreSQL) client for transactional data.
Handles orders, cart, user authentication, and real-time data.
"""
from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from supabase import create_client, Client
from typing import Generator
import logging
import os

# Try to import production config first, then local, then default
try:
    from config_production import settings
except ImportError:
    try:
        from config_local import settings
    except ImportError:
        from config import settings

logger = logging.getLogger(__name__)

# Supabase client for auth and realtime features (using service key for server operations)
_supabase_client: Client = None

def get_supabase_client() -> Client:
    """
    Get the Supabase client instance for server-side operations.
    Uses the service role key for bypassing RLS policies.
    """
    global _supabase_client
    if _supabase_client is None:
        # Use service key if available, otherwise fall back to anon key
        api_key = settings.supabase_service_key or settings.supabase_anon_key
        _supabase_client = create_client(
            settings.supabase_url,
            api_key
        )
        logger.info(f"✅ Supabase client initialized with {'service' if settings.supabase_service_key else 'anon'} key")
    return _supabase_client

# Legacy client for backward compatibility (deprecated - use get_supabase_client() instead)
supabase_client: Client = None

def init_supabase_client():
    """Initialize the global supabase_client for backward compatibility."""
    global supabase_client
    supabase_client = get_supabase_client()

# SQLAlchemy setup for direct PostgreSQL access (if needed)
try:
    engine = create_engine(
        settings.supabase_url.replace('https://', 'postgresql://'),  # Convert URL format if needed
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
        echo=settings.debug
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base = declarative_base()
    metadata = MetaData()
except Exception as e:
    logger.warning(f"⚠️ SQLAlchemy engine setup failed (using Supabase client only): {e}")
    engine = None
    SessionLocal = None
    Base = None
    metadata = None


def get_db() -> Generator:
    """
    Dependency function to get a database session.
    Yields a SQLAlchemy session and ensures proper cleanup.
    """
    if SessionLocal is None:
        raise RuntimeError("SQLAlchemy not initialized. Use get_supabase_client() for Supabase operations.")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_supabase_tables():
    """
    Initialize Supabase tables for transactional data.
    Creates tables if they don't exist.
    """
    try:
        if Base is not None and engine is not None:
            Base.metadata.create_all(bind=engine)
            logger.info("✅ Supabase PostgreSQL tables initialized successfully")
        else:
            logger.info("ℹ️ Using Supabase client API (SQLAlchemy not available)")
    except Exception as e:
        logger.error(f"❌ Error initializing Supabase tables: {e}")
        raise


def test_supabase_connection() -> bool:
    """Test the Supabase connection."""
    try:
        # Test using Supabase client
        supabase = get_supabase_client()
        # Simple query to test connection
        result = supabase.table("users").select("count", count="exact").limit(0).execute()
        logger.info(f"✅ Supabase connection successful (users table accessible)")
        return True
    except Exception as e:
        logger.error(f"❌ Supabase connection failed: {e}")
        return False
