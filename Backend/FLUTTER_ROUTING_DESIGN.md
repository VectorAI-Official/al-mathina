# Flutter Mobile App - Backend Routing Design

## 📱 App Layout Overview

After login, the Flutter app's main page displays:

```
┌─────────────────────────────────────┐
│  ⭐ BEST SELLERS                    │  ← Header 1
├─────────────────────────────────────┤
│  [Card] [Card] [Card]               │  ← Main Category Cards (3-column grid)
│  [Card] [Card] [Card]               │
├─────────────────────────────────────┤
│  📂 GROCERY & KITCHEN               │  ← Header 2 (Section)
├─────────────────────────────────────┤
│  [Card] [Card] [Card]               │  ← Main Category Cards (3-column grid)
│  [Card] [Card] [Card]               │
├─────────────────────────────────────┤
│  📂 SNACKS & DRINKS                 │  ← Header 3 (Section)
├─────────────────────────────────────┤
│  [Card] [Card] [Card]               │  ← Main Category Cards (3-column grid)
└─────────────────────────────────────┘
```

**When any Main Category card is clicked:**
→ Navigate to **Product List Page** with left-right separation (Subcategories + Products)

---

## 🎯 Routing Architecture

### Route 1: Get Home Page Data (Initial Load)
**Purpose:** Get all sections and their main categories for home screen

**Endpoint:** `GET /api/flutter/home`

**Response Structure:**
```json
{
  "best_sellers": {
    "title": "Best Sellers",
    "icon": "⭐",
    "main_categories": [
      {
        "id": "best_seller_drinks",
        "name": "Drinks & Juices",
        "image_url": "/static/uploads/drinks_thumb.jpg",
        "product_count": 15,
        "section": "Best Seller",
        "main_category": "Drinks & Juices"
      },
      {
        "id": "best_seller_snacks",
        "name": "Snacks & Namkeen",
        "image_url": "/static/uploads/snacks_thumb.jpg",
        "product_count": 8,
        "section": "Best Seller",
        "main_category": "Snacks & Namkeen"
      }
    ]
  },
  "sections": [
    {
      "title": "Grocery & Kitchen",
      "icon": "📂",
      "section_name": "Grocery & Kitchen",
      "main_categories": [
        {
          "id": "grocery_atta",
          "name": "Atta, Rice & Dal",
          "image_url": "/static/uploads/atta_thumb.jpg",
          "product_count": 24,
          "section": "Grocery & Kitchen",
          "main_category": "Atta, Rice & Dal"
        },
        {
          "id": "grocery_oil",
          "name": "Edible Oils & Ghee",
          "image_url": "/static/uploads/oil_thumb.jpg",
          "product_count": 12,
          "section": "Grocery & Kitchen",
          "main_category": "Edible Oils & Ghee"
        }
      ]
    },
    {
      "title": "Snacks & Drinks",
      "icon": "📂",
      "section_name": "Snacks & Drinks",
      "main_categories": [
        {
          "id": "snacks_biscuits",
          "name": "Biscuits & Cookies",
          "image_url": "/static/uploads/biscuits_thumb.jpg",
          "product_count": 18,
          "section": "Snacks & Drinks",
          "main_category": "Biscuits & Cookies"
        }
      ]
    }
  ]
}
```

**Usage in Flutter:**
1. Display "Best Sellers" header first with 3-column grid of main categories
2. Loop through `sections` array
3. For each section: Display header → Display 3-column grid of main categories

---

### Route 2: Get Subcategories for a Main Category
**Purpose:** When user clicks a main category card, get its subcategories for sidebar

**Endpoint:** `GET /api/flutter/main-category/{section}/{main_category}/subcategories`

**Example:** `GET /api/flutter/main-category/Grocery & Kitchen/Atta, Rice & Dal/subcategories`

**Response:**
```json
{
  "section": "Grocery & Kitchen",
  "main_category": "Atta, Rice & Dal",
  "subcategories": [
    {
      "name": "Atta & Flour",
      "product_count": 12,
      "icon": "🌾"
    },
    {
      "name": "Rice & Rice Products",
      "product_count": 15,
      "icon": "🍚"
    },
    {
      "name": "Dal & Pulses",
      "product_count": 18,
      "icon": "🫘"
    }
  ]
}
```

**Usage in Flutter:**
Display subcategories in left sidebar of product list page

---

### Route 3: Get Products for a Subcategory
**Purpose:** When user selects a subcategory from sidebar, load products

**Endpoint:** `GET /api/flutter/products`

**Query Parameters:**
- `section` (required): Section name
- `main_category` (required): Main category name
- `subcategory` (required): Subcategory name
- `page` (optional): Page number (default: 1)
- `limit` (optional): Products per page (default: 20)

**Example:** `GET /api/flutter/products?section=Grocery & Kitchen&main_category=Atta, Rice & Dal&subcategory=Atta & Flour&page=1&limit=20`

**Response:**
```json
{
  "section": "Grocery & Kitchen",
  "main_category": "Atta, Rice & Dal",
  "subcategory": "Atta & Flour",
  "products": [
    {
      "item_id": "prod_00001",
      "product_name": "Aashirvaad Atta",
      "weight": "5kg",
      "price": 285.00,
      "image_url": "/static/uploads/aashirvaad_atta.jpg",
      "stock": 150,
      "in_stock": true,
      "is_best_seller": true
    },
    {
      "item_id": "prod_00002",
      "product_name": "Pillsbury Chakki Atta",
      "weight": "10kg",
      "price": 520.00,
      "image_url": "/static/uploads/pillsbury_atta.jpg",
      "stock": 89,
      "in_stock": true,
      "is_best_seller": false
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_products": 45,
    "per_page": 20,
    "has_next": true,
    "has_prev": false
  }
}
```

**Usage in Flutter:**
Display products in right side of screen with grid/list layout

---

### Route 4: Get Product Details
**Purpose:** When user taps a product, show detailed information

**Endpoint:** `GET /api/flutter/product/{item_id}`

**Example:** `GET /api/flutter/product/prod_00001`

**Response:**
```json
{
  "item_id": "prod_00001",
  "product_name": "Aashirvaad Atta",
  "category": {
    "section": "Grocery & Kitchen",
    "main_category": "Atta, Rice & Dal",
    "subcategory": "Atta & Flour"
  },
  "weight": "5kg",
  "price": 285.00,
  "stock": 150,
  "in_stock": true,
  "is_best_seller": true,
  "description": "Premium quality whole wheat atta made from the choicest grains",
  "image_url": "/static/uploads/aashirvaad_atta.jpg",
  "images": [
    "/static/uploads/aashirvaad_atta.jpg",
    "/static/uploads/aashirvaad_atta_2.jpg"
  ]
}
```

**Usage in Flutter:**
Display in product detail modal/page with add to cart button

---

### Route 5: Search Products
**Purpose:** Global search across all products

**Endpoint:** `GET /api/flutter/search`

**Query Parameters:**
- `q` (required): Search query
- `page` (optional): Page number
- `limit` (optional): Results per page

**Example:** `GET /api/flutter/search?q=atta&page=1&limit=20`

**Response:**
```json
{
  "query": "atta",
  "results": [
    {
      "item_id": "prod_00001",
      "product_name": "Aashirvaad Atta",
      "weight": "5kg",
      "price": 285.00,
      "image_url": "/static/uploads/aashirvaad_atta.jpg",
      "category_breadcrumb": "Grocery & Kitchen → Atta, Rice & Dal → Atta & Flour",
      "section": "Grocery & Kitchen",
      "main_category": "Atta, Rice & Dal",
      "subcategory": "Atta & Flour"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 2,
    "total_results": 35,
    "per_page": 20
  }
}
```

**Usage in Flutter:**
Display search results with ability to navigate to product's category

---

### Route 6: Get Best Seller Products Only
**Purpose:** Load all best seller products (alternative to home page)

**Endpoint:** `GET /api/flutter/best-sellers`

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Products per page

**Response:**
```json
{
  "products": [
    {
      "item_id": "prod_00001",
      "product_name": "Aashirvaad Atta",
      "weight": "5kg",
      "price": 285.00,
      "image_url": "/static/uploads/aashirvaad_atta.jpg",
      "section": "Grocery & Kitchen",
      "main_category": "Atta, Rice & Dal",
      "subcategory": "Atta & Flour",
      "category_breadcrumb": "Grocery & Kitchen → Atta, Rice & Dal → Atta & Flour"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 1,
    "total_products": 8,
    "per_page": 20
  }
}
```

---

## 🔄 Navigation Flow Examples

### Example 1: User browses Grocery section
1. **Home Page:** User sees "Grocery & Kitchen" header with main category cards
2. **Tap:** User taps "Atta, Rice & Dal" card
3. **API Call:** `GET /api/flutter/main-category/Grocery & Kitchen/Atta, Rice & Dal/subcategories`
4. **Result:** Left sidebar shows: "Atta & Flour", "Rice & Rice Products", "Dal & Pulses"
5. **Auto-load:** First subcategory selected automatically
6. **API Call:** `GET /api/flutter/products?section=Grocery & Kitchen&main_category=Atta, Rice & Dal&subcategory=Atta & Flour`
7. **Result:** Right side shows products in grid

### Example 2: User clicks Best Seller card
1. **Home Page:** User sees "Best Sellers" header with main category cards
2. **Tap:** User taps "Drinks & Juices" (from Best Seller section)
3. **API Call:** `GET /api/flutter/main-category/Best Seller/Drinks & Juices/subcategories`
4. **Result:** Left sidebar shows subcategories under Drinks
5. **User selects:** "Soft Drinks" from sidebar
6. **API Call:** `GET /api/flutter/products?section=Best Seller&main_category=Drinks & Juices&subcategory=Soft Drinks`
7. **Result:** Shows only best seller products from Soft Drinks

---

## 📋 Database Queries Behind Each Route

### Route 1: Home Page Data
```python
# Get Best Seller main categories
db.products.aggregate([
    {"$match": {"is_best_seller": True, "active": True}},
    {"$group": {
        "_id": "$category_main",
        "count": {"$sum": 1},
        "section": {"$first": "$category_section"}
    }}
])

# Get all sections with main categories
db.category_hierarchy.find({})
```

### Route 2: Subcategories
```python
db.category_hierarchy.findOne(
    {"section": section_name},
    {"main_categories.{main_category_name}": 1}
)
```

### Route 3: Products
```python
db.products.find({
    "category_section": section,
    "category_main": main_category,
    "category_sub": subcategory,
    "active": True
}).skip(skip).limit(limit)
```

### Route 4: Product Details
```python
db.products.findOne({"item_id": item_id, "active": True})
```

### Route 5: Search
```python
db.products.find({
    "$or": [
        {"product_name": {"$regex": query, "$options": "i"}},
        {"category_main": {"$regex": query, "$options": "i"}},
        {"category_sub": {"$regex": query, "$options": "i"}}
    ],
    "active": True
})
```

### Route 6: Best Sellers
```python
db.products.find({"is_best_seller": True, "active": True})
```

---

## 🔧 Implementation Steps

### Phase 1: Create New Flutter Routes File
**File:** `Backend/routes/flutter.py`

```python
from fastapi import APIRouter, Query, HTTPException
from typing import Optional

router = APIRouter(prefix="/api/flutter", tags=["Flutter Mobile App"])

@router.get("/home")
async def get_home_data():
    """Get all sections and categories for home page"""
    pass

@router.get("/main-category/{section}/{main_category}/subcategories")
async def get_subcategories(section: str, main_category: str):
    """Get subcategories for a main category"""
    pass

@router.get("/products")
async def get_products(
    section: str,
    main_category: str,
    subcategory: str,
    page: int = 1,
    limit: int = 20
):
    """Get products for a subcategory with pagination"""
    pass

@router.get("/product/{item_id}")
async def get_product_details(item_id: str):
    """Get single product details"""
    pass

@router.get("/search")
async def search_products(
    q: str,
    page: int = 1,
    limit: int = 20
):
    """Search products globally"""
    pass

@router.get("/best-sellers")
async def get_best_sellers(page: int = 1, limit: int = 20):
    """Get all best seller products"""
    pass
```

### Phase 2: Register Router in main.py
```python
from routes import inventory, cart, orders, admin, flutter

app.include_router(flutter.router)  # Add this line
```

### Phase 3: Test Endpoints
Use Postman or curl to test each endpoint with sample data

---

## 🎨 Flutter UI Components Mapping

### Home Page
- **ScrollView** with sections
- Each section has:
  - **Header Widget** (title + icon)
  - **GridView.builder** (3 columns) for main category cards

### Product List Page
- **Row** with two children:
  - **Left:** ListView of subcategory buttons (width: 30%)
  - **Right:** GridView of product cards (width: 70%)

### Product Detail Modal
- **Bottom Sheet** or **Dialog** with:
  - Image carousel
  - Product details
  - Add to cart button

---

## 🔐 Security Considerations

1. **Active Products Only:** All routes should filter `active: true`
2. **URL Encoding:** Section/category names with spaces must be URL-encoded
3. **Rate Limiting:** Consider adding rate limits to prevent abuse
4. **Pagination:** Always use pagination to prevent large data transfers
5. **Image URLs:** Return absolute URLs for images (e.g., `http://backend:8000/static/uploads/...`)

---

## 📊 Response Time Optimization

1. **Index Creation:**
   ```python
   db.products.create_index([("category_section", 1)])
   db.products.create_index([("category_main", 1)])
   db.products.create_index([("category_sub", 1)])
   db.products.create_index([("is_best_seller", 1)])
   db.products.create_index([("active", 1)])
   ```

2. **Caching:** Consider caching home page data (rarely changes)

3. **Image Optimization:** Serve thumbnails for grid views, full images for detail view

---

## 🧪 Sample API Calls for Testing

```bash
# 1. Home Page Data
curl http://localhost:8000/api/flutter/home

# 2. Subcategories
curl "http://localhost:8000/api/flutter/main-category/Grocery%20%26%20Kitchen/Atta%2C%20Rice%20%26%20Dal/subcategories"

# 3. Products
curl "http://localhost:8000/api/flutter/products?section=Grocery%20%26%20Kitchen&main_category=Atta%2C%20Rice%20%26%20Dal&subcategory=Atta%20%26%20Flour&page=1&limit=20"

# 4. Product Details
curl http://localhost:8000/api/flutter/product/prod_00001

# 5. Search
curl "http://localhost:8000/api/flutter/search?q=atta&page=1"

# 6. Best Sellers
curl http://localhost:8000/api/flutter/best-sellers
```

---

## ✅ Next Steps

1. ✅ Review this routing design
2. ⏳ Create `routes/flutter.py` file
3. ⏳ Implement each endpoint with proper error handling
4. ⏳ Add database indexes for performance
5. ⏳ Test all endpoints with Postman
6. ⏳ Share API documentation with Flutter team
7. ⏳ Begin Flutter development

---

## 📝 Notes

- **Best Seller as Section:** "Best Seller" is treated as a special section with its own main categories
- **Product Count:** Always include product count in responses for UI badges
- **Image URLs:** Must be absolute URLs for Flutter to load them
- **Error Handling:** Return proper HTTP status codes (404, 400, 500)
- **Pagination:** Essential for mobile app performance
- **Category Breadcrumbs:** Help users understand product location

