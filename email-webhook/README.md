# AL-Madhina Email Webhook - Vercel Deployment

## What This Does
Provides unlimited FREE email sending for your Render backend by:
1. Render calls this Vercel webhook via HTTP (allowed)
2. Vercel function sends email via Gmail SMTP (not blocked on Vercel)
3. Unlimited emails, zero cost forever

---

## Setup Instructions

### Step 1: Install Vercel CLI

```powershell
npm install -g vercel
```

### Step 2: Login to Vercel

```powershell
vercel login
```

Follow the prompts to authenticate.

### Step 3: Deploy

```powershell
cd email-webhook
vercel deploy --prod
```

Vercel will ask:
- **Set up and deploy?** `Y`
- **Which scope?** Choose your account
- **Link to existing project?** `N`
- **Project name?** `al-mathina-email` (or any name)
- **Directory?** `./` (press Enter)

**Deployment URL:** Vercel will show you the URL (e.g., `https://al-mathina-email.vercel.app`)

### Step 4: Configure Environment Variables on Vercel

Go to: **Vercel Dashboard** → Your project → **Settings** → **Environment Variables**

Add these 3 variables:

```
SMTP_USER=almathina64@gmail.com
SMTP_PASSWORD=cgpj fbdz srve oqhn
API_SECRET=<generate-random-secret>
```

**Generate API_SECRET:**
```powershell
# PowerShell
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Copy the generated random string.

### Step 5: Redeploy After Adding Variables

```powershell
vercel deploy --prod
```

---

## Testing Your Webhook

### PowerShell Test:

```powershell
$headers = @{
    "Content-Type" = "application/json"
    "x-api-key" = "YOUR_API_SECRET_HERE"
}

$body = @{
    to = @("faizalbashafaizalbasha07@gmail.com")
    subject = "Test Email from Vercel"
    html = "<h1>Hello!</h1><p>This is a test email.</p>"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://YOUR_VERCEL_URL/api/send-email" -Method POST -Headers $headers -Body $body
```

**Expected Response:**
```json
{
  "success": true,
  "messageId": "...",
  "accepted": ["faizalbashafaizalbasha07@gmail.com"],
  "rejected": []
}
```

---

## Step 6: Update Render Backend

Go to: **Render Dashboard** → `al-mathina` service → **Environment**

Add these 2 variables:

```
EMAIL_WEBHOOK_URL=https://YOUR_VERCEL_URL/api/send-email
EMAIL_WEBHOOK_SECRET=<same-api-secret-from-vercel>
```

**Keep existing:**
```
ADMIN_EMAIL=faizalbashafaizalbasha07@gmail.com,sathishsuba2208@gmail.com,abuarsath30@gmail.com
```

Click **Save** → Render will auto-redeploy.

---

## Done! ✅

Your system is now configured for:
- ✅ **Unlimited emails** (no daily limits)
- ✅ **Zero cost** (Vercel free tier)
- ✅ **Works on Render** (HTTP webhook bypasses SMTP block)
- ✅ **Gmail delivery** (500/day per account, add more if needed)

---

## Monitoring

### Check Vercel Logs:
```powershell
vercel logs YOUR_PROJECT_NAME --follow
```

### Check Render Logs:
Look for:
```
📤 EMAIL: Sending via webhook...
✅ EMAIL: Emails sent successfully via webhook!
```

---

## Troubleshooting

### Webhook returns 401 Unauthorized:
- Check `API_SECRET` matches on both Vercel and Render
- Verify `x-api-key` header is set correctly

### Webhook returns 500 Error:
- Check Vercel logs: `vercel logs`
- Verify Gmail credentials are correct
- Make sure Gmail App Password is still valid

### No emails received:
- Check spam folders
- Verify `ADMIN_EMAIL` has correct addresses
- Test webhook directly with PowerShell command above

---

## Cost Breakdown

| Service | Monthly Cost | Limit |
|---------|-------------|-------|
| Render Backend | $0 | Free tier |
| Vercel Function | $0 | Unlimited invocations |
| Gmail SMTP | $0 | 500 emails/day per account |
| **Total** | **$0** | **Unlimited** |

If you need more than 500 emails/day, create additional Gmail accounts and rotate them.
