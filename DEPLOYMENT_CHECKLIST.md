# 🚀 Production Deployment Checklist

## ✅ Pre-Deployment Checklist

### 1. Environment Configuration
- [ ] `.env.production` file created with all credentials
- [ ] `MONGO_PASSWORD` set correctly
- [ ] `CLOUDINARY_CLOUD_NAME` set
- [ ] `CLOUDINARY_API_KEY` set  
- [ ] `CLOUDINARY_API_SECRET` set
- [ ] `JWT_SECRET_KEY` set to strong random value

### 2. Database Migration
- [ ] MongoDB Atlas cluster is running
- [ ] Database migration completed (`python migrate_to_atlas.py`)
- [ ] All collections verified in Atlas dashboard
- [ ] IP whitelist configured (0.0.0.0/0 for Fly.io)

### 3. Cloud Services Verification
- [ ] Test cloud integration (`python test_cloud_integration.py`)
- [ ] MongoDB Atlas connection successful
- [ ] Cloudinary initialized successfully
- [ ] Test image upload works (optional)

### 4. Code Review
- [ ] All production files committed to git
- [ ] `main_production.py` uses correct routes
- [ ] `admin_production.py` has Cloudinary integration
- [ ] `cloudinary_helper.py` module working
- [ ] Database client auto-detects production environment

## 🛫 Deployment Steps

### Step 1: Install Fly CLI
```powershell
# PowerShell (Administrator)
iwr https://fly.io/install.ps1 -useb | iex

# Verify installation
fly version
```

### Step 2: Login to Fly.io
```bash
fly auth login
```

### Step 3: Launch App
```bash
cd C:\Users\faisa\AndroidStudioProjects\AlMathina

fly launch
```

**Configuration:**
- App name: `almathina-backend`
- Region: `sin` (Singapore) or closest to users
- PostgreSQL: **No**
- Redis: **No**

### Step 4: Set Secrets
```bash
fly secrets set MONGO_PASSWORD=VectoraI_123
fly secrets set CLOUDINARY_CLOUD_NAME=vectorai
fly secrets set CLOUDINARY_API_KEY=JFpyMTpUZ01pRxaFpZjm_Na6H-s
fly secrets set CLOUDINARY_API_SECRET=your_actual_secret
fly secrets set JWT_SECRET_KEY=generate_strong_random_key
fly secrets set ENVIRONMENT=production
```

### Step 5: Deploy
```bash
fly deploy
```

### Step 6: Verify Deployment
```bash
# Check status
fly status

# View logs
fly logs

# Test health endpoint
curl https://almathina-backend.fly.dev/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "almathina-backend",
  "version": "2.0.0",
  "mongodb": "connected",
  "cloudinary": true
}
```

## 📱 Update Flutter App

### Update API URL
File: `flutter_preview/lib/api_service.dart`

```dart
// Change from
const String BASE_URL = "http://192.168.1.6:8000";

// To
const String BASE_URL = "https://almathina-backend.fly.dev";
```

### Rebuild Flutter App
```bash
cd flutter_preview
flutter clean
flutter pub get
flutter run -d chrome  # Test
```

## 🧪 Post-Deployment Testing

### 1. Test Health Endpoint
```bash
curl https://almathina-backend.fly.dev/health
```

### 2. Test API Endpoints
```bash
# Get sections
curl https://almathina-backend.fly.dev/api/flutter/home

# Test image upload
curl -X POST https://almathina-backend.fly.dev/admin/api/upload/image \
  -F "file=@test.jpg" \
  -F "category_type=product" \
  -F "product_id=TEST001"
```

### 3. Test Flutter App
- [ ] Open Flutter app
- [ ] Categories load correctly
- [ ] Images display from Cloudinary
- [ ] Search works
- [ ] Tamil language works
- [ ] Product details load
- [ ] Cart functionality works

### 4. Test Admin Dashboard
- [ ] Login works
- [ ] Category management works
- [ ] Product CRUD works
- [ ] Image uploads to Cloudinary
- [ ] Most Bought management works

## 🔍 Monitoring

### View Logs
```bash
# Real-time logs
fly logs

# Tail logs
fly logs -f

# View metrics
fly dashboard
```

### Check App Status
```bash
fly status
fly scale show
```

## 🐛 Troubleshooting

### App Won't Start
```bash
fly logs
# Check for missing environment variables
fly secrets list
```

### MongoDB Connection Failed
- Verify MONGO_PASSWORD is correct
- Check MongoDB Atlas cluster is running
- Verify IP whitelist includes 0.0.0.0/0
- Check connection string in config_production.py

### Cloudinary Not Working
```bash
# Verify secrets
fly secrets list

# Check logs for Cloudinary errors
fly logs | grep -i cloudinary
```

### Image Upload Fails
- Check Cloudinary credentials
- Verify file size < 5MB
- Check file is valid image format
- Review logs for specific error

## 📊 Performance Optimization

### Scale Up (if needed)
```bash
# Scale to 2 instances
fly scale count 2

# Increase memory
fly scale memory 512
```

### Add Custom Domain (Optional)
```bash
fly certs add api.almathina.com
```

## 🔐 Security Hardening

### Update CORS Origins
File: `Backend/main_production.py`

```python
# Change from
allow_origins=["*"]

# To
allow_origins=[
    "https://yourdomain.com",
    "https://www.yourdomain.com"
]
```

### Rotate Secrets (Periodically)
```bash
# Generate new JWT secret
fly secrets set JWT_SECRET_KEY=new_random_secret

# Update MongoDB password
fly secrets set MONGO_PASSWORD=new_password
```

## ✅ Success Criteria

- [x] Backend deployed to Fly.io
- [x] Health endpoint returns healthy
- [x] MongoDB Atlas connected
- [x] Cloudinary initialized
- [x] Flutter app connects successfully
- [x] Images load from Cloudinary
- [x] All API endpoints working
- [x] Admin dashboard functional
- [x] Tamil language working
- [x] Products display correctly

## 📝 Post-Deployment Tasks

1. [ ] Update documentation with production URL
2. [ ] Share API documentation with team (`/docs`)
3. [ ] Set up monitoring alerts (Fly.io)
4. [ ] Configure backup schedule (MongoDB Atlas)
5. [ ] Test disaster recovery
6. [ ] Document rollback procedure
7. [ ] Update README with production info

## 🎉 Deployment Complete!

Your AL-Madhina backend is now running in production with:
- ✅ MongoDB Atlas for data storage
- ✅ Cloudinary for image CDN
- ✅ Fly.io for global hosting
- ✅ Automatic scaling
- ✅ HTTPS enabled
- ✅ Health monitoring

Access your API documentation:
📖 https://almathina-backend.fly.dev/docs

Need help? Check the logs:
```bash
fly logs -f
```
