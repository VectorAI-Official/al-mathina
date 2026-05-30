# Test script for admin endpoints
# Creates test data and tests all admin APIs

Write-Host "`n🧪 Admin API Testing Script`n" -ForegroundColor Cyan

# Test data
$testOrder = @{
    order_id = "TEST_ORDER_001"
    user_phone = "1234567890"
    items = @(
        @{
            product_name = "Test Product"
            quantity = 2
            price = 100
        }
    )
    total_amount = 200
    status = "pending"
    created_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    updated_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
} | ConvertTo-Json -Depth 10

$testUser = @{
    phone = "1234567890"
    store_name = "Test Store"
    owner_name = "John Doe"
    addresses = @()
    created_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
} | ConvertTo-Json -Depth 10

Write-Host "📝 Test data prepared" -ForegroundColor Green

# Test endpoints
$endpoints = @(
    @{method="GET"; url="/admin/api/products/all"; desc="Get all products"},
    @{method="GET"; url="/admin/api/categories/all"; desc="Get all categories"},
    @{method="GET"; url="/admin/api/most-bought"; desc="Get most bought"},
    @{method="GET"; url="/admin/api/stores/list"; desc="Get stores list"},
    @{method="GET"; url="/admin/api/stores/statistics"; desc="Get statistics"},
    @{method="GET"; url="/admin/api/stores/revenue-summary"; desc="Get revenue summary"},
    @{method="GET"; url="/api/admin/orders"; desc="Get all orders"},
    @{method="GET"; url="/api/admin/orders/stats/summary"; desc="Get order stats"}
)

Write-Host "`n🔍 Testing endpoints:`n" -ForegroundColor Yellow

foreach ($ep in $endpoints) {
    Try {
        $url = "http://localhost:9000$($ep.url)"
        $result = Invoke-WebRequest -Uri $url -Method $ep.method -UseBasicParsing -ErrorAction Stop
        
        Write-Host "✅ $($ep.desc)" -ForegroundColor Green
        Write-Host "   Status: $($result.StatusCode)" -ForegroundColor Gray
        Write-Host "   Content-Length: $($result.Content.Length)" -ForegroundColor Gray
    } Catch {
        Write-Host "❌ $($ep.desc)" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

Write-Host "`n✨ Testing complete`n" -ForegroundColor Cyan
