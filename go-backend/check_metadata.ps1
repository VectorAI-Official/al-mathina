# Check category_metadata collection to debug image issue
Write-Host "Checking category_metadata collection" -ForegroundColor Cyan

# Query Go backend metadata endpoint
Write-Host "`n1. Fetching metadata from Go backend..." -ForegroundColor Yellow
$metadata = curl.exe -s http://localhost:9000/admin/api/categories/metadata | ConvertFrom-Json

Write-Host "Total metadata entries: $($metadata.metadata.Count)" -ForegroundColor Gray

# Check all type values
Write-Host "`n2. All 'type' values in metadata:" -ForegroundColor Yellow
$metadata.metadata | Group-Object -Property type | ForEach-Object {
    Write-Host "  - Type '$($_.Name)': $($_.Count) entries" -ForegroundColor Gray
}

# Show ALL metadata entries (first 10)
Write-Host "`n3. First 10 metadata entries:" -ForegroundColor Yellow
$metadata.metadata | Select-Object -First 10 | ForEach-Object {
    Write-Host "  - Name: $($_.name)" -ForegroundColor White
    Write-Host "    Type: '$($_.type)'" -ForegroundColor Gray
    Write-Host "    Section: $($_.section)" -ForegroundColor Gray
    Write-Host "    Main Category: $($_.main_category)" -ForegroundColor Gray
    Write-Host "    Image URL: $($_.image_url)" -ForegroundColor $(if ($_.image_url) { "Green" } else { "Red" })
    Write-Host ""
}

# Check for test_main category (any type)
Write-Host "`n4. Looking for 'test_main' in any field..." -ForegroundColor Yellow
$testEntries = $metadata.metadata | Where-Object { 
    $_.name -eq "test_main" -or 
    $_.main_category -eq "test_main" -or
    $_.section -eq "test_main"
}
if ($testEntries) {
    Write-Host "  ✓ Found entries:" -ForegroundColor Green
    $testEntries | Format-List name, type, section, main_category, image_url
} else {
    Write-Host "  ✗ No entries found for 'test_main'" -ForegroundColor Red
}
