# 🔔 FCM Push Notifications - Quick Test Guide

## ⚡ Quick Setup (2 minutes)

### 1. Download Firebase Service Account
- Go to: https://console.firebase.google.com/
- Select your project → ⚙️ Project Settings → Service Accounts
- Click **"Generate New Private Key"**
- Save as: `Backend/firebase-service-account.json`

### 2. Update Supabase (Run in SQL Editor)
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS store_name TEXT;
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token);
```

### 3. Install Dependencies
```powershell
# Backend
cd Backend
pip install firebase-admin

# Flutter
cd ../flutter_preview
flutter pub get
```

---

## 🧪 Test Flow

### Step 1: Start Backend
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Expected logs on startup:**
```
✅ Firebase Admin SDK initialized successfully
```

### Step 2: Run Flutter App
```powershell
cd flutter_preview
flutter run -d chrome  # or android emulator
```

**Expected logs on app launch:**
```
✅ FCM: User granted notification permission
✅ FCM Token: eyJhbGciOiJSUzI1NiIsImtpZC...
✅ FCM token saved to backend
```

### Step 3: Login
- Enter phone number and OTP
- Login successful

**Expected logs:**
```
🔔 Refreshing FCM token for push notifications...
✅ FCM token saved to backend
```

### Step 4: Check Token in Database
Open Supabase → Table Editor → users table:

**Should see:**
| phone | fcm_token | store_name |
|-------|-----------|------------|
| +91XXXXXXXXXX | eyJhbGci... | YourStore |

### Step 5: Place Test Order
1. Add items to cart
2. Proceed to checkout
3. Complete order

**Expected backend logs:**
```
Created order ORD-20241207-ABC12 for user +91XXXXXXXXXX
✅ Push notification sent for order ORD-20241207-ABC12
```

**Expected on device:**
```
📱 Notification appears:
   Title: 🎉 Order Received!
   Body: Your order #ABC12 for ₹250.00 has been placed successfully.
   Color: Green (#28a745)
```

---

## 🎯 What to Look For

### ✅ Success Indicators

1. **Backend Console**:
   ```
   ✅ Firebase Admin SDK initialized successfully
   ✅ FCM token saved to backend
   ✅ Push notification sent for order ORD-XXXXXXX
   ```

2. **Flutter Console**:
   ```
   ✅ FCM: User granted notification permission
   ✅ FCM Token: eyJhbGci...
   ✅ FCM token saved to backend
   📩 Foreground message: Order Received!
   ```

3. **Device/Emulator**:
   - Notification appears with green branding
   - Shows order details with rupee symbol
   - Tapping opens app

4. **Supabase**:
   - `users.fcm_token` field populated
   - Token is long string (100+ characters)

### ❌ Common Issues

#### Issue 1: "Firebase service account file not found"
**Solution**: Download from Firebase Console and save as `Backend/firebase-service-account.json`

#### Issue 2: "User declined notification permission"
**Solution**: 
- On Android: Go to App Settings → Notifications → Enable
- On Chrome: Allow notifications when prompted

#### Issue 3: "No FCM token found for user"
**Solution**:
- Check if user logged in (FCM refreshes after login)
- Check Supabase: `SELECT fcm_token FROM users WHERE phone = '+91XXXXXXXXXX';`
- If null, try logout → login again

#### Issue 4: Backend logs show "Firebase not initialized"
**Solution**:
- Ensure `firebase-service-account.json` exists in `Backend/` folder
- Check file permissions (should be readable)
- Restart backend server

---

## 🔍 Debug Commands

### Check if FCM token is saved:
```sql
-- In Supabase SQL Editor
SELECT phone, 
       LEFT(fcm_token, 30) as token_preview, 
       store_name 
FROM users 
WHERE fcm_token IS NOT NULL;
```

### Test notification manually (Python):
```python
# In Backend directory
from utils.fcm_service import fcm_service
import asyncio

async def test():
    token = "YOUR_FCM_TOKEN_HERE"  # Copy from Supabase
    success = await fcm_service.send_order_notification(
        fcm_token=token,
        order_id="TEST-12345",
        total_amount=100.0,
        items_count=3,
        store_name="Test Store"
    )
    print(f"Notification sent: {success}")

asyncio.run(test())
```

### Check Firebase Admin SDK status:
```python
import firebase_admin
print("Apps:", firebase_admin._apps)  # Should show 1 app
```

---

## 📱 Testing Environments

### ✅ Chrome (Web) - LIMITED
- Can receive notifications if Chrome is open
- No background notifications
- Good for initial testing

### ✅ Android Emulator - FULL SUPPORT
- Foreground notifications ✅
- Background notifications ✅
- Lockscreen notifications ✅
- Best for complete testing

### ✅ Real Android Device - PRODUCTION
- All features work
- Best for final validation
- Test APK: `flutter build apk`

---

## 🎨 Notification Preview

### Foreground (App Open):
```
┌──────────────────────────────────┐
│ 🎉 Order Received!               │
│                                  │
│ Your order #ABC12 for ₹250.00   │
│ has been placed successfully.    │
│                                  │
│ Thank you, YourStore! 🙏         │
│                                  │
│ [Al-Mathina green header]        │
└──────────────────────────────────┘
```

### Background (App Closed):
```
┌──────────────────────────────────┐
│ 🏪 AL-Madhina                    │
│ 🎉 Order Received!               │
│ Your order #ABC12 for ₹250...   │
│                                  │
│ [Tap to open]                    │
└──────────────────────────────────┘
```

---

## ✅ Test Checklist

- [ ] Firebase service account downloaded
- [ ] Supabase users table updated
- [ ] Backend shows "Firebase initialized"
- [ ] App requests notification permission
- [ ] FCM token appears in logs
- [ ] FCM token saved in Supabase
- [ ] Test order places successfully
- [ ] Notification received instantly
- [ ] Notification has green branding
- [ ] Order details correct in notification
- [ ] Tapping notification opens app

---

## 🚀 Production Notes

Before deploying to production:

1. **Change base URL** in `fcm_service.dart`:
   ```dart
   const String baseUrl = 'https://al-mathina.onrender.com';
   ```

2. **Add to .gitignore**:
   ```
   firebase-service-account.json
   ```

3. **Set environment variable** (production):
   ```bash
   export FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/service-account.json
   ```

4. **Test on real device**:
   ```bash
   flutter build apk --release
   flutter install
   ```

---

## 📊 Expected Response Times

| Event | Time | Notes |
|-------|------|-------|
| FCM token generation | ~1-2s | On app launch |
| Token save to backend | ~500ms | HTTP POST |
| Order creation | ~200ms | MongoDB insert |
| Notification send | ~100ms | Firebase Admin SDK |
| **Total (order → notification)** | **~300ms** | ⚡ Instant! |

---

## 🎯 Success!

When everything works, you'll see:

1. ✅ User opens app → Notification permission granted
2. ✅ User logs in → FCM token refreshed and saved
3. ✅ User places order → **INSTANT notification** with Al-Mathina branding
4. ✅ Notification shows correct order details
5. ✅ Backend logs confirm notification sent

**🎉 Zero-cost instant notifications are now live!**
