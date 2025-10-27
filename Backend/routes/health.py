"""
Simple health check endpoint for Fly.io monitoring.
"""
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
async def health_check():
    """Health check endpoint for Fly.io."""
    return {
        "status": "healthy",
        "service": "AL-Madhina Backend",
        "environment": "production"
    }
