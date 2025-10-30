# Language Persistence Testing Guide

## Prerequisites
- Flutter development environment set up
- AL-Madhina Flutter app accessible
- Ability to run the app in Chrome (flutter run -d chrome) or an emulator

## Test Cases

### Test 1: Default Language on First Launch
**Objective**: Verify app defaults to English on first launch

**Steps**:
1. Clear app data/cache or use a clean environment
2. Run the app: `flutter run -d chrome`
3. Observe the app initialization

**Expected Result**: 
- App loads and displays in English
- All text labels in English (Home, Cart, Favorites, Profile)
- Language dropdown shows "English" selected

**Pass/Fail**: ___________

---

### Test 2: Change Language to Tamil
**Objective**: Verify language can be changed to Tamil

**Steps**:
1. App is running and showing in English
2. Click on the language dropdown in the app bar (top right)
3. Select "தமிழ்" (Tamil)
4. Observe the UI update

**Expected Result**:
- Language dropdown shows "தமிழ்" selected
- All UI text changes to Tamil immediately
- Example translations:
  - "Home" → "முகப்பு"
  - "Cart" → "வண்டி"
  - "Favorites" → "விருப்பங்கள்"
  - "Profile" → "சுயவிவரம்"

**Pass/Fail**: ___________

---

### Test 3: Language Persistence After App Close & Reopen
**Objective**: Verify language preference is saved and restored

**Steps**:
1. App is running in Tamil (from Test 2)
2. Close the app completely (stop from terminal or close browser tab)
3. Wait 2-3 seconds
4. Rerun the app: `flutter run -d chrome`
5. Observe the initial language

**Expected Result**:
- App starts in Tamil (not English)
- No need to re-select the language
- All UI text displays in Tamil
- Language dropdown shows "தமிழ்" selected on app bar

**Pass/Fail**: ___________

---

### Test 4: Switch Back to English and Persist
**Objective**: Verify switching back to English also persists

**Steps**:
1. App is running in Tamil (from Test 3)
2. Click on the language dropdown
3. Select "English"
4. Observe the UI update to English
5. Close the app completely
6. Rerun the app

**Expected Result**:
- Step 4: UI updates to English
- Step 6: App starts in English with English UI text
- No need to re-select language

**Pass/Fail**: ___________

---

### Test 5: Multiple Language Switches
**Objective**: Verify persistence works with multiple rapid language changes

**Steps**:
1. App is running
2. Switch to Tamil
3. Switch to English
4. Switch to Tamil
5. Close and reopen app

**Expected Result**:
- Each switch works instantly
- Final language (Tamil) is saved and restored on app restart

**Pass/Fail**: ___________

---

### Test 6: Language Preference Across Different Screens
**Objective**: Verify language is maintained when navigating to different screens

**Steps**:
1. App running in Tamil
2. Navigate to different screens:
   - Home → Favorites → Profile → Cart → Home
3. Close and reopen app

**Expected Result**:
- Language remains Tamil throughout navigation
- All screens display content in Tamil
- After restart, app opens in Tamil

**Pass/Fail**: ___________

---

### Test 7: Device Storage Verification (Android/iOS)
**Objective**: Verify language preference is stored in SharedPreferences

**Steps** (if testing on Android):
1. Run app on Android device/emulator
2. Change language to Tamil
3. Open Android Debug Bridge (adb):
   ```
   adb shell
   cd /data/data/com.example.flutter_preview
   cd shared_prefs
   cat your_app_preferences.xml
   ```
4. Look for `userLanguage` key

**Expected Result**:
- Should find entry like:
  ```xml
  <string name="userLanguage">ta</string>
  ```

**Pass/Fail**: ___________

---

### Test 8: Clear SharedPreferences Recovery
**Objective**: Verify app handles missing saved preference gracefully

**Steps**:
1. App running in Tamil
2. Clear app data (Settings → Apps → flutter_preview → Clear Storage)
3. Reopen app

**Expected Result**:
- App opens in default English (graceful fallback)
- No crashes or errors
- Language dropdown works normally

**Pass/Fail**: ___________

---

## Performance Tests

### Test 9: Startup Time
**Objective**: Verify language loading doesn't impact startup time

**Steps**:
1. Record time to see UI on first launch
2. Change to Tamil
3. Close app completely
4. Record time to see UI on restart with saved language

**Expected Result**:
- Startup time is similar (no noticeable delay)
- Language preference loads before UI renders
- App appears with correct language immediately

**Pass/Fail**: ___________

---

## Edge Cases

### Test 10: Invalid Language Code
**Objective**: Verify app handles corrupted saved data

**Steps** (manual):
1. Edit SharedPreferences to set userLanguage to invalid value (e.g., "fr")
2. Open app

**Expected Result**:
- App defaults to English
- No crashes
- Error is logged to console

**Pass/Fail**: ___________

---

## Automated Testing Script

You can verify the implementation by checking:

```bash
# Check if language loading method exists
grep -n "loadLanguage" flutter_preview/lib/main.dart

# Check if language saving is implemented
grep -n "_saveLanguage" flutter_preview/lib/main.dart

# Check if main() calls loadLanguage
grep -A 5 "void main()" flutter_preview/lib/main.dart
```

---

## Summary Checklist

- [ ] Default language is English on first launch
- [ ] Language can be changed to Tamil
- [ ] Selected language persists after app restart
- [ ] Can switch back to English and it persists
- [ ] Multiple language switches work correctly
- [ ] Language maintained across all screens
- [ ] No performance degradation
- [ ] Graceful handling of missing/invalid data
- [ ] No crashes during language switching
- [ ] SharedPreferences stores language correctly

---

## Known Limitations & Notes

1. **First-Time Load**: Language loading happens synchronously in main(), so there's a slight initialization delay (negligible)
2. **Multiple Devices**: Language preference is device-specific (not synced across devices)
3. **App Update**: Language preference is preserved during app updates (not reset)
4. **Uninstall**: Language preference is lost when app is uninstalled (standard behavior)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App still shows English after restart | Clear app cache: `flutter clean` then rebuild |
| Language doesn't persist | Check device storage permissions |
| Language dropdown not working | Check Provider dependency is correctly installed |
| Error loading preferences | Check SharedPreferences package version (^2.1.0+) |
| Multiple languages not appearing | Verify translations map in main.dart |

