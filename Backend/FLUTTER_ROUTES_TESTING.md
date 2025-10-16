# Flutter Routes - Quick Testing Guide

## 🚀 Start Backend Server

```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python main.py
```

Server will run on: `http://localhost:8000`

---

## 🧪 Test All Routes with curl

### 1. Home Page Data (All Sections + Best Sellers)

```bash
curl http://localhost:8000/api/flutter/home
```

**Expected Response:**
- `best_sellers` object with main categories from featured products
- `sections` array with all regular sections and their main categories
- Product counts for each main category
- Image URLs for main categories

---

### 2. Get Subcategories for a Main Category

**Example 1: Grocery section**
```bash
curl "http://localhost:8000/api/flutter/main-category/Grocery%20%26%20Kitchen/Atta%2C%20Rice%20%26%20Dal/subcategories"
```

**Example 2: Best Seller**
```bash
curl "http://localhost:8000/api/flutter/main-category/Best%20Seller/Drinks%20%26%20Juices/subcategories"
```

**Expected Response:**
- `section` name
- `main_category` name
- `subcategories` array with names and product counts

---

### 3. Get Products for a Subcategory (with Pagination)

**Example 1: First page**
```bash
curl "http://localhost:8000/api/flutter/products?section=Grocery%20%26%20Kitchen&main_category=Atta%2C%20Rice%20%26%20Dal&subcategory=Atta&page=1&limit=20"
```

**Example 2: Second page**
```bash
curl "http://localhost:8000/api/flutter/products?section=Grocery%20%26%20Kitchen&main_category=Atta%2C%20Rice%20%26%20Dal&subcategory=Atta&page=2&limit=20"
```

**Expected Response:**
- `products` array with product details
- `pagination` object with page info

---

### 4. Get Product Details by ID

```bash
curl http://localhost:8000/api/flutter/product/prod_00001
```

**Expected Response:**
- Complete product information
- Category breadcrumb
- Image URLs
- Stock status

---

### 5. Search Products

**Example 1: Search for "atta"**
```bash
curl "http://localhost:8000/api/flutter/search?q=atta&page=1&limit=20"
```

**Example 2: Search for "juice"**
```bash
curl "http://localhost:8000/api/flutter/search?q=juice&page=1"
```

**Expected Response:**
- `results` array with matching products
- Category breadcrumbs for navigation
- Pagination info

---

### 6. Get All Best Seller Products

```bash
curl "http://localhost:8000/api/flutter/best-sellers?page=1&limit=20"
```

**Expected Response:**
- All products with `is_best_seller: true`
- Category breadcrumbs
- Pagination info

---

## 🔍 Testing with Postman

### Import as Collection

Create a new Postman collection with these requests:

#### 1. Home Data
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/home`

#### 2. Subcategories
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/main-category/{{section}}/{{main_category}}/subcategories`
- **Path Variables:**
  - `section`: Grocery & Kitchen
  - `main_category`: Atta, Rice & Dal

#### 3. Products
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/products`
- **Query Params:**
  - `section`: Grocery & Kitchen
  - `main_category`: Atta, Rice & Dal
  - `subcategory`: Atta
  - `page`: 1
  - `limit`: 20

#### 4. Product Details
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/product/{{item_id}}`
- **Path Variables:**
  - `item_id`: prod_00001

#### 5. Search
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/search`
- **Query Params:**
  - `q`: atta
  - `page`: 1
  - `limit`: 20

#### 6. Best Sellers
- **Method:** GET
- **URL:** `http://localhost:8000/api/flutter/best-sellers`
- **Query Params:**
  - `page`: 1
  - `limit`: 20

---

## 🌐 Interactive API Documentation

FastAPI provides automatic interactive documentation:

1. **Swagger UI:** http://localhost:8000/docs
2. **ReDoc:** http://localhost:8000/redoc

Navigate to "Flutter Mobile App" section to see all routes with:
- Request/response schemas
- Try-it-out functionality
- Example values

---

## 📊 Expected Data Flow

### Scenario 1: User Opens App

```
1. App loads → GET /api/flutter/home
   ↓
2. Response: Best Sellers + All Sections with Main Categories
   ↓
3. App renders home screen with headers and 3-column grids
```

### Scenario 2: User Clicks Main Category Card

```
1. User taps "Atta, Rice & Dal" card
   ↓
2. App calls → GET /api/flutter/main-category/Grocery & Kitchen/Atta, Rice & Dal/subcategories
   ↓
3. Response: List of subcategories (Atta, Rice, Dal)
   ↓
4. App shows product list page with left sidebar
   ↓
5. App auto-selects first subcategory → GET /api/flutter/products?section=...&main_category=...&subcategory=Atta
   ↓
6. Response: Products for "Atta" subcategory
   ↓
7. App displays products in right side grid
```

### Scenario 3: User Searches

```
1. User types "atta" in search bar
   ↓
2. App calls → GET /api/flutter/search?q=atta
   ↓
3. Response: All matching products with breadcrumbs
   ↓
4. User taps a result
   ↓
5. App navigates to product's original category using breadcrumb data
```

---

## ✅ Validation Checklist

- [ ] Server starts without errors
- [ ] `/api/flutter/home` returns Best Sellers and Sections
- [ ] Best Sellers shows only products with `is_best_seller: true`
- [ ] All sections have main categories with product counts
- [ ] Subcategories endpoint returns correct list
- [ ] Products endpoint returns paginated results
- [ ] Product detail endpoint returns single product
- [ ] Search returns matching products
- [ ] Best sellers endpoint returns only featured products
- [ ] All image URLs are valid
- [ ] Pagination works correctly
- [ ] URL encoding handles spaces and special characters

---

## 🐛 Troubleshooting

### Issue: "Section not found"
**Cause:** URL encoding issues with spaces
**Solution:** Ensure spaces are encoded as `%20` and `&` as `%26`

### Issue: "No products returned"
**Cause:** Products marked as `active: false`
**Solution:** Check product active status in database

### Issue: "Best Sellers empty"
**Cause:** No products have `is_best_seller: true`
**Solution:** Set some products as best sellers in admin dashboard

### Issue: "Image URLs broken"
**Cause:** Relative paths instead of absolute
**Solution:** Images should be absolute URLs or start with `/static/uploads/`

---

## 📝 Database Indexes for Performance

Run these to optimize query performance:

```python
db.products.create_index([("category_section", 1)])
db.products.create_index([("category_main", 1)])
db.products.create_index([("category_sub", 1)])
db.products.create_index([("is_best_seller", 1)])
db.products.create_index([("active", 1)])
db.products.create_index([("product_name", "text")])  # For search
```

---

## 🔒 CORS Configuration

The backend is already configured to allow Flutter connections:

```python
allow_origins=[
    "http://127.0.0.1:*",  # Flutter web local
    "http://localhost:*",   # Alternative localhost
    "*"  # Allow all for development
]
```

For production, restrict to specific Flutter domains.

---

## 📱 Flutter Integration Steps

1. **Add HTTP package** to `pubspec.yaml`:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```

2. **Create API service class**:
   ```dart
   class AlMadhinaAPI {
     static const String baseURL = 'http://localhost:8000/api/flutter';
     
     Future<Map<String, dynamic>> getHomeData() async {
       final response = await http.get(Uri.parse('$baseURL/home'));
       return jsonDecode(response.body);
     }
     
     // Add other methods...
   }
   ```

3. **Handle image URLs**:
   ```dart
   Image.network(
     'http://localhost:8000${product.imageUrl}',
     errorBuilder: (context, error, stackTrace) => Icon(Icons.image_not_supported)
   )
   ```

---

## 🎯 Next Steps After Testing

1. ✅ Verify all 6 endpoints work correctly
2. ⏳ Share API base URL with Flutter team
3. ⏳ Provide sample responses for each endpoint
4. ⏳ Set up some test products as best sellers
5. ⏳ Add category images in admin dashboard
6. ⏳ Flutter team begins integration
7. ⏳ Test with actual Flutter app

