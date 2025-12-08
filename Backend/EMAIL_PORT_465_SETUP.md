# Email Configuration for Render - Port 465 SSL Setup

## Problem Solved
Render blocks SMTP port 587 (TLS), causing `Network is unreachable` error.

## Solution
Use port 465 with SSL instead of port 587 with TLS (100% free, no third-party services needed).

---

## Step 1: Update Render Environment Variables

Go to: **Render Dashboard → al-mathina service → Environment**

### Update/Add these variables:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USE_SSL=true
SMTP_USER=almathina64@gmail.com
SMTP_PASSWORD=cgpj fbdz srve oqhn
ADMIN_EMAIL=faizalbashafaizalbasha07@gmail.com,sathishsuba2208@gmail.com,abuarsath30@gmail.com
```

### Important Notes:
- ✅ **SMTP_PORT** changed from 587 → **465**
- ✅ **SMTP_USE_SSL** set to **true** (new variable)
- ✅ **ADMIN_EMAIL** added with 3 recipients (comma-separated, no spaces after commas)
- ✅ **SMTP_PASSWORD** is the Gmail App Password (same as before)

---

## Step 2: Save and Redeploy

1. Click **"Save Changes"** in Render environment variables
2. Render will automatically redeploy (takes ~2 minutes)
3. Watch deployment logs for success

---

## Step 3: Test Email Delivery

1. Place a test order from Flutter app
2. Check Render logs for:
   ```
   📤 EMAIL: Connecting to SMTP server (SSL)...
   🔐 EMAIL: SSL connection established
   🔐 EMAIL: Logging in...
   📨 EMAIL: Sending to 3 admins...
      ✓ Sent to: faizalbashafaizalbasha07@gmail.com
      ✓ Sent to: sathishsuba2208@gmail.com
      ✓ Sent to: abuarsath30@gmail.com
   ✅ EMAIL: Emails sent successfully!
   ```

3. Check all 3 inboxes (and spam folders)

---

## What Changed in Code

### Before (Port 587 - TLS):
```python
with smtplib.SMTP('smtp.gmail.com', 587, timeout=30) as server:
    server.starttls()  # Start TLS encryption
    server.login(...)
```

### After (Port 465 - SSL):
```python
server = smtplib.SMTP_SSL('smtp.gmail.com', 465, timeout=30)
try:
    server.login(...)  # Already encrypted via SSL
finally:
    server.quit()
```

---

## Why Port 465 Works on Render

- ✅ Port 465 uses **SMTP_SSL** (encrypted from start)
- ✅ Port 587 uses **SMTP + STARTTLS** (Render blocks this)
- ✅ Many cloud hosts allow 465 but block 587
- ✅ Gmail supports both ports equally
- ✅ 100% free, no third-party services needed

---

## Troubleshooting

### If you still get "Network unreachable":
Render may block both ports. Alternative solutions:
1. Use Render's outbound proxy (if available)
2. Switch to transactional email service (SendGrid, Mailgun)
3. Use webhooks to external email service

### If emails go to spam:
1. Add SPF record to domain DNS (if using custom domain)
2. Use Gmail's "Less secure app" setting (not recommended)
3. Consider domain-based email instead of @gmail.com

### Check logs show only 1 recipient instead of 3:
Make sure `ADMIN_EMAIL` has **no spaces** after commas:
```
✅ Correct: email1@test.com,email2@test.com,email3@test.com
❌ Wrong:   email1@test.com, email2@test.com, email3@test.com
```

---

## Testing Locally

The same configuration works locally:

```powershell
cd Backend
python test_smtp.py
```

Should show:
```
🔐 EMAIL: SSL connection established
✅ Step 3: Authenticated!
📨 Step 4: Sending email...
✅ Step 4: Email sent!
```

---

## Zero Cost Solution ✅

This solution is **completely free**:
- ✅ No SendGrid API
- ✅ No Mailgun subscription
- ✅ No Resend account
- ✅ Uses existing Gmail account
- ✅ Works within Gmail's free limits (500 emails/day)

Perfect for your use case!
