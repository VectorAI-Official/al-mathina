# Link Products to Inventory Script
# This script automatically links products to their corresponding inventory items

$baseUrl = "http://localhost:9000"

Write-Host "`n📦 Product-Inventory Linking Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Function to get base name (remove size variants)
function Get-BaseName {
    param([string]$name)
    
    # Remove size patterns like "500g", "1kg", "1.5kg", etc.
    $baseName = $name -replace '\s*\d+(\.\d+)?\s*(kg|g|ml|l|liters?|pieces?|pcs?|gm|gms|ltr)?\s*$', ''
    return $baseName.Trim()
}

Write-Host "`n📥 Fetching products and inventory..." -ForegroundColor Yellow

try {
    # Get all products
    $productsResponse = Invoke-RestMethod -Uri "$baseUrl/admin/api/products/all" -ErrorAction Stop
    $products = $productsResponse.products
    Write-Host "✅ Found $($products.Count) products" -ForegroundColor Green

    # Get all inventory items
    $inventory = Invoke-RestMethod -Uri "$baseUrl/admin/api/inventory" -ErrorAction Stop
    Write-Host "✅ Found $($inventory.Count) inventory items" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error fetching data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🔗 Linking products to inventory..." -ForegroundColor Yellow

$linked = 0
$failed = 0
$alreadyLinked = 0
$noMatch = 0

foreach ($product in $products) {
    # Skip if already linked
    if ($product.inventory_id) {
        $alreadyLinked++
        continue
    }

    # Get base name for matching
    $productBaseName = Get-BaseName -name $product.product_name
    
    # Find matching inventory item
    $matchingInventory = $inventory | Where-Object { $_.inventory_name -eq $productBaseName } | Select-Object -First 1
    
    if ($matchingInventory) {
        try {
            $body = @{
                inventory_id = $matchingInventory.inventory_id
            } | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri "$baseUrl/admin/api/products/$($product._id)/link-inventory" `
                              -Method POST `
                              -Body $body `
                              -ContentType "application/json" `
                              -ErrorAction Stop
            
            Write-Host "  ✅ Linked: $($product.product_name) → $($matchingInventory.inventory_name) ($($matchingInventory.inventory_id))" -ForegroundColor Green
            $linked++
            
            # Rate limiting to avoid overwhelming server
            Start-Sleep -Milliseconds 100
        }
        catch {
            Write-Host "  ❌ Failed: $($product.product_name) - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
    else {
        Write-Host "  ⚠️  No match: $($product.product_name) (base: $productBaseName)" -ForegroundColor Yellow
        $noMatch++
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ Newly Linked: $linked products" -ForegroundColor Green
Write-Host "⏭️  Already Linked: $alreadyLinked products" -ForegroundColor Blue
Write-Host "⚠️  No Match: $noMatch products" -ForegroundColor Yellow
Write-Host "❌ Failed: $failed products" -ForegroundColor Red
Write-Host "`n🎉 Linking process complete!" -ForegroundColor Cyan

# Show verification suggestion
if ($linked -gt 0) {
    Write-Host "`n💡 Tip: Visit http://localhost:9000/admin/inventory to view linked products" -ForegroundColor Cyan
}
