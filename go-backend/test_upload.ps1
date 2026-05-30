# Test image upload endpoint
Write-Host "Testing Image Upload Endpoint" -ForegroundColor Cyan

# Create a test image file (1x1 pixel PNG)
$testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
$testImageBytes = [Convert]::FromBase64String($testImageBase64)
$testImagePath = Join-Path $PSScriptRoot "test_image.png"
[IO.File]::WriteAllBytes($testImagePath, $testImageBytes)

Write-Host "`nTest file created: $testImagePath" -ForegroundColor Yellow
Write-Host "File exists: $(Test-Path $testImagePath)" -ForegroundColor Gray

# Test upload using curl (simpler than Invoke-RestMethod for file uploads)
try {
    $response = curl.exe -s -X POST http://localhost:9000/admin/api/upload-image `
        -F "file=@$testImagePath;type=image/png"
    
    Write-Host "`n✓ Upload completed!" -ForegroundColor Green
    Write-Host "Response: $response" -ForegroundColor Gray
    
    # Parse JSON response
    $responseObj = $response | ConvertFrom-Json
    
    if ($responseObj.url) {
        Write-Host "`n✓ Image URL: $($responseObj.url)" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n✗ Upload failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    # Cleanup test file
    if (Test-Path $testImagePath) {
        Remove-Item $testImagePath
        Write-Host "`nTest file cleaned up" -ForegroundColor Yellow
    }
}
