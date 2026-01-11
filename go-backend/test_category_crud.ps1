# Category Hierarchy CRUD Testing Script for Go Backend
# Tests all category management operations with the "testing" section

$baseUrl = "http://localhost:9000"
$testSection = "testing"
$testMainCategory = "test_main"
$testSubcategory = "test_sub"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GO BACKEND CATEGORY CRUD TESTS      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: GET All Hierarchy
Write-Host "TEST 1: Get All Hierarchy" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/categories/all"
$hierarchy = $response | ConvertFrom-Json
$testingSection = $hierarchy.hierarchy | Where-Object { $_.section -eq $testSection }
if ($testingSection) {
    Write-Host "✓ 'testing' section found" -ForegroundColor Green
    Write-Host "  Main categories: $($testingSection.main_categories.Keys -join ', ')" -ForegroundColor Gray
} else {
    Write-Host "✗ 'testing' section NOT found" -ForegroundColor Red
}
Write-Host ""

# Test 2: GET All Sections
Write-Host "TEST 2: Get All Sections" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/categories/sections"
$sections = ($response | ConvertFrom-Json).sections
if ($sections -contains $testSection) {
    Write-Host "✓ 'testing' in sections list" -ForegroundColor Green
} else {
    Write-Host "✗ 'testing' NOT in sections list" -ForegroundColor Red
}
Write-Host "  Total sections: $($sections.Count)" -ForegroundColor Gray
Write-Host ""

# Test 3: GET Main Categories for testing section
Write-Host "TEST 3: Get Main Categories for '$testSection'" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/categories/main/$testSection"
$mainCategories = ($response | ConvertFrom-Json).main_categories
Write-Host "  Main categories found: $($mainCategories.Count)" -ForegroundColor Gray
if ($mainCategories.Count -gt 0) {
    Write-Host "  Categories: $($mainCategories -join ', ')" -ForegroundColor Gray
}
Write-Host ""

# Test 4: GET Subcategories for testing/testing
Write-Host "TEST 4: Get Subcategories for '$testSection/testing'" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/categories/sub/$testSection/testing"
$subcategories = ($response | ConvertFrom-Json).subcategories
Write-Host "  Subcategories found: $($subcategories.Count)" -ForegroundColor Gray
if ($subcategories.Count -gt 0) {
    Write-Host "  Subcategories: $($subcategories -join ', ')" -ForegroundColor Gray
} else {
    Write-Host "  (No subcategories - expected for empty test category)" -ForegroundColor Gray
}
Write-Host ""

# Test 5: CREATE New Section (if not exists)
Write-Host "TEST 5: Create New Section 'test_new_section'" -ForegroundColor Yellow
$testNewSection = "test_new_section"
$jsonBody = @{section = $testNewSection} | ConvertTo-Json -Compress
$response = curl.exe -s -X POST "$baseUrl/admin/api/categories/section" `
    -H "Content-Type: application/json" `
    -d $jsonBody
Write-Host "  Response: $response" -ForegroundColor Gray
Write-Host ""

# Test 6: ADD Main Category to Section
Write-Host "TEST 6: Add Main Category to Section" -ForegroundColor Yellow
$jsonBody = @{section = $testSection; main_category = $testMainCategory} | ConvertTo-Json -Compress
$response = curl.exe -s -X POST "$baseUrl/admin/api/categories/main" `
    -H "Content-Type: application/json" `
    -d $jsonBody
Write-Host "  Response: $response" -ForegroundColor Gray
Write-Host ""

# Test 7: ADD Subcategory
Write-Host "TEST 7: Add Subcategory" -ForegroundColor Yellow
$jsonBody = @{section = $testSection; main_category = $testMainCategory; subcategory = $testSubcategory} | ConvertTo-Json -Compress
$response = curl.exe -s -X POST "$baseUrl/admin/api/categories/sub" `
    -H "Content-Type: application/json" `
    -d $jsonBody
Write-Host "  Response: $response" -ForegroundColor Gray
Write-Host ""

# Test 8: VERIFY Changes - Get hierarchy again
Write-Host "TEST 8: Verify Changes - Get Updated Hierarchy" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/categories/all"
$hierarchy = $response | ConvertFrom-Json
$testingSection = $hierarchy.hierarchy | Where-Object { $_.section -eq $testSection }
if ($testingSection) {
    Write-Host "✓ Changes verified:" -ForegroundColor Green
    if ($testingSection.main_categories.$testMainCategory) {
        Write-Host "  ✓ Main category '$testMainCategory' exists" -ForegroundColor Green
        $subs = $testingSection.main_categories.$testMainCategory
        if ($subs -contains $testSubcategory) {
            Write-Host "  ✓ Subcategory '$testSubcategory' exists" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Subcategory '$testSubcategory' NOT found" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ Main category '$testMainCategory' NOT found" -ForegroundColor Red
    }
} else {
    Write-Host "✗ 'testing' section NOT found after changes" -ForegroundColor Red
}
Write-Host ""

# Test 9: GET Products in testing section (should be empty)
Write-Host "TEST 9: Get Products in '$testSection' Section" -ForegroundColor Yellow
$response = curl.exe -s "$baseUrl/admin/api/products/all"
$products = ($response | ConvertFrom-Json).products
$testingProducts = $products | Where-Object { $_.category_section -eq $testSection }
if ($testingProducts) {
    Write-Host "  Found $($testingProducts.Count) products" -ForegroundColor Gray
} else {
    Write-Host "  No products (expected for testing section)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   TEST SUMMARY                        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Base URL: $baseUrl" -ForegroundColor Gray
Write-Host "Test Section: $testSection" -ForegroundColor Gray
Write-Host "Test Main Category: $testMainCategory" -ForegroundColor Gray
Write-Host "Test Subcategory: $testSubcategory" -ForegroundColor Gray
Write-Host ""
Write-Host "All category hierarchy endpoints tested!" -ForegroundColor Green
Write-Host "The Go backend now reads from category_hierarchy collection" -ForegroundColor Green
Write-Host "matching the Python/FastAPI backend implementation." -ForegroundColor Green
