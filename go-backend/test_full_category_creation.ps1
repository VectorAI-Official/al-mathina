# Test creating main category with image via Go backend
Write-Host "Testing Main Category Creation with Image" -ForegroundColor Cyan

# Step 1: Upload an image
Write-Host "`n1. Uploading test image..." -ForegroundColor Yellow
$testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
$testImageBytes = [Convert]::FromBase64String($testImageBase64)
$testImagePath = Join-Path $PSScriptRoot "test_category_image.png"
[IO.File]::WriteAllBytes($testImagePath, $testImageBytes)

$uploadResponse = curl.exe -s -X POST http://localhost:9000/admin/api/upload-image `
    -F "file=@$testImagePath;type=image/png" | ConvertFrom-Json

Remove-Item $testImagePath
Write-Host "  Image uploaded: $($uploadResponse.url)" -ForegroundColor Green

# Step 2: Create main category with uploaded image
Write-Host "`n2. Creating main category 'GoTest Category'..." -ForegroundColor Yellow
$categoryData = @{
    section = "test_new_section"
    main_category = "GoTest Category"
    main_category_ta = "கோ டெஸ்ட்"
    image_url = $uploadResponse.url
} | ConvertTo-Json -Compress

$createResponse = curl.exe -s -X POST http://localhost:9000/admin/api/categories/main `
    -H "Content-Type: application/json" `
    -d $categoryData | ConvertFrom-Json

Write-Host "  Response: $($createResponse.message)" -ForegroundColor Green

# Step 3: Verify metadata was saved
Write-Host "`n3. Checking metadata..." -ForegroundColor Yellow
Start-Sleep -Seconds 2  # Wait for DB write

$metadata = curl.exe -s http://localhost:9000/admin/api/categories/metadata | ConvertFrom-Json
$gotestMeta = $metadata.metadata | Where-Object { $_.name -eq "GoTest Category" }

if ($gotestMeta) {
    Write-Host "  ✓ Metadata found!" -ForegroundColor Green
    Write-Host "    Name: $($gotestMeta.name)" -ForegroundColor Gray
    Write-Host "    Type: $($gotestMeta.type)" -ForegroundColor Gray
    Write-Host "    Section: $($gotestMeta.section)" -ForegroundColor Gray
    Write-Host "    Image URL: $($gotestMeta.image_url)" -ForegroundColor Gray
    Write-Host "    Tamil Name: $($gotestMeta.name_ta)" -ForegroundColor Gray
    
    # Verify image is accessible
    $imageTest = curl.exe -s -I "http://localhost:9000$($gotestMeta.image_url)" | Select-String "HTTP"
    Write-Host "`n  ✓ Image accessible: $imageTest" -ForegroundColor Green
} else {
    Write-Host "  ✗ Metadata NOT found!" -ForegroundColor Red
}

# Step 4: Check hierarchy
Write-Host "`n4. Verifying hierarchy..." -ForegroundColor Yellow
$hierarchy = curl.exe -s http://localhost:9000/admin/api/categories | ConvertFrom-Json
$testSection = $hierarchy | Where-Object { $_.section -eq "test_new_section" }
if ($testSection.main_categories."GoTest Category") {
    Write-Host "  ✓ Category exists in hierarchy" -ForegroundColor Green
} else {
    Write-Host "  ✗ Category NOT in hierarchy" -ForegroundColor Red
}

Write-Host "`n✅ Test complete! Check admin dashboard now." -ForegroundColor Cyan
