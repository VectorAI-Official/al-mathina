"""
FCM (Firebase Cloud Messaging) Routes for Push Notifications
Handles FCM token registration and notification management
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from database.supabase_client import get_supabase_client
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/user", tags=["FCM Notifications"])

class FCMTokenRequest(BaseModel):
    phone: str
    fcm_token: str

@router.post("/fcm-token")
async def save_fcm_token(request: FCMTokenRequest):
    """
    Save or update user's FCM token for push notifications
    """
    try:
        supabase = get_supabase_client()
        
        # Check if user exists
        user_check = supabase.table("users").select("*").eq("phone", request.phone).execute()
        
        if not user_check.data:
            # Create new user with FCM token
            result = supabase.table("users").insert({
                "phone": request.phone,
                "fcm_token": request.fcm_token,
                "created_at": datetime.utcnow().isoformat()
            }).execute()
            
            logger.info(f"✅ Created new user with FCM token: {request.phone}")
            return {
                "success": True,
                "message": "User created and FCM token saved",
                "data": result.data[0] if result.data else None
            }
        else:
            # Update existing user's FCM token
            result = supabase.table("users").update({
                "fcm_token": request.fcm_token,
                "updated_at": datetime.utcnow().isoformat()
            }).eq("phone", request.phone).execute()
            
            logger.info(f"✅ Updated FCM token for user: {request.phone}")
            return {
                "success": True,
                "message": "FCM token updated",
                "data": result.data[0] if result.data else None
            }
            
    except Exception as e:
        logger.error(f"❌ Error saving FCM token: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to save FCM token: {str(e)}")

@router.get("/fcm-token/{phone}")
async def get_fcm_token(phone: str):
    """
    Retrieve user's FCM token (used internally by backend)
    """
    try:
        supabase = get_supabase_client()
        
        result = supabase.table("users").select("fcm_token").eq("phone", phone).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="User not found")
        
        fcm_token = result.data[0].get("fcm_token")
        
        if not fcm_token:
            raise HTTPException(status_code=404, detail="FCM token not found for user")
        
        return {
            "success": True,
            "fcm_token": fcm_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error retrieving FCM token: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve FCM token: {str(e)}")
