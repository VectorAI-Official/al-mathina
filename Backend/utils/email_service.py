"""
Email Notification Service for AL-Madhina
Sends order notification emails to admin
"""

import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)


class EmailService:
    """
    Singleton service for sending email notifications
    Uses Gmail SMTP (free tier)
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
            
            # Get email credentials from environment variables
            self.smtp_host = os.getenv('SMTP_HOST', 'smtp.gmail.com')
            self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
            self.smtp_user = os.getenv('SMTP_USER', '')  # Your Gmail address
            self.smtp_password = os.getenv('SMTP_PASSWORD', '')  # App-specific password
            
            # Admin emails - multiple recipients supported
            admin_emails_env = os.getenv('ADMIN_EMAIL', self.smtp_user)
            # Split by comma if multiple emails provided
            self.admin_emails = [email.strip() for email in admin_emails_env.split(',') if email.strip()]
            
            # Fallback to default admin emails if not configured
            if not self.admin_emails or not any(self.admin_emails):
                self.admin_emails = [
                    'faizalbashafaizalbasha07@gmail.com',
                    'sathishsuba2208@gmail.com',
                    'abuarsath30@gmail.com' 
                ]
                logger.info("ℹ️ EMAIL: Using default admin emails")
            
            if not self.smtp_user or not self.smtp_password:
                logger.warning("⚠️ EMAIL: SMTP credentials not configured")
                logger.warning("⚠️ EMAIL: Set SMTP_USER and SMTP_PASSWORD environment variables")
                logger.warning("⚠️ EMAIL: Email notifications will be disabled")
                self.enabled = False
            else:
                logger.info(f"✅ EMAIL: Configured to send from: {self.smtp_user}")
                logger.info(f"✅ EMAIL: Admin notifications to: {', '.join(self.admin_emails)}")
                self.enabled = True
            
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
            logger.warning("⚠️ EMAIL: Service not enabled (credentials missing)")
            logger.warning("⚠️ EMAIL: Set SMTP_USER and SMTP_PASSWORD on Render")
            print("⚠️ EMAIL: Service disabled - skipping", flush=True)
            return False
        
        try:
            logger.info("\n" + "="*60)
            logger.info("📧 EMAIL: Sending admin notification")
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
            
            # Create message
            message = MIMEMultipart('alternative')
            message['From'] = self.smtp_user
            message['To'] = ', '.join(self.admin_emails)
            message['Subject'] = subject
            
            # Attach HTML body
            html_part = MIMEText(html_body, 'html')
            message.attach(html_part)
            
            # Log recipient emails before sending
            logger.info(f"📧 EMAIL: Preparing to send to {len(self.admin_emails)} recipient(s):")
            for idx, email in enumerate(self.admin_emails, 1):
                logger.info(f"   {idx}. {email}")
            print(f"📧 EMAIL: Recipients: {', '.join(self.admin_emails)}", flush=True)
            
            # Send email to all admin recipients with timeout
            logger.info(f"📤 EMAIL: Connecting to {self.smtp_host}:{self.smtp_port}...")
            print(f"📤 EMAIL: Connecting to SMTP server...", flush=True)
            
            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30) as server:
                logger.info("🔐 EMAIL: Starting TLS...")
                print("🔐 EMAIL: Securing connection...", flush=True)
                server.starttls()
                
                logger.info("🔐 EMAIL: Authenticating...")
                print("🔐 EMAIL: Logging in...", flush=True)
                server.login(self.smtp_user, self.smtp_password)
                
                logger.info(f"📨 EMAIL: Sending to {len(self.admin_emails)} recipient(s)...")
                print(f"📨 EMAIL: Sending to {len(self.admin_emails)} admins...", flush=True)
                
                for idx, admin_email in enumerate(self.admin_emails, 1):
                    try:
                        server.sendmail(self.smtp_user, admin_email, message.as_string())
                        logger.info(f"   ✓ [{idx}/{len(self.admin_emails)}] Sent to: {admin_email}")
                        print(f"   ✓ Sent to: {admin_email}", flush=True)
                    except Exception as send_error:
                        logger.error(f"   ✗ [{idx}/{len(self.admin_emails)}] Failed to send to {admin_email}: {send_error}")
                        print(f"   ✗ Failed: {admin_email}", flush=True)
            
            logger.info(f"✅ EMAIL: Notification process completed")
            logger.info(f"✅ EMAIL: All recipients: {', '.join(self.admin_emails)}")
            print(f"✅ EMAIL: Emails sent successfully!", flush=True)
            logger.info("="*60 + "\n")
            return True
            
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
