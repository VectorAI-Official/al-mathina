# Stock Isolation - Inventory vs Product Stock

## ✅ Key Principle: COMPLETE ISOLATION

**Product Stock** and **Inventory Stock** are **100% independent** and **never mixed**.

---

## 📦 Two Separate Stock Systems

### 1. Product Stock (Individual)
- **Field:** `product.stock` in `products` collection
- **Scope:** Each product has its own stock counter
- **Used when:** Product is NOT linked to inventory
- **Example:** 
  - "Sugar 500g" → stock: 100 pieces
  - "Sugar 1kg" → stock: 50 pieces
  - "Sugar 1.5kg" → stock: 30 pieces

### 2. Inventory Stock (Centralized)
- **Field:** `inventory.stock_quantity` in `inventory` collection
- **Scope:** Shared across ALL linked products
- **Used when:** Products ARE linked to inventory
- **Example:**
  - "Sugar" inventory → stock_quantity: 1000 kg
  - Linked to: "Sugar 500g", "Sugar 1kg", "Sugar 1.5kg"

---

## 🔗 What Happens When You Link?

### BEFORE Linking:
```javascript
// Product (standalone)
{
  product_name: "Sugar 500g",
  stock: 100,  // ← Used for order tracking
  inventory_id: null
}
```

### AFTER Linking:
```javascript
// Product (linked)
{
  product_name: "Sugar 500g",
  stock: 100,  // ← UNTOUCHED! Still 100, but now IGNORED for orders
  inventory_id: "INV-1736622558-42"  // ← Link to centralized inventory
}

// Inventory (centralized)
{
  inventory_id: "INV-1736622558-42",
  inventory_name: "Sugar",
  stock_quantity: 1000,  // ← NOW used for order tracking
  unit: "kg"
}
```

**CRITICAL:** Product's `stock: 100` **remains unchanged** but is **no longer used** for order tracking!

---

## 📉 Order Delivery Stock Reduction

### Scenario: Customer orders "Sugar 500g" (qty: 3)

#### If Product NOT Linked:
```javascript
// BEFORE order delivered
{ product_name: "Sugar 500g", stock: 100 }

// AFTER order delivered (qty: 3)
{ product_name: "Sugar 500g", stock: 97 }  // Reduced by 3
```

#### If Product IS Linked:
```javascript
// BEFORE order delivered
Product: { product_name: "Sugar 500g", stock: 100, inventory_id: "INV-42" }
Inventory: { inventory_name: "Sugar", stock_quantity: 1000 }

// AFTER order delivered (qty: 3)
Product: { product_name: "Sugar 500g", stock: 100, inventory_id: "INV-42" }  // UNCHANGED!
Inventory: { inventory_name: "Sugar", stock_quantity: 997 }  // Reduced by 3
```

**Key:** Product stock stays at 100, inventory stock goes to 997.

---

## 🔓 What Happens When You Unlink?

### BEFORE Unlinking:
```javascript
Product: { stock: 100, inventory_id: "INV-42" }
Inventory: { stock_quantity: 997 }
```

### AFTER Unlinking:
```javascript
Product: { stock: 100, inventory_id: null }  // Stock UNCHANGED, now used again
Inventory: { stock_quantity: 997 }  // Unchanged
```

**Result:** Product goes back to using its own `stock: 100` for order tracking.

---

## ⚠️ Important Warnings

### 1. No Automatic Sync
- Linking does NOT copy product stock to inventory
- Unlinking does NOT copy inventory stock to product
- **Admin must manually manage both stocks**

### 2. Stock Values Can Diverge
```javascript
// This is NORMAL and EXPECTED:
Product: { stock: 100 }  // Individual tracking (ignored when linked)
Inventory: { stock_quantity: 5 }  // Centralized tracking (active when linked)
```

### 3. Switching Modes
- Link → Unlink → Link again: Product stock never changes
- Old product stock value is always preserved

---

## ✅ UI Confirmations Added

### Link Confirmation:
```
Link this product to "Sugar" inventory?

⚠️ IMPORTANT:
• Product's individual stock will remain unchanged
• Inventory stock is managed separately
• When orders are delivered, inventory stock will reduce

Continue?
```

### Unlink Confirmation:
```
⚠️ UNLINK CONFIRMATION

Are you sure you want to unlink this product from "Sugar" inventory?

After unlinking:
• Product will use its own individual stock
• Centralized inventory tracking will stop
• Product's current stock value remains unchanged

Continue with unlinking?
```

---

## 🎯 Best Practices

### 1. Choose One Method Per Product
- Either use product stock OR inventory stock
- Don't try to sync both manually
- Link products permanently or not at all

### 2. Set Stock Once When Linking
When linking products:
1. Set inventory stock to desired value
2. Ignore product stock (it stays as-is)
3. Use inventory page to manage stock

### 3. Bulk Link Workflow
```
1. Create inventory item "Sugar" with stock_quantity: 1000
2. Link all Sugar variants (500g, 1kg, 1.5kg)
3. Forget about individual product stocks
4. Manage only inventory stock from now on
```

### 4. Unlinking Strategy
Only unlink if:
- You want to stop centralized tracking
- Product is being discontinued
- Switching back to individual stock management

---

## 🔍 How to Check Current Mode

### Via Dashboard Product Edit:
- Dropdown shows: "No inventory link" → Using product stock
- Dropdown shows: "Sugar (1000 kg)" → Using inventory stock

### Via Inventory Link Modal:
- Status badge: "Not linked" → Using product stock
- Status badge: "✓ Linked" → Using inventory stock

---

## 📊 Summary Table

| Action | Product Stock | Inventory Stock | Orders Use |
|--------|--------------|-----------------|------------|
| Create product (no link) | Set by admin | N/A | Product stock |
| Link to inventory | **UNCHANGED** | Set separately | Inventory stock |
| Order delivered (linked) | **UNCHANGED** | Reduced | Inventory stock |
| Order delivered (unlinked) | Reduced | N/A | Product stock |
| Unlink from inventory | **UNCHANGED** | **UNCHANGED** | Product stock |

---

## 🚀 Example Workflow

### Day 1: Create Products (Old Method)
```javascript
"Sugar 500g" → stock: 100
"Sugar 1kg" → stock: 50
"Sugar 1.5kg" → stock: 30
```

### Day 2: Switch to Inventory (New Method)
```javascript
// Create inventory
Inventory "Sugar" → stock_quantity: 1000 kg

// Link products (stock values stay 100, 50, 30 but are ignored)
"Sugar 500g" → inventory_id: "INV-42"
"Sugar 1kg" → inventory_id: "INV-42"
"Sugar 1.5kg" → inventory_id: "INV-42"
```

### Day 3: Customer Orders
```javascript
Order: "Sugar 500g" x 5 pieces
Result: Inventory stock_quantity: 1000 → 995 kg
        Product stock: 100 (UNCHANGED)
```

### Day 4: Unlink One Product
```javascript
Unlink "Sugar 1.5kg"
Result: Product stock: 30 (used again for orders)
        Inventory stock_quantity: 995 (unchanged)
```

---

## ✅ UI Visual Indicators

### Dashboard Product Form:
```
┌─────────────────────────────────────┐
│ Stock Quantity: [100]               │
│ Individual product stock (isolated  │
│ from inventory)                     │
├─────────────────────────────────────┤
│ 📦 Link to Inventory                │
│ [Sugar (1000 kg)             ▼]    │
│ Centralized tracking. Product stock │
│ stays separate.                     │
└─────────────────────────────────────┘
```

### Inventory Link Modal:
```
┌──────────────────────────────────────┐
│ ℹ️ Stock Isolation                   │
│ • Product stock and inventory stock  │
│   are separate                       │
│ • Linking does NOT change product's  │
│   individual stock                   │
│ • When orders deliver, only          │
│   inventory stock reduces            │
└──────────────────────────────────────┘
```

---

## 💡 Why This Design?

1. **Flexibility:** Admin can switch between methods anytime
2. **No Data Loss:** Original product stock is always preserved
3. **Clear Separation:** No confusion about which stock is active
4. **Easy Migration:** Can gradually move products to inventory system
5. **Backward Compatible:** Old products continue working as-is

---

## 🎯 Quick Decision Guide

**Use Product Stock (No Link) When:**
- ✅ Unique product with no variants
- ✅ Small inventory (<10 products)
- ✅ Simple tracking needs
- ✅ One-time or discontinued items

**Use Inventory Stock (Linked) When:**
- ✅ Multiple product variants (500g, 1kg, 1.5kg)
- ✅ Large inventory (>100 products)
- ✅ Centralized stock management needed
- ✅ Want single stock counter for all variants
- ✅ Need stock history and alerts

---

## ✅ Implementation Complete!

All stock isolation is now implemented with:
- ✅ Confirmation dialogs on link/unlink
- ✅ Info tooltips explaining separation
- ✅ Clear UI hints in forms
- ✅ No automatic stock syncing
- ✅ Product stock preserved during all operations
