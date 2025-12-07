"""
Supabase (PostgreSQL) client for transactional data.
Handles orders, cart, user authentication, and real-time data.
"""
from supabase import create_client, Client
from typing import Generator, Optional
import logging
import os

# Try to import SQLAlchemy (optional)
try:
    from sqlalchemy import create_engine, MetaData
    from sqlalchemy.ext.declarative import declarative_base
    from sqlalchemy.orm import sessionmaker
    HAS_SQLALCHEMY = True
except ImportError:
    HAS_SQLALCHEMY = False
    create_engine = None
    MetaData = None
    declarative_base = None
    sessionmaker = None

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

# SQLAlchemy setup for direct PostgreSQL access (optional - only if SQLAlchemy is installed)
engine = None
SessionLocal = None
Base = None
metadata = None

if HAS_SQLALCHEMY:
    try:
        # Note: SQLAlchemy not needed for Supabase client operations
        # Only uncomment if you need direct SQL access
        # engine = create_engine(...)
        # SessionLocal = sessionmaker(...)
        # Base = declarative_base()
        # metadata = MetaData()
        logger.info("ℹ️ SQLAlchemy available but not initialized (using Supabase client API)")
    except Exception as e:
        logger.warning(f"⚠️ SQLAlchemy setup skipped: {e}")
else:
    logger.info("ℹ️ SQLAlchemy not installed (using Supabase client API only)")


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
    Note: Using Supabase client API - tables managed via Supabase dashboard/SQL editor.
    """
    try:
        if HAS_SQLALCHEMY and Base is not None and engine is not None:
            Base.metadata.create_all(bind=engine)
            logger.info("✅ Supabase PostgreSQL tables initialized via SQLAlchemy")
        else:
            logger.info("ℹ️ Using Supabase client API (tables managed via Supabase dashboard)")
    except Exception as e:
        logger.warning(f"⚠️ Table initialization skipped: {e}")


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
