# Flutter App - Backend Routing Visual Guide

## 🎨 Complete User Journey with API Calls

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER OPENS APP                               │
│                        (After Login)                                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                    ╔═════════════════════════════════╗
                    ║  API: GET /api/flutter/home     ║
                    ╚═════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │           RESPONSE STRUCTURE                      │
          ├───────────────────────────────────────────────────┤
          │  {                                                │
          │    "best_sellers": {                              │
          │      "title": "Best Sellers",                     │
          │      "icon": "⭐",                                 │
          │      "main_categories": [...]                     │
          │    },                                             │
          │    "sections": [                                  │
          │      {                                            │
          │        "title": "Grocery & Kitchen",              │
          │        "icon": "📂",                               │
          │        "main_categories": [...]                   │
          │      }                                            │
          │    ]                                              │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUTTER RENDERS HOME PAGE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  ⭐ BEST SELLERS                                           │    │
│  ├───────────────────────────────────────────────────────────┤    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                   │    │
│  │  │ Drinks  │  │ Snacks  │  │ Grocery │                   │    │
│  │  │  & Juice│  │& Namkeen│  │  Items  │                   │    │
│  │  │    15   │  │    8    │  │   12    │ ← Product counts  │    │
│  │  └─────────┘  └─────────┘  └─────────┘                   │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  📂 GROCERY & KITCHEN                                      │    │
│  ├───────────────────────────────────────────────────────────┤    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                   │    │
│  │  │  Atta,  │  │ Edible  │  │ Spices  │                   │    │
│  │  │Rice &Dal│  │Oils&Ghee│  │& Masala │                   │    │
│  │  │   24    │  │   12    │  │   18    │                   │    │
│  │  └─────────┘  └─────────┘  └─────────┘                   │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  📂 SNACKS & DRINKS                                        │    │
│  ├───────────────────────────────────────────────────────────┤    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                   │    │
│  │  │Biscuits │  │  Chips  │  │ Juices  │                   │    │
│  │  │& Cookies│  │& Namkeen│  │& Drinks │                   │    │
│  │  │   18    │  │   15    │  │   10    │                   │    │
│  │  └─────────┘  └─────────┘  └─────────┘                   │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    USER TAPS "Atta, Rice & Dal" CARD
                                  │
                                  ▼
        ╔═══════════════════════════════════════════════════════╗
        ║  API: GET /api/flutter/main-category/                 ║
        ║       Grocery & Kitchen/Atta, Rice & Dal/subcategories║
        ╚═══════════════════════════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │           RESPONSE STRUCTURE                      │
          ├───────────────────────────────────────────────────┤
          │  {                                                │
          │    "section": "Grocery & Kitchen",                │
          │    "main_category": "Atta, Rice & Dal",           │
          │    "subcategories": [                             │
          │      {"name": "Atta", "product_count": 12},       │
          │      {"name": "Rice", "product_count": 15},       │
          │      {"name": "Dal", "product_count": 18}         │
          │    ]                                              │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 FLUTTER RENDERS PRODUCT LIST PAGE                   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┬──────────────────────────────────────────────┐   │
│  │             │  Atta, Rice & Dal Products                   │   │
│  ├─────────────┼──────────────────────────────────────────────┤   │
│  │ ▸ Atta (12) │  ┌────────┐  ┌────────┐  ┌────────┐         │   │
│  │   Rice (15) │  │ Product│  │ Product│  │ Product│         │   │
│  │   Dal  (18) │  │ ₹285.00│  │ ₹520.00│  │ ₹180.00│         │   │
│  │             │  └────────┘  └────────┘  └────────┘         │   │
│  │             │  ┌────────┐  ┌────────┐  ┌────────┐         │   │
│  │   30%       │  │ Product│  │ Product│  │ Product│         │   │
│  │  Width      │  │ ₹425.00│  │ ₹190.00│  │ ₹350.00│   70%  │   │
│  │             │  └────────┘  └────────┘  └────────┘  Width  │   │
│  │             │                                              │   │
│  │  Sidebar    │         Product Grid (Auto-loaded)          │   │
│  └─────────────┴──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                   AUTOMATIC: First subcategory selected
                                  │
                                  ▼
            ╔═══════════════════════════════════════════════╗
            ║  API: GET /api/flutter/products?             ║
            ║       section=Grocery & Kitchen              ║
            ║       &main_category=Atta, Rice & Dal        ║
            ║       &subcategory=Atta                      ║
            ║       &page=1&limit=20                       ║
            ╚═══════════════════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │           RESPONSE STRUCTURE                      │
          ├───────────────────────────────────────────────────┤
          │  {                                                │
          │    "products": [                                  │
          │      {                                            │
          │        "item_id": "prod_00001",                   │
          │        "product_name": "Aashirvaad Atta",         │
          │        "price": 285.00,                           │
          │        "stock": 150,                              │
          │        "in_stock": true,                          │
          │        "is_best_seller": true,                    │
          │        "image_url": "/static/uploads/..."         │
          │      },                                           │
          │      ...                                          │
          │    ],                                             │
          │    "pagination": {                                │
          │      "current_page": 1,                           │
          │      "total_pages": 3,                            │
          │      "has_next": true                             │
          │    }                                              │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
                    USER TAPS ON A PRODUCT CARD
                                  │
                                  ▼
            ╔═══════════════════════════════════════════════╗
            ║  API: GET /api/flutter/product/prod_00001    ║
            ╚═══════════════════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │           RESPONSE STRUCTURE                      │
          ├───────────────────────────────────────────────────┤
          │  {                                                │
          │    "item_id": "prod_00001",                       │
          │    "product_name": "Aashirvaad Atta",             │
          │    "category": {                                  │
          │      "section": "Grocery & Kitchen",              │
          │      "main_category": "Atta, Rice & Dal",         │
          │      "subcategory": "Atta"                        │
          │    },                                             │
          │    "weight": "5kg",                               │
          │    "price": 285.00,                               │
          │    "stock": 150,                                  │
          │    "description": "Premium quality...",           │
          │    "image_url": "/static/uploads/..."            │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│               FLUTTER SHOWS PRODUCT DETAIL MODAL                    │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   [Product Image]                           │   │
│  │                                                             │   │
│  │  Aashirvaad Atta                              ⭐ Best Seller│   │
│  │  5kg                                                        │   │
│  │                                                             │   │
│  │  ₹285.00                                      🟢 In Stock  │   │
│  │                                                             │   │
│  │  📁 Grocery & Kitchen → Atta, Rice & Dal → Atta            │   │
│  │                                                             │   │
│  │  Description:                                               │   │
│  │  Premium quality whole wheat atta made from the             │   │
│  │  choicest grains...                                         │   │
│  │                                                             │   │
│  │  ┌─────────────────┐  ┌─────────────────────────────────┐ │   │
│  │  │  Add to Cart    │  │  - [1] +                        │ │   │
│  │  └─────────────────┘  └─────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Search Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                   USER TYPES IN SEARCH BAR                          │
│                   Query: "atta"                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
            ╔═══════════════════════════════════════════════╗
            ║  API: GET /api/flutter/search?q=atta&page=1  ║
            ╚═══════════════════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │           RESPONSE STRUCTURE                      │
          ├───────────────────────────────────────────────────┤
          │  {                                                │
          │    "query": "atta",                               │
          │    "results": [                                   │
          │      {                                            │
          │        "item_id": "prod_00001",                   │
          │        "product_name": "Aashirvaad Atta",         │
          │        "price": 285.00,                           │
          │        "category_breadcrumb":                     │
          │          "Grocery & Kitchen → ... → Atta",        │
          │        "section": "Grocery & Kitchen",            │
          │        "main_category": "Atta, Rice & Dal",       │
          │        "subcategory": "Atta"                      │
          │      },                                           │
          │      ...                                          │
          │    ],                                             │
          │    "pagination": {                                │
          │      "total_results": 35                          │
          │    }                                              │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   FLUTTER SHOWS SEARCH RESULTS                      │
├─────────────────────────────────────────────────────────────────────┤
│  Search Results for "atta" (35 products found)                     │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ [Image] Aashirvaad Atta - 5kg                    ₹285.00    │  │
│  │         📁 Grocery & Kitchen → Atta, Rice & Dal → Atta      │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ [Image] Pillsbury Chakki Atta - 10kg             ₹520.00    │  │
│  │         📁 Grocery & Kitchen → Atta, Rice & Dal → Atta      │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  User can tap any result → Navigates to that product's category   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## ⭐ Best Sellers Special Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│       USER TAPS "Drinks & Juices" FROM BEST SELLERS SECTION        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
        ╔═══════════════════════════════════════════════════════╗
        ║  API: GET /api/flutter/main-category/                 ║
        ║       Best Seller/Drinks & Juices/subcategories       ║
        ╚═══════════════════════════════════════════════════════╝
                                  │
                                  ▼
          ┌───────────────────────────────────────────────────┐
          │  {                                                │
          │    "section": "Best Seller",                      │
          │    "main_category": "Drinks & Juices",            │
          │    "subcategories": [                             │
          │      {"name": "Soft Drinks", "product_count": 8}, │
          │      {"name": "Juices", "product_count": 7}       │
          │    ]                                              │
          │  }                                                │
          └───────────────────────────────────────────────────┘
                                  │
                                  ▼
            ╔═══════════════════════════════════════════════╗
            ║  API: GET /api/flutter/products?             ║
            ║       section=Best Seller                    ║
            ║       &main_category=Drinks & Juices         ║
            ║       &subcategory=Soft Drinks               ║
            ╚═══════════════════════════════════════════════╝
                                  │
                                  ▼
                  Shows ONLY Best Seller products
                  from "Soft Drinks" subcategory
                  (Products where is_best_seller=true)
```

---

## 📊 All 6 API Endpoints at a Glance

```
┌────────────────────────────────────────────────────────────────┐
│                    FLUTTER API ENDPOINTS                       │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1️⃣  GET /api/flutter/home                                    │
│      → Returns: Best Sellers + All Sections with Main Cats    │
│      → Used for: Home page initial load                       │
│                                                                │
│  2️⃣  GET /api/flutter/main-category/{section}/{main}/sub...   │
│      → Returns: List of subcategories                         │
│      → Used for: Product list page sidebar                    │
│                                                                │
│  3️⃣  GET /api/flutter/products?section=...&main=...&sub=...   │
│      → Returns: Paginated products                            │
│      → Used for: Product grid display                         │
│                                                                │
│  4️⃣  GET /api/flutter/product/{item_id}                       │
│      → Returns: Single product details                        │
│      → Used for: Product detail modal                         │
│                                                                │
│  5️⃣  GET /api/flutter/search?q=...                            │
│      → Returns: Search results                                │
│      → Used for: Search functionality                         │
│                                                                │
│  6️⃣  GET /api/flutter/best-sellers                            │
│      → Returns: All featured products                         │
│      → Used for: Best Sellers dedicated page (optional)       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 🗂️ Database Structure Simplified

```
MongoDB: almadhinadb
│
├── products (24 documents)
│   ├── item_id: "prod_00001"
│   ├── product_name: "Aashirvaad Atta"
│   ├── category_section: "Grocery & Kitchen"  ← Level 1
│   ├── category_main: "Atta, Rice & Dal"      ← Level 2
│   ├── category_sub: "Atta"                   ← Level 3
│   ├── price: 285.00
│   ├── stock: 150
│   ├── is_best_seller: true  ← Flag for featured products
│   ├── active: true          ← Only active products shown
│   └── image_url: "/static/uploads/..."
│
├── category_hierarchy (4 documents)
│   └── Structure: Section → Main Categories → Subcategories
│       {
│         "section": "Grocery & Kitchen",
│         "main_categories": {
│           "Atta, Rice & Dal": {
│             "subcategories": ["Atta", "Rice", "Dal"]
│           }
│         }
│       }
│
└── category_metadata (5 documents)
    └── Stores images for sections/categories
        {
          "section": "Grocery & Kitchen",
          "level": "main",
          "name": "Atta, Rice & Dal",
          "image_url": "/static/uploads/atta_thumb.jpg"
        }
```

---

## 🎯 Key Points for Flutter Team

1. **Base URL**: `http://localhost:8000/api/flutter`

2. **URL Encoding**: Encode spaces as `%20`, ampersands as `%26`
   - Example: `Atta, Rice & Dal` → `Atta%2C%20Rice%20%26%20Dal`

3. **Image URLs**: Prepend with `http://localhost:8000`
   - Response: `"/static/uploads/image.jpg"`
   - Flutter: `"http://localhost:8000/static/uploads/image.jpg"`

4. **Pagination**: Use `page` and `limit` query parameters
   - Default: 20 items per page
   - Check `has_next` for infinite scroll

5. **Error Handling**: Check HTTP status codes
   - 200: Success
   - 404: Not found
   - 500: Server error

6. **Best Seller**: Special section name, treat differently
   - Shows only products with `is_best_seller: true`
   - Appears first on home page

7. **Product Count Badges**: All categories include `product_count`

8. **Stock Status**: Use `in_stock` boolean for UI

9. **Category Breadcrumbs**: Use for navigation and context

10. **Active Products Only**: Backend filters `active: true` automatically

---

## 📞 Quick Reference

```
Home Page          → /api/flutter/home
Subcategories      → /api/flutter/main-category/{section}/{main}/subcategories
Products           → /api/flutter/products?section=...&main=...&sub=...
Product Detail     → /api/flutter/product/{item_id}
Search             → /api/flutter/search?q=...
Best Sellers       → /api/flutter/best-sellers
```

**Interactive Docs**: http://localhost:8000/docs (after starting server)

---

## ✅ Ready for Development

The backend routing is **fully implemented and documented**. 

Next steps:
1. Test all endpoints with Postman/curl
2. Share API docs with Flutter team
3. Begin Flutter UI development
4. Test integration end-to-end
