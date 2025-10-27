# Fly.io Deployment Guide for AL-Madhina Backend

## Prerequisites

1. **Install Fly CLI**
   ```powershell
   # PowerShell (run as Administrator)
   iwr https://fly.io/install.ps1 -useb | iex
   ```

2. **Sign up for Fly.io**
   ```bash
   fly auth signup
   # Or login if you have an account
   fly auth login
   ```

## Step 1: Set Environment Variables

Set your MongoDB password (replace with your actual password):

```powershell
# PowerShell
$env:MONGO_PASSWORD='your_mongodb_password_here'
$env:CLOUDINARY_CLOUD_NAME='your_cloud_name'
$env:CLOUDINARY_API_KEY='your_api_key'
$env:CLOUDINARY_API_SECRET='your_api_secret'
```

## Step 2: Migrate Database to MongoDB Atlas

Run the migration script:

```powershell
cd Backend
python migrate_to_atlas.py
```

This will:
- Connect to your local MongoDB
- Connect to MongoDB Atlas
- Migrate all collections (products, category_metadata, etc.)
- Preserve all your data including images metadata

## Step 3: Launch Fly.io App

```bash
# Navigate to project root
cd ..

# Launch the app (this creates it on Fly.io)
fly launch
```

When prompted:
- App name: `almathina-backend` (or your choice)
- Region: Choose closest to your users (e.g., `sin` for Singapore, `bom` for Mumbai)
- PostgreSQL: **No** (we're using MongoDB Atlas)
- Redis: **No**

## Step 4: Set Secrets on Fly.io

```bash
# Set MongoDB password
fly secrets set MONGO_PASSWORD=your_mongodb_password_here

# Set Cloudinary credentials
fly secrets set CLOUDINARY_CLOUD_NAME=your_cloud_name
fly secrets set CLOUDINARY_API_KEY=your_api_key
fly secrets set CLOUDINARY_API_SECRET=your_api_secret

# Optional: Set JWT secret
fly secrets set JWT_SECRET_KEY=generate_a_strong_random_secret_here
```

## Step 5: Deploy

```bash
# Deploy the application
fly deploy
```

## Step 6: Get Your Backend URL

```bash
# Get your app info
fly status

# Your backend URL will be:
# https://almathina-backend.fly.dev
```

## Step 7: Update Flutter App

In `flutter_preview/lib/api_service.dart`, update:

```dart
// Change from
const String BASE_URL = "http://192.168.1.6:8000";

// To
const String BASE_URL = "https://almathina-backend.fly.dev";
```

## Useful Fly.io Commands

```bash
# View logs
fly logs

# SSH into your app
fly ssh console

# Scale your app
fly scale count 1  # Number of instances

# View app status
fly status

# Open dashboard
fly dashboard
```

## Monitoring

Fly.io provides:
- Health checks (configured in fly.toml)
- Automatic restarts
- Metrics dashboard
- Log aggregation

Access at: https://fly.io/dashboard

## Cost Estimate

**Free Tier (First Month):**
- 3 shared-cpu-1x VMs (256MB RAM each)
- 3GB persistent volumes
- 160GB outbound data transfer

**After Free Tier:**
- ~$1.94/month for 1 VM (256MB)
- Additional charges for bandwidth

## Troubleshooting

### App won't start
```bash
fly logs
# Check for missing environment variables or connection issues
```

### Database connection fails
```bash
# Verify secrets are set
fly secrets list

# Test MongoDB Atlas connection from your local machine
python -c "from pymongo import MongoClient; client = MongoClient('your_atlas_uri'); print(client.server_info())"
```

### Need to update code
```bash
# Simply run deploy again
fly deploy
```

## Next Steps

1. ✅ Migrate database
2. ✅ Deploy to Fly.io
3. ✅ Set secrets
4. ✅ Update Flutter app with new URL
5. ⬜ Implement Cloudinary image upload (TODO)
6. ⬜ Test all endpoints
7. ⬜ Set up custom domain (optional)

## Support

- Fly.io Docs: https://fly.io/docs/
- MongoDB Atlas Docs: https://docs.atlas.mongodb.com/
- Cloudinary Docs: https://cloudinary.com/documentation
