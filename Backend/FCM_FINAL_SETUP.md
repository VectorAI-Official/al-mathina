# 🔧 FCM Setup - Final Steps

## ✅ What's Been Done

1. **Backend updated** to use Supabase service key properly
2. **Database migration** SQL created for users table
3. **Flutter** configured to save tokens to production backend
4. **Environment template** updated with SUPABASE_SERVICE_KEY

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Get Your Supabase Service Key

1. Go to: https://supabase.com/dashboard/project/zuhkndylyavedmfrovsj/settings/api
2. Copy the **`service_role` secret key** (NOT the anon key)
3. ⚠️ **IMPORTANT**: Keep this secret! Never commit to Git.

### Step 2: Update Backend Environment

Edit `Backend/.env.local` (or create from template):

```bash
# Copy template if you don't have .env.local
cp Backend/.env.local.template Backend/.env.local
```

Then add your service key:

```dotenv
SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1aGtuZHlseWF2ZWRtZnJvdnNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwODc2NDAsImV4cCI6MjA4MDY2MzY0MH0.MeRnP6FlqZ5HcK_JWx_yMNBNE7SWhJT7M1vC1WeAKSQ
SUPABASE_SERVICE_KEY=paste-your-service-role-key-here
```

### Step 3: Run Database Migration

Go to Supabase SQL Editor:
https://supabase.com/dashboard/project/zuhkndylyavedmfrovsj/sql

Copy and run this SQL (or use the file `Backend/database/migrations/001_add_fcm_support.sql`):

```sql
-- Add FCM token support
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS store_name TEXT,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
```

**Verify it worked:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND column_name IN ('fcm_token', 'store_name');
```

You should see both columns listed.

### Step 4: Install Backend Dependencies

```powershell
cd Backend
pip install supabase firebase-admin
```

### Step 5: Start Backend

```powershell
cd Backend
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Expected output:**
```
✅ Supabase client initialized with service key
✅ Supabase connection successful (users table accessible)
✅ Firebase Admin SDK initialized successfully
```

### Step 6: Run Flutter App

```powershell
cd flutter_preview
flutter run -d RZ8NA1WCLWL
```

---

## 🧪 Test the Complete Flow

### 1. Login to App
- User logs in with phone + OTP
- **Expected logs:**
  ```
  ✅ FCM: User granted notification permission
  ✅ FCM Token: eyJhbGci...
  ✅ FCM token saved to backend
  ```

### 2. Verify Token in Supabase

Run in Supabase SQL Editor:
```sql
SELECT phone, 
       LEFT(fcm_token, 30) as token_preview,
       store_name,
       created_at
FROM users
WHERE fcm_token IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;
```

### 3. Place Test Order
- Add items to cart
- Complete checkout
- **Expected:**
  - Backend logs: `✅ Push notification sent for 2 split order(s)`
  - Device: **Instant notification appears!** 🎉

---

## 🔍 Troubleshooting

### Issue: "Supabase client initialized with anon key"
**Fix:** Make sure `SUPABASE_SERVICE_KEY` is set in `.env.local`

### Issue: "Failed to save FCM token: 401"
**Fix:** Check that service key is correct (copy from Supabase dashboard)

### Issue: "Table 'users' doesn't exist"
**Fix:** Run the migration SQL in Supabase SQL Editor

### Issue: "No FCM token found for user"
**Fix:** User must login first (token refreshes on login)

---

## 📝 Summary of Changes

### Backend Files Modified:
- ✅ `database/supabase_client.py` - Added `get_supabase_client()` with service key support
- ✅ `.env.local.template` - Added `SUPABASE_SERVICE_KEY` field
- ✅ `database/migrations/001_add_fcm_support.sql` - Created migration script

### Flutter Files Already Updated:
- ✅ `lib/services/fcm_service.dart` - Production URL configured
- ✅ `lib/main.dart` - FCM initialization on app launch
- ✅ `lib/screens/phone_auth_screen.dart` - Token refresh on login

### What Happens Now:

```
User logs in
  ↓
App requests notification permission
  ↓
Firebase generates FCM token
  ↓
Flutter sends token to backend (POST /api/user/fcm-token)
  ↓
Backend saves to Supabase users.fcm_token (using service key)
  ↓
User places order
  ↓
Backend fetches FCM token from Supabase
  ↓
Backend sends notification via Firebase Admin SDK
  ↓
User receives INSTANT push notification! 🎉
```

---

## ✨ You're Done!

Just follow steps 1-6 above and you'll have:
- ✅ FCM tokens saved in your Supabase database
- ✅ Instant push notifications on order placement
- ✅ Beautiful Al-Mathina branded notifications
- ✅ All completely FREE (Firebase FCM has no cost)

**Total setup time: ~5 minutes** ⚡

Need help? Check the logs in:
- Backend console (shows token saves and notification sends)
- Flutter console (shows FCM initialization and token generation)
- Supabase Table Editor (shows saved tokens)
