# Firebase Version Synchronization Check
# Run this before deploying Firebase updates

Write-Host "🔍 Checking Firebase package synchronization..." -ForegroundColor Cyan

# Check Dart versions
Write-Host "`n📦 Dart Dependencies (pubspec.yaml):" -ForegroundColor Yellow
$pubspec = Get-Content "$PSScriptRoot\..\pubspec.yaml" -Raw
if ($pubspec -match "firebase_core:\s*[\^~]?(\d+\.\d+\.\d+)") {
    $coreVersion = $matches[1]
    Write-Host "  firebase_core: $coreVersion" -ForegroundColor Green
}
if ($pubspec -match "firebase_auth:\s*[\^~]?(\d+\.\d+\.\d+)") {
    $authVersion = $matches[1]
    Write-Host "  firebase_auth: $authVersion" -ForegroundColor Green
}

# Check Android BoM
Write-Host "`n🤖 Android Dependencies (build.gradle.kts):" -ForegroundColor Yellow
$gradle = Get-Content "$PSScriptRoot\..\android\app\build.gradle.kts" -Raw
if ($gradle -match "firebase-bom:(\d+\.\d+\.\d+)") {
    $bomVersion = $matches[1]
    Write-Host "  Firebase BoM: $bomVersion" -ForegroundColor Green
}

# Compatibility check
Write-Host "`n✅ Compatibility Status:" -ForegroundColor Yellow

if ($authVersion -eq "4.16.0" -and $bomVersion -eq "33.1.0") {
    Write-Host "  ✓ Versions are synchronized and compatible!" -ForegroundColor Green
} elseif ($authVersion -eq "4.15.0") {
    Write-Host "  ✗ WARNING: firebase_auth 4.15.0 is outdated!" -ForegroundColor Red
    Write-Host "    Update pubspec.yaml to firebase_auth: ^4.16.0" -ForegroundColor Red
} elseif ($bomVersion -eq "34.5.0") {
    Write-Host "  ✗ WARNING: BoM 34.5.0 is incompatible with firebase_auth 4.16.0!" -ForegroundColor Red
    Write-Host "    Update android/app/build.gradle.kts to 33.1.0" -ForegroundColor Red
} else {
    Write-Host "  ⚠ Custom versions detected - verify compatibility manually" -ForegroundColor Yellow
    Write-Host "    Check: https://firebase.google.com/support/release-notes/android" -ForegroundColor Yellow
}

Write-Host "`n📚 Reference:" -ForegroundColor Cyan
Write-Host "  See DEPENDENCY_SYNC_GUIDE.md for details" -ForegroundColor Cyan
