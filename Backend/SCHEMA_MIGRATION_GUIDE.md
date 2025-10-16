# Schema Migration: Brand-Based to Nested Categorization

## Overview
Successfully migrated the AL-Madhina product catalog from a simple brand-based structure to a comprehensive three-level nested categorization system.

## Schema Changes

### Old Schema (Brand-Based)
```json
{
  "category": "Atta",
  "brand": "Aashirvaad",
  "name": "Aashirvaad Atta",
  "image_path": "...",
  "weight": "10kg box",
  "price": 45.99,
  "stock": 120,
  "active": true,
  "description": "..."
}
```

### New Schema (Nested Categorization)
```json
{
  "_id": ObjectId,
  "item_id": "prod_aashirvaad_001",
  "product_name": "Aashirvaad Atta 10kg",
  "category_section": "Groceries",
  "category_main": "Atta, Rice & Dal",
  "category_sub": "Wheat Flour",
  "image_url": "https://...",
  "weight": "10kg",
  "price": 420.00,
  "stock": 90,
  "active": true,
  "description": "100% MP Sharbati wheat flour"
}
```

## Category Hierarchy

### Level 1: Section (category_section)
Purpose: App home screen section blocks
Examples:
- Best Seller
- Groceries
- Personal Care
- Snacks

### Level 2: Main Category (category_main)
Purpose: Category card display
Examples:
- Drinks & Juices
- Atta, Rice & Dal
- Cooking Essentials
- Bath & Body
- Hair Care
- Biscuits & Cookies

### Level 3: Subcategory (category_sub)
Purpose: Drill-down filtering
Examples:
- Soft Drinks
- Basmati Rice
- Cooking Oil
- Wheat Flour
- Soap
- Shampoo
- Cream Biscuits

## Files Modified

### 1. Backend Models (`models.py`)
**Changes:**
- Removed `brand` field from `ProductResponse`
- Added `item_id` (unique SKU)
- Added `product_name` (full display name)
- Added `category_section`, `category_main`, `category_sub`
- Changed `image_path` to `image_url`
- Updated `CartItemRequest` and `CartItemResponse` to use new fields

**Impact:** All API responses now use the new schema

### 2. Database Initialization (`database/mongodb_client.py`)
**Changes:**
- Completely rewrote sample product data with 14 realistic products
- Products now span multiple sections and categories
- Updated indexes: removed brand index, added indexes for all three category levels
- Added compound index for hierarchical queries

**Sample Products Added:**
- Beverages: Sprite, Coca-Cola
- Groceries: Daawat Rice, India Gate Rice, Fortune Oil, Saffola Oil, Aashirvaad Atta, Pillsbury Atta
- Personal Care: Lux Soap, Dove Soap, Clinic Plus Shampoo, Pantene Shampoo
- Snacks: Oreo, Bourbon Biscuits

### 3. Admin Routes (`routes/admin_local.py`)
**Changes:**
- Updated `/api/categories/all` endpoint to return three separate arrays:
  - `sections` (category_section values)
  - `main_categories` (category_main values)
  - `sub_categories` (category_sub values)
- CRUD endpoints now handle the new field structure
- Product validation uses new fields

### 4. Dashboard HTML (`templates/admin_dashboard.html`)
**Changes:**
- Updated table headers:
  - Removed "Brand" column
  - Added "Section", "Main Category", "Subcategory" columns
- Updated colspan from 8 to 9 for loading states
- Replaced single category dropdown with three separate dropdowns:
  - Section (Level 1)
  - Main Category (Level 2)
  - Subcategory (Level 3)
- Added `item_id` input field
- Added form hints for each category level
- Updated search placeholder text

### 5. Dashboard JavaScript (`static/admin/js/dashboard.js`)
**Changes:**
- Updated `loadCategories()` to handle hierarchical response
- Modified `populateCategoryFilters()` to populate three dropdowns
- Updated `displayProducts()`:
  - Shows all three category levels as badges
  - Displays item_id in monospace font
  - Uses product_name instead of name
- Modified `filterProducts()`:
  - Searches across all category levels
  - Filters by main_category
- Updated `editProduct()` to populate all three category fields
- Modified `handleProductSubmit()`:
  - Sends JSON instead of FormData
  - Includes all new fields in the payload
- Updated `updateStatistics()` to count unique main categories

### 6. Dashboard CSS (`static/admin/css/dashboard.css`)
**Changes:**
- Added `.category-badge` styling for category pills
- Added `.item-id` styling for monospace SKU display
- Added `.form-hint` styling for input field helper text

### 7. Inventory Routes (`routes/inventory.py`)
**Changes:**
- Updated `/sections` endpoint:
  - Now queries `category_section` from products
  - Returns section names with product counts
- Updated `/products` endpoint:
  - Replaced `category` and `brand` filters with `section`, `main_category`, `sub_category`
  - Updated response to use new ProductResponse schema
- Updated `/products/{id}` endpoint:
  - Changed from `{category}/{brand}` to `{item_id}`
  - Uses item_id for lookups

## API Endpoints Changed

### Admin Dashboard API
- `GET /admin/api/categories/all`
  - Old: `{ categories: ["Atta", "Soap", ...] }`
  - New: `{ sections: [...], main_categories: [...], sub_categories: [...] }`

- `POST /admin/api/products/add`
  - Old payload: `{ name, brand, category, ... }`
  - New payload: `{ item_id, product_name, category_section, category_main, category_sub, ... }`

- `PUT /admin/api/products/{id}`
  - Same payload changes as POST

### Inventory API
- `GET /api/inventory/sections`
  - Old: Returned category cards
  - New: Returns section hierarchy with counts

- `GET /api/inventory/products`
  - Old query params: `?category=Atta&brand=Aashirvaad`
  - New query params: `?section=Groceries&main_category=Atta, Rice & Dal&sub_category=Wheat Flour`

- `GET /api/inventory/products/{item_id}`
  - Old: `/products/{category}/{brand}`
  - New: `/products/{item_id}` (e.g., `/products/prod_sprite_001`)

## Database Migration Notes

### Automatic Migration
The existing products in MongoDB will **not** be automatically migrated. When the backend restarts:
- The `init_mongo_collections()` function checks if the products collection exists
- If it doesn't exist, it creates the collection with new sample data
- **If it does exist**, it will not modify existing products

### Manual Migration Required
To migrate existing production data, you need to:

1. **Backup existing data:**
   ```bash
   mongodump --uri="mongodb://localhost:27017/almadhinadb" --out=backup/
   ```

2. **Drop the old products collection** (or rename it):
   ```javascript
   use almadhinadb
   db.products.renameCollection('products_old')
   ```

3. **Restart the backend** to create new products with correct schema

4. **Or manually transform data** using a migration script:
   ```javascript
   db.products_old.find().forEach(function(product) {
     db.products.insertOne({
       item_id: "prod_" + product.brand.toLowerCase().replace(' ', '_') + "_001",
       product_name: product.name,
       category_section: "Groceries",  // Map old category to section
       category_main: mapToMainCategory(product.category),
       category_sub: product.brand,
       image_url: product.image_path,
       weight: product.weight,
       price: product.price,
       stock: product.stock,
       active: product.active,
       description: product.description
     });
   });
   ```

## Testing Checklist

- [ ] Backend starts without errors
- [ ] Admin login works
- [ ] Admin dashboard displays products with three category columns
- [ ] Can create new products with all three category levels
- [ ] Can edit existing products
- [ ] Category dropdowns populate correctly
- [ ] Search filters across all category levels
- [ ] Category filter works with main_category
- [ ] Image upload still works
- [ ] Product deletion works
- [ ] `/api/inventory/sections` returns section hierarchy
- [ ] `/api/inventory/products` filters work with new parameters
- [ ] `/api/inventory/products/{item_id}` returns correct product

## Flutter Integration Notes

The Flutter app will need to be updated to:
1. Use the new three-level category navigation
2. Query products using section → main → sub hierarchy
3. Display products using `product_name` and `item_id`
4. Update cart to use `item_id` instead of category/brand combination

## Rollback Procedure

If issues arise:
1. Restore MongoDB from backup
2. Git revert these commits:
   - models.py changes
   - mongodb_client.py changes
   - admin_local.py changes
   - inventory.py changes
   - Frontend changes (HTML/JS/CSS)
3. Restart backend

## Future Enhancements

1. **Dynamic Category Management:** Add admin UI to create/edit category hierarchies
2. **Category Icons:** Add icon support for each category level
3. **Bulk Import:** CSV/Excel import for products with new schema
4. **Analytics:** Track popular products by category level
5. **Category SEO:** Add metadata for each category level
