# 🚀 Quick Start Guide - Database Sync Fix

## Problem
Products deleted through dashboard come back after page reload.

## Solution
Use the correct backend server that connects to MongoDB.

---

## ✅ How to Start Backend Correctly

### Option 1: Use the New Start Script (Recommended)
```powershell
cd Backend
.\start_local.ps1
```

This script will:
- ✓ Check virtual environment
- ✓ Verify MongoDB is running
- ✓ Start the correct server (main_local.py)

### Option 2: Manual Start
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
uvicorn main_local:app --reload --host 127.0.0.1 --port 8000
```

---

## 🧪 Quick Test

### Step 1: Start Backend
```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
.\start_local.ps1
```

### Step 2: Verify Backend is Running
Open browser to: **http://127.0.0.1:8000/**

You should see:
```json
{
  "name": "AL-Madhina Wholesale API",
  "version": "1.0.0-local",
  "status": "running",
  "database": "Local MongoDB"  ← This confirms correct server!
}
```

### Step 3: Access Dashboard
Open: **http://127.0.0.1:8000/admin/login**
- Username: `admin`
- Password: `admin123`

### Step 4: Test Delete
1. Go to dashboard
2. Delete a product
3. Hard refresh page (Ctrl+Shift+R)
4. Product should stay deleted! ✓

---

## 🔍 Troubleshooting

### Products Still Come Back?

**1. Check Which Server is Running**
Look at terminal output when server starts. You should see:
```
✓ MongoDB connected successfully
✓ Admin routes loaded (local MongoDB version)
```

**NOT:**
```
✓ Supabase connected
✓ PostgreSQL ready
```

**2. Hard Refresh Browser**
- Windows: `Ctrl + Shift + R`
- Mac: `Cmd + Shift + R`

**3. Clear Browser Cache**
- Open DevTools (F12)
- Right-click refresh button
- Select "Empty Cache and Hard Reload"

**4. Check MongoDB is Persisting**
```powershell
# Test from Python
cd Backend
.\venv\Scripts\Activate.ps1
python -c "from database.mongodb_client import get_mongo_db; db = get_mongo_db(); print(f'Total products: {db.products.count_documents({})}')"
```

---

## ✅ What's Fixed

### Backend (✓ Already Correct)
- `admin_local.py` - All CRUD operations use MongoDB
- `main_local.py` - Loads admin_local.py routes
- Delete endpoint properly removes from database

### Frontend (✓ Already Correct)
- Delete functions call API correctly
- After delete, reloads fresh data from database
- No local caching or storage used

### Database (✓ MongoDB Running)
- MongoDB service is running
- Data is persisted to disk
- 24 products currently in database

---

## 📊 Current Status

| Component | Status | Details |
|-----------|--------|---------|
| MongoDB | ✅ Running | Service active, 24 products |
| Backend API | ✅ Ready | All endpoints working |
| Delete Endpoint | ✅ Working | Removes from MongoDB |
| Frontend | ✅ Working | Calls API, reloads data |
| **Issue** | ⚠️ Wrong Server | Need to use `main_local.py` |

---

## 🎯 Action Required

**YOU NEED TO:**

1. **Stop current server** (if running)
   - Press `Ctrl+C` in terminal

2. **Start correct server**
   ```powershell
   cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
   .\start_local.ps1
   ```

3. **Verify it's working**
   - Go to http://127.0.0.1:8000/
   - Should see `"database": "Local MongoDB"`

4. **Test delete**
   - Login to dashboard
   - Delete a product
   - Hard refresh (Ctrl+Shift+R)
   - Product stays deleted ✓

---

## 💡 Why Products Were Coming Back

**Previous Situation:**
- You might have been running `main.py` (requires Supabase)
- Or browser cache was showing old data
- Or multiple server instances were running

**Now:**
- `main_local.py` uses only MongoDB
- All deletes go to MongoDB
- Data persists across restarts

---

## 📝 Files Created

1. **start_local.ps1** - Easy start script for local development
2. **DATABASE_SYNC_FIX.md** - Detailed troubleshooting guide
3. **QUICK_START.md** - This file

---

## 🔗 Important URLs

- **API Root:** http://127.0.0.1:8000/
- **Health Check:** http://127.0.0.1:8000/health
- **API Docs:** http://127.0.0.1:8000/docs
- **Admin Login:** http://127.0.0.1:8000/admin/login
- **Admin Dashboard:** http://127.0.0.1:8000/admin/dashboard

---

**Next Step:** Run `.\start_local.ps1` and test! 🚀

