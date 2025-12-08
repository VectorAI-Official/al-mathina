# Email Notification Setup Guide

## Overview
Email notifications are sent to admin when customers place orders. The system uses Gmail's free SMTP service.

## Gmail SMTP Configuration

### Step 1: Enable 2-Factor Authentication
1. Go to: https://myaccount.google.com/security
2. Enable "2-Step Verification"
3. Complete the setup process

### Step 2: Generate App Password
1. Go to: https://myaccount.google.com/apppasswords
2. Select app: "Mail"
3. Select device: "Other (Custom name)"
4. Enter name: "AL-Madhina Backend"
5. Click "Generate"
6. **Copy the 16-character password** (no spaces)

### Step 3: Configure Environment Variables on Render

1. **Go to Render Dashboard**: https://dashboard.render.com
2. **Select service**: `al-mathina`
3. **Click "Environment" tab**
4. **Add these environment variables**:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx  # 16-char app password from Step 2
ADMIN_EMAIL=your-email@gmail.com  # Email to receive order notifications
```

**Example:**
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=almathina.orders@gmail.com
SMTP_PASSWORD=abcd efgh ijkl mnop
ADMIN_EMAIL=admin@almathina.com
```

5. **Click "Save Changes"**
6. **Wait for auto-redeploy** (~2 minutes)

### Step 4: Verify Setup

After deployment, check Render logs for:
```
✅ EMAIL: Configured to send from: your-email@gmail.com
✅ EMAIL: Admin notifications to: admin@almathina.com
```

If not configured:
```
⚠️ EMAIL: SMTP credentials not configured
⚠️ EMAIL: Email notifications will be disabled
```

## Test Email Notification

1. **Place a test order** from the Flutter app
2. **Check Render logs** for:
   ```
   📧 EMAIL: Sending admin notification...
   📤 EMAIL: Connecting to smtp.gmail.com:587...
   🔐 EMAIL: Authenticating...
   📨 EMAIL: Sending message...
   ✅ EMAIL: Notification sent successfully
   ```

3. **Check admin email inbox** for:
   - Subject: "🛒 New Order Received - ORD-XXXXXXXX"
   - Beautiful HTML email with order details
   - "View Order in Admin Panel" button

## Email Features

### Email Content Includes:
- ✅ Order ID with direct link
- ✅ Customer information (store name, phone)
- ✅ Payment method
- ✅ Complete delivery address
- ✅ Itemized order list with quantities and prices
- ✅ Total amount (formatted with ₹ symbol)
- ✅ One-click button to view order in admin panel

### Email Design:
- 📱 Mobile-responsive HTML
- 🎨 AL-Mathina brand colors (green gradient)
- 🔗 Direct link to order: `https://al-mathina.onrender.com/admin/orders?order_id=ORD-XXXXX`
- ✨ Professional styling with tables and formatting

## Troubleshooting

### Issue: "Username and Password not accepted"
**Solution**: Make sure you're using an App Password, not your regular Gmail password

### Issue: "SMTP Authentication Error"
**Solution**: 
1. Verify 2FA is enabled on Gmail account
2. Generate a new App Password
3. Copy it without spaces
4. Update SMTP_PASSWORD on Render

### Issue: Email not received
**Solution**:
1. Check spam/junk folder
2. Verify ADMIN_EMAIL is correct
3. Check Render logs for error messages
4. Try sending a test email using Python locally

### Issue: Email service disabled
**Solution**: 
1. Verify all environment variables are set on Render
2. Check logs for "SMTP credentials not configured"
3. Make sure SMTP_USER and SMTP_PASSWORD are not empty

## Alternative Email Providers

If you prefer not to use Gmail, you can use:

### SendGrid (Free: 100 emails/day)
```bash
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=<your-sendgrid-api-key>
```

### Mailgun (Free: 5000 emails/month)
```bash
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USER=<your-mailgun-user>
SMTP_PASSWORD=<your-mailgun-password>
```

### Outlook/Hotmail
```bash
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USER=your-email@outlook.com
SMTP_PASSWORD=<your-password>
```

## Security Notes

- ✅ App passwords are safer than regular passwords
- ✅ App passwords can be revoked anytime
- ✅ Never commit SMTP credentials to git
- ✅ Use Render environment variables (encrypted at rest)
- ✅ Rotate App Password every 3-6 months

## Order Link Behavior

When admin clicks "View Order in Admin Panel" button:
1. Opens: `https://al-mathina.onrender.com/admin/orders?order_id=ORD-XXXXX`
2. Admin page loads with order management interface
3. The specific order card with matching ID is automatically highlighted/opened
4. Admin can immediately update order status, view details, or take action

---

**Created**: December 8, 2025  
**Status**: Ready for configuration
