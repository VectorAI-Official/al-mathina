"""
Test SMTP Email Configuration
Sends a test email to verify Gmail SMTP setup
"""

import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# SMTP Configuration (same as in email_service.py)
SMTP_HOST = 'smtp.gmail.com'
SMTP_PORT = 587
SMTP_USER = 'almathina64@gmail.com'
SMTP_PASSWORD = 'cgpj fbdz srve oqhn'

# Test recipient
TEST_RECIPIENT = 'faizalbashafaizalbasha07@gmail.com'

def test_smtp():
    """Test SMTP connection and email sending"""
    print("\n" + "="*60)
    print("🧪 SMTP EMAIL TEST")
    print("="*60)
    
    print(f"\n📧 Configuration:")
    print(f"   Host: {SMTP_HOST}:{SMTP_PORT}")
    print(f"   From: {SMTP_USER}")
    print(f"   To: {TEST_RECIPIENT}")
    print(f"   Password: {'*' * len(SMTP_PASSWORD)} (masked)")
    
    try:
        # Create test email
        message = MIMEMultipart('alternative')
        message['From'] = SMTP_USER
        message['To'] = TEST_RECIPIENT
        message['Subject'] = f"🧪 Test Email - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        html_body = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 20px; border-radius: 8px; }
                .content { background: #f8f9fa; padding: 20px; margin-top: 20px; border-radius: 8px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 style="margin: 0;">🧪 SMTP Test Email</h1>
                    <p style="margin: 5px 0 0 0;">AL-Madhina Email Service Test</p>
                </div>
                <div class="content">
                    <h2 style="color: #28a745;">✅ Email Configuration Working!</h2>
                    <p>This is a test email from the AL-Madhina backend to verify SMTP configuration.</p>
                    <p><strong>Sender:</strong> almathina64@gmail.com</p>
                    <p><strong>Time:</strong> """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</p>
                    <p>If you received this email, the SMTP configuration is working correctly.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        html_part = MIMEText(html_body, 'html')
        message.attach(html_part)
        
        print(f"\n📤 Step 1: Connecting to {SMTP_HOST}:{SMTP_PORT}...")
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
            print("✅ Step 1: Connected!")
            
            print("\n🔐 Step 2: Starting TLS encryption...")
            server.starttls()
            print("✅ Step 2: TLS enabled!")
            
            print("\n🔐 Step 3: Authenticating...")
            server.login(SMTP_USER, SMTP_PASSWORD)
            print("✅ Step 3: Authenticated!")
            
            print(f"\n📨 Step 4: Sending email to {TEST_RECIPIENT}...")
            server.sendmail(SMTP_USER, TEST_RECIPIENT, message.as_string())
            print("✅ Step 4: Email sent!")
        
        print("\n" + "="*60)
        print("🎉 SUCCESS! Test email sent successfully!")
        print("="*60)
        print(f"\n📬 Check inbox: {TEST_RECIPIENT}")
        print("   (Also check spam folder)")
        print()
        
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print("\n" + "="*60)
        print("❌ AUTHENTICATION FAILED!")
        print("="*60)
        print(f"\nError: {e}")
        print("\n🔧 Possible fixes:")
        print("   1. Verify the App Password is correct")
        print("   2. Generate a new App Password at:")
        print("      https://myaccount.google.com/apppasswords")
        print("   3. Make sure 2-Step Verification is enabled")
        print()
        return False
        
    except smtplib.SMTPException as e:
        print("\n" + "="*60)
        print("❌ SMTP ERROR!")
        print("="*60)
        print(f"\nError: {e}")
        print(f"Error type: {type(e).__name__}")
        print()
        return False
        
    except Exception as e:
        print("\n" + "="*60)
        print("❌ UNEXPECTED ERROR!")
        print("="*60)
        print(f"\nError: {e}")
        print(f"Error type: {type(e).__name__}")
        
        import traceback
        print("\nTraceback:")
        print(traceback.format_exc())
        print()
        return False

if __name__ == "__main__":
    test_smtp()
