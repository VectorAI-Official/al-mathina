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
    Supports multiple devices per phone number
    Auto-cleans old inactive tokens (>90 days) to save storage
    """
    try:
        logger.info(f"📱 Attempting to save FCM token for phone: {request.phone}")
        supabase = get_supabase_client()
        logger.info(f"✅ Supabase client obtained successfully")
        
        # Clean up old inactive tokens (>90 days) to save storage
        from datetime import timedelta
        ninety_days_ago = (datetime.utcnow() - timedelta(days=90)).isoformat()
        try:
            cleanup_result = supabase.table("user_devices").delete().lt("last_active", ninety_days_ago).execute()
            if cleanup_result.data:
                logger.info(f"🧹 Cleaned up {len(cleanup_result.data)} old inactive FCM tokens (>90 days)")
        except Exception as cleanup_error:
            logger.warning(f"⚠️ Token cleanup failed (non-critical): {cleanup_error}")
        
        # Save to user_devices table (multi-device support)
        device_result = supabase.table("user_devices").upsert({
            "phone": request.phone,
            "fcm_token": request.fcm_token,
            "last_active": datetime.utcnow().isoformat()
        }, on_conflict="phone,fcm_token").execute()
        
        logger.info(f"✅ Saved to user_devices table for phone: {request.phone}")
        
        # Also update users table for backward compatibility
        user_check = supabase.table("users").select("*").eq("phone", request.phone).execute()
        logger.info(f"📋 User check result: found={len(user_check.data) if user_check.data else 0} users")
        
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
                "message": "User created and FCM token saved to both tables",
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
                "message": "FCM token updated in both tables",
                "data": result.data[0] if result.data else None
            }
            
    except Exception as e:
        logger.error(f"❌ Error saving FCM token: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to save FCM token: {str(e)}")

@router.get("/fcm-token/{phone}")
async def get_fcm_token(phone: str):
    """
    Retrieve all FCM tokens for a phone number (supports multiple devices)
    """
    try:
        supabase = get_supabase_client()
        
        # Get all device tokens for this phone
        result = supabase.table("user_devices").select("fcm_token, device_id, device_name, last_active").eq("phone", phone).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="No devices found for user")
        
        return {
            "success": True,
            "device_count": len(result.data),
            "devices": result.data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error retrieving FCM tokens: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve FCM tokens: {str(e)}")
