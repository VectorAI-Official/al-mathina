# Item ID Auto-Fetch and Edit Lock

## Overview
Updated the admin dashboard to automatically fetch the item_id from the database when editing products and prevent modifications to this field during edits.

## Changes Made

### 1. JavaScript Updates (`static/admin/js/dashboard.js`)

#### Open Create Modal
- **Behavior:** When creating a new product, the `item_id` field is **enabled** and editable
- **Placeholder:** Shows "e.g., prod_sprite_001" to guide users
- **User Action:** Admin must manually enter a unique item_id

```javascript
function openCreateModal() {
    // ... existing code ...
    
    // Enable item_id field for new products
    const itemIdInput = document.getElementById('productItemId');
    itemIdInput.disabled = false;
    itemIdInput.placeholder = 'e.g., prod_sprite_001';
    
    // ... existing code ...
}
```

#### Edit Product Modal
- **Behavior:** When editing an existing product, the `item_id` field is **disabled** and read-only
- **Auto-Fetch:** The item_id is automatically populated from the product data fetched from MongoDB
- **Visual Indicator:** Placeholder changes to "Auto-filled from database"
- **User Action:** Admin cannot modify the item_id field

```javascript
function editProduct(productId) {
    // ... existing code ...
    
    // Populate and disable item_id field for editing (read-only)
    const itemIdInput = document.getElementById('productItemId');
    itemIdInput.value = product.item_id || '';
    itemIdInput.disabled = true;
    itemIdInput.placeholder = 'Auto-filled from database';
    
    // ... existing code ...
}
```

#### Form Submission
- **Create:** Includes `item_id` in the payload (admin-provided value)
- **Update:** Excludes `item_id` from the payload (prevents modification)

```javascript
function handleProductSubmit(e) {
    // Build product data
    const productData = {
        product_name: ...,
        category_section: ...,
        // ... other fields ...
    };
    
    // Only include item_id for new products
    if (!currentProductId) {
        productData.item_id = document.getElementById('productItemId').value;
    }
    
    // ... submit logic ...
}
```

### 2. CSS Updates (`static/admin/css/dashboard.css`)

Added visual styling for disabled input fields:

```css
.form-group input:disabled {
    background-color: #F5F5F5;
    color: var(--text-gray);
    cursor: not-allowed;
    border-color: #E0E0E0;
}
```

**Visual Changes:**
- Disabled fields have a light gray background (#F5F5F5)
- Text color is muted (gray)
- Cursor changes to "not-allowed" icon when hovering
- Border becomes lighter to indicate non-interactive state

## User Experience

### Creating a New Product
1. Admin clicks "Add New Product"
2. Modal opens with all fields empty and editable
3. Admin enters a unique `item_id` (e.g., `prod_maggi_001`)
4. Admin fills in other product details
5. Clicks "Save Product"
6. Backend validates and creates the product with the provided `item_id`

### Editing an Existing Product
1. Admin clicks "Edit" button on a product row
2. Modal opens with all product data pre-filled
3. The `item_id` field shows the existing value but is **disabled** (grayed out)
4. Admin can modify all other fields (name, categories, price, stock, etc.)
5. Clicks "Save Product"
6. Backend updates the product **without** changing the `item_id`

## Benefits

### 1. Data Integrity
- Prevents accidental modification of primary identifiers
- Maintains referential integrity across the system (cart items, orders, etc.)
- Ensures item_id remains constant throughout product lifecycle

### 2. User Experience
- Clear visual distinction between editable and non-editable fields
- Reduces admin confusion about which fields can be modified
- Prevents duplicate item_id errors during updates

### 3. System Consistency
- item_id serves as a stable reference for:
  - Cart items (`CartItemRequest.item_id`)
  - Order line items
  - Analytics and reporting
  - External integrations

### 4. Simplified Backend Logic
- Backend doesn't need to handle item_id updates
- No validation required for item_id changes during PUT requests
- Reduces risk of database inconsistencies

## Edge Cases Handled

1. **New Product with Duplicate item_id:**
   - Backend will reject with error (unique index on `item_id`)
   - Admin receives error message to choose different item_id

2. **Editing Product Missing item_id:**
   - Field shows empty but disabled
   - Form hint indicates "Auto-filled from database"

3. **Client-Side Tampering:**
   - Even if JavaScript is bypassed and item_id is included in PUT request
   - Backend can validate and reject item_id updates
   - (Current backend accepts it, but can add validation if needed)

## Testing Checklist

- [x] Create new product → item_id field is enabled and editable
- [x] Edit existing product → item_id field is disabled and shows current value
- [x] Disabled field has gray background and not-allowed cursor
- [x] Form submission excludes item_id when editing
- [x] Form submission includes item_id when creating
- [x] Placeholder text changes based on mode (create vs edit)

## Future Enhancements

1. **Auto-Generate item_id:** For new products, offer a button to auto-generate item_id based on product name
   ```javascript
   function generateItemId() {
       const name = document.getElementById('productName').value;
       const id = 'prod_' + name.toLowerCase().replace(/[^a-z0-9]/g, '_') + '_001';
       document.getElementById('productItemId').value = id;
   }
   ```

2. **Backend Validation:** Add explicit validation in admin routes to reject item_id updates:
   ```python
   @router.put("/api/products/{product_id}")
   async def update_product(product_id: str, request: Request, ...):
       data = await request.json()
       
       # Prevent item_id modification
       if 'item_id' in data:
           del data['item_id']
       
       # ... update logic ...
   ```

3. **Audit Trail:** Log when admins attempt to modify item_id (security monitoring)

4. **Bulk Update:** Allow batch item_id changes through a special admin tool with confirmation dialog
