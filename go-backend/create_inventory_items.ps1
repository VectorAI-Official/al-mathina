# Create Inventory Items from Existing Products
# This script analyzes all 659 products and creates inventory items

Write-Host "📦 Inventory Creation Script" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:9000"

# Step 1: Fetch all products
Write-Host "📥 Fetching all products..." -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri "$baseUrl/admin/api/products/all" -Method Get
$products = $response.products

Write-Host "✅ Found $($products.Count) products" -ForegroundColor Green
Write-Host ""

# Step 2: Group products by base name (removing size/weight variants)
Write-Host "🔍 Analyzing product names..." -ForegroundColor Yellow

function Get-BaseName($productName) {
    # Remove common size patterns: 500g, 1kg, 1.5kg, 250ml, etc.
    $baseName = $productName -replace '\s*\d+(\.\d+)?\s*(kg|g|ml|l|liters?|pieces?|pcs?|gm|gms|ltr)?\s*$', ''
    $baseName = $baseName.Trim()
    
    # If the name is too short after removal, use original
    if ($baseName.Length -lt 3) {
        return $productName
    }
    
    return $baseName
}

# Group products by base name
$productGroups = @{}
foreach ($product in $products) {
    $productName = $product.product_name
    if ([string]::IsNullOrWhiteSpace($productName)) { continue }
    
    $baseName = Get-BaseName $productName
    
    if (-not $productGroups.ContainsKey($baseName)) {
        $productGroups[$baseName] = @{
            BaseName = $baseName
            Products = @()
            Section = $product.category_section
            MainCategory = $product.category_main
        }
    }
    
    $productGroups[$baseName].Products += $product
}

Write-Host "✅ Found $($productGroups.Count) unique product groups" -ForegroundColor Green
Write-Host ""

# Step 3: Create inventory items
Write-Host "🚀 Creating inventory items..." -ForegroundColor Yellow
Write-Host ""

$created = 0
$failed = 0
$skipped = 0

foreach ($groupName in $productGroups.Keys) {
    $group = $productGroups[$groupName]
    
    # Determine unit based on product names
    $unit = "pieces"
    $sampleName = $group.Products[0].product_name.ToLower()
    
    if ($sampleName -match 'kg|kgs|kilogram') {
        $unit = "kg"
    } elseif ($sampleName -match 'g|gm|gms|gram') {
        $unit = "kg"  # Convert grams to kg for consistency
    } elseif ($sampleName -match 'ml|ltr|l|liters?|litres?') {
        $unit = "liters"
    } elseif ($sampleName -match 'packet|pack') {
        $unit = "packets"
    } elseif ($sampleName -match 'box|boxes') {
        $unit = "boxes"
    }
    
    # Create inventory item
    $inventoryData = @{
        inventory_name = $groupName
        stock_quantity = 0  # Admin will set manually
        low_stock_threshold = 10
        unit = $unit
        section = $group.Section
        category = $group.MainCategory
        notes = "Auto-created from $($group.Products.Count) product variant(s)"
    }
    
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/admin/api/inventory" `
            -Method Post `
            -ContentType "application/json" `
            -Body ($inventoryData | ConvertTo-Json) `
            -ErrorAction Stop
        
        $created++
        Write-Host "  ✅ Created: $groupName ($unit) - $($group.Products.Count) variants" -ForegroundColor Green
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 409 -or $_.Exception.Message -like "*already exists*") {
            $skipped++
            Write-Host "  ⏭️  Skipped: $groupName (already exists)" -ForegroundColor Gray
        } else {
            $failed++
            Write-Host "  ❌ Failed: $groupName - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Add small delay to avoid overwhelming the server
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ Created: $created items" -ForegroundColor Green
Write-Host "⏭️  Skipped: $skipped items (duplicates)" -ForegroundColor Yellow
Write-Host "❌ Failed: $failed items" -ForegroundColor Red
Write-Host "📦 Total Unique Products: $($productGroups.Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Inventory creation complete!" -ForegroundColor Green
