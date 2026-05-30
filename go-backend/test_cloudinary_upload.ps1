#!/usr/bin/env pwsh
# Test Cloudinary image upload integration

$GO_BACKEND_URL = "http://localhost:9000"

Write-Host "`n🧪 CLOUDINARY UPLOAD TEST" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Create test image (1x1 PNG)
$testImagePath = "test_category_image.png"
$base64PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
[System.IO.File]::WriteAllBytes($testImagePath, [System.Convert]::FromBase64String($base64PNG))

Write-Host "`n✓ Test image created: $testImagePath" -ForegroundColor Green

# Test 1: Upload without category metadata (should use local storage)
Write-Host "`n📤 TEST 1: Upload without category metadata (fallback to local)" -ForegroundColor Yellow
$response1 = curl.exe -X POST "$GO_BACKEND_URL/admin/api/upload-image" `
    -F "file=@$testImagePath" `
    -s | ConvertFrom-Json

Write-Host "Response:" -ForegroundColor Cyan
$response1 | ConvertTo-Json -Depth 3
if ($response1.storage -eq "local") {
    Write-Host "✓ PASS: Fallback to local storage works" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Expected local storage" -ForegroundColor Red
}

# Test 2: Upload with category metadata (should use Cloudinary)
Write-Host "`n📤 TEST 2: Upload with category metadata (Cloudinary upload)" -ForegroundColor Yellow
$response2 = curl.exe -X POST "$GO_BACKEND_URL/admin/api/upload-image" `
    -F "file=@$testImagePath" `
    -F "category_type=section" `
    -F "category_name=Testing" `
    -s | ConvertFrom-Json

Write-Host "Response:" -ForegroundColor Cyan
$response2 | ConvertTo-Json -Depth 3

if ($response2.storage -eq "cloudinary") {
    Write-Host "✓ PASS: Cloudinary upload successful" -ForegroundColor Green
    Write-Host "  Image URL: $($response2.url)" -ForegroundColor Cyan
    
    # Verify URL format
    if ($response2.url -like "https://res.cloudinary.com/vectorai/*") {
        Write-Host "✓ PASS: URL matches Cloudinary format" -ForegroundColor Green
    } else {
        Write-Host "✗ FAIL: URL doesn't match Cloudinary format" -ForegroundColor Red
    }
} else {
    Write-Host "✗ FAIL: Expected Cloudinary storage, got: $($response2.storage)" -ForegroundColor Red
}

# Cleanup
Remove-Item $testImagePath -ErrorAction SilentlyContinue
Write-Host "`n✓ Test image deleted" -ForegroundColor Green

Write-Host "`n🎯 TEST SUMMARY:" -ForegroundColor Cyan
Write-Host "  - Local fallback: $(if ($response1.storage -eq 'local') {'✓ PASS'} else {'✗ FAIL'})" -ForegroundColor $(if ($response1.storage -eq 'local') {'Green'} else {'Red'})
Write-Host "  - Cloudinary upload: $(if ($response2.storage -eq 'cloudinary') {'✓ PASS'} else {'✗ FAIL'})" -ForegroundColor $(if ($response2.storage -eq 'cloudinary') {'Green'} else {'Red'})
Write-Host "  - URL format: $(if ($response2.url -like 'https://res.cloudinary.com/*') {'✓ PASS'} else {'✗ FAIL'})" -ForegroundColor $(if ($response2.url -like 'https://res.cloudinary.com/*') {'Green'} else {'Red'})
