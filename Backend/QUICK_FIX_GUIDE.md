# Quick Start Guide - Local MongoDB Admin Dashboard

## Fixed Issues ✅

1. **Products Loading**: Fixed JavaScript to properly handle API responses
2. **Category Dropdown**: Fixed category population in the "Add Product" form
3. **Local MongoDB**: Created version that works with local MongoDB (no Supabase/MongoDB Atlas)

## Option 1: Test with Demo (No Database Required) - CURRENTLY RUNNING

The demo server is currently running with mock data. **Refresh your browser** to see the fixes:

- Categories should now appear in the dropdown
- Products should load immediately  
- All CRUD operations work (changes stored in memory)

**Current URL**: http://127.0.0.1:8000/admin/dashboard

## Option 2: Connect to Local MongoDB (Real Database)

### Step 1: Install MongoDB Locally

**Option A - Using Docker (Recommended)**:
```powershell
# Start MongoDB container
docker run -d --name almathina-mongodb -p 27017:27017 mongo:latest
```

**Option B - Install MongoDB Community Edition**:
Download from: https://www.mongodb.com/try/download/community

### Step 2: Start Backend with MongoDB

```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Stop the demo server first (Ctrl+C in the terminal)

# Option A: Use the automated script
.\start_mongodb.ps1

# Option B: Manual start
.\venv\Scripts\python.exe .\main_local.py
```

### Step 3: Access Dashboard

Open: http://127.0.0.1:8000/admin/login

- Username: `admin`
- Password: `admin123`

## Features Working Now ✅

1. **View Products** - See all products in a sortable table
2. **Add Product** - Click "Add New Product" button
   - Fill in product details
   - Select category from dropdown (NOW WORKING!)
   - Upload image (saved locally)
3. **Edit Product** - Click pencil icon on any product
4. **Delete Product** - Click trash icon with confirmation
5. **Search** - Type in search box to filter products
6. **Filter by Category** - Use category dropdown

## What Changed?

### Demo Mode (main_demo.py):
- Fixed category API to return simple array of strings
- JavaScript now handles API response correctly
- Products load without delay

### Real Database Mode (main_local.py):
- **No Supabase required!**
- Uses local MongoDB on `localhost:27017`
- Images saved to `Backend/static/uploads/` folder
- All CRUD operations persist in MongoDB
- Sample data auto-created on first run

## Current Status

✅ **Demo server is running** - You can test immediately by refreshing browser  
⏳ **MongoDB setup** - Run when you want to use real database

## Next Steps

1. **Test Demo Now**: Refresh your browser at http://127.0.0.1:8000/admin/dashboard
2. **Try Adding Product**: Click "Add New Product" - categories should now appear
3. **Switch to MongoDB**: When ready, follow "Option 2" above

## Troubleshooting

**Categories not showing?**
- Hard refresh browser: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Check browser console (F12) for errors

**MongoDB connection failed?**
- Check Docker is running: `docker ps`
- Or install MongoDB Community Edition locally

**Port 8000 already in use?**
- Stop other server: Find terminal and press Ctrl+C
- Or change port in config_local.py

## File Structure

```
Backend/
├── main_demo.py          # Demo mode (currently running)
├── main_local.py         # MongoDB mode (NEW)
├── config_local.py       # Local config (NEW)
├── start_mongodb.ps1     # Auto-start script (NEW)
├── routes/
│   ├── admin.py          # Original (needs Supabase)
│   └── admin_local.py    # Local version (NEW)
└── static/
    └── uploads/          # Local image storage (NEW)
```
