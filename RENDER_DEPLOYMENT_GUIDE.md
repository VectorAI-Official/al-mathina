# Render.com Backend Deployment Guide (Free Trial)

## ✅ Quick Overview

**Render** is perfect for deploying FastAPI backends:
- ✅ Free tier available
- ✅ No credit card required for free trial
- ✅ Easy GitHub integration
- ✅ Auto-deploys from Git
- ✅ Great for development & testing
- ✅ Easy to scale up when needed

---

## 🚀 Step-by-Step Deployment

### **Step 1: Create Render Account (Free)**

1. Go to https://render.com
2. Click **"Sign Up"** (top right)
3. Choose: **Sign up with GitHub** (recommended)
   - Or email if you prefer
4. **No credit card required** for free tier ✅

---

### **Step 2: Prepare Your Backend**

1. Make sure your backend is **cleaned** ✅ (Already done!)
2. Verify these files exist in `/Backend`:
   - `Dockerfile` ✅
   - `requirements.txt` ✅
   - `main_production.py` ✅
   - `config_production.py` ✅

3. **Important:** Verify your `Dockerfile` looks like this:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Make sure it listens on 0.0.0.0:8080
CMD ["uvicorn", "main_production:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

### **Step 3: Push Code to GitHub**

1. Make sure your repo is on GitHub: https://github.com/VectorAI-Official/al-mathina
2. Commit your cleaned backend:

```powershell
cd Backend
git add -A
git commit -m "Backend cleanup for production deployment"
git push
```

---

### **Step 4: Create Render Service**

1. Log in to **Render Dashboard**: https://dashboard.render.com
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository:
   - Search for: **al-mathina**
   - Click **"Connect"**

---

### **Step 5: Configure Service**

**Fill in these settings:**

| Setting | Value |
|---------|-------|
| **Name** | `almathina-backend` (or any name) |
| **Environment** | `Docker` |
| **Region** | Choose closest to you (e.g., `Singapore` for better latency) |
| **Branch** | `main` |
| **Root Directory** | `Backend` ⚠️ **IMPORTANT** |
| **Plan** | `Free` (or `Pay-as-you-go` if free tier full) |

---

### **Step 6: Add Environment Variables**

Click **"Advanced"** and add your secrets:

```
MONGODB_URI = mongodb+srv://your-username:password@cluster.mongodb.net/?retryWrites=true&w=majority
CLOUDINARY_CLOUD_NAME = your-cloudinary-name
CLOUDINARY_API_KEY = your-api-key
CLOUDINARY_API_SECRET = your-api-secret
ENVIRONMENT = production
DEBUG = false
```

**⚠️ IMPORTANT:** Do NOT put these in code. Add them here in Render dashboard.

---

### **Step 7: Deploy**

1. Click **"Create Web Service"**
2. Wait for deployment (should take 2-5 minutes)
3. You'll see logs in real-time
4. When done, you'll get a URL like: `https://almathina-backend.onrender.com`

---

## ✅ Verify Deployment

Once deployed, test your endpoints:

```powershell
# Test 1: Health check
Invoke-WebRequest "https://almathina-backend.onrender.com/health" | Select-Object StatusCode

# Test 2: Get home data
Invoke-WebRequest "https://almathina-backend.onrender.com/api/flutter/home" | Select-Object -ExpandProperty Content

# Test 3: Get products
Invoke-WebRequest "https://almathina-backend.onrender.com/api/flutter/products?skip=0&limit=10" | Select-Object -ExpandProperty Content

# Test 4: Create order
$body = @{
    phone = "1234567890"
    items = @(@{ product_id = "test"; quantity = 1; price = 100 })
    total_amount = 100
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://almathina-backend.onrender.com/api/flutter/user/orders" -Method POST -Body $body -ContentType "application/json"
```

---

## 📱 Update Flutter App

Once you have your Render URL, update Flutter to use it:

**File:** `flutter_preview/lib/api_service.dart`

Find this line:
```dart
static const String baseUrl = 'http://192.168.1.6:8000';
```

Change to:
```dart
static const String baseUrl = 'https://almathina-backend.onrender.com';
```

Then run:
```powershell
cd flutter_preview
flutter pub get
flutter run -d RZ8NA1WCLWL
```

---

## 🆓 Free Tier Limitations

| Feature | Free Tier |
|---------|-----------|
| **Requests/month** | Unlimited ✅ |
| **Memory** | 512MB |
| **CPU** | Shared |
| **Auto-sleep** | ⚠️ Sleeps after 15 min of inactivity |
| **Duration** | 3 months of continuous free use |
| **Cost** | $0 |

**Note:** Free tier spins down after 15 minutes of inactivity. First request after sleep takes ~30 seconds to wake up.

---

## 💳 After Free Trial (Optional)

When free trial ends (3 months):
- Upgrade to **Pay-as-you-go**: ~$7-10/month
- Same as Fly.io pricing
- Or switch to Fly.io later

---

## 🔧 Troubleshooting

### **Deployment Failed**

1. Check logs in Render dashboard
2. Common issues:
   - Missing `Dockerfile` in Backend folder
   - `requirements.txt` has invalid packages
   - `main_production.py` not found

### **Can't Connect to MongoDB**

- Verify `MONGODB_URI` is correct
- Check MongoDB Atlas allows external connections
- IP whitelist in MongoDB Atlas: Set to `0.0.0.0/0` (allow all)

### **Cloudinary errors**

- Verify credentials are correct
- Check secret values have no extra spaces

### **Service sleeping after 15 min**

- This is normal on free tier
- Use paid plan if you need always-on
- Or use Render's paid option

---

## 📋 Deployment Checklist

- [ ] Render account created (free)
- [ ] GitHub repo has `Backend` directory
- [ ] `Dockerfile` exists in Backend
- [ ] `requirements.txt` exists in Backend
- [ ] `main_production.py` exists in Backend
- [ ] Code pushed to GitHub
- [ ] MongoDB URI ready
- [ ] Cloudinary credentials ready
- [ ] Created Web Service on Render
- [ ] Environment variables added to Render
- [ ] Deployment successful (check logs)
- [ ] Tested endpoints (health check works)
- [ ] Updated Flutter app with Render URL
- [ ] Flutter app can create orders

---

## 🚀 Quick Summary

**What you do:**
1. Create free Render account
2. Connect GitHub repo
3. Add environment variables
4. Deploy (Render does everything else)

**What I can help with:**
- Debugging deployment errors
- Fixing endpoint issues
- Updating Flutter app config
- Migrating from free to paid tier

---

## ❓ Questions?

**What's your MongoDB URI?** Send me:
```
MONGODB_URI=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

Once you have these, you're 5 minutes away from deployment! ✅

---

**Ready? Create your Render account and let me know the URL you get!** 🚀
