# Test Admin Buying Price API
# This script tests the admin buying price feature by making API calls

$baseUrl = "https://al-mathina.onrender.com"
# Alternative for local testing: $baseUrl = "http://127.0.0.1:8000"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Admin Buying Price API Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Admin user (should see buying_price)
Write-Host "[TEST 1] Admin User (7339651541)" -ForegroundColor Yellow
$adminPhone = "7339651541"
$url = "$baseUrl/api/flutter/products?user_phone=$adminPhone&limit=3"
Write-Host "URL: $url" -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "  Is Admin: $($response.is_admin)" -ForegroundColor Cyan
    Write-Host "  Products: $($response.products.Count)" -ForegroundColor Cyan
    
    if ($response.products.Count -gt 0) {
        $product = $response.products[0]
        Write-Host ""
        Write-Host "  Sample Product:" -ForegroundColor Magenta
        Write-Host "    Name: $($product.product_name)" -ForegroundColor White
        Write-Host "    Price: Rs.$($product.price)" -ForegroundColor White
        if ($product.buying_price) {
            Write-Host "    Buying Price: Rs.$($product.buying_price)" -ForegroundColor Green
            $margin = $product.price - $product.buying_price
            Write-Host "    Margin: Rs.$margin" -ForegroundColor Green
        } else {
            Write-Host "    Buying Price: NOT FOUND (ERROR)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host ""

# Test 2: Regular user (should NOT see buying_price)
Write-Host "[TEST 2] Regular User (9876543210)" -ForegroundColor Yellow
$regularPhone = "9876543210"
$url = "$baseUrl/api/flutter/products?user_phone=$regularPhone&limit=3"
Write-Host "URL: $url" -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "  Is Admin: $($response.is_admin)" -ForegroundColor Cyan
    Write-Host "  Products: $($response.products.Count)" -ForegroundColor Cyan
    
    if ($response.products.Count -gt 0) {
        $product = $response.products[0]
        Write-Host ""
        Write-Host "  Sample Product:" -ForegroundColor Magenta
        Write-Host "    Name: $($product.product_name)" -ForegroundColor White
        Write-Host "    Price: Rs.$($product.price)" -ForegroundColor White
        if ($product.buying_price) {
            Write-Host "    Buying Price: Rs.$($product.buying_price) - SHOULD NOT EXIST (ERROR)" -ForegroundColor Red
        } else {
            Write-Host "    Buying Price: Not shown (correct)" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host ""

# Test 3: No user_phone (should NOT see buying_price)
Write-Host "[TEST 3] No user_phone parameter" -ForegroundColor Yellow
$url = "$baseUrl/api/flutter/products?limit=3"
Write-Host "URL: $url" -ForegroundColor Gray

try {
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "  Is Admin: $($response.is_admin)" -ForegroundColor Cyan
    Write-Host "  Products: $($response.products.Count)" -ForegroundColor Cyan
    
    if ($response.products.Count -gt 0) {
        $product = $response.products[0]
        Write-Host ""
        Write-Host "  Sample Product:" -ForegroundColor Magenta
        Write-Host "    Name: $($product.product_name)" -ForegroundColor White
        Write-Host "    Price: Rs.$($product.price)" -ForegroundColor White
        if ($product.buying_price) {
            Write-Host "    Buying Price: Rs.$($product.buying_price) - SHOULD NOT EXIST (ERROR)" -ForegroundColor Red
        } else {
            Write-Host "    Buying Price: Not shown (correct)" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

