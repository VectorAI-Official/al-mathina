# 🔥 Firebase SHA Keys Setup Guide - Fix Chrome Redirection

## 📋 Your SHA Keys (COPY THESE!)

### **Debug SHA-1 Key:**
```
BE:B3:4D:45:99:CA:09:2C:0C:20:98:5F:BE:DF:C9:72:95:3C:7E:0F
```

### **Debug SHA-256 Key:**
```
A9:F7:86:1F:6E:8F:3B:54:0D:41:5D:29:88:F3:FC:B3:CC:9C:67:AB:22:3D:FF:4E:AD:9F:E1:3E:56:09:55:E1
```

---

## 🎯 Step-by-Step Firebase Configuration

### **Step 1: Add SHA Keys to Firebase Console**

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/
   - Select your project: **"AL-Madhina"** (or your project name)

2. **Navigate to Project Settings:**
   - Click the **⚙️ Gear icon** (top left) → **Project Settings**

3. **Select Your Android App:**
   - Scroll down to **"Your apps"** section
   - Click on your Android app (package name should match: `com.example.flutter_preview` or similar)

4. **Add SHA Fingerprints:**
   - Click **"Add fingerprint"** button
   - **First**, paste the **SHA-1** key:
     ```
     BE:B3:4D:45:99:CA:09:2C:0C:20:98:5F:BE:DF:C9:72:95:3C:7E:0F
     ```
   - Click **"Save"**
   
   - Click **"Add fingerprint"** again
   - **Second**, paste the **SHA-256** key:
     ```
     A9:F7:86:1F:6E:8F:3B:54:0D:41:5D:29:88:F3:FC:B3:CC:9C:67:AB:22:3D:FF:4E:AD:9F:E1:3E:56:09:55:E1
     ```
   - Click **"Save"**

5. **Download Updated google-services.json:**
   - After adding SHA keys, click **"google-services.json"** download button
   - **IMPORTANT:** Replace the old file at:
     ```
     flutter_preview/android/app/google-services.json
     ```

---

### **Step 2: Enable Play Integrity API**

1. **Open Google Cloud Console:**
   - Go to: https://console.cloud.google.com/
   - Select the **same project** linked to your Firebase (usually auto-selected)

2. **Enable Play Integrity API:**
   - In the search bar at top, type: **"Play Integrity API"**
   - Click on **"Play Integrity API"** from results
   - Click **"Enable"** button
   - Wait for 1-2 minutes for activation

3. **Alternative (if Play Integrity not available):**
   - Search for **"Android Device Verification"** or **"SafetyNet"**
   - Enable it (older alternative to Play Integrity)

---

### **Step 3: Update Firebase Auth SDK**

Your current version: `firebase_auth: ^6.1.2` ✅ (Already latest!)

**Verify in pubspec.yaml:**
```yaml
dependencies:
  firebase_core: ^4.2.1
  firebase_auth: ^6.1.2  # Already updated!
```

If you see older versions, run:
```bash
flutter pub upgrade firebase_auth firebase_core
```

---

### **Step 4: Clean Build & Cache**

Run these commands in terminal (PowerShell):

```powershell
# Navigate to flutter project
cd flutter_preview

# Clean Flutter cache
flutter clean

# Clean Android build
cd android
./gradlew clean
cd ..

# Get dependencies fresh
flutter pub get

# Rebuild the app
flutter build apk --debug
```

---

### **Step 5: Configure AndroidManifest.xml (Verify)**

Make sure your `android/app/src/main/AndroidManifest.xml` has proper permissions:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
<uses-permission android:name="android.permission.READ_SMS"/>
```

---

### **Step 6: Test OTP Without Chrome Redirection**

1. **Uninstall old app** from your device/emulator:
   ```bash
   adb uninstall com.example.flutter_preview
   ```

2. **Install fresh build:**
   ```bash
   flutter run
   ```

3. **Test OTP:**
   - Enter phone number
   - Click "Send OTP"
   - **Should NOT redirect to Chrome** anymore!
   - OTP should verify silently in background

---

## 🔍 How It Works Now

### **Before (with Chrome redirection):**
1. User enters phone number
2. Firebase can't verify device silently
3. Opens Chrome for reCAPTCHA verification
4. User completes CAPTCHA
5. Returns to app
6. OTP sent

### **After (with SHA keys + Play Integrity):**
1. User enters phone number
2. Firebase uses **Play Integrity API** to verify device silently
3. No browser redirect needed!
4. OTP sent immediately
5. User enters OTP
6. Login complete ✅

---

## 🚨 Common Issues & Fixes

### **Issue 1: Still showing Chrome after adding SHA keys**
**Solution:**
- Wait 10-15 minutes after adding SHA keys (Firebase propagation time)
- Download NEW `google-services.json` file
- Clean build completely:
  ```bash
  flutter clean
  cd android && ./gradlew clean && cd ..
  rm -rf build/
  flutter pub get
  flutter run
  ```

### **Issue 2: "App not authorized" error**
**Solution:**
- Verify SHA keys match exactly (check for extra spaces)
- Ensure package name in Firebase matches your app's package name
- Check `android/app/build.gradle.kts` → `applicationId`

### **Issue 3: Play Integrity API not working**
**Solution:**
- Enable "Android Device Verification" API instead
- Make sure Google Cloud project is linked to Firebase
- Verify billing is enabled (Play Integrity requires paid account for production)

---

## 🎉 Success Checklist

- [x] SHA-1 key added to Firebase Console
- [x] SHA-256 key added to Firebase Console
- [x] New `google-services.json` downloaded and replaced
- [x] Play Integrity API enabled in Google Cloud Console
- [x] Firebase Auth SDK updated to latest version
- [x] Flutter clean build completed
- [x] App uninstalled and reinstalled fresh
- [x] OTP verification tested - NO Chrome redirection!

---

## 📞 Your SHA Keys Reference

Keep these for future reference (e.g., when releasing to Play Store, you'll need release keystore SHA keys too):

**Debug Keys (Development):**
- SHA-1: `BE:B3:4D:45:99:CA:09:2C:0C:20:98:5F:BE:DF:C9:72:95:3C:7E:0F`
- SHA-256: `A9:F7:86:1F:6E:8F:3B:54:0D:41:5D:29:88:F3:FC:B3:CC:9C:67:AB:22:3D:FF:4E:AD:9F:E1:3E:56:09:55:E1`

**Location:** `C:\Users\faisa\.android\debug.keystore`

---

## 🔐 For Production Release (Later)

When you create a release build, generate release keystore SHA keys:

```powershell
keytool -list -v -keystore your_release.keystore -alias your_alias
```

And add those SHA keys to Firebase Console the same way!

---

## 💡 Quick Command Reference

**Get SHA keys anytime:**
```powershell
& "C:\Program Files\Java\jre1.8.0_471\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

**Clean & rebuild:**
```bash
flutter clean && flutter pub get && flutter run
```

---

✅ **Follow these steps exactly, and your Chrome redirection will be gone!**
