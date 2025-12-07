# Firebase Cloud Messaging (FCM) Setup Guide

## 🎯 Overview
This guide will help you set up Firebase Cloud Messaging for instant push notifications when users place orders.

**✅ Zero-Cost Solution** - FCM is completely free for unlimited notifications!

---

## 📱 What's Already Done

### ✅ Flutter App (Frontend)
- **Packages installed**: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`
- **Service created**: `lib/services/fcm_service.dart`
- **Initialization**: FCM initializes on app launch in `main.dart`
- **Token management**: FCM token is automatically fetched and sent to backend
- **Auto-refresh**: Token refreshes on login and when Firebase updates it
- **Foreground notifications**: Shows beautiful local notifications with Al-Mathina green branding
- **Background handling**: Properly handles notifications when app is closed

### ✅ Backend (FastAPI)
- **Package installed**: `firebase-admin==6.5.0`
- **Routes created**: `/api/user/fcm-token` (save token), `/api/user/fcm-token/{phone}` (get token)
- **Service created**: `utils/fcm_service.py` with singleton pattern
- **Integration**: Order creation automatically sends push notification
- **Supabase storage**: FCM tokens stored in `users` table
- **Branded messages**: All notifications include Al-Mathina green color (#28a745)

---

## 🔧 Setup Steps (5 minutes)

### Step 1: Download Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Al-Mathina** project (or the project where `google-services.json` came from)
3. Click the ⚙️ gear icon → **Project Settings**
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the downloaded JSON file as: `Backend/firebase-service-account.json`

**⚠️ IMPORTANT**: Never commit this file to Git! Add to `.gitignore` if not already present.

### Step 2: Update Supabase Users Table

Run this SQL in your Supabase SQL Editor:

```sql
-- Add fcm_token column to users table if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token);

-- Add store_name if not exists (for personalized notifications)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS store_name TEXT;
```

### Step 3: Install Dependencies

```powershell
# Backend
cd Backend
pip install -r requirements.txt

# Flutter
cd ../flutter_preview
flutter pub get
```

### Step 4: Test the Setup

1. **Start Backend**:
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

2. **Run Flutter App**:
```powershell
cd flutter_preview
flutter run -d chrome  # For testing, or use android emulator
```

3. **Login** to the app - this will:
   - Request notification permission
   - Get FCM token
   - Save token to backend

4. **Place an order** - you should instantly receive:
   - Push notification with order details
   - Title: "🎉 Order Received!"
   - Body: "Your order #XXXXX for ₹XXX has been placed successfully."
   - If store name exists: "Thank you, {StoreName}! 🙏"

---

## 🎨 Notification Branding

All notifications include **Al-Mathina branding**:

- **Color**: Green (#28a745) - Al-Mathina brand color
- **Icon**: App launcher icon (`ic_launcher`)
- **Sound**: Default notification sound
- **Vibration**: Enabled
- **Priority**: High (shows on lockscreen)
- **Channel**: "Order Notifications" (for user control)

---

## 📝 How It Works (Technical Flow)

### 1. **App Launch**
```
Flutter app starts
  → Firebase initializes
  → FCM requests permission
  → Gets device FCM token
  → Sends token to backend: POST /api/user/fcm-token
  → Backend saves token to Supabase users table
```

### 2. **User Login**
```
User enters OTP
  → Login succeeds
  → FCM token refreshes (ensures latest token)
  → Token sent to backend again
```

### 3. **Order Placement**
```
User places order
  → Backend creates order in MongoDB
  → Backend fetches user's FCM token from Supabase
  → Backend sends notification via Firebase Admin SDK
  → User receives instant push notification! 🎉
```

### 4. **Notification Display**
```
If app is open (foreground):
  → Local notification shows with Al-Mathina branding
  → User sees in-app notification

If app is closed (background):
  → System notification shows
  → User taps → app opens
```

---

## 🔍 Troubleshooting

### Issue: "Firebase service account file not found"
**Solution**: Make sure `Backend/firebase-service-account.json` exists. Download from Firebase Console.

### Issue: "User didn't receive notification"
**Checklist**:
1. ✅ User granted notification permission?
2. ✅ FCM token saved in Supabase? Check: `SELECT fcm_token FROM users WHERE phone = '+91XXXXXXXXXX';`
3. ✅ Firebase service account file exists?
4. ✅ Check backend logs for "✅ Push notification sent successfully"

### Issue: "Firebase not initialized"
**Solution**: Ensure `firebase-service-account.json` is in `Backend/` directory and `firebase-admin` is installed.

### Issue: Notifications work on emulator but not real device
**Solution**: 
1. Make sure `google-services.json` is in `flutter_preview/android/app/`
2. Build release APK: `flutter build apk`
3. Install on device: `flutter install`

---

## 🚀 Production Deployment

### Environment Variable (Optional)
Instead of hardcoding the path, set environment variable:

```bash
export FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/firebase-service-account.json
```

### Docker Deployment
If deploying with Docker, add service account file as secret:

```dockerfile
# In Dockerfile
COPY firebase-service-account.json /app/firebase-service-account.json
ENV FIREBASE_SERVICE_ACCOUNT_PATH=/app/firebase-service-account.json
```

### Fly.io Deployment
```bash
# Set as secret
fly secrets set FIREBASE_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"
```

---

## 📊 Monitoring

Check backend logs for FCM activity:

```
✅ FCM Token: eyJhbGciOiJSUzI1NiIsImtpZC...  # Token received
✅ FCM token saved to backend                 # Token stored in Supabase
✅ Push notification sent successfully        # Notification sent
   Order: ORD-20241207-ABC12                  # Order ID
```

---

## 🎯 Testing Checklist

- [ ] Firebase service account file downloaded
- [ ] Supabase users table has `fcm_token` column
- [ ] Backend dependencies installed (`firebase-admin`)
- [ ] Flutter dependencies installed (`firebase_messaging`)
- [ ] App requests notification permission on launch
- [ ] FCM token appears in backend logs
- [ ] FCM token saved in Supabase users table
- [ ] Order creation sends notification
- [ ] Notification shows with Al-Mathina branding
- [ ] Tapping notification opens app

---

## 📚 Additional Resources

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Admin SDK Docs](https://firebase.google.com/docs/admin/setup)
- [FCM Architecture](https://firebase.google.com/docs/cloud-messaging/fcm-architecture)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)

---

## 🔐 Security Notes

1. **Never commit** `firebase-service-account.json` to Git
2. Add to `.gitignore`: `firebase-service-account.json`
3. Use environment variables in production
4. Rotate service account keys periodically
5. Limit permissions: Service account only needs "Cloud Messaging Admin"

---

## ✅ Success Criteria

When everything is working:

1. ✅ User opens app → sees "User granted notification permission"
2. ✅ User logs in → sees "FCM Token refreshed"
3. ✅ User places order → receives instant notification
4. ✅ Notification has Al-Mathina green color and branding
5. ✅ Backend logs show "Push notification sent successfully"

---

**🎉 Congratulations! Your zero-cost push notification system is ready!**
