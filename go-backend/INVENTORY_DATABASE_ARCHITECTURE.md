# Inventory Management - Database Architecture

## 📊 Database Overview

The inventory management system uses **MongoDB** with 4 new/modified collections working together with existing collections.

---

## 🗂️ Collection Structure

### 1. `inventory` Collection (NEW - Master Inventory Items)

**Purpose**: Centralized inventory items that multiple product variants link to

**Schema**:
```javascript
{
  _id: ObjectId("..."),
  inventory_id: "INV-1736535000",           // Unique identifier
  inventory_name: "Sugar",                   // Master item name
  stock_quantity: 1000,                      // Current stock (in base unit)
  low_stock_threshold: 50,                   // Alert when stock <= this
  unit: "kg",                                // Base unit (kg, liters, pieces)
  category: "Groceries",                     // Optional category
  section: "Provisions",                     // Optional section
  notes: "Premium white sugar",              // Optional notes
  created_at: ISODate("2026-01-11T00:00:00Z"),
  updated_at: ISODate("2026-01-11T05:30:00Z"),
  last_restocked_at: ISODate("2026-01-11T03:00:00Z"), // Last restock time
  is_active: true                            // Soft delete flag
}
```

**Indexes**:
```javascript
db.inventory.createIndex({ "inventory_id": 1 }, { unique: true })
db.inventory.createIndex({ "inventory_name": 1 })
db.inventory.createIndex({ "section": 1 })
db.inventory.createIndex({ "is_active": 1 })
db.inventory.createIndex({ "inventory_name": "text" }) // For search
```

**Example Data**:
```javascript
// Single inventory item for all sugar products
{
  inventory_id: "INV-1736535000",
  inventory_name: "Sugar",
  stock_quantity: 1000,      // 1000 kg total
  low_stock_threshold: 50,
  unit: "kg",
  section: "Provisions",
  is_active: true
}
```

---

### 2. `products` Collection (MODIFIED - Added inventory_id Field)

**Purpose**: Individual products that link to inventory items

**New Field Added**:
```javascript
{
  _id: ObjectId("..."),
  item_id: "SUGAR-500G",
  product_name: "Sugar 500g",
  weight: "500g",
  price: 25.0,
  buying_price: 20.0,
  category_section: "Provisions",
  category_main: "Groceries",
  subcategory: "Sugar & Sweeteners",
  image_url: "https://...",
  
  // ✨ NEW FIELD
  inventory_id: "INV-1736535000",  // Links to inventory.inventory_id
  
  created_at: ISODate("..."),
  updated_at: ISODate("...")
}
```

**Example Linking** (Multiple products → One inventory):
```javascript
// Product 1: Sugar 500g
{ item_id: "SUGAR-500G", inventory_id: "INV-1736535000", weight: "500g" }

// Product 2: Sugar 1kg
{ item_id: "SUGAR-1KG", inventory_id: "INV-1736535000", weight: "1kg" }

// Product 3: Sugar 1.5kg
{ item_id: "SUGAR-1.5KG", inventory_id: "INV-1736535000", weight: "1.5kg" }

// All three products share the same inventory stock (INV-1736535000)
```

**Index** (for fast product→inventory lookups):
```javascript
db.products.createIndex({ "inventory_id": 1 })
```

---

### 3. `inventory_history` Collection (NEW - Audit Trail)

**Purpose**: Track every stock change for compliance and debugging

**Schema**:
```javascript
{
  _id: ObjectId("..."),
  inventory_id: "INV-1736535000",
  inventory_name: "Sugar",
  quantity_before: 1000,
  quantity_after: 995,
  quantity_changed: -5,                     // Negative = reduction
  reason: "order_delivered",                // Enum: restock, order_delivered, damaged, expired, adjustment
  changed_by: "system",                     // Or admin user ID
  order_id: "ORD-1736535100",              // Optional: link to order
  timestamp: ISODate("2026-01-11T05:30:00Z")
}
```

**Indexes**:
```javascript
db.inventory_history.createIndex({ "inventory_id": 1, "timestamp": -1 })
db.inventory_history.createIndex({ "order_id": 1 })
db.inventory_history.createIndex({ "timestamp": -1 })
```

**Example History**:
```javascript
[
  {
    inventory_id: "INV-1736535000",
    inventory_name: "Sugar",
    quantity_before: 0,
    quantity_after: 1000,
    quantity_changed: 1000,
    reason: "restock",
    changed_by: "admin-7339651541",
    timestamp: ISODate("2026-01-10T10:00:00Z")
  },
  {
    inventory_id: "INV-1736535000",
    inventory_name: "Sugar",
    quantity_before: 1000,
    quantity_after: 995,
    quantity_changed: -5,
    reason: "order_delivered",
    changed_by: "system",
    order_id: "ORD-1736535100",
    timestamp: ISODate("2026-01-11T05:30:00Z")
  }
]
```

---

### 4. `inventory_alerts` Collection (NEW - Stock Alerts)

**Purpose**: Track low stock and out-of-stock situations

**Schema**:
```javascript
{
  _id: ObjectId("..."),
  inventory_id: "INV-1736535000",
  inventory_name: "Sugar",
  current_stock: 45,
  threshold: 50,
  alert_type: "low_stock",          // Enum: low_stock, out_of_stock
  created_at: ISODate("2026-01-11T05:30:00Z"),
  is_resolved: false                // Set to true when restocked
}
```

**Indexes**:
```javascript
db.inventory_alerts.createIndex({ "inventory_id": 1, "is_resolved": 1 })
db.inventory_alerts.createIndex({ "created_at": -1 })
```

**Example Alerts**:
```javascript
[
  {
    inventory_id: "INV-1736535000",
    inventory_name: "Sugar",
    current_stock: 45,
    threshold: 50,
    alert_type: "low_stock",
    created_at: ISODate("2026-01-11T05:30:00Z"),
    is_resolved: false
  },
  {
    inventory_id: "INV-1736540000",
    inventory_name: "Rice",
    current_stock: 0,
    threshold: 100,
    alert_type: "out_of_stock",
    created_at: ISODate("2026-01-11T06:00:00Z"),
    is_resolved: false
  }
]
```

---

## 🔄 Data Flow & Relationships

### Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        INVENTORY SYSTEM                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│    inventory     │  Master inventory items
│  (NEW)           │
│                  │
│ inventory_id (PK)│◄─────────────┐
│ inventory_name   │              │
│ stock_quantity   │              │ Links via inventory_id
│ low_stock_thresh │              │
│ unit             │              │
└──────────────────┘              │
        │                         │
        │                         │
        │ Triggers alerts         │
        ▼                         │
┌──────────────────┐              │
│inventory_alerts  │              │
│  (NEW)           │              │
│                  │         ┌────┴──────────┐
│ inventory_id (FK)│         │   products    │  Product variants
│ current_stock    │         │  (MODIFIED)   │
│ threshold        │         │               │
│ alert_type       │         │ item_id (PK)  │
└──────────────────┘         │ inventory_id  │◄───┐
                             │ product_name  │    │
┌──────────────────┐         │ weight        │    │
│inventory_history │         │ price         │    │
│  (NEW)           │         └───────────────┘    │
│                  │                 │            │
│ inventory_id (FK)│                 │            │
│ quantity_before  │                 │            │
│ quantity_after   │                 │ Ordered    │
│ reason           │                 │            │
│ order_id (FK)    │◄────┐           ▼            │
└──────────────────┘     │   ┌───────────────┐   │
        ▲                └───┤    orders     │   │
        │                    │               │   │
        │ Records change     │ order_id (PK) │   │
        │                    │ items[]       │   │
        │                    │ status        │───┘
        │                    └───────────────┘
        │                            │
        │                            │ status = "delivered"
        └────────────────────────────┘ triggers stock reduction
```

### Data Flow Example: Order Delivery

**Step 1: Customer Orders**
```javascript
// Order created in `orders` collection
POST /api/orders
{
  user_phone: "9487715568",
  items: [
    { item_id: "SUGAR-1KG", quantity: 5 }  // 5 x 1kg = 5kg
  ],
  status: "pending"
}
// ✅ Stock NOT reduced yet (only on delivery)
```

**Step 2: Admin Marks as Delivered**
```javascript
// Update order status
PUT /api/admin/orders/ORD-123/status
{ "status": "delivered" }

// 🔄 System automatically:
// 1. Finds product "SUGAR-1KG" → inventory_id: "INV-1736535000"
// 2. Gets current stock: 1000 kg
// 3. Reduces stock: 1000 - 5 = 995 kg
// 4. Updates inventory collection
// 5. Creates history entry
// 6. Checks threshold (50 kg) - no alert needed
```

**Step 3: Database State After**
```javascript
// inventory collection
{
  inventory_id: "INV-1736535000",
  stock_quantity: 995,  // Was 1000, now 995
  updated_at: ISODate("2026-01-11T05:30:00Z")
}

// inventory_history collection (new entry)
{
  inventory_id: "INV-1736535000",
  quantity_before: 1000,
  quantity_after: 995,
  quantity_changed: -5,
  reason: "order_delivered",
  order_id: "ORD-123",
  timestamp: ISODate("2026-01-11T05:30:00Z")
}
```

---

## 🔍 Key Design Decisions

### 1. **Why Separate `inventory` and `products`?**

**Problem**: Different product sizes (500g, 1kg, 1.5kg) all share the same physical stock.

**Solution**: 
- `inventory` = Physical stock (1000 kg of sugar in warehouse)
- `products` = Sellable variants (Sugar 500g, Sugar 1kg, etc.)
- Multiple products can link to one inventory item

**Benefits**:
- Accurate stock tracking (no duplicate counting)
- Easy bulk management (update one inventory item, affects all linked products)
- Product variants can have different prices, but share stock

### 2. **Why `inventory_id` and not `_id`?**

**Reason**: MongoDB's `_id` is an ObjectId (complex, hard to remember). Using custom IDs like `INV-1736535000` makes:
- Easier debugging (readable in logs)
- Better API responses (clean JSON)
- Simpler product linking (admin can see/remember "INV-xxx")

### 3. **Why Track History?**

**Use Cases**:
- Audit compliance ("Who reduced stock?")
- Debugging discrepancies ("Why is stock 0?")
- Analytics ("How often do we restock?")
- Order-stock traceability ("Which order caused this change?")

### 4. **Why Soft Delete (`is_active`)?**

**Reason**: Never truly delete inventory items because:
- Historical orders reference them
- Analytics need past data
- Accidental deletions recoverable
- Compliance requirements (audit trail)

---

## 📈 Performance Considerations

### Recommended Indexes

```javascript
// inventory collection
db.inventory.createIndex({ "inventory_id": 1 }, { unique: true })
db.inventory.createIndex({ "inventory_name": 1 })
db.inventory.createIndex({ "section": 1 })
db.inventory.createIndex({ "is_active": 1 })
db.inventory.createIndex({ "inventory_name": "text" })

// products collection (existing + new)
db.products.createIndex({ "item_id": 1 })
db.products.createIndex({ "inventory_id": 1 })  // NEW for linking
db.products.createIndex({ "category_section": 1, "category_main": 1 })

// inventory_history collection
db.inventory_history.createIndex({ "inventory_id": 1, "timestamp": -1 })
db.inventory_history.createIndex({ "order_id": 1 })

// inventory_alerts collection
db.inventory_alerts.createIndex({ "inventory_id": 1, "is_resolved": 1 })
db.inventory_alerts.createIndex({ "created_at": -1 })
```

### Query Patterns

**Fast Lookups**:
```javascript
// Get inventory with linked products (1 query to inventory + 1 to products)
const inventory = await db.inventory.findOne({ inventory_id: "INV-123" })
const products = await db.products.find({ inventory_id: "INV-123" })

// Check stock before order (indexed on inventory_id)
const stock = await db.inventory.findOne(
  { inventory_id: "INV-123" },
  { projection: { stock_quantity: 1 } }
)
```

**Efficient Updates**:
```javascript
// Atomic stock update (no race conditions)
await db.inventory.updateOne(
  { inventory_id: "INV-123" },
  { 
    $inc: { stock_quantity: -5 },  // Atomic decrement
    $set: { updated_at: new Date() }
  }
)
```

---

## 🛡️ Data Integrity Rules

### 1. **Product Linking Validation**
- Products can only link to `is_active: true` inventory items
- Unlinking doesn't delete products (just removes `inventory_id` field)
- Deleting inventory requires unlinking all products first (or `force: true`)

### 2. **Stock Reduction Rules**
- Stock can NEVER go negative (validation in code)
- Stock reduction only on `status: "delivered"` (not "pending", "shipped")
- If insufficient stock, set to 0 and log warning (don't fail order update)

### 3. **History Immutability**
- History entries are NEVER updated or deleted
- Each stock change creates a new history document
- Timestamp ensures chronological order

### 4. **Alert Deduplication**
- Only one unresolved alert per inventory item
- New alert NOT created if existing unresolved alert exists
- Alerts auto-resolved when stock goes above threshold (future feature)

---

## 🚀 Migration Strategy

### For Existing Products

```javascript
// Step 1: Create inventory items from unique product names
const uniqueProducts = await db.products.aggregate([
  { $group: { _id: "$product_name", section: { $first: "$category_section" } } }
])

for (const prod of uniqueProducts) {
  await db.inventory.insertOne({
    inventory_id: `INV-${Date.now()}`,
    inventory_name: prod._id,
    stock_quantity: 0,  // Admin will set manually
    low_stock_threshold: 10,
    unit: "pieces",
    section: prod.section,
    created_at: new Date(),
    is_active: true
  })
}

// Step 2: Admin links products to inventory via UI
// (Manual linking allows flexibility for variants)
```

### Rollback Plan

```javascript
// If needed to rollback, just remove inventory_id field from products
db.products.updateMany(
  { inventory_id: { $exists: true } },
  { $unset: { inventory_id: "" } }
)

// Inventory collections can remain for future use
```

---

## 📝 Summary

**Collections**:
- `inventory` - Master stock items (NEW)
- `products` - Individual sellable items (MODIFIED: +inventory_id)
- `inventory_history` - Stock change audit trail (NEW)
- `inventory_alerts` - Low/out of stock warnings (NEW)

**Key Relationships**:
- 1 inventory item → N products (one-to-many)
- 1 order → N inventory changes (one-to-many via order_id)
- 1 inventory item → N history entries (one-to-many)
- 1 inventory item → 0-1 active alert (one-to-zero-or-one)

**Stock Reduction Trigger**:
- Order status: `pending` → No stock change
- Order status: `shipped` → No stock change
- Order status: `delivered` → ✅ Stock reduced automatically
