"""
Admin authentication and session management.
Simple session-based auth for admin dashboard with mock credentials.
"""
from fastapi import HTTPException, Request, Response, Depends
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from typing import Optional
import secrets
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

# Mock admin credentials (hardcoded for development)
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "admin123"

# In-memory session store (use Redis/database in production)
active_sessions = {}
SESSION_DURATION = timedelta(hours=8)

security = HTTPBasic()


def generate_session_token() -> str:
    """Generate a secure random session token."""
    return secrets.token_urlsafe(32)


def create_session(username: str) -> str:
    """
    Create a new session for authenticated user.
    Returns session token.
    """
    session_token = generate_session_token()
    active_sessions[session_token] = {
        "username": username,
        "created_at": datetime.now(),
        "expires_at": datetime.now() + SESSION_DURATION
    }
    logger.info(f"Session created for user: {username}")
    return session_token


def get_session(session_token: str) -> Optional[dict]:
    """
    Retrieve session data by token.
    Returns None if session doesn't exist or is expired.
    """
    if session_token not in active_sessions:
        return None
    
    session_data = active_sessions[session_token]
    
    # Check if session is expired
    if datetime.now() > session_data["expires_at"]:
        del active_sessions[session_token]
        logger.info(f"Session expired and removed: {session_token[:8]}...")
        return None
    
    return session_data


def delete_session(session_token: str):
    """Delete a session (logout)."""
    if session_token in active_sessions:
        username = active_sessions[session_token].get("username", "unknown")
        del active_sessions[session_token]
        logger.info(f"Session deleted for user: {username}")


def verify_credentials(username: str, password: str) -> bool:
    """
    Verify admin credentials.
    Returns True if credentials are valid.
    """
    correct_username = secrets.compare_digest(username, ADMIN_USERNAME)
    correct_password = secrets.compare_digest(password, ADMIN_PASSWORD)
    return correct_username and correct_password


async def get_current_session(request: Request) -> dict:
    """
    Dependency to check if request has valid session.
    Raises HTTPException if not authenticated.
    """
    session_token = request.cookies.get("admin_session")
    
    if not session_token:
        raise HTTPException(
            status_code=401,
            detail="Not authenticated. Please login.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    session_data = get_session(session_token)
    
    if not session_data:
        raise HTTPException(
            status_code=401,
            detail="Session expired or invalid. Please login again.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    return session_data


def require_admin(request: Request) -> dict:
    """
    Synchronous version for templates.
    Returns session data or raises exception.
    """
    session_token = request.cookies.get("admin_session")
    
    if not session_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session_data = get_session(session_token)
    
    if not session_data:
        raise HTTPException(status_code=401, detail="Session expired")
    
    return session_data
