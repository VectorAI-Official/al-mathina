# 📱 Al-Madhina App - Quick Install Script
# Run this script to install the app on your connected Android device

Write-Host "
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         AL-MATHINA APP - INSTALLATION SCRIPT            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
" -ForegroundColor Cyan

# Check if ADB is available
$adbPath = Get-Command adb -ErrorAction SilentlyContinue

if (-not $adbPath) {
    Write-Host "❌ ADB not found in PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install the app manually:" -ForegroundColor Yellow
    Write-Host "1. Copy 'AlMathina-Release.apk' from Desktop to your phone" -ForegroundColor White
    Write-Host "2. Open File Manager on phone" -ForegroundColor White
    Write-Host "3. Navigate to where you copied the APK" -ForegroundColor White
    Write-Host "4. Tap on the APK file to install" -ForegroundColor White
    Write-Host "5. Allow 'Install from Unknown Sources' if prompted" -ForegroundColor White
    Write-Host ""
    Pause
    exit
}

# Check if device is connected
Write-Host "🔍 Checking for connected devices..." -ForegroundColor Yellow
$devices = & adb devices | Select-String -Pattern "device$"

if (-not $devices) {
    Write-Host "❌ No Android device connected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Connect your Android phone via USB cable" -ForegroundColor White
    Write-Host "2. Enable 'USB Debugging' in Developer Options" -ForegroundColor White
    Write-Host "3. Run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "OR install manually from Desktop/AlMathina-Release.apk" -ForegroundColor Cyan
    Write-Host ""
    Pause
    exit
}

Write-Host "✅ Device connected!" -ForegroundColor Green
Write-Host ""

# Check if APK exists
$apkPath = "$env:USERPROFILE\Desktop\AlMathina-Release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "❌ APK not found at: $apkPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Looking for APK in build folder..." -ForegroundColor Yellow
    $buildApkPath = "C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview\build\app\outputs\flutter-apk\app-release.apk"
    
    if (Test-Path $buildApkPath) {
        Write-Host "✅ Found APK in build folder!" -ForegroundColor Green
        $apkPath = $buildApkPath
    } else {
        Write-Host "❌ APK not found anywhere!" -ForegroundColor Red
        Pause
        exit
    }
}

# Uninstall old version first (optional, will fail if not installed - that's OK)
Write-Host "🗑️  Uninstalling old version (if exists)..." -ForegroundColor Yellow
& adb uninstall com.vectorai.almadhina 2>$null
Write-Host ""

# Install new APK
Write-Host "📦 Installing Al-Madhina App..." -ForegroundColor Cyan
Write-Host "   APK Size: 49.9 MB" -ForegroundColor Gray
Write-Host "   This may take 30-60 seconds..." -ForegroundColor Gray
Write-Host ""

$installResult = & adb install -r "$apkPath" 2>&1

if ($installResult -match "Success") {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                          ║" -ForegroundColor Green
    Write-Host "║           ✅ INSTALLATION SUCCESSFUL! ✅                ║" -ForegroundColor Green
    Write-Host "║                                                          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Al-Madhina app is now installed on your device!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Open the 'Al-Mathina' app from your phone" -ForegroundColor White
    Write-Host "   2. Enter your phone number (with +91 prefix)" -ForegroundColor White
    Write-Host "   3. Verify: NO Chrome browser should open!" -ForegroundColor White
    Write-Host "   4. Enter the OTP you receive" -ForegroundColor White
    Write-Host "   5. Start shopping! 🛒" -ForegroundColor White
    Write-Host ""
    Write-Host "🔥 Firebase Auth with SHA keys is now active!" -ForegroundColor Green
    Write-Host "   - No more Chrome redirection" -ForegroundColor Green
    Write-Host "   - Silent device verification" -ForegroundColor Green
    Write-Host "   - Instant OTP delivery" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Installation failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $installResult -ForegroundColor Red
    Write-Host ""
    Write-Host "Please try manual installation:" -ForegroundColor Yellow
    Write-Host "1. Copy 'AlMathina-Release.apk' from Desktop to your phone" -ForegroundColor White
    Write-Host "2. Open the APK file on your phone to install" -ForegroundColor White
    Write-Host ""
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
