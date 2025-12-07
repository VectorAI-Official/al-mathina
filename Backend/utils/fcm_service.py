"""
Firebase Cloud Messaging (FCM) Notification Service
Sends push notifications to Flutter app users
"""

import firebase_admin
from firebase_admin import credentials, messaging
import logging
import os
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

class FCMService:
    """
    Singleton service for sending FCM push notifications
    """
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FCMService, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not self._initialized:
            self._initialize_firebase()
            FCMService._initialized = True
    
    def _initialize_firebase(self):
        """
        Initialize Firebase Admin SDK with service account
        """
        try:
            # Check if Firebase is already initialized
            if firebase_admin._apps:
                logger.info("✅ Firebase Admin SDK already initialized")
                return
            
            # Load service account credentials
            # You need to download this from Firebase Console:
            # Project Settings > Service Accounts > Generate New Private Key
            service_account_path = os.getenv(
                'FIREBASE_SERVICE_ACCOUNT_PATH',
                'firebase-service-account.json'
            )
            
            if not os.path.exists(service_account_path):
                logger.warning(f"⚠️ Firebase service account file not found: {service_account_path}")
                logger.warning("Push notifications will not work. Download from Firebase Console.")
                return
            
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            logger.info("✅ Firebase Admin SDK initialized successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize Firebase Admin SDK: {str(e)}")
    
    async def send_order_notification(
        self,
        fcm_token: str,
        order_id: str,
        total_amount: float,
        items_count: int,
        store_name: Optional[str] = None
    ) -> bool:
        """
        Send order confirmation notification to user
        
        Args:
            fcm_token: User's FCM device token
            order_id: Order ID
            total_amount: Total order amount
            items_count: Number of items in order
            store_name: Optional store name for personalization
        
        Returns:
            bool: True if notification sent successfully
        """
        try:
            # Check if Firebase is initialized
            if not firebase_admin._apps:
                logger.warning("⚠️ Firebase not initialized. Cannot send notification.")
                return False
            
            # Prepare notification message with Al-Mathina branding
            title = "🎉 Order Received!"
            body = f"Your order #{order_id[-6:]} for ₹{total_amount:,.2f} has been placed successfully."
            
            if store_name:
                body += f"\n\nThank you, {store_name}! 🙏"
            
            # Create FCM message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                    image=None  # Optional: Add Al-Mathina logo URL
                ),
                data={
                    'type': 'order_confirmation',
                    'order_id': order_id,
                    'total_amount': str(total_amount),
                    'items_count': str(items_count),
                    'timestamp': str(int(os.times().elapsed * 1000))
                },
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='ic_launcher',
                        color='#28a745',  # Al-Mathina green
                        sound='default',
                        channel_id='orders_channel'
                    )
                ),
                token=fcm_token
            )
            
            # Send message
            response = messaging.send(message)
            logger.info(f"✅ Push notification sent successfully: {response}")
            logger.info(f"   Order: {order_id}, User FCM Token: {fcm_token[:20]}...")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to send push notification: {str(e)}")
            logger.error(f"   Order: {order_id}, FCM Token: {fcm_token[:20] if fcm_token else 'None'}...")
            return False
    
    async def send_custom_notification(
        self,
        fcm_token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Send custom notification to user
        
        Args:
            fcm_token: User's FCM device token
            title: Notification title
            body: Notification body
            data: Optional data payload
        
        Returns:
            bool: True if notification sent successfully
        """
        try:
            if not firebase_admin._apps:
                logger.warning("⚠️ Firebase not initialized. Cannot send notification.")
                return False
            
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body
                ),
                data=data or {},
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='ic_launcher',
                        color='#28a745',
                        sound='default'
                    )
                ),
                token=fcm_token
            )
            
            response = messaging.send(message)
            logger.info(f"✅ Custom notification sent: {response}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to send custom notification: {str(e)}")
            return False

# Singleton instance
fcm_service = FCMService()
