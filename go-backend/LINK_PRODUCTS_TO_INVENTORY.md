# Linking Products to Inventory Items

## Overview
You now have **516 inventory items** created from your 659 products. To link products to their inventory items, you have 3 options:

---

## Option 1: Via Admin Dashboard UI (Recommended)

### Step 1: Access Product Management
1. Go to `http://localhost:9000/admin` (or your admin dashboard)
2. View your products list

### Step 2: Link Individual Products
**Backend Endpoint Available:**
```
POST /admin/api/products/:product_id/link-inventory
Content-Type: application/json

{
  "inventory_id": "INV-1736622558-1"
}
```

**Response:**
```json
{
  "message": "Product linked to inventory successfully"
}
```

---

## Option 2: Via PowerShell Script (Bulk Linking)

Create a script to automatically link products to inventory items by matching names:

```powershell
# Link products to inventory items
$baseUrl = "http://localhost:9000"

# Get all products
$products = (Invoke-RestMethod -Uri "$baseUrl/admin/api/products/all").products

# Get all inventory items
$inventory = Invoke-RestMethod -Uri "$baseUrl/admin/api/inventory"

Write-Host "📦 Linking $($products.Count) products to inventory..." -ForegroundColor Cyan

$linked = 0
$failed = 0

foreach ($product in $products) {
    # Find matching inventory item by base name
    $productBaseName = $product.product_name -replace '\s*\d+(\.\d+)?\s*(kg|g|ml|l|liters?|pieces?|pcs?|gm|gms|ltr)?\s*$', ''
    
    $matchingInventory = $inventory | Where-Object { $_.inventory_name -eq $productBaseName } | Select-Object -First 1
    
    if ($matchingInventory) {
        try {
            $body = @{
                inventory_id = $matchingInventory.inventory_id
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "$baseUrl/admin/api/products/$($product._id)/link-inventory" `
                              -Method POST `
                              -Body $body `
                              -ContentType "application/json" | Out-Null
            
            Write-Host "  ✅ Linked: $($product.product_name) → $($matchingInventory.inventory_name)" -ForegroundColor Green
            $linked++
            
            Start-Sleep -Milliseconds 50  # Rate limiting
        }
        catch {
            Write-Host "  ❌ Failed: $($product.product_name) - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
    else {
        Write-Host "  ⚠️  No match: $($product.product_name)" -ForegroundColor Yellow
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ Linked: $linked products" -ForegroundColor Green
Write-Host "❌ Failed: $failed products" -ForegroundColor Red
```

Save as `link_products_to_inventory.ps1` and run:
```powershell
cd go-backend
.\link_products_to_inventory.ps1
```

---

## Option 3: Manual API Calls (For Testing)

### Example: Link "Sugar 500g" to "Sugar" inventory

```bash
# 1. Find the inventory_id for "Sugar"
curl -X GET "http://localhost:9000/admin/api/inventory" | jq '.[] | select(.inventory_name == "Sugar")'

# Output example:
# {
#   "inventory_id": "INV-1736622558-42",
#   "inventory_name": "Sugar",
#   ...
# }

# 2. Find the product _id for "Sugar 500g"
curl -X GET "http://localhost:9000/admin/api/products/all" | jq '.products[] | select(.product_name == "Sugar 500g")'

# Output example:
# {
#   "_id": "507f1f77bcf86cd799439011",
#   "product_name": "Sugar 500g",
#   ...
# }

# 3. Link them
curl -X POST "http://localhost:9000/admin/api/products/507f1f77bcf86cd799439011/link-inventory" \
     -H "Content-Type: application/json" \
     -d '{"inventory_id": "INV-1736622558-42"}'
```

---

## Option 4: UI Enhancement (Future)

You can add a "Link to Inventory" button in the product table:

**In dashboard.html product row:**
```html
<button onclick="openLinkInventoryModal('${product._id}', '${product.product_name}')">
    🔗 Link
</button>
```

**Add modal with inventory search:**
```javascript
async function openLinkInventoryModal(productId, productName) {
    // Show modal with searchable inventory dropdown
    const inventory = await fetch('/admin/api/inventory/search?q=' + productName).then(r => r.json());
    
    // Display matching inventory items
    // On select, call linkProductToInventory(productId, selectedInventoryId)
}

async function linkProductToInventory(productId, inventoryId) {
    const response = await fetch(`/admin/api/products/${productId}/link-inventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ inventory_id: inventoryId })
    });
    
    if (response.ok) {
        alert('✅ Product linked to inventory!');
        loadProducts();  // Refresh table
    }
}
```

---

## Verification

After linking, verify products are linked:

```powershell
# Get inventory item with linked products
$inventoryId = "INV-1736622558-42"
$result = Invoke-RestMethod -Uri "http://localhost:9000/admin/api/inventory/$inventoryId"

Write-Host "Inventory: $($result.inventory_name)"
Write-Host "Linked Products: $($result.linked_products.Count)"
$result.linked_products | ForEach-Object {
    Write-Host "  - $($_.product_name) ($_id: $($_id))"
}
```

---

## How Stock Reduction Works

Once products are linked to inventory:

1. **Customer places order** → Order items include product IDs
2. **Admin marks order "delivered"** → Backend triggers `reduceInventoryForOrder()`
3. **System finds inventory_id** for each product in the order
4. **Stock quantity reduced** automatically in inventory
5. **History entry created** with order_id reference
6. **Alert generated** if stock falls below threshold

Example:
- Customer orders "Sugar 500g" (qty: 3)
- Product "Sugar 500g" is linked to inventory "Sugar"
- When order marked "delivered", "Sugar" inventory stock reduced by 3
- If stock was 50, it becomes 47
- If threshold is 10 and stock drops to 9, alert is created

---

## Next Steps

**Choose your approach:**

1. ✅ **Recommended**: Run the PowerShell script (Option 2) to auto-link all 659 products
2. 🎨 **UI Enhancement**: Add linking UI to dashboard for manual control
3. 🔍 **Verify**: Check inventory page to see linked products count

After linking, set actual stock quantities via Inventory Management page!
