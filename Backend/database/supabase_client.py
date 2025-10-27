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

# SQLAlchemy setup for direct PostgreSQL access
engine = create_engine(
    settings.supabase_url,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=settings.debug
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
metadata = MetaData()

# Supabase client for auth and realtime features
supabase_client: Client = create_client(
    settings.supabase_api_url,
    settings.supabase_anon_key
)


def get_db() -> Generator:
    """
    Dependency function to get a database session.
    Yields a SQLAlchemy session and ensures proper cleanup.
    """
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
        Base.metadata.create_all(bind=engine)
        logger.info("Supabase PostgreSQL tables initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing Supabase tables: {e}")
        raise


def test_supabase_connection() -> bool:
    """Test the Supabase PostgreSQL connection."""
    try:
        with engine.connect() as connection:
            connection.execute("SELECT 1")
        logger.info("✓ Supabase PostgreSQL connection successful")
        return True
    except Exception as e:
        logger.error(f"✗ Supabase PostgreSQL connection failed: {e}")
        return False
