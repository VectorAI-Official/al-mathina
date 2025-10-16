# Run Flutter Web App
Set-Location "c:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview"
Write-Host "Current Directory: $(Get-Location)"
Write-Host "Checking pubspec.yaml..."
if (Test-Path "pubspec.yaml") {
    Write-Host "pubspec.yaml found!"
    flutter run -d chrome --web-port 9090
} else {
    Write-Host "ERROR: pubspec.yaml not found!"
}
