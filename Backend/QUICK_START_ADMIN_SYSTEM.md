# 🚀 Quick Start Guide: Admin Buying Price System

## ⚡ Quick Setup (5 Minutes)

**Database Architecture Note:**
- Admin status (`is_admin`) stored in **Supabase (PostgreSQL/SQL)** `users` table
- Product buying prices (`buying_price`) stored in **MongoDB (NoSQL)** `products` collection
- Backend queries BOTH databases to determine what data to return

### Step 1: Database Migration (1 min)

**Option A: PowerShell (Recommended)**
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python database/add_admin_column.py
```

**Option B: Supabase SQL Editor**
```sql
-- Run this in Supabase SQL Editor
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
UPDATE users SET is_admin = true WHERE phone IN ('7339651541', '8870503350', '9487715568');
```

### Step 2: Test Backend API (2 min)

```powershell
# Start backend
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000

# In new PowerShell window, run tests
python Backend/test_admin_system.py
```

**Expected Output:**
```
✅ Admin 7339651541: buying_price INCLUDED
✅ Admin 8870503350: buying_price INCLUDED
✅ Admin 9487715568: buying_price INCLUDED
✅ Regular user: buying_price EXCLUDED
```

### Step 3: Update Flutter (See full guide)

→ Read: `Backend/FLUTTER_ADMIN_IMPLEMENTATION.md`

---

## 📋 Pre-Migration Checklist

Before running migration:
- [ ] Backend is running
- [ ] Supabase credentials in `.env` are correct
- [ ] Database backup created (optional but recommended)
- [ ] Terminal is in `Backend/` directory

---

## 🧪 Quick API Test (Manual)

### Test Admin User
```bash
curl "http://127.0.0.1:8000/api/flutter/products?user_phone=7339651541&limit=2"
```

**Expected Response:**
```json
{
  "products": [
    {
      "item_id": "...",
      "product_name": "Basmati Rice",
      "price": 100.0,
      "buying_price": 80.0,  ← SHOULD BE PRESENT
      ...
    }
  ],
  "is_admin": true,  ← SHOULD BE TRUE
  "pagination": {...}
}
```

### Test Regular User
```bash
curl "http://127.0.0.1:8000/api/flutter/products?user_phone=9876543210&limit=2"
```

**Expected Response:**
```json
{
  "products": [
    {
      "item_id": "...",
      "product_name": "Basmati Rice",
      "price": 100.0,
      // NO buying_price field ← CORRECT
      ...
    }
  ],
  "is_admin": false,  ← SHOULD BE FALSE
  "pagination": {...}
}
```

---

## 🎯 Admin Phone Numbers

| Phone      | Status |
|------------|--------|
| 7339651541 | ✅ Admin |
| 8870503350 | ✅ Admin |
| 9487715568 | ✅ Admin |
| All others | ❌ Regular |

---

## 🔧 What Changed

### Backend Files Modified
1. ✅ `Backend/routes/flutter.py` - Added admin check, buying_price field
2. ✅ `Backend/database/add_admin_column.py` - Migration script (NEW)
3. ✅ `Backend/test_admin_system.py` - Test script (NEW)
4. ✅ `Backend/FLUTTER_ADMIN_IMPLEMENTATION.md` - Full guide (NEW)

### Database Changes
1. ✅ `users` table: Added `is_admin` BOOLEAN column
2. ✅ 3 admin users marked with `is_admin = true`

### API Changes
1. ✅ `GET /api/flutter/products` now accepts `user_phone` parameter
2. ✅ Response includes `is_admin` boolean flag
3. ✅ `buying_price` field conditionally added for admins

---

## 🐛 Troubleshooting

### "Column is_admin does not exist"
→ Run migration: `python database/add_admin_column.py`

### "buying_price not showing for admin"
→ Check migration ran: `SELECT phone, is_admin FROM users WHERE phone='7339651541'`

### "Backend not starting"
→ Check `.env` has `SUPABASE_URL` and `SUPABASE_SERVICE_KEY`

### "Test script fails to connect"
→ Make sure backend is running at `http://127.0.0.1:8000`

---

## 📞 Next Steps

1. ✅ Run database migration
2. ✅ Test backend API with curl/test script
3. 📱 Update Flutter app (see `FLUTTER_ADMIN_IMPLEMENTATION.md`)
4. 🧪 Test Flutter app with admin and regular users
5. 🚀 Deploy to production

---

## 📚 Full Documentation

→ Complete guide: `Backend/FLUTTER_ADMIN_IMPLEMENTATION.md`
→ Backend README: `Backend/README.md`
→ Flutter routes: `FLUTTER_ROUTES_TESTING.md`

---

**Last Updated:** 2025-01-26
