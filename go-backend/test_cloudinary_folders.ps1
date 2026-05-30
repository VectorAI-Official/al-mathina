#!/usr/bin/env pwsh
# Test Cloudinary upload with Go backend

$GO_BACKEND_URL = "http://localhost:9000"

Write-Host "`n🧪 TESTING CLOUDINARY UPLOAD" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Create test image (1x1 PNG)
$base64PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
[System.IO.File]::WriteAllBytes("test_upload.png", [System.Convert]::FromBase64String($base64PNG))

Write-Host "`n📤 TEST 1: Upload WITHOUT category metadata (should go to almathina/)" -ForegroundColor Yellow
try {
    $response1 = curl.exe -X POST "$GO_BACKEND_URL/admin/api/upload-image" `
        -F "file=@test_upload.png" `
        -s -w "\n%{http_code}" | Out-String
    
    $parts = $response1 -split "`n"
    $httpCode = $parts[-1].Trim()
    $body = ($parts[0..($parts.Length-2)] -join "`n") | ConvertFrom-Json
    
    Write-Host "HTTP Status: $httpCode" -ForegroundColor Cyan
    Write-Host "Storage: $($body.storage)" -ForegroundColor Cyan
    Write-Host "URL: $($body.url)" -ForegroundColor Cyan
    
    if ($body.url -like "https://res.cloudinary.com/vectorai/*almathina*") {
        Write-Host "✅ PASS: Cloudinary upload with almathina folder" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL: Expected Cloudinary URL with almathina folder" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📤 TEST 2: Upload WITH category metadata (should go to almathina/categories/section/)" -ForegroundColor Yellow
try {
    $response2 = curl.exe -X POST "$GO_BACKEND_URL/admin/api/upload-image" `
        -F "file=@test_upload.png" `
        -F "category_type=section" `
        -F "category_name=Testing" `
        -s -w "\n%{http_code}" | Out-String
    
    $parts = $response2 -split "`n"
    $httpCode = $parts[-1].Trim()
    $body = ($parts[0..($parts.Length-2)] -join "`n") | ConvertFrom-Json
    
    Write-Host "HTTP Status: $httpCode" -ForegroundColor Cyan
    Write-Host "Storage: $($body.storage)" -ForegroundColor Cyan
    Write-Host "URL: $($body.url)" -ForegroundColor Cyan
    
    if ($body.url -like "https://res.cloudinary.com/vectorai/*almathina/categories/section*") {
        Write-Host "✅ PASS: Cloudinary upload with category folder structure" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL: Expected Cloudinary URL with almathina/categories/section" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Remove-Item test_upload.png -ErrorAction SilentlyContinue

Write-Host "`n✅ Test complete!" -ForegroundColor Green
