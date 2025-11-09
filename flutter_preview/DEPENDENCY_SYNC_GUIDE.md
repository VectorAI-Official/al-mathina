# Dependency Synchronization Guide

## The Issue We Solved

**Root Cause**: `PigeonUserDetails` type casting error occurred because:
- `pubspec.yaml` had old Firebase versions (firebase_auth 4.15.0)
- Android BoM had incompatible version (34.5.0)
- Internal Pigeon types within firebase_auth plugin were mismatched

## Prevention Rules

### 1. Always Update Both Dart & Native Dependencies Together

When updating Firebase packages:

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.32.0
  firebase_auth: ^4.16.0
```

**ALSO update Android:**

```kotlin
// android/app/build.gradle.kts
implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
```

**Check compatibility**: https://firebase.google.com/support/release-notes/android

### 2. Pre-Deployment Checklist

Before merging Firebase updates:

- [ ] Run `flutter pub get`
- [ ] Run `flutter clean`
- [ ] Check Firebase BoM version compatibility
- [ ] Test on physical device
- [ ] Verify authentication flow completes without crashes

### 3. Version Pinning for Stability

For production, consider exact versions:

```yaml
dependencies:
  firebase_core: 2.32.0  # Remove ^
  firebase_auth: 4.16.0  # Remove ^
```

### 4. Quick Verification Commands

```powershell
# Check installed versions
flutter pub deps | Select-String "firebase"

# Verify no dependency conflicts
flutter pub deps --style=tree
```

### 5. CI/CD Integration

Add to GitHub Actions:

```yaml
- name: Verify Firebase Sync
  run: |
    flutter pub get
    flutter pub deps | grep "firebase_auth 4.16.0" || exit 1
```

## Current Working Configuration

**Dart Side (pubspec.yaml):**
- firebase_core: ^2.32.0
- firebase_auth: ^4.16.0

**Native Side (android/app/build.gradle.kts):**
- Firebase BoM: 33.1.0

**Status**: ✅ Synchronized and tested

## This App Does NOT Use Custom Pigeon

- No custom MethodChannels
- No custom Pigeon schemas
- Only standard Firebase Auth APIs
- PigeonUserDetails is internal to firebase_auth plugin

Therefore, complex Pigeon codegen workflows are not needed.
