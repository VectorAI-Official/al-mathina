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
            logger.info("🚀 FCM: Starting Firebase initialization...")
            # Check if Firebase is already initialized
            if firebase_admin._apps:
                logger.info("✅ FCM: Firebase Admin SDK already initialized")
                return
            
            # Load service account credentials
            # You need to download this from Firebase Console:
            # Project Settings > Service Accounts > Generate New Private Key
            service_account_path = os.getenv(
                'FIREBASE_SERVICE_ACCOUNT_PATH',
                'firebase-service-account.json'
            )
            
            logger.info(f"🔍 FCM: Looking for credentials at: {service_account_path}")
            logger.info(f"🔍 FCM: Current working directory: {os.getcwd()}")
            logger.info(f"🔍 FCM: File exists: {os.path.exists(service_account_path)}")
            
            if not os.path.exists(service_account_path):
                logger.error(f"❌ FCM: Firebase service account file not found: {service_account_path}")
                logger.error("❌ FCM: Push notifications will NOT work. Download from Firebase Console.")
                return
            
            logger.info("📄 FCM: Loading service account credentials...")
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            logger.info("✅ FCM: Firebase Admin SDK initialized successfully!")
            logger.info("🎉 FCM: Ready to send push notifications")
            
        except Exception as e:
            logger.error(f"❌ FCM: Failed to initialize Firebase Admin SDK: {str(e)}")
            logger.error(f"❌ FCM: Exception type: {type(e).__name__}")
            import traceback
            logger.error(f"❌ FCM: Traceback: {traceback.format_exc()}")
    
    async def send_order_notification(
        self,
        fcm_token: str,
        order_id: str,
        total_amount: float,
        items_count: int,
        store_name: Optional[str] = None,
        user_phone: Optional[str] = None
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
            logger.info("\n" + "="*60)
            logger.info("📱 FCM: SENDING ORDER NOTIFICATION")
            logger.info(f"📱 FCM: Order ID: {order_id}")
            logger.info(f"📱 FCM: Total Amount: ₹{total_amount:,.2f}")
            logger.info(f"📱 FCM: Items Count: {items_count}")
            logger.info(f"📱 FCM: Store Name: {store_name or 'N/A'}")
            logger.info(f"📱 FCM: Token (first 30 chars): {fcm_token[:30]}...")
            logger.info("="*60)
            
            # Check if Firebase is initialized
            if not firebase_admin._apps:
                logger.error("❌ FCM: Firebase not initialized. Cannot send notification.")
                logger.error("❌ FCM: Did firebase-service-account.json load correctly?")
                return False
            
            logger.info("✅ FCM: Firebase is initialized, preparing message...")
            
            # Prepare notification message with Al-Mathina branding
            title = "🎉 Order Received!"
            body = f"Your order #{order_id[-6:]} for ₹{total_amount:,.2f} has been placed successfully."
            
            if store_name:
                body += f"\n\nThank you, {store_name}! 🙏"
            
            logger.info(f"📝 FCM: Title: {title}")
            logger.info(f"📝 FCM: Body: {body}")
            
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
                    'user_phone': user_phone or '',
                    'total_amount': str(total_amount),
                    'items_count': str(items_count),
                    'timestamp': str(int(os.times().elapsed * 1000)),
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK'
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
            
            logger.info("📤 FCM: Sending message to Firebase...")
            # Send message
            response = messaging.send(message)
            logger.info(f"✅ FCM: Push notification sent successfully!")
            logger.info(f"✅ FCM: Firebase response: {response}")
            logger.info(f"✅ FCM: Order: {order_id}")
            logger.info("="*60 + "\n")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ FCM: Failed to send push notification")
            logger.error(f"❌ FCM: Error: {str(e)}")
            logger.error(f"❌ FCM: Error type: {type(e).__name__}")
            logger.error(f"❌ FCM: Order: {order_id}")
            logger.error(f"❌ FCM: Token: {fcm_token[:30] if fcm_token else 'None'}...")
            import traceback
            logger.error(f"❌ FCM: Traceback: {traceback.format_exc()}")
            logger.error("="*60 + "\n")
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
