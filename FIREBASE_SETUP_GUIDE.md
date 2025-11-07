# Firebase Android App Configuration

## App Details
- **App Name:** Al-Mathina
- **Package Name:** com.vectorai.almadhina
- **Firebase Project ID:** al-mathina
- **App ID:** 1:753225358557:android:5aa8dd7a891f803058cf34

## SHA Certificate Fingerprints

### Debug (Development)
These fingerprints are from your debug keystore and are used during development and testing.

**SHA-1:**
```
BE:B3:4D:45:99:CA:09:2C:0C:20:98:5F:BE:DF:C9:72:95:3C:7E:0F
```

**SHA-256:**
```
A9:F7:86:1F:6E:8F:3B:54:0D:41:5D:29:88:F3:FC:B3:CC:9C:67:AB:22:3D:FF:4E:AD:9F:E1:3E:56:09:55:E1
```

## Firebase Console Setup Instructions

### Step 1: Add SHA Fingerprints to Firebase
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **al-mathina**
3. Go to **Project Settings** (gear icon)
4. Select the **Android app** tab (com.vectorai.almadhina)
5. Scroll down to **"SHA certificate fingerprints"**
6. Click **"Add fingerprint"**
7. Add **SHA-1** fingerprint:
   ```
   BE:B3:4D:45:99:CA:09:2C:0C:20:98:5F:BE:DF:C9:72:95:3C:7E:0F
   ```
8. Click **"Add fingerprint"** again
9. Add **SHA-256** fingerprint:
   ```
   A9:F7:86:1F:6E:8F:3B:54:0D:41:5D:29:88:F3:FC:B3:CC:9C:67:AB:22:3D:FF:4E:AD:9F:E1:3E:56:09:55:E1
   ```
10. Click **"Save"**

### Step 2: Enable Phone Number Authentication
1. Go to Firebase Console > **Authentication**
2. Click **"Sign-in method"** tab
3. Find **"Phone"** provider
4. Click the toggle to **Enable**
5. Read and accept the terms
6. Click **"Save"**

### Step 3: Add Test Phone Numbers (Optional - for development)
1. In **Sign-in method** tab
2. Expand **"Phone numbers for testing"**
3. Add test phone numbers (e.g., +1 650-555-3434)
4. Add 6-digit verification code (e.g., 123456)
5. Click **"Add"**

## Android App Configuration Files

### ✅ Updated Files
- `android/build.gradle.kts` - Google Services plugin added
- `android/app/build.gradle.kts` - Firebase dependencies added
- `android/app/google-services.json` - Firebase config file
- `flutter_preview/pubspec.yaml` - Firebase packages added

### ✅ Dart Implementation
- `lib/firebase_options.dart` - Firebase initialization options
- `lib/services/phone_auth_service.dart` - Phone authentication service
- `lib/screens/phone_auth_screen.dart` - Phone auth UI screen
- `lib/main.dart` - Firebase initialization at app startup

## Testing Phone Authentication

### On Emulator/Device
```bash
cd flutter_preview
flutter clean
flutter pub get
flutter run -d <device_id>
```

### With Test Phone Numbers
1. Use a test phone number added in Firebase console
2. OTP will be sent to console instead of actual SMS
3. Use the test code you configured (e.g., 123456)

### With Real Phone Numbers (Production)
1. Firebase will send real SMS to the phone number
2. User must enter the code they receive
3. Make sure phone number is in E.164 format (+country_code...)

## Production Signing

For release builds, you'll also need to:
1. Generate a production keystore
2. Get SHA-1 and SHA-256 from production keystore
3. Add production fingerprints to Firebase console

```bash
# Generate production keystore
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release_key
```

Then get fingerprints from release keystore:
```bash
keytool -list -v -keystore ~/key.jks -alias release_key
```

## Troubleshooting

### "Phone verification failed" Error
- ✅ SHA fingerprints not added to Firebase? → Add them (see steps above)
- ✅ Phone number sign-in not enabled? → Enable it in Firebase console
- ✅ Using test phone number without adding it? → Add test numbers in console

### "Missing initial state" Error
- This happens with reCAPTCHA flow
- Try on a device with Google Play Services
- Or use a test phone number in Firebase console

### SMS Not Received
- Check if phone number is in E.164 format (+country_code...)
- Verify SMS region policy in Firebase > Authentication > Settings
- Check if using test phone number with test code

## Next Steps

1. ✅ Add SHA fingerprints to Firebase (see Step 1 above)
2. ✅ Enable Phone authentication (see Step 2 above)
3. ✅ Test with sample phone number
4. Deploy to Google Play Store for production

---

**Generated:** November 7, 2025
**Project:** AL-Mathina
**Status:** Ready for Phone Authentication Integration
