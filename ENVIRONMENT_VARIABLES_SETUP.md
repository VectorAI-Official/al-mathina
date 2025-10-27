# Environment Variables & Credentials Management

## Overview
The AL-Madhina backend now uses a secure `.env.production` file to manage sensitive credentials instead of hardcoding them in `docker-compose.yml`.

## Current Setup

### Files
1. **`.env.production`** - Contains all sensitive credentials (LOCAL ONLY - never commit)
2. **`.env.production.example`** - Template file showing all required variables
3. **`docker-compose.yml`** - Updated to read from `.env.production` using `env_file` directive
4. **`.gitignore`** - Updated to exclude `.env.production` and `.env.production.local`

### Environment Variables

#### Cloudinary Configuration
```
CLOUDINARY_CLOUD_NAME=vectorai
CLOUDINARY_API_KEY=315192596216358
CLOUDINARY_API_SECRET=JFpyMTpUZ01pRxaFpZjm_Na6H-s
```

**Source:** https://cloudinary.com/console/settings/api-keys
- ✓ Cloud Name: `vectorai`
- ✓ API Key: Valid 15-digit number
- ✓ API Secret: 27-character secret (currently in .env.production)

#### MongoDB Atlas Configuration
```
MONGO_URI=mongodb+srv://vectoraiautomations_db_user:VectoraI_123@al-mathina.9xt8cbd.mongodb.net/?retryWrites=true&w=majority&appName=al-mathina&tlsAllowInvalidCertificates=true&tlsInsecure=false
MONGO_PASSWORD=VectoraI_123
MONGO_DB_NAME=almadhinadb
```

**Source:** https://cloud.mongodb.com
- ✓ Cluster: `al-mathina.9xt8cbd.mongodb.net`
- ✓ Database: `almadhinadb`
- ✓ TLS Bypass Enabled: `tlsAllowInvalidCertificates=true` (needed for SSL handshake)

#### FastAPI Configuration
```
HOST=0.0.0.0
PORT=8080
RELOAD=false
DEBUG=false
LOG_LEVEL=INFO
ENVIRONMENT=production
```

#### JWT Configuration
```
JWT_SECRET_KEY=change_this_to_a_strong_random_secret_in_production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

## How It Works

### Local Development (Docker)
```
docker-compose.yml → env_file: .env.production → Backend reads all variables
```

### Production (Fly.io)
```
Fly.io Environment Variables → Backend reads all variables
```

## How to Verify Credentials

### 1. Run Credential Validation
```powershell
cd Backend
python validate_credentials.py
```

This script:
- ✓ Loads credentials from `.env.production`
- ✓ Checks all required variables are set
- ✓ Validates format (length, characters)
- ✓ Tests Cloudinary signature generation
- ✓ Displays masked credentials for security

### 2. Test Image Upload
1. Start backend: `docker-compose up -d`
2. Open dashboard: http://localhost:8000/admin/dashboard
3. Create a test product
4. Upload an image
5. Check if upload succeeds

### 3. Check Docker Logs
```powershell
docker-compose logs -f backend
```

Look for:
- ✓ `Cloudinary initialized successfully`
- ✓ `MongoDB Atlas - Lazy connection`
- ✓ `✅ Backend Ready`

## Double-Checking Credentials

### Verify Cloudinary Credentials
1. Go to https://cloudinary.com/console
2. Log in to your account
3. Go to **Settings → API Keys**
4. Verify:
   - Cloud Name matches: `vectorai`
   - API Key matches: `315192596216358`
   - API Secret matches: `JFpyMTpUZ01pRxaFpZjm_Na6H-s`

### Verify MongoDB Credentials
1. Go to https://cloud.mongodb.com
2. Log in to your account
3. Go to **Database Access**
4. Find user: `vectoraiautomations_db_user`
5. Verify password: `VectoraI_123`
6. Go to **Network Access**
7. Ensure IP `0.0.0.0/0` is whitelisted (for local testing)

## If Credentials Are Wrong

If image upload fails with `Invalid Signature` error:

### Step 1: Get Correct Credentials
- **For Cloudinary:** https://cloudinary.com/console/settings/api-keys
- **For MongoDB:** https://cloud.mongodb.com

### Step 2: Update `.env.production`
```bash
# Edit the file
nano Backend/.env.production

# Or use VS Code
code Backend/.env.production
```

Replace the incorrect values with correct ones from the dashboards.

### Step 3: Restart Container
```powershell
cd Backend
docker-compose down
docker-compose up -d --build
```

### Step 4: Verify
```powershell
python validate_credentials.py
```

## Security Best Practices

✅ **Implemented:**
1. Credentials stored in `.env.production` (not in code)
2. `.env.production` excluded from git (in .gitignore)
3. Example template provided (`.env.production.example`)
4. Docker reads from env file automatically
5. Credentials validated before use

📋 **For Production (Fly.io):**
1. Set environment variables in Fly.io dashboard (not in file)
2. Use `flyctl secrets set` for sensitive values:
   ```powershell
   flyctl secrets set CLOUDINARY_API_SECRET=<actual_secret>
   flyctl secrets set MONGO_PASSWORD=<actual_password>
   ```
3. Never commit `.env` files to git
4. Rotate credentials periodically

## Troubleshooting

### "MONGO_PASSWORD variable not set" Warning
This is just a warning - the actual MONGO_URI already contains the password, so it's not critical.

### "Cloudinary initialized successfully" but image upload fails
1. Check error in logs: `docker-compose logs backend | grep -i error`
2. Run validation: `python validate_credentials.py`
3. Verify API Secret hasn't been rotated in Cloudinary dashboard

### "Invalid Signature" Error
The API Secret is wrong. Follow "If Credentials Are Wrong" steps above.

## Testing Image Upload

### Create Test Script
```powershell
# Create a test product and upload image
curl -X POST "http://localhost:8000/admin/api/products" \
  -H "Content-Type: application/json" \
  -d '{
    "product_name": "Test Product",
    "price": 100,
    "stock": 10
  }'

# Then upload image to product ID
$product_id = "60d5ec49c1234567890abcde"
curl -X POST "http://localhost:8000/admin/api/upload/image/$product_id" \
  -F "file=@test_image.png"
```

## Files Modified

1. **Backend/docker-compose.yml** - Added `env_file: .env.production`
2. **Backend/.env.production** - Now reads credentials from this file
3. **Backend/.env.production.example** - Template for new environments
4. **Backend/.gitignore** - Added `.env.production` entries
5. **Backend/validate_credentials.py** - New validation script
6. **Backend/config_production.py** - No changes (already supports env vars)

## Next Steps

1. ✓ Credentials are validated and in `.env.production`
2. ✓ Backend is running with env file configuration
3. Test image upload in dashboard
4. If all works, prepare for Fly.io deployment
5. For Fly.io: Set same environment variables in deployment config
