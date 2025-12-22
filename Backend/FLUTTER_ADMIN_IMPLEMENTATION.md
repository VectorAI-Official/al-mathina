# Flutter Admin System Implementation Guide

## 🎯 Overview

This guide explains how to implement the admin buying price feature in the Flutter app. Admin users (identified by phone number) will see product buying prices below the selling price in subcategory product listings.

**Admin Phone Numbers:**
- 7339651541
- 8870503350
- 9487715568

---

## ⚠️ CRITICAL SETUP REQUIREMENTS

**Before using this admin system, you MUST:**

1. **Add Supabase credentials to `Backend/.env.production`** (required for Docker/production):
   ```bash
   SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
   **Without these, backend will fail with DNS errors and admin check won't work!**

2. **Run Supabase migration** to add `is_admin` column and mark admin users (see Deployment section)

3. **Restart Docker backend** after adding credentials: `docker-compose restart`

4. **Verify with tests**: Run `python test_api_routing.py` - must show **7/7 tests passing**

---

## 📋 Backend API Contract (Complete Specification)

### 🔌 API Endpoint Details

**Endpoint:** `GET /api/flutter/products`  
**Base URL:** `https://al-mathina.onrender.com` (Production) or `http://127.0.0.1:8000` (Local)

### 📥 Request Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|----------|
| `user_phone` | string | **REQUIRED for admin features** | User's phone number (10 digits) | `7339651541` |
| `section` | string | Optional | Filter by section | `Provisions` |
| `main_category` | string | Optional | Filter by main category | `Rice & Pulses` |
| `subcategory` | string | Optional | Filter by subcategory | `Rice` |
| `search` | string | Optional | Search product names | `basmati` |
| `page` | integer | Optional | Page number (default: 1) | `1` |
| `limit` | integer | Optional | Items per page (default: 20) | `20` |

### 📤 Response Structure

#### Admin User Response (with `user_phone` matching admin numbers)
```json
{
  "products": [
    {
      "item_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Basmati Rice",
      "price": 100.0,
      "buying_price": 80.0,           // ⭐ ONLY FOR ADMIN
      "section": "Provisions",
      "main_category": "Rice & Pulses",
      "subcategory": "Rice",
      "image_url": "https://res.cloudinary.com/...",
      "description": "Premium quality basmati rice",
      "unit": "kg",
      "stock_quantity": 150
    }
  ],
  "is_admin": true,                 // ⭐ Admin flag
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_products": 150,
    "total_pages": 8
  },
  "section": "Provisions",          // Echo filters if provided
  "main_category": "Rice & Pulses",
  "subcategory": "Rice"
}
```

#### Regular User Response (no `user_phone` or non-admin phone)
```json
{
  "products": [
    {
      "item_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Basmati Rice",
      "price": 100.0,
      // ❌ NO buying_price field
      "section": "Provisions",
      "main_category": "Rice & Pulses",
      "subcategory": "Rice",
      "image_url": "https://res.cloudinary.com/...",
      "description": "Premium quality basmati rice",
      "unit": "kg",
      "stock_quantity": 150
    }
  ],
  "is_admin": false,                // ⭐ Not admin
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_products": 150,
    "total_pages": 8
  }
}
```

### 🔑 Admin Phone Numbers

**Flutter sends (without country code):**
```
7339651541
8870503350
9487715568
```

**Supabase stores (with +91 prefix):**
```
+917339651541
+918870503350
+919487715568
```

**Backend handles both formats automatically** - send phone WITHOUT +91 prefix from Flutter.

### 🎯 Key Response Differences

| Field | Admin User | Regular User | Notes |
|-------|------------|--------------|-------|
| `is_admin` | `true` | `false` | Always present in response |
| `buying_price` | ✅ Included | ❌ Excluded | Only in products array for admin |
| Other fields | Same | Same | All other product fields identical |

### 🔒 Security Notes

1. **Server-side validation**: Admin check happens on backend (cannot be faked)
2. **Fresh check**: Admin status checked on EVERY request (no caching)
3. **Conditional inclusion**: `buying_price` only added if Supabase confirms admin status
4. **Database split**: 
   - Supabase checks `is_admin` flag
   - MongoDB returns products with `buying_price`
   - Backend conditionally includes field in response

### 📊 Database Architecture

#### Supabase (PostgreSQL) - Authentication Layer
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  phone TEXT UNIQUE NOT NULL,
  is_admin BOOLEAN DEFAULT false,  -- Admin flag
  fcm_token TEXT                    -- Push notifications
);

-- Admin users
INSERT INTO users (phone, is_admin) VALUES
  ('7339651541', true),
  ('8870503350', true),
  ('9487715568', true);
```

#### MongoDB - Application Data
```javascript
// products collection
{
  _id: ObjectId("..."),
  item_id: "550e8400-e29b-41d4-a716-446655440000",
  product_name: "Basmati Rice",
  price: 100.0,
  buying_price: 80.0,  // Cost price for admin view
  section: "Provisions",
  main_category: "Rice & Pulses",
  subcategory: "Rice",
  image_url: "https://...",
  stock_quantity: 150
}
```

---

## 🔧 Flutter Implementation Steps

### Step 1: Update API Service

**File:** `flutter_preview/lib/api_service.dart`

#### 1.1 Add User Phone to Products Request

**IMPORTANT:** Backend expects `user_phone` parameter to enable admin features.

**Backend Endpoint:**
```
GET https://al-mathina.onrender.com/api/flutter/products
```

**Query Parameters Flutter Must Send:**
```dart
{
  'user_phone': '7339651541',      // ⭐ REQUIRED for admin check
  'subcategory': 'Rice',            // Optional filter
  'section': 'Provisions',          // Optional filter
  'main_category': 'Rice & Pulses', // Optional filter
  'limit': '20',                     // Optional (default: 20)
  'page': '1'                        // Optional (default: 1)
}
```

**Example Request URL:**
```
https://al-mathina.onrender.com/api/flutter/products?user_phone=7339651541&subcategory=Rice&limit=20
```

**Current Code (Locate this in `api_service.dart`):**
```dart
Future<List<Product>> fetchProducts({
  String? subcategory,
  String? section,
  String? mainCategory,
}) async {
  // Build query parameters
  Map<String, String> queryParams = {};
  if (subcategory != null) queryParams['subcategory'] = subcategory;
  if (section != null) queryParams['section'] = section;
  if (mainCategory != null) queryParams['main_category'] = mainCategory;
  
  final uri = Uri.parse('$baseUrl/api/flutter/products')
    .replace(queryParameters: queryParams);
  final response = await http.get(uri);
  ...
}
```

**✅ Modified Code (What Backend Expects):**
```dart
Future<ProductsResponse> fetchProducts({  // ⭐ Changed return type
  String? subcategory,
  String? section,
  String? mainCategory,
  required String userPhone,  // ⭐ REQUIRED for admin check
}) async {
  // Build query parameters (EXACTLY as backend expects)
  Map<String, String> queryParams = {
    'user_phone': userPhone,  // ⭐ CRITICAL: Backend reads this
  };
  
  // Add optional filters
  if (subcategory != null) queryParams['subcategory'] = subcategory;
  if (section != null) queryParams['section'] = section;
  if (mainCategory != null) queryParams['main_category'] = mainCategory;
  
  // Build full URL with query parameters
  final uri = Uri.parse('$baseUrl/api/flutter/products')
    .replace(queryParameters: queryParams);
  
  print('🔍 Fetching products: $uri');  // Debug log
  
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    
    // ⭐ Backend sends: {products: [...], is_admin: bool, pagination: {...}}
    final productsResponse = ProductsResponse.fromJson(data);
    
    print('✅ Products loaded: ${productsResponse.products.length}');
    print('👤 Is Admin: ${productsResponse.isAdmin}');
    
    return productsResponse;
  } else {
    throw Exception('Failed to load products: ${response.statusCode}');
  }
}
```

**🎯 What Backend Sends Back:**

**For Admin User (7339651541):**
```json
{
  "products": [
    {
      "product_name": "Basmati Rice",
      "price": 100.0,
      "buying_price": 80.0  // ⭐ Backend includes this
    }
  ],
  "is_admin": true,  // ⭐ Backend sets this to true
  "pagination": {...}
}
```

**For Regular User (9876543210):**
```json
{
  "products": [
    {
      "product_name": "Basmati Rice",
      "price": 100.0
      // ❌ NO buying_price field
    }
  ],
  "is_admin": false,  // ⭐ Backend sets this to false
  "pagination": {...}
}
```

#### 1.2 Create ProductsResponse Model

**Add this new class to `api_service.dart`:**
```dart
class ProductsResponse {
  final List<Product> products;
  final bool isAdmin;
  final Map<String, dynamic> pagination;
  
  ProductsResponse({
    required this.products,
    required this.isAdmin,
    required this.pagination,
  });
  
  factory ProductsResponse.fromJson(Map<String, dynamic> json) {
    return ProductsResponse(
      products: (json['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList(),
      isAdmin: json['is_admin'] ?? false,
      pagination: json['pagination'] ?? {},
    );
  }
}
```

#### 1.3 Update Product Model

**Add `buyingPrice` field to Product class:**
```dart
class Product {
  final String itemId;
  final String productName;
  final double price;
  final double? buyingPrice;  // ⭐ NEW - nullable since only admins get it
  final String section;
  final String mainCategory;
  final String subcategory;
  final String imageUrl;
  final String? description;
  
  Product({
    required this.itemId,
    required this.productName,
    required this.price,
    this.buyingPrice,  // ⭐ NEW - optional
    required this.section,
    required this.mainCategory,
    required this.subcategory,
    required this.imageUrl,
    this.description,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemId: json['item_id'] ?? '',
      productName: json['product_name'] ?? 'Unknown Product',
      price: (json['price'] ?? 0).toDouble(),
      buyingPrice: json['buying_price'] != null   // ⭐ NEW
          ? (json['buying_price'] as num).toDouble()
          : null,
      section: json['section'] ?? '',
      mainCategory: json['main_category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      imageUrl: getImageUrl(json['image_url'] ?? ''),
      description: json['description'],
    );
  }
}
```

---

### Step 2: Update State Management

**File:** `flutter_preview/lib/screens/subcategory_products_screen.dart` (or wherever you manage product state)

#### 2.1 Store Admin Status in State

```dart
class _SubcategoryProductsScreenState extends State<SubcategoryProductsScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isAdmin = false;  // ⭐ NEW - track admin status
  String? _userPhone;      // ⭐ NEW - get from auth/profile
  
  @override
  void initState() {
    super.initState();
    _loadUserPhone();  // ⭐ NEW
    _fetchProducts();
  }
  
  // ⭐ NEW method - get user's phone from auth state
  Future<void> _loadUserPhone() async {
    // TODO: Replace with your actual auth logic
    // Example: Get from SharedPreferences, Provider, or auth service
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userPhone = prefs.getString('user_phone');
    });
  }
  
  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService().fetchProducts(
        subcategory: widget.subcategory,
        userPhone: _userPhone,  // ⭐ NEW - pass user phone
      );
      
      setState(() {
        _products = response.products;
        _isAdmin = response.isAdmin;  // ⭐ NEW - store admin status
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      setState(() => _isLoading = false);
    }
  }
}
```

---

### Step 3: Update UI to Display Buying Price

#### 3.1 Product Card Widget

**Modify your product card to show buying price for admins:**

```dart
class ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;  // ⭐ NEW parameter
  
  const ProductCard({
    Key? key,
    required this.product,
    required this.isAdmin,  // ⭐ NEW
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Image.network(
            product.imageUrl,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                Text(
                  product.productName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 4),
                
                // Selling Price
                Text(
                  '₹${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                
                // ⭐ NEW: Buying Price (Admin Only)
                if (isAdmin && product.buyingPrice != null) ...[
                  SizedBox(height: 2),
                  Text(
                    'Buying: ₹${product.buyingPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    'Margin: ₹${(product.price - product.buyingPrice!).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 3.2 Use ProductCard in ListView

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.subcategory),
      // ⭐ Optional: Show admin badge in app bar
      actions: [
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text('Admin'),
              backgroundColor: Colors.orange,
              labelStyle: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: _products[index],
                isAdmin: _isAdmin,  // ⭐ Pass admin status
              );
            },
          ),
  );
}
```

---

## 🧪 Testing Checklist

### Backend Tests (Run in PowerShell)

```powershell
# 1. Start backend (Docker recommended)
cd Backend
docker-compose up -d

# Wait 5 seconds for startup
Start-Sleep -Seconds 5

# 2. Run comprehensive API routing tests
python test_api_routing.py
```

**Expected Test Results (7/7 passing):**
```
🎉 ALL TESTS PASSED - Backend is ready for Flutter integration!

Tests Passed: 7/7
Success Rate: 100.0%

  ✅ PASS: admin_7339651541
  ✅ PASS: admin_8870503350
  ✅ PASS: admin_9487715568
  ✅ PASS: regular_user
  ✅ PASS: no_user_phone
  ✅ PASS: filters_admin
  ✅ PASS: filters_regular
```

**What's Tested:**
- ✅ All 3 admin users receive `buying_price` field
- ✅ Regular users do NOT receive `buying_price`
- ✅ `is_admin` flag correctly returned in response
- ✅ Section filters work with Tamil section names
- ✅ Supabase connection and admin check working
- ✅ Phone format handling (with/without +91 prefix)

### Manual API Testing (curl)

#### Test Admin User
```bash
# Admin user should get buying_price field
curl "http://127.0.0.1:8000/api/flutter/products?user_phone=7339651541&limit=2"

# Expected Response:
{
  "products": [
    {
      "product_name": "Basmati Rice",
      "price": 100.0,
      "buying_price": 80.0,  // ⭐ PRESENT
      ...
    }
  ],
  "is_admin": true,  // ⭐ TRUE
  "pagination": {...}
}
```

#### Test Regular User
```bash
# Regular user should NOT get buying_price field
curl "http://127.0.0.1:8000/api/flutter/products?user_phone=9876543210&limit=2"

# Expected Response:
{
  "products": [
    {
      "product_name": "Basmati Rice",
      "price": 100.0,
      // ❌ NO buying_price field
      ...
    }
  ],
  "is_admin": false,  // ⭐ FALSE
  "pagination": {...}
}
```

#### Test Without user_phone
```bash
# No user_phone parameter (should treat as regular user)
curl "http://127.0.0.1:8000/api/flutter/products?limit=2"

# Expected Response:
{
  "products": [...],  // NO buying_price
  "is_admin": false,  // ⭐ FALSE
  "pagination": {...}
}
```

#### Test With Filters (Admin)
```bash
# Admin user with section filter
curl "http://127.0.0.1:8000/api/flutter/products?user_phone=7339651541&section=Provisions&limit=5"

# Expected Response:
{
  "products": [  // All from Provisions section
    {"buying_price": 80.0, ...},  // ⭐ Has buying_price
    {"buying_price": 120.0, ...}
  ],
  "is_admin": true,
  "section": "Provisions",  // ⭐ Filter applied
  "pagination": {...}
}
```

### Production API Testing

```bash
# Test on production server (Render.com)
curl "https://al-mathina.onrender.com/api/flutter/products?user_phone=7339651541&limit=1"

# Expected: Same response as local, with is_admin=true and buying_price
```

### Flutter Tests

1. **Test Admin User:**
   - Login with: 7339651541, 8870503350, or 9487715568
   - Navigate to any subcategory
   - ✅ Should see "Admin" badge in app bar
   - ✅ Each product card shows:
     - Selling price (green, bold)
     - "Buying: ₹XX.XX" (gray, small)
     - "Margin: ₹XX.XX" (blue, small)

2. **Test Regular User:**
   - Login with any other phone number
   - Navigate to any subcategory
   - ✅ No "Admin" badge in app bar
   - ✅ Product cards show ONLY selling price
   - ✅ No buying price or margin displayed

3. **Edge Cases:**
   - No internet: Handle API errors gracefully
   - No user logged in: Should work but not show admin features
   - Product with missing buying_price: Don't show buying price section

---

## 🔐 Security Notes

1. **Server-side Validation:**
   - ✅ Admin status is checked on BACKEND (not client)
   - ✅ Buying price is ONLY sent when `is_admin: true`
   - ✅ Cannot fake admin status from Flutter app

2. **Best Practices:**
   - Never store admin status in Flutter app permanently
   - Always fetch fresh `is_admin` status on each API call
   - Log admin actions for audit trail (future enhancement)

---

## 📊 Database Structure

### Supabase `users` Table

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key (auto-generated) |
| phone | TEXT | User's phone number (unique) |
| name | TEXT | User's name |
| email | TEXT | User's email |
| store_name | TEXT | Store name |
| fcm_token | TEXT | Firebase Cloud Messaging token |
| is_admin | BOOLEAN | **NEW** - Admin flag (default: false) |

**Admin Users:**
```sql
SELECT * FROM users WHERE is_admin = true;
```

Expected result:
```
| phone      | is_admin | name           | store_name      |
|------------|----------|----------------|-----------------|
| 7339651541 | true     | Admin User 1   | Store 1         |
| 8870503350 | true     | Admin User 2   | Store 2         |
| 9487715568 | true     | Admin User 3   | Store 3         |
```

---

## 🚀 Deployment Steps

### 1. Backend Deployment (Render.com)

```bash
# Already deployed - changes auto-deploy on git push
git add .
git commit -m "Add admin buying price system"
git push origin main

# Monitor deployment at: https://dashboard.render.com
```

### 2. Run Migration on Production

**Option A: Supabase SQL Editor (Recommended)**
```sql
-- 1. Add is_admin column
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 2. Mark admin users (NOTE: +91 prefix required!)
UPDATE users SET is_admin = true 
WHERE phone IN ('+917339651541', '+918870503350', '+919487715568');

-- 3. Verify (should return 3 rows)
SELECT phone, is_admin, fcm_token FROM users WHERE is_admin = true;
```

**Expected Output:**
```
| phone         | is_admin | fcm_token |
|---------------|----------|--------|
| +917339651541 | true     | ...    |
| +918870503350 | true     | ...    |
| +919487715568 | true     | ...    |
```

### 3. Add Supabase Credentials to Production Environment

**CRITICAL:** Update `Backend/.env.production` with Supabase credentials:

```bash
# Edit Backend/.env.production and add these lines:
SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1aGtuZHlseWF2ZWRtZnJvdnNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwODc2NDAsImV4cCI6MjA4MDY2MzY0MH0.MeRnP6FlqZ5HcK_JWx_yMNBNE7SWhJT7M1vC1WeAKSQ
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1aGtuZHlseWF2ZWRtZnJvdnNqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTA4NzY0MCwiZXhwIjoyMDgwNjYzNjQwfQ.a9TkJJSVbFjmFQ8BkB1Vnzp1uGFpPKVCTjteCdAu_Pw
```

**Then restart Docker:**
```bash
cd Backend
docker-compose restart
```

### 4. Flutter App Deployment

```bash
# Test locally first
cd flutter_preview
flutter run -d chrome

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web            # Web
```

---

## 🐛 Troubleshooting

### Issue: Admin users not seeing buying_price

**Check:**
1. **CRITICAL:** Verify Supabase environment variables are set in `.env.production`:
   ```bash
   # In Backend/.env.production (REQUIRED for Docker/production)
   SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
   
   **Without these, backend cannot connect to Supabase and admin check will fail!**

2. Database migration ran successfully:
   ```sql
   SELECT column_name, data_type FROM information_schema.columns 
   WHERE table_name = 'users' AND column_name = 'is_admin';
   ```

3. Admin flag is set (note +91 prefix in database):
   ```sql
   SELECT phone, is_admin FROM users WHERE phone = '+917339651541';
   ```

4. Backend logs show no DNS errors:
   ```bash
   # Check Docker logs for errors
   cd Backend
   docker-compose logs --tail=50 backend
   
   # Should NOT see: "Failed to check admin status: [Errno -2] Name or service not known"
   # This error means Supabase env vars are missing!
   ```

5. API returns correct data:
   ```bash
   curl "http://127.0.0.1:8000/api/flutter/products?user_phone=7339651541&limit=1"
   ```

### Issue: Regular users seeing buying_price

**This should NEVER happen** - it means backend security is broken.

**Check:**
1. Backend code in `routes/flutter.py` has admin check
2. Buying price is conditionally added: `if is_admin: product_data["buying_price"] = ...`
3. Test with non-admin phone: `curl "http://127.0.0.1:8000/api/flutter/products?user_phone=9999999999"`

### Issue: Flutter app crashes on buying_price

**Check:**
1. Product model has nullable `buyingPrice?` field
2. UI checks `if (isAdmin && product.buyingPrice != null)`
3. Safe null handling: `product.buyingPrice!.toStringAsFixed(2)`

---

## 📝 Code Review Checklist

Before merging to production:

- [ ] Database migration script tested locally
- [ ] Backend API returns `is_admin` flag correctly
- [ ] Backend ONLY includes `buying_price` for admin users
- [ ] Flutter Product model has `buyingPrice?` field
- [ ] Flutter API service passes `userPhone` parameter
- [ ] Flutter UI conditionally shows buying price
- [ ] Tested with all 3 admin phone numbers
- [ ] Tested with regular user (no buying price visible)
- [ ] Error handling for missing/null buying prices
- [ ] Code follows project naming conventions
- [ ] Updated documentation in this file

---

## 🎉 Expected Final Result

### Admin User View (Phone: 7339651541)

```
┌─────────────────────────────────────┐
│  🛍️ Subcategory: Rice         [Admin]│
└─────────────────────────────────────┘

┌──────────┐  ┌──────────┐  ┌──────────┐
│ Basmati  │  │ Ponni    │  │ Sona     │
│ Rice     │  │ Rice     │  │ Masoori  │
│          │  │          │  │          │
│ ₹100.00  │  │ ₹85.00   │  │ ₹95.00   │
│ Buying:  │  │ Buying:  │  │ Buying:  │
│ ₹80.00   │  │ ₹70.00   │  │ ₹78.00   │
│ Margin:  │  │ Margin:  │  │ Margin:  │
│ ₹20.00   │  │ ₹15.00   │  │ ₹17.00   │
└──────────┘  └──────────┘  └──────────┘
```

### Regular User View (Phone: 9876543210)

```
┌─────────────────────────────────────┐
│  🛍️ Subcategory: Rice               │
└─────────────────────────────────────┘

┌──────────┐  ┌──────────┐  ┌──────────┐
│ Basmati  │  │ Ponni    │  │ Sona     │
│ Rice     │  │ Rice     │  │ Masoori  │
│          │  │          │  │          │
│ ₹100.00  │  │ ₹85.00   │  │ ₹95.00   │
└──────────┘  └──────────┘  └──────────┘
```

---

## 📞 Support

For questions or issues:
1. Check backend logs: `Backend/logs/`
2. Check Flutter console: `flutter logs`
3. Test API manually: `Backend/test_admin_system.py`
4. Review this documentation

---

## ✅ Production Deployment Checklist

Before deploying to production, verify:

- [ ] Supabase migration executed successfully (3 admin users marked)
- [ ] Supabase credentials added to `Backend/.env.production`
- [ ] Docker backend restarted after adding credentials
- [ ] Backend tests passing: `python test_api_routing.py` shows **7/7 tests**
- [ ] Manual API test confirms admin users get `buying_price`
- [ ] Manual API test confirms regular users DON'T get `buying_price`
- [ ] Docker logs show no DNS errors ("Name or service not known")
- [ ] Flutter app updated with `userPhone` parameter in API calls
- [ ] Flutter Product model has nullable `buyingPrice?` field
- [ ] Flutter UI conditionally displays buying price for admins only

---

**Last Updated:** December 22, 2025
**Author:** Al-Mathina Development Team
**Version:** 2.0 (Updated with phone format fixes and Supabase environment requirements)
