"""
Email Notification Service for AL-Madhina
Sends order notification emails via Vercel Webhook (unlimited, free)
"""

import os
from typing import List, Optional
import logging
import httpx

logger = logging.getLogger(__name__)


class EmailService:
    """
    Singleton service for sending email notifications
    Uses Vercel webhook for unlimited free emails
    """
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(EmailService, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not self._initialized:
            self._initialize()
            EmailService._initialized = True
    
    def _initialize(self):
        """Initialize email configuration"""
        try:
            logger.info("📧 EMAIL: Starting initialization...")
            
            # Get Vercel webhook configuration
            webhook_base = os.getenv('EMAIL_WEBHOOK_URL', '').strip()
            
            # Build full webhook URL if not already complete
            if webhook_base:
                if not webhook_base.startswith('http'):
                    # Add https:// and endpoint path
                    self.webhook_url = f"https://{webhook_base}/api/send-email"
                elif not webhook_base.endswith('/api/send-email'):
                    # Add endpoint path if missing
                    self.webhook_url = f"{webhook_base}/api/send-email"
                else:
                    self.webhook_url = webhook_base
            else:
                self.webhook_url = ''
            
            self.webhook_secret = os.getenv('EMAIL_WEBHOOK_SECRET', '')
            
            # Admin emails - multiple recipients supported
            admin_emails_env = os.getenv('ADMIN_EMAIL', '')
            
            if admin_emails_env:
                self.admin_emails = [email.strip() for email in admin_emails_env.split(',') if email.strip()]
                logger.info(f"ℹ️ EMAIL: Using admin emails from env: {len(self.admin_emails)} recipients")
            else:
                # Fallback to default admin emails
                self.admin_emails = [
                    'faizalbashafaizalbasha07@gmail.com',
                    'sathishsuba2208@gmail.com',
                    'abuarsath30@gmail.com' 
                ]
                logger.info("ℹ️ EMAIL: Using default admin emails (3 recipients)")
            
            # Check if webhook is configured
            if self.webhook_url and self.webhook_secret:
                self.enabled = True
                logger.info("✅ EMAIL: Using Vercel webhook (unlimited, free)")
                logger.info(f"✅ EMAIL: Webhook: {self.webhook_url}")
                logger.info(f"✅ EMAIL: Recipients: {', '.join(self.admin_emails)}")
            else:
                self.enabled = False
                logger.warning("⚠️ EMAIL: Webhook not configured")
                logger.warning("⚠️ EMAIL: Set EMAIL_WEBHOOK_URL and EMAIL_WEBHOOK_SECRET")
                logger.warning("⚠️ EMAIL: Email notifications will be disabled")
            
        except Exception as e:
            logger.error(f"❌ EMAIL: Failed to initialize: {str(e)}")
            self.enabled = False
    
    def is_enabled(self) -> bool:
        """Check if email service is enabled"""
        return self.enabled
    
    async def send_order_notification_to_admin(
        self,
        order_id: str,
        user_phone: str,
        store_name: Optional[str],
        items: List[dict],
        total_amount: float,
        delivery_address: dict,
        payment_method: str
    ) -> bool:
        """
        Send order notification email to admin
        
        Args:
            order_id: Order ID
            user_phone: Customer phone number
            store_name: Customer store name
            items: List of order items
            total_amount: Total order amount
            delivery_address: Delivery address details
            payment_method: Payment method
        
        Returns:
            bool: True if email sent successfully
        """
        if not self.enabled:
            logger.warning("⚠️ EMAIL: Service not enabled (webhook not configured)")
            logger.warning("⚠️ EMAIL: Set EMAIL_WEBHOOK_URL and EMAIL_WEBHOOK_SECRET on Render")
            print("⚠️ EMAIL: Service disabled - skipping", flush=True)
            return False
        
        try:
            logger.info("\n" + "="*60)
            logger.info("📧 EMAIL: Sending admin notification via webhook")
            logger.info(f"📧 EMAIL: Order ID: {order_id}")
            logger.info(f"📧 EMAIL: Customer: {store_name or 'N/A'} ({user_phone})")
            logger.info(f"📧 EMAIL: Total: ₹{total_amount:,.2f}")
            logger.info("="*60)
            
            # Create email content
            subject = f"🛒 New Order Received - {order_id}"
            
            # Build items list HTML
            items_html = ""
            for idx, item in enumerate(items, 1):
                item_name = item.get('name', 'Unknown')
                quantity = item.get('quantity', 1)
                price = item.get('price', 0)
                total = quantity * price
                items_html += f"""
                <tr>
                    <td style="padding: 8px; border-bottom: 1px solid #ddd;">{idx}</td>
                    <td style="padding: 8px; border-bottom: 1px solid #ddd;">{item_name}</td>
                    <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">{quantity}</td>
                    <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹{price:,.2f}</td>
                    <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹{total:,.2f}</td>
                </tr>
                """
            
            # Build address HTML
            address_parts = []
            if delivery_address.get('street'):
                address_parts.append(delivery_address['street'])
            if delivery_address.get('city'):
                address_parts.append(delivery_address['city'])
            if delivery_address.get('state'):
                address_parts.append(delivery_address['state'])
            if delivery_address.get('pincode'):
                address_parts.append(f"PIN: {delivery_address['pincode']}")
            if delivery_address.get('landmark'):
                address_parts.append(f"Landmark: {delivery_address['landmark']}")
            
            address_html = "<br>".join(address_parts) if address_parts else "Not provided"
            
            # Order management link
            order_link = f"https://al-mathina.onrender.com/admin/orders?order_id={order_id}"
            
            # HTML email body
            html_body = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                    .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                    .header {{ background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; }}
                    .content {{ background: #f8f9fa; padding: 20px; }}
                    .order-details {{ background: white; padding: 15px; border-radius: 5px; margin: 15px 0; }}
                    .table {{ width: 100%; border-collapse: collapse; margin: 15px 0; }}
                    .table th {{ background: #28a745; color: white; padding: 10px; text-align: left; }}
                    .total {{ font-size: 18px; font-weight: bold; color: #28a745; text-align: right; padding: 10px 0; }}
                    .button {{ display: inline-block; background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 15px 0; }}
                    .footer {{ background: #e9ecef; padding: 15px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #6c757d; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1 style="margin: 0;">🛒 New Order Received!</h1>
                        <p style="margin: 5px 0 0 0;">Order ID: <strong>{order_id}</strong></p>
                    </div>
                    
                    <div class="content">
                        <div class="order-details">
                            <h2 style="color: #28a745; margin-top: 0;">Customer Information</h2>
                            <p><strong>Store Name:</strong> {store_name or 'Not provided'}</p>
                            <p><strong>Phone:</strong> {user_phone}</p>
                            <p><strong>Payment Method:</strong> {payment_method.upper()}</p>
                        </div>
                        
                        <div class="order-details">
                            <h2 style="color: #28a745; margin-top: 0;">Delivery Address</h2>
                            <p>{address_html}</p>
                        </div>
                        
                        <div class="order-details">
                            <h2 style="color: #28a745; margin-top: 0;">Order Items</h2>
                            <table class="table">
                                <thead>
                                    <tr>
                                        <th>#</th>
                                        <th>Item</th>
                                        <th style="text-align: center;">Qty</th>
                                        <th style="text-align: right;">Price</th>
                                        <th style="text-align: right;">Total</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {items_html}
                                </tbody>
                            </table>
                            <div class="total">
                                Total Amount: ₹{total_amount:,.2f}
                            </div>
                        </div>
                        
                        <div style="text-align: center;">
                            <a href="{order_link}" class="button">
                                📋 View Order in Admin Panel
                            </a>
                            <p style="font-size: 12px; color: #6c757d;">
                                Click the button above to manage this order
                            </p>
                        </div>
                    </div>
                    
                    <div class="footer">
                        <p>AL-Madhina Wholesale Management System</p>
                        <p>This is an automated notification. Please do not reply to this email.</p>
                    </div>
                </div>
            </body>
            </html>
            """
            

            
            # Send via Vercel webhook
            logger.info(f"📧 EMAIL: Sending to {len(self.admin_emails)} recipient(s):")
            for idx, email in enumerate(self.admin_emails, 1):
                logger.info(f"   {idx}. {email}")
            print(f"📧 EMAIL: Recipients: {', '.join(self.admin_emails)}", flush=True)
            
            # Prepare webhook payload
            payload = {
                'to': self.admin_emails,
                'subject': subject,
                'html': html_body
            }
            
            headers = {
                'Content-Type': 'application/json',
                'x-api-key': self.webhook_secret
            }
            
            logger.info(f"📤 EMAIL: Calling webhook: {self.webhook_url}")
            print(f"📤 EMAIL: Sending via webhook...", flush=True)
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    self.webhook_url,
                    json=payload,
                    headers=headers
                )
                
                if response.status_code == 200:
                    result = response.json()
                    logger.info(f"✅ EMAIL: Webhook successful: {result}")
                    print(f"✅ EMAIL: Emails sent successfully via webhook!", flush=True)
                    logger.info("="*60 + "\n")
                    return True
                else:
                    logger.error(f"❌ EMAIL: Webhook failed: {response.status_code}")
                    logger.error(f"❌ EMAIL: Response: {response.text}")
                    print(f"❌ EMAIL: Webhook failed with status {response.status_code}", flush=True)
                    return False
            
        except Exception as e:
            logger.error(f"❌ EMAIL: Failed to send notification")
            logger.error(f"❌ EMAIL: Error: {str(e)}")
            logger.error(f"❌ EMAIL: Error type: {type(e).__name__}")
            import traceback
            logger.error(f"❌ EMAIL: Traceback: {traceback.format_exc()}")
            logger.error("="*60 + "\n")
            return False


# Singleton instance
email_service = EmailService()
