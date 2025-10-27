# AL-Madhina API Endpoint Reference

Complete reference of all 12+ API endpoints for Flutter mobile app.

## Quick Reference Table

| # | Endpoint | Method | Purpose | Params | Status |
|---|----------|--------|---------|--------|--------|
| 1 | `/api/flutter/home` | GET | Get sections and main categories | `lang` (optional) | ✅ Ready |
| 2 | `/api/flutter/main-category/{section}/{main_category}/subcategories` | GET | Get subcategories for a main category | `lang` (optional) | ✅ Ready |
| 3 | `/api/flutter/products` | GET | Get paginated products with filters | `section`, `main_category`, `subcategory`, `page`, `limit`, `lang` | ✅ Ready |
| 4 | `/api/flutter/product/{item_id}` | GET | Get single product details | `lang` (optional) | ✅ Ready |
| 5 | `/api/flutter/search` | GET | Search products globally | `q` (required), `page`, `limit` | ✅ Ready |
| 6 | `/api/flutter/favorites/{user_id}` | GET | Get user's favorite products | `lang` (optional) | ✅ Ready |
| 7 | `/api/flutter/favorites/{user_id}/{item_id}` | POST | Add product to favorites | None | ✅ Ready |
| 8 | `/api/flutter/favorites/{user_id}/{item_id}` | DELETE | Remove product from favorites | None | ✅ Ready |
| 9 | `/api/flutter/orders/{user_id}` | GET | Get user's orders | `status`, `page`, `limit`, `lang` | ✅ Ready |
| 10 | `/api/flutter/orders` | POST | Create new order | `user_id`, `items`, `delivery_address`, `payment_method`, `total_amount` | ✅ Ready |

---

## Detailed Endpoint Specifications

### 1️⃣ GET /api/flutter/home
**Get Home Page Data with Best Sellers**

```
GET http://localhost:8000/api/flutter/home?lang=en
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| lang | string | No | en | Language: `en` (English) or `ta` (Tamil) |

**Response (200 OK):**
```json
{
  "best_sellers": {
    "title": "Most Bought",
    "icon": "⭐",
    "main_categories": [
      {
        "name": "Category Name",
        "image_url": "http://localhost:8000/static/uploads/...",
        "product_count": 15,
        "section": "Section Name",
        "main_category": "Main Category Name"
      }
    ]
  },
  "sections": [
    {
      "title": "Section Title",
      "icon": "🛒",
      "section_name": "Section Name",
      "main_categories": [...]
    }
  ]
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/home?lang=en"
```

**Flutter Usage:**
```dart
final homeData = await ApiService.getHomeData(lang: 'en');
```

---

### 2️⃣ GET /api/flutter/main-category/{section}/{main_category}/subcategories
**Get Subcategories for a Main Category**

```
GET http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories?lang=en
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| section | string (path) | Yes | - | Section name (URL encoded) |
| main_category | string (path) | Yes | - | Main category name (URL encoded) |
| lang | string | No | en | Language: `en` or `ta` |

**Response (200 OK):**
```json
{
  "section": "Groceries",
  "main_category": "Rice & Grains",
  "subcategories": [
    {
      "name": "Basmati Rice",
      "name_display": "பாஸ்மதி அரிசி",
      "product_count": 8,
      "icon": "📦",
      "image_url": "http://localhost:8000/static/uploads/basmati.jpg"
    }
  ]
}
```

**Error (404):**
```json
{
  "detail": "Section not found: Groceries"
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories"
```

**Flutter Usage:**
```dart
final subcats = await ApiService.getSubcategories(
  section: 'Groceries',
  mainCategory: 'Rice & Grains',
  lang: 'en'
);
```

---

### 3️⃣ GET /api/flutter/products
**Get Products with Pagination and Filters**

```
GET http://localhost:8000/api/flutter/products?section=Groceries&main_category=Rice%20%26%20Grains&page=1&limit=20
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| section | string | No | - | Filter by section name |
| main_category | string | No | - | Filter by main category |
| subcategory | string | No | - | Filter by subcategory |
| page | integer | No | 1 | Page number (min: 1) |
| limit | integer | No | 20 | Results per page (max: 100) |
| lang | string | No | en | Language: `en` or `ta` |

**Response (200 OK):**
```json
{
  "products": [
    {
      "item_id": "PROD001",
      "product_name": "Premium Basmati Rice 1kg",
      "product_name_display": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
      "weight": "1kg",
      "price": 150.0,
      "stock": 50,
      "in_stock": true,
      "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
      "section": "Groceries",
      "main_category": "Rice & Grains",
      "subcategory": "Basmati Rice"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_products": 95,
    "per_page": 20,
    "has_next": true,
    "has_prev": false
  }
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/products?section=Groceries&page=1&limit=20"
```

**Flutter Usage:**
```dart
final products = await ApiService.getProducts(
  section: 'Groceries',
  mainCategory: 'Rice & Grains',
  page: 1,
  limit: 20
);
```

---

### 4️⃣ GET /api/flutter/product/{item_id}
**Get Single Product Details**

```
GET http://localhost:8000/api/flutter/product/PROD001?lang=en
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| item_id | string (path) | Yes | - | Unique product identifier |
| lang | string | No | en | Language: `en` or `ta` |

**Response (200 OK):**
```json
{
  "item_id": "PROD001",
  "product_name": "Premium Basmati Rice 1kg",
  "product_name_ta": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
  "weight": "1kg",
  "price": 150.0,
  "stock": 50,
  "in_stock": true,
  "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
  "images": [
    "http://localhost:8000/static/uploads/basmati_1kg.jpg"
  ],
  "category": {
    "section": "Groceries",
    "main_category": "Rice & Grains",
    "subcategory": "Basmati Rice"
  },
  "description": "Premium long-grain basmati rice",
  "is_best_seller": false
}
```

**Error (404):**
```json
{
  "detail": "Product not found: PROD001"
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/product/PROD001"
```

**Flutter Usage:**
```dart
final product = await ApiService.getProductDetails(itemId: 'PROD001');
```

---

### 5️⃣ GET /api/flutter/search
**Search Products Globally**

```
GET http://localhost:8000/api/flutter/search?q=rice&page=1&limit=20
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| q | string | Yes | - | Search query (min: 1 character) |
| page | integer | No | 1 | Page number |
| limit | integer | No | 20 | Results per page (max: 100) |

**Response (200 OK):**
```json
{
  "query": "rice",
  "results": [
    {
      "item_id": "PROD001",
      "product_name": "Premium Basmati Rice 1kg",
      "product_name_ta": "",
      "weight": "1kg",
      "price": 150.0,
      "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
      "category_breadcrumb": "Groceries → Rice & Grains → Basmati Rice",
      "section": "Groceries",
      "main_category": "Rice & Grains",
      "subcategory": "Basmati Rice",
      "in_stock": true
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_results": 45,
    "per_page": 20,
    "has_next": true,
    "has_prev": false
  }
}
```

**Error (400):**
```json
{
  "detail": "Search query must be at least 1 character"
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/search?q=rice&page=1"
```

**Flutter Usage:**
```dart
final results = await ApiService.searchProducts(query: 'rice', page: 1);
```

---

### 6️⃣ GET /api/flutter/favorites/{user_id}
**Get User's Favorite Products**

```
GET http://localhost:8000/api/flutter/favorites/user_123?lang=en
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| user_id | string (path) | Yes | - | Unique user identifier |
| lang | string | No | en | Language: `en` or `ta` |

**Response (200 OK):**
```json
{
  "user_id": "user_123",
  "favorites": [
    {
      "item_id": "PROD001",
      "product_name": "Premium Basmati Rice 1kg",
      "product_name_display": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
      "product_name_ta": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
      "weight": "1kg",
      "price": 150.0,
      "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
      "category": {
        "section": "Groceries",
        "main_category": "Rice & Grains",
        "subcategory": "Basmati Rice"
      },
      "in_stock": true,
      "stock": 50
    }
  ],
  "total_count": 5
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/favorites/user_123"
```

**Flutter Usage:**
```dart
final favorites = await ApiService.getUserFavorites(userId: 'user_123');
```

---

### 7️⃣ POST /api/flutter/favorites/{user_id}/{item_id}
**Add Product to Favorites**

```
POST http://localhost:8000/api/flutter/favorites/user_123/PROD001
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | string (path) | Yes | Unique user identifier |
| item_id | string (path) | Yes | Product item ID |

**Request Body:** None

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Product added to favorites",
  "item_id": "PROD001"
}
```

**Error (404):**
```json
{
  "detail": "Product not found: PROD001"
}
```

**cURL Example:**
```bash
curl -X POST "http://localhost:8000/api/flutter/favorites/user_123/PROD001"
```

**Flutter Usage:**
```dart
await ApiService.addToFavorites(userId: 'user_123', itemId: 'PROD001');
```

---

### 8️⃣ DELETE /api/flutter/favorites/{user_id}/{item_id}
**Remove Product from Favorites**

```
DELETE http://localhost:8000/api/flutter/favorites/user_123/PROD001
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | string (path) | Yes | Unique user identifier |
| item_id | string (path) | Yes | Product item ID |

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Product removed from favorites",
  "item_id": "PROD001"
}
```

**cURL Example:**
```bash
curl -X DELETE "http://localhost:8000/api/flutter/favorites/user_123/PROD001"
```

**Flutter Usage:**
```dart
await ApiService.removeFromFavorites(userId: 'user_123', itemId: 'PROD001');
```

---

### 9️⃣ GET /api/flutter/orders/{user_id}
**Get User's Orders with Filters**

```
GET http://localhost:8000/api/flutter/orders/user_123?status=pending&page=1&limit=10&lang=en
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| user_id | string (path) | Yes | - | Unique user identifier |
| status | string | No | - | Filter: `pending`, `completed`, `cancelled` |
| page | integer | No | 1 | Page number |
| limit | integer | No | 10 | Orders per page (max: 50) |
| lang | string | No | en | Language: `en` or `ta` |

**Response (200 OK):**
```json
{
  "user_id": "user_123",
  "orders": [
    {
      "order_id": "507f1f77bcf86cd799439011",
      "user_id": "user_123",
      "status": "pending",
      "total_amount": 450.0,
      "items_count": 2,
      "items": [
        {
          "item_id": "PROD001",
          "product_name": "Premium Basmati Rice 1kg",
          "product_name_display": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
          "quantity": 2,
          "price": 150.0,
          "total": 300.0,
          "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg"
        }
      ],
      "delivery_address": "123 Main St, City",
      "payment_method": "cod",
      "created_at": "2025-10-27T10:30:00",
      "updated_at": "2025-10-27T10:30:00",
      "estimated_delivery": "2025-10-30T10:30:00"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 2,
    "total_orders": 15,
    "per_page": 10,
    "has_next": true,
    "has_prev": false
  }
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/flutter/orders/user_123?page=1&limit=10"
```

**Flutter Usage:**
```dart
final orders = await ApiService.getUserOrders(
  userId: 'user_123',
  status: 'pending',
  page: 1,
  limit: 10
);
```

---

### 🔟 POST /api/flutter/orders
**Create New Order**

```
POST http://localhost:8000/api/flutter/orders
Content-Type: application/json
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "items": [
    {
      "item_id": "PROD001",
      "quantity": 2,
      "price": 150.0
    },
    {
      "item_id": "PROD002",
      "quantity": 1,
      "price": 75.0
    }
  ],
  "delivery_address": "123 Main St, City, State 123456",
  "payment_method": "cod",
  "total_amount": 375.0
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | string | Yes | Unique user identifier |
| items | array | Yes | Array of order items |
| items[].item_id | string | Yes | Product ID |
| items[].quantity | integer | Yes | Quantity (min: 1) |
| items[].price | number | Yes | Price per unit |
| delivery_address | string | Yes | Delivery address |
| payment_method | string | No | `cod`, `upi`, `card` (default: `cod`) |
| total_amount | number | Yes | Total order amount |

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Order created successfully",
  "order_id": "507f1f77bcf86cd799439011",
  "status": "pending",
  "created_at": "2025-10-27T10:30:00"
}
```

**Error (400):**
```json
{
  "detail": "Missing required fields: user_id, items, delivery_address"
}
```

**cURL Example:**
```bash
curl -X POST "http://localhost:8000/api/flutter/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_123",
    "items": [
      {"item_id": "PROD001", "quantity": 2, "price": 150.0}
    ],
    "delivery_address": "123 Main St, City",
    "payment_method": "cod",
    "total_amount": 300.0
  }'
```

**Flutter Usage:**
```dart
await ApiService.createOrder(
  userId: 'user_123',
  items: [
    {'item_id': 'PROD001', 'quantity': 2, 'price': 150.0}
  ],
  deliveryAddress: '123 Main St, City',
  paymentMethod: 'cod',
  totalAmount: 300.0
);
```

---

## HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK - Request successful | All successful operations |
| 400 | Bad Request - Invalid parameters | Missing required fields |
| 404 | Not Found - Resource doesn't exist | Product/Order not found |
| 500 | Internal Server Error | Database error |

---

## Response Headers

All responses include:
```
Content-Type: application/json
Cache-Control: no-cache, no-store, must-revalidate
Access-Control-Allow-Origin: *
```

---

## Rate Limiting (Future)

Currently no rate limiting. Will be implemented:
- 100 requests per minute per IP
- 1000 requests per hour per user

---

## Deprecation Policy

Endpoints will be deprecated with 30 days notice:
1. Announcement in version notes
2. Old endpoint continues to work
3. New endpoint introduced
4. 30-day grace period
5. Old endpoint removed

---

## SDK Integration Examples

### Using Dart http package

```dart
import 'package:http/http.dart' as http;

final response = await http.get(
  Uri.parse('http://localhost:8000/api/flutter/home'),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  print(data);
} else {
  throw Exception('Failed to load data');
}
```

### Using Flutter Dio package

```dart
import 'package:dio/dio.dart';

final dio = Dio();
final response = await dio.get('http://localhost:8000/api/flutter/home');
print(response.data);
```

---

## Documentation URLs

- **Interactive API Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

