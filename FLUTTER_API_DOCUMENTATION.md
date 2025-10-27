# AL-Madhina Flutter API Documentation

Complete API reference for Flutter mobile app integration with Docker-hosted backend.

## Backend Configuration

- **Docker Service**: `backend-backend-1`
- **Internal Port**: 8080
- **Host Port**: 8000
- **Base URL**: `http://localhost:8000` (for Flutter web preview on Chrome)
- **API Prefix**: `/api/flutter`

## Environment Setup

### Flask app endpoint:
```
http://localhost:8000/api/flutter
```

### Docker Compose Configuration:
```yaml
services:
  backend:
    ports:
      - "8000:8080"  # Host:Container
```

---

## API Endpoints

### 1. Home Page Data

#### Get Home Page Data (with language support)

```http
GET /api/flutter/home?lang=en
```

**Query Parameters:**
- `lang` (optional): Language code
  - `en` - English (default)
  - `ta` - Tamil

**Response:**
```json
{
  "best_sellers": {
    "title": "Most Bought",
    "icon": "⭐",
    "main_categories": [
      {
        "name": "Rice & Grains",
        "image_url": "http://localhost:8000/static/uploads/rice.jpg",
        "product_count": 15,
        "section": "Groceries",
        "main_category": "Rice & Grains"
      }
    ]
  },
  "sections": [
    {
      "title": "Groceries",
      "icon": "🛒",
      "section_name": "Groceries",
      "main_categories": [
        {
          "name": "Rice & Grains",
          "image_url": "http://localhost:8000/static/uploads/rice.jpg",
          "product_count": 15,
          "section": "Groceries",
          "main_category": "Rice & Grains"
        }
      ]
    }
  ]
}
```

**Usage in Flutter:**
```dart
final homeData = await ApiService.getHomeData(lang: 'en');
print(homeData.bestSellers.mainCategories);
print(homeData.sections);
```

---

### 2. Subcategories

#### Get Subcategories for a Main Category

```http
GET /api/flutter/main-category/{section}/{main_category}/subcategories?lang=en
```

**Path Parameters:**
- `section`: Section name (URL encoded, e.g., "Groceries")
- `main_category`: Main category name (URL encoded, e.g., "Rice & Grains")

**Query Parameters:**
- `lang` (optional): Language code (`en` or `ta`, default: `en`)

**Response:**
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
    },
    {
      "name": "Brown Rice",
      "name_display": "பழுப்பு அரிசி",
      "product_count": 5,
      "icon": "📦",
      "image_url": "http://localhost:8000/static/uploads/brown_rice.jpg"
    }
  ]
}
```

**Usage in Flutter:**
```dart
final subcats = await ApiService.getSubcategories(
  section: 'Groceries',
  mainCategory: 'Rice & Grains',
  lang: 'en'
);
```

---

### 3. Products

#### Get Products with Filters

```http
GET /api/flutter/products?section=Groceries&main_category=Rice%20%26%20Grains&subcategory=Basmati%20Rice&page=1&limit=20&lang=en
```

**Query Parameters:**
- `section` (optional): Section name
- `main_category` (optional): Main category name
- `subcategory` (optional): Subcategory name
- `page` (optional): Page number (default: 1, min: 1)
- `limit` (optional): Products per page (default: 20, max: 100)
- `lang` (optional): Language code (`en` or `ta`, default: `en`)

**Response:**
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

**Usage in Flutter:**
```dart
final products = await ApiService.getProducts(
  section: 'Groceries',
  mainCategory: 'Rice & Grains',
  subcategory: 'Basmati Rice',
  page: 1,
  limit: 20
);
```

---

### 4. Product Details

#### Get Single Product Details

```http
GET /api/flutter/product/{item_id}?lang=en
```

**Path Parameters:**
- `item_id`: Unique product identifier (e.g., "PROD001")

**Query Parameters:**
- `lang` (optional): Language code (`en` or `ta`, default: `en`)

**Response:**
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

**Usage in Flutter:**
```dart
final product = await ApiService.getProductDetails(itemId: 'PROD001');
```

---

### 5. Search Products

#### Search Global Product Database

```http
GET /api/flutter/search?q=rice&page=1&limit=20
```

**Query Parameters:**
- `q` (required): Search query (min: 1 character)
- `page` (optional): Page number (default: 1, min: 1)
- `limit` (optional): Results per page (default: 20, max: 100)

**Response:**
```json
{
  "query": "rice",
  "results": [
    {
      "item_id": "PROD001",
      "product_name": "Premium Basmati Rice 1kg",
      "weight": "1kg",
      "price": 150.0,
      "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
      "category_breadcrumb": "Groceries → Rice & Grains → Basmati Rice",
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

**Usage in Flutter:**
```dart
final results = await ApiService.searchProducts(
  query: 'rice',
  page: 1,
  limit: 20
);
```

---

### 6. Favorites Management

#### Get User Favorites

```http
GET /api/flutter/favorites/{user_id}?lang=en
```

**Path Parameters:**
- `user_id`: Unique user identifier (e.g., "user_123")

**Query Parameters:**
- `lang` (optional): Language code (`en` or `ta`, default: `en`)

**Response:**
```json
{
  "user_id": "user_123",
  "favorites": [
    {
      "item_id": "PROD001",
      "product_name": "Premium Basmati Rice 1kg",
      "product_name_display": "பிரீமியம் பாஸ்மதி அரிசி 1கி",
      "weight": "1kg",
      "price": 150.0,
      "image_url": "http://localhost:8000/static/uploads/basmati_1kg.jpg",
      "in_stock": true,
      "stock": 50
    }
  ],
  "total_count": 5
}
```

**Usage in Flutter:**
```dart
final favorites = await ApiService.getUserFavorites(userId: 'user_123', lang: 'en');
```

---

#### Add Product to Favorites

```http
POST /api/flutter/favorites/{user_id}/{item_id}
```

**Path Parameters:**
- `user_id`: Unique user identifier
- `item_id`: Product item ID

**Response:**
```json
{
  "success": true,
  "message": "Product added to favorites",
  "item_id": "PROD001"
}
```

**Usage in Flutter:**
```dart
await ApiService.addToFavorites(userId: 'user_123', itemId: 'PROD001');
```

---

#### Remove Product from Favorites

```http
DELETE /api/flutter/favorites/{user_id}/{item_id}
```

**Path Parameters:**
- `user_id`: Unique user identifier
- `item_id`: Product item ID

**Response:**
```json
{
  "success": true,
  "message": "Product removed from favorites",
  "item_id": "PROD001"
}
```

**Usage in Flutter:**
```dart
await ApiService.removeFromFavorites(userId: 'user_123', itemId: 'PROD001');
```

---

### 7. Orders Management

#### Get User Orders

```http
GET /api/flutter/orders/{user_id}?status=pending&page=1&limit=10&lang=en
```

**Path Parameters:**
- `user_id`: Unique user identifier

**Query Parameters:**
- `status` (optional): Filter by status (`pending`, `completed`, `cancelled`)
- `page` (optional): Page number (default: 1, min: 1)
- `limit` (optional): Orders per page (default: 10, max: 50)
- `lang` (optional): Language code (`en` or `ta`, default: `en`)

**Response:**
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
    "total_pages": 1,
    "total_orders": 5,
    "per_page": 10,
    "has_next": false,
    "has_prev": false
  }
}
```

**Usage in Flutter:**
```dart
final orders = await ApiService.getUserOrders(
  userId: 'user_123',
  status: 'pending',
  page: 1,
  limit: 10
);
```

---

#### Create New Order

```http
POST /api/flutter/orders
Content-Type: application/json

{
  "user_id": "user_123",
  "items": [
    {"item_id": "PROD001", "quantity": 2, "price": 150.0},
    {"item_id": "PROD002", "quantity": 1, "price": 75.0}
  ],
  "delivery_address": "123 Main St, City",
  "payment_method": "cod",
  "total_amount": 375.0
}
```

**Request Body:**
- `user_id` (required): Unique user identifier
- `items` (required): Array of order items
  - `item_id`: Product ID
  - `quantity`: Number of items
  - `price`: Price per item
- `delivery_address` (required): Delivery address
- `payment_method` (optional): `cod`, `upi`, `card` (default: `cod`)
- `total_amount` (required): Total order amount

**Response:**
```json
{
  "success": true,
  "message": "Order created successfully",
  "order_id": "507f1f77bcf86cd799439011",
  "status": "pending",
  "created_at": "2025-10-27T10:30:00"
}
```

**Usage in Flutter:**
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

## Flutter App Data Flow

### 1. Home Page Flow
1. **Load Home Data**: Call `/api/flutter/home?lang=en`
2. **Display Best Sellers**: Show most bought categories at top
3. **Display Sections**: Show all sections with their main categories
4. **On Category Click**: Navigate to subcategory page

### 2. Subcategory Page Flow
1. **Load Subcategories**: Call `/api/flutter/main-category/{section}/{main_category}/subcategories?lang=en`
2. **Display Subcategories**: Show as sidebar or grid
3. **On Subcategory Select**: Call products endpoint with filters

### 3. Products Page Flow
1. **Load Products**: Call `/api/flutter/products?section=...&main_category=...&subcategory=...`
2. **Display Products**: Show in grid or list
3. **Pagination**: Use `page` parameter to load more
4. **On Product Click**: Navigate to product details or add to favorites

### 4. Favorites Page Flow
1. **Load Favorites**: Call `/api/flutter/favorites/{user_id}?lang=en`
2. **Display Favorites**: Show as grid or list
3. **Add/Remove**: Call POST/DELETE `/api/flutter/favorites/{user_id}/{item_id}`
4. **Refresh**: Reload favorites after add/remove

### 5. Orders Page Flow
1. **Load Orders**: Call `/api/flutter/orders/{user_id}?page=1&limit=10`
2. **Display Orders**: Show order history
3. **Filter by Status**: Use `status` query parameter
4. **Pagination**: Use `page` parameter for more orders
5. **Create Order**: Call POST `/api/flutter/orders` with cart data

---

## Error Handling

All API endpoints return appropriate HTTP status codes:

- **200 OK**: Successful request
- **400 Bad Request**: Missing or invalid parameters
- **404 Not Found**: Resource not found
- **500 Internal Server Error**: Server error

Error Response Format:
```json
{
  "detail": "Error message describing what went wrong"
}
```

**Flutter Exception Handling:**
```dart
try {
  final data = await ApiService.getHomeData();
} on HttpException catch (e) {
  print('HTTP Error: ${e.message}');
} catch (e) {
  print('Error: $e');
}
```

---

## Image URLs

All image URLs are returned as absolute URLs:
- Format: `http://localhost:8000/static/uploads/...`
- From Cloudinary: Direct CDN URLs (already absolute)
- Local uploads: Converted to absolute using request base URL

**Usage in Flutter:**
```dart
Image.network(
  product.imageUrl,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported),
    );
  },
)
```

---

## Language Support

All endpoints support language parameter:

**English (Default):**
```
GET /api/flutter/home?lang=en
```

**Tamil:**
```
GET /api/flutter/home?lang=ta
```

**Response with Tamil:**
- `name_display`: Tamil translation
- `product_name_display`: Tamil product name
- Falls back to English if translation not available

---

## Docker Backend Integration

### Starting Backend

```powershell
# From project root
cd Backend
docker-compose up -d

# Check container status
docker ps

# View logs
docker logs backend-backend-1

# Stop container
docker-compose down
```

### API Health Check

```http
GET http://localhost:8000/health
```

### FastAPI Documentation

Interactive API docs available at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## Testing Endpoints

### Using cURL

```bash
# Get home data
curl "http://localhost:8000/api/flutter/home"

# Get subcategories
curl "http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories"

# Search products
curl "http://localhost:8000/api/flutter/search?q=rice"

# Get favorites
curl "http://localhost:8000/api/flutter/favorites/user_123"

# Get orders
curl "http://localhost:8000/api/flutter/orders/user_123"
```

---

## Performance Optimization

1. **Pagination**: Use `limit` parameter to reduce data transfer
2. **Caching**: Flutter app should cache home data and categories
3. **Image Optimization**: Use appropriate image sizes in Flutter
4. **Language**: Only request translations when needed (set `lang=ta`)

---

## Future Enhancements

- [ ] User authentication and JWT tokens
- [ ] Shopping cart management API
- [ ] Product reviews and ratings
- [ ] Wishlists
- [ ] Order tracking with real-time updates
- [ ] Payment integration
- [ ] User profile management
- [ ] Promotional codes and discounts

