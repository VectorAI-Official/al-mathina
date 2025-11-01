# 🐳 Docker + Localhost Backend Setup Guide

Complete guide to run backend locally with cloud databases for Flutter preview testing.

---

## 📋 Prerequisites

```powershell
# Check Docker is installed
docker --version

# Check Docker Desktop is running (should see stats)
docker stats --no-stream
```

If Docker isn't installed, [download Docker Desktop](https://www.docker.com/products/docker-desktop).

---

## 🚀 Quick Start (2 Minutes)

### Option 1: Using Docker Compose (Recommended)

```powershell
# 1️⃣ Navigate to Backend folder
cd Backend

# 2️⃣ Run Docker Compose
docker-compose up

# Expected output:
# ✅ backend | INFO:     Application startup complete
# ✅ backend | Uvicorn running on http://0.0.0.0:8000
```

**Backend is now available at:** `http://localhost:8000`

### Option 2: Direct Docker Command

```powershell
# Build image
docker build -t al-mathina-backend .

# Run container
docker run -p 8000:8080 --env-file .env.production al-mathina-backend
```

---

## 📱 Testing with Flutter Preview

### Step 1: Verify Backend is Running

```powershell
# In new PowerShell window
curl http://localhost:8000/docs

# Should show FastAPI Swagger UI
```

### Step 2: Connect Flutter to Localhost

Edit `flutter_preview/lib/api_service.dart`:

```dart
// CHANGE THIS:
const String API_BASE_URL = 'https://al-mathina.onrender.com';

// TO THIS (for localhost testing):
const String API_BASE_URL = 'http://127.0.0.1:8000';
```

### Step 3: Run Flutter Preview

```powershell
# In another PowerShell window
cd flutter_preview
flutter run -d chrome
```

### Step 4: Access Admin Dashboard

```
Browser: http://localhost:8000/admin
Login: admin / admin123
```

---

## 🐳 Docker Commands Reference

### Starting & Stopping

```powershell
# Start in background (detached mode)
docker-compose up -d

# Stop containers
docker-compose down

# View running containers
docker ps

# View container logs
docker logs <container_id>
# or with compose:
docker-compose logs -f

# Restart
docker-compose restart
```

### Debugging

```powershell
# Check container status
docker-compose ps

# Enter container shell
docker exec -it <container_id> bash

# View resource usage
docker stats

# Build with no cache (fresh build)
docker-compose build --no-cache
docker-compose up
```

### Cleaning Up

```powershell
# Stop and remove containers
docker-compose down

# Remove unused images
docker image prune

# Remove everything (careful!)
docker system prune -a
```

---

## ⚙️ Configuration Files

### `.env.production` (Already Set Up)

```bash
# These are already configured to use cloud databases:
MONGO_URI=mongodb+srv://vectoraiautomations_db_user:VectoraI_123@al-mathina.9xt8cbd.mongodb.net/...
CLOUDINARY_CLOUD_NAME=vectorai
CLOUDINARY_API_KEY=315192596216358
CLOUDINARY_API_SECRET=JFpyMTpUZ01pRxaFpZjm_Na6H-s
```

**No changes needed!** Docker automatically loads `.env.production`.

### `Dockerfile` (Updated)

```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*
COPY Backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY Backend/ .

# Expose port
EXPOSE 8080

# Run production app
CMD ["python", "-m", "uvicorn", "main_production:app", "--host", "0.0.0.0", "--port", "8080"]
```

### `docker-compose.yml` (Updated)

```yaml
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8080"  # localhost:8000 → container:8080
    env_file:
      - Backend/.env.production
    environment:
      - ENVIRONMENT=production
    volumes:
      - ./Backend:/app
      - /app/__pycache__
      - /app/.pytest_cache
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

## 🔍 Troubleshooting

### Problem: Port 8000 Already in Use

```powershell
# Find what's using port 8000
netstat -ano | findstr :8000

# Kill process (replace PID)
taskkill /PID <PID> /F

# Or change port in docker-compose.yml:
# ports:
#   - "8001:8080"  # Use 8001 instead
```

### Problem: "Connection Refused" from Flutter

✅ **Solution:**
- On **Windows/Mac**: Use `127.0.0.1:8000` or `localhost:8000`
- Update `api_service.dart`:
  ```dart
  const String API_BASE_URL = 'http://127.0.0.1:8000';
  ```

### Problem: "Cannot Connect to MongoDB"

✅ **Solutions:**
1. Check internet connection (MongoDB Atlas requires it)
2. Verify MongoDB Atlas IP whitelist:
   - Go to: https://cloud.mongodb.com/v2/
   - Navigate to: Network Access → IP Whitelist
   - Add: `0.0.0.0/0` (allows all IPs - dev only)

3. Check `.env.production` has correct `MONGO_URI`

### Problem: Docker Container Crashes

```powershell
# View detailed error logs
docker-compose logs --tail=50

# Rebuild without cache
docker-compose build --no-cache
docker-compose up

# Check what's failing
docker exec -it <container_id> bash
python -c "from database.mongodb_client import test_mongo_connection; test_mongo_connection()"
```

### Problem: "Module not found" Error

```powershell
# Rebuild with fresh dependencies
docker-compose down
docker-compose build --no-cache
docker-compose up
```

---

## 📊 Testing Workflow

### Step-by-Step Test Flow

```
1️⃣ START DOCKER
   └─ docker-compose up

2️⃣ VERIFY BACKEND HEALTH
   └─ curl http://localhost:8000/docs
   └─ Should show Swagger UI ✅

3️⃣ UPDATE FLUTTER API URL
   └─ Edit api_service.dart
   └─ Change to http://127.0.0.1:8000

4️⃣ OPEN BROWSER TABS
   ├─ Tab 1: http://localhost:8000/admin (Admin Dashboard)
   ├─ Tab 2: Chrome (for Flutter preview)
   └─ Tab 3: http://localhost:8000/docs (API Docs)

5️⃣ RUN FLUTTER
   └─ cd flutter_preview && flutter run -d chrome

6️⃣ OPEN DEVELOPER CONSOLE
   └─ Press F12 in Flutter/Admin windows
   └─ Watch console logs in real-time

7️⃣ TEST FLOW
   ├─ Admin: Add category → Check logs
   ├─ Admin: Upload image → Check Cloudinary
   ├─ Flutter: Load home → Check API calls
   └─ Flutter: View products → Verify data

8️⃣ VERIFY LOGS
   ├─ Check 🟢 green ✅ indicators
   ├─ Check 🔴 red ❌ errors
   └─ Use LOGS_VISUAL_REFERENCE.md for help
```

### Quick Testing Commands

```powershell
# Test API health
curl http://localhost:8000/health

# Test categories endpoint
curl http://localhost:8000/api/flutter/categories

# Test home endpoint
curl http://localhost:8000/api/flutter/home

# Test admin login
curl -X POST http://localhost:8000/admin/login `
  -d "username=admin&password=admin123"
```

---

## 💾 Hot Reload in Docker

The `docker-compose.yml` mounts the Backend directory for hot-reload:

```yaml
volumes:
  - ./Backend:/app  # Changes reflected immediately
```

**However**, Python code reloads **after you save**:

1. Edit a Python file in `Backend/`
2. Save the file (Ctrl+S)
3. Watch container logs for reload notification:
   ```
   INFO:     Will watch for changes in these directories: ['/app']
   INFO:     Uvicorn running on http://0.0.0.0:8080
   ```
4. Refresh API in browser - changes apply immediately ✅

---

## 🔐 Environment Variables

All sensitive data is in `.env.production`:

```bash
MONGO_URI=mongodb+srv://...
CLOUDINARY_CLOUD_NAME=vectorai
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
```

**Already set up!** Docker loads from this file automatically.

---

## 🎯 Complete Testing Checklist

```
BEFORE YOU START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Docker Desktop is running
□ VPN disabled (if behind corporate firewall)
□ Internet connection working (MongoDB Atlas needs it)

DOCKER STARTUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Run: docker-compose up
□ See: "INFO:     Application startup complete"
□ Try: curl http://localhost:8000/docs
□ See: FastAPI Swagger UI

FLUTTER SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Edit api_service.dart
□ Change API_BASE_URL to http://127.0.0.1:8000
□ Save file
□ Run: flutter run -d chrome

ADMIN DASHBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Open: http://localhost:8000/admin
□ Login: admin / admin123
□ See: Dashboard loads
□ Check: Mobile view (F12)

DEBUGGING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Press F12 in browser
□ Go to Console tab
□ Look for 🟢 green ✅ logs (success)
□ Look for 🔴 red ❌ errors
□ Use LOGS_VISUAL_REFERENCE.md to debug

TESTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Admin: Add new category
□ Check: Appears in Flutter app
□ Admin: Upload product image
□ Check: Image displays in Flutter
□ Flutter: Click sections
□ Check: Subcategories load
□ Flutter: View products
□ Check: All data displays correctly

SUCCESS INDICATORS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Backend running: http://localhost:8000/docs works
✅ Admin dashboard: http://localhost:8000/admin works
✅ Flutter connects: No CORS errors in console
✅ Data flows: Admin changes → Flutter shows immediately
✅ Logs are helpful: See colored logs for each action
```

---

## 🚀 Next Steps

After Docker is running successfully:

1. **Use the logging guides:**
   - `LOGS_QUICK_START.md` - Quick reference
   - `MOBILE_VIEW_LOGGING_GUIDE.md` - Detailed logging
   - `LOGS_VISUAL_REFERENCE.md` - Visual flow charts

2. **Debug the white screen issue:**
   - Open DevTools (F12)
   - Check console logs
   - Identify failing step
   - Apply fix
   - Verify in logs

3. **Deploy when ready:**
   - Test thoroughly locally
   - Deploy backend to Render
   - Update Flutter API URL to production
   - Deploy Flutter app

---

## 📞 Quick Reference

| Need | Command |
|------|---------|
| Start backend | `docker-compose up` |
| Backend URL | `http://localhost:8000` |
| Admin Dashboard | `http://localhost:8000/admin` |
| API Docs | `http://localhost:8000/docs` |
| View logs | `docker-compose logs -f` |
| Stop backend | `docker-compose down` |
| Rebuild | `docker-compose build --no-cache && docker-compose up` |
| Test API | `curl http://localhost:8000/health` |
| Enter container | `docker exec -it <container_id> bash` |

---

**You're all set! Start with:** `docker-compose up` 🐳✨
