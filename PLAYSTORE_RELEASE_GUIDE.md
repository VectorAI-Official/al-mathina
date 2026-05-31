# Play Store Release Guide (Al-Mathina Flutter App)

This guide provides step-by-step instructions for generating a production-ready Android App Bundle (AAB) for the Play Store.

## 1. Generate a Release Keystore

If you don't have a keystore yet, generate one using `keytool`:

```bash
keytool -genkey -v -keystore app-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias al-mathina
```

**Important:** Keep this file safe and never commit it to source control.

## 2. Set up `key.properties`

Create (or update) the `flutter_preview/android/key.properties` file with your credentials:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=al-mathina
storeFile=../app-release.jks
```

*Note: `storeFile` is relative to the `flutter_preview/android/app/` directory.*

## 3. Build the Android App Bundle (AAB)

Run the following command from the project root:

```bash
cd flutter_preview
flutter build appbundle --release
```

Alternatively, using Gradle directly:

```bash
cd flutter_preview/android
./gradlew bundleRelease
```

The output will be located at:
`flutter_preview/build/app/outputs/bundle/release/app-release.aab`

## 4. Versioning

To increment the version for a new release, modify `flutter_preview/pubspec.yaml`:

```yaml
version: 1.0.1+2
```

- `1.0.1` is the `versionName`.
- `2` is the `versionCode`.

## 5. Optimization Notes

The release build is configured with:
- **Minification (R8)**: `minifyEnabled true`
- **Resource Shrinking**: `shrinkResources true`
- **Debug Symbols**: Included in the AAB (`ndk { debugSymbolLevel 'FULL' }`) for crash reporting.
