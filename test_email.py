#!/usr/bin/env python3
"""Test email sending with Gmail SMTP"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

SMTP_USER = "almathina64@gmail.com"
SMTP_PASSWORD = "cgpj fbdz srve oqhn"  # Gmail App Password
TO_EMAIL = "faizalbashafaizalbasha07@gmail.com"

print("🧪 Testing Email Send...")
print(f"From: {SMTP_USER}")
print(f"To: {TO_EMAIL}")

try:
    # Create SMTP connection
    print("\n📧 Connecting to Gmail SMTP...")
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    print("✅ Connected")

    # Login
    print("🔐 Logging in...")
    server.login(SMTP_USER, SMTP_PASSWORD)
    print("✅ Logged in")

    # Create email
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Test Email from AL-Mathina"
    msg["From"] = SMTP_USER
    msg["To"] = TO_EMAIL

    html = """\
    <html>
      <body>
        <h1>✅ Test Email Successful!</h1>
        <p>This email was sent from your local machine.</p>
        <p>Gmail SMTP credentials are working correctly.</p>
      </body>
    </html>
    """

    part = MIMEText(html, "html")
    msg.attach(part)

    # Send
    print("📤 Sending email...")
    server.sendmail(SMTP_USER, TO_EMAIL, msg.as_string())
    print("✅ Email sent successfully!")

    server.quit()

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
