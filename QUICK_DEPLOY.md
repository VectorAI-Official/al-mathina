# ⚡ Quick Start: Deploy in 5 Minutes

## ✅ Prerequisites Check

Run this test to verify everything is ready:
```bash
cd Backend
python test_cloud_integration.py
```

Expected:
- ✅ MongoDB Atlas: PASSED
- ✅ Cloudinary: PASSED (after adding valid API key)

## 🚀 Deploy to Fly.io (5 Steps)

### Step 1: Get Cloudinary Credentials (1 min)
1. Go to https://cloudinary.com/console
2. Copy: API Key & API Secret
3. Update `Backend/.env.production`:
   ```bash
   CLOUDINARY_API_KEY=your_actual_key
   CLOUDINARY_API_SECRET=your_actual_secret
   ```

### Step 2: Install Fly CLI (1 min)
```powershell
# PowerShell (Administrator)
iwr https://fly.io/install.ps1 -useb | iex
```

Verify: `fly version`

### Step 3: Login & Launch (1 min)
```bash
fly auth login
cd C:\Users\faisa\AndroidStudioProjects\AlMathina
fly launch
```

When prompted:
- App name: **almathina-backend** (or your choice)
- Region: **sin** (Singapore)
- PostgreSQL: **No**
- Redis: **No**

### Step 4: Set Secrets (1 min)
```bash
fly secrets set MONGO_PASSWORD=VectoraI_123
fly secrets set CLOUDINARY_CLOUD_NAME=vectorai
fly secrets set CLOUDINARY_API_KEY=your_actual_key
fly secrets set CLOUDINARY_API_SECRET=your_actual_secret
fly secrets set ENVIRONMENT=production
```

### Step 5: Deploy! (1 min)
```bash
fly deploy
```

Wait 30-60 seconds for deployment...

## ✅ Verify Deployment

```bash
# Check health
curl https://almathina-backend.fly.dev/health

# Expected response:
{
  "status": "healthy",
  "mongodb": "connected",
  "cloudinary": true
}
```

## 📱 Update Flutter App

File: `flutter_preview/lib/api_service.dart`

```dart
const String BASE_URL = "https://almathina-backend.fly.dev";
```

Rebuild:
```bash
cd flutter_preview
flutter clean
flutter pub get
flutter run -d chrome
```

## 🎉 Done!

Your backend is now live at:
- **API**: https://almathina-backend.fly.dev
- **Docs**: https://almathina-backend.fly.dev/docs
- **Health**: https://almathina-backend.fly.dev/health

## 📊 Monitoring

```bash
# View logs
fly logs

# Check status
fly status

# Open dashboard
fly dashboard
```

## 🐛 Troubleshooting

### Issue: Deploy fails
```bash
fly logs  # Check error
fly secrets list  # Verify secrets set
```

### Issue: Health check fails
```bash
fly ssh console  # SSH into container
python -c "from database.mongodb_client import test_mongo_connection; test_mongo_connection()"
```

### Issue: MongoDB connection fails
- Verify MONGO_PASSWORD is correct
- Check MongoDB Atlas IP whitelist (0.0.0.0/0)

## 📚 Full Documentation

- **Complete Guide**: CLOUD_INTEGRATION_GUIDE.md
- **Architecture**: ARCHITECTURE_DIAGRAM.md
- **Checklist**: DEPLOYMENT_CHECKLIST.md
- **Summary**: CLOUD_SETUP_COMPLETE.md

---

**🎊 Congratulations! Your app is now live on the cloud!** 🚀
