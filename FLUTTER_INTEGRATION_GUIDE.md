# Flutter App Integration Guide - AL-Madhina

Complete step-by-step guide to integrate AL-Madhina Flutter app with Docker-hosted backend and implement all pages.

## Table of Contents

1. [Setup & Configuration](#setup--configuration)
2. [Page Implementation](#page-implementation)
3. [Data Flow Architecture](#data-flow-architecture)
4. [Testing & Debugging](#testing--debugging)
5. [Deployment](#deployment)

---

## Setup & Configuration

### 1. Environment Configuration

**File**: `flutter_preview/lib/api_service.dart`

Already updated to use Docker URL:
```dart
const String BASE_URL = "http://localhost:8000";
const String API_BASE = "$BASE_URL/api/flutter";
```

### 2. Backend Requirements

**Ensure Docker backend is running:**

```powershell
# Navigate to project root
cd c:\Users\faisa\AndroidStudioProjects\AlMathina

# Start Docker containers
docker-compose up -d

# Verify backend is running
docker ps

# Check backend logs
docker logs backend-backend-1

# Test API connectivity
curl http://localhost:8000/docs
```

### 3. Flutter App Setup

```powershell
# Navigate to Flutter project
cd flutter_preview

# Install dependencies
flutter pub get

# Run on Chrome (for web preview)
flutter run -d chrome

# Or specify host and port
flutter run -d chrome --web-port=5000
```

**Expected Output:**
```
Launching lib/main.dart on Chrome in debug mode...
Building Chrome application...
Connecting to Service Protocol...
```

---

## Page Implementation

### Home Page

#### Implementation File: `lib/main.dart`

**Key Components:**

```dart
// HomeScreen widget
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> futureHomeData;
  String selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    futureHomeData = ApiService.getHomeData(lang: selectedLanguage);
  }

  void _switchLanguage(String lang) {
    setState(() {
      selectedLanguage = lang;
      futureHomeData = ApiService.getHomeData(lang: selectedLanguage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AL-Madhina'),
        actions: [
          DropdownButton<String>(
            value: selectedLanguage,
            onChanged: (String? newValue) {
              if (newValue != null) _switchLanguage(newValue);
            },
            items: [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<HomeData>(
        future: futureHomeData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          }

          final homeData = snapshot.data!;

          return ListView(
            children: [
              // Best Sellers Section
              _buildBestSellersSection(homeData.bestSellers),
              
              // Regular Sections
              ...homeData.sections.map((section) {
                return _buildSectionWidget(section);
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBestSellersSection(BestSellersSection bestSellers) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${bestSellers.icon} ${bestSellers.title}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: bestSellers.mainCategories.length,
            itemBuilder: (context, index) {
              final category = bestSellers.mainCategories[index];
              return _buildCategoryCard(category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWidget(Section section) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${section.icon} ${section.title}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: section.mainCategories.length,
            itemBuilder: (context, index) {
              final category = section.mainCategories[index];
              return _buildCategoryCard(category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(MainCategory category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubcategoryPage(
              section: category.section,
              mainCategory: category.mainCategory,
              title: category.name,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        child: Column(
          children: [
            Image.network(
              category.imageUrl,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: Icon(Icons.image_not_supported),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${category.productCount} items',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Subcategory Page

#### Implementation File: `lib/pages/subcategory_page.dart`

```dart
import 'package:flutter/material.dart';
import '../api_service.dart';

class SubcategoryPage extends StatefulWidget {
  final String section;
  final String mainCategory;
  final String title;

  SubcategoryPage({
    required this.section,
    required this.mainCategory,
    required this.title,
  });

  @override
  _SubcategoryPageState createState() => _SubcategoryPageState();
}

class _SubcategoryPageState extends State<SubcategoryPage> {
  late Future<Map<String, dynamic>> futureSubcategories;

  @override
  void initState() {
    super.initState();
    futureSubcategories = ApiService.getSubcategories(
      section: widget.section,
      mainCategory: widget.mainCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureSubcategories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No subcategories found'));
          }

          final data = snapshot.data!;
          final subcategories = data['subcategories'] as List? ?? [];

          return ListView.builder(
            itemCount: subcategories.length,
            itemBuilder: (context, index) {
              final subcategory = subcategories[index];
              return ListTile(
                title: Text(subcategory['name_display'] ?? subcategory['name']),
                subtitle: Text('${subcategory['product_count']} products'),
                leading: Container(
                  width: 50,
                  height: 50,
                  child: Image.network(
                    subcategory['image_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported);
                    },
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductsPage(
                        section: widget.section,
                        mainCategory: widget.mainCategory,
                        subcategory: subcategory['name'],
                        title: subcategory['name_display'] ?? subcategory['name'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

---

### Products Page

#### Implementation File: `lib/pages/products_page.dart`

```dart
import 'package:flutter/material.dart';
import '../api_service.dart';

class ProductsPage extends StatefulWidget {
  final String section;
  final String mainCategory;
  final String subcategory;
  final String title;

  ProductsPage({
    required this.section,
    required this.mainCategory,
    required this.subcategory,
    required this.title,
  });

  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<Map<String, dynamic>> futureProducts;
  int currentPage = 1;
  List<dynamic> allProducts = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final products = await ApiService.getProducts(
        section: widget.section,
        mainCategory: widget.mainCategory,
        subcategory: widget.subcategory,
        page: currentPage,
        limit: 20,
      );
      
      setState(() {
        if (currentPage == 1) {
          allProducts = products['products'] ?? [];
        } else {
          allProducts.addAll(products['products'] ?? []);
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  void _loadMore() {
    currentPage++;
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: allProducts.isEmpty && !isLoading
          ? Center(child: Text('No products found'))
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: allProducts.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == allProducts.length) {
                  return Center(child: CircularProgressIndicator());
                }

                final product = allProducts[index];
                return _buildProductCard(product);
              },
            ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              itemId: product['item_id'],
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        child: Column(
          children: [
            Image.network(
              product['image_url'] ?? '',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: Icon(Icons.image_not_supported),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['product_name'] ?? 'N/A',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    product['weight'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₹${product['price']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Product Detail Page

#### Implementation File: `lib/pages/product_detail_page.dart`

```dart
import 'package:flutter/material.dart';
import '../api_service.dart';

class ProductDetailPage extends StatefulWidget {
  final String itemId;

  ProductDetailPage({required this.itemId});

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<Map<String, dynamic>> futureProduct;
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    futureProduct = ApiService.getProductDetails(itemId: widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureProduct,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Product not found'));
          }

          final product = snapshot.data!;
          final inStock = product['in_stock'] ?? false;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  product['image_url'] ?? '',
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: Icon(Icons.image_not_supported),
                    );
                  },
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['product_name'] ?? 'N/A',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (product['product_name_ta'] != null)
                        Text(
                          product['product_name_ta'],
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      SizedBox(height: 12),
                      Text(
                        '₹${product['price']}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${product['weight']} | ',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            inStock ? '✓ In Stock' : '✗ Out of Stock',
                            style: TextStyle(
                              fontSize: 16,
                              color: inStock ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (product['description'] != null)
                        Text(
                          product['description'],
                          style: TextStyle(fontSize: 14),
                        ),
                      SizedBox(height: 24),
                      // Quantity Selector
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: quantity > 1
                                ? () => setState(() => quantity--)
                                : null,
                          ),
                          Text('$quantity', style: TextStyle(fontSize: 18)),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: inStock
                                ? () => setState(() => quantity++)
                                : null,
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Add to Cart Button
                      ElevatedButton(
                        onPressed: inStock
                            ? () {
                                // Implement add to cart logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added $quantity ${product['product_name']} to cart',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text('Add to Cart'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

### Favorites Page

#### Implementation File: `lib/pages/favorites_page.dart`

```dart
import 'package:flutter/material.dart';
import '../api_service.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<Map<String, dynamic>> futureFavorites;
  final String userId = 'user_123'; // Replace with actual user ID

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      futureFavorites = ApiService.getUserFavorites(userId: userId);
    });
  }

  void _removeFavorite(String itemId) async {
    try {
      await ApiService.removeFromFavorites(userId: userId, itemId: itemId);
      _loadFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed from favorites')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites ❤️'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureFavorites,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final favorites = snapshot.data?['favorites'] as List? ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No favorites yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final item = favorites[index];
              return ListTile(
                leading: Image.network(
                  item['image_url'] ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.image_not_supported);
                  },
                ),
                title: Text(item['product_name'] ?? 'N/A'),
                subtitle: Text('₹${item['price']}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeFavorite(item['item_id']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

### Orders Page

#### Implementation File: `lib/pages/orders_page.dart`

```dart
import 'package:flutter/material.dart';
import '../api_service.dart';

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<Map<String, dynamic>> futureOrders;
  final String userId = 'user_123'; // Replace with actual user ID
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      futureFav = ApiService.getUserOrders(
        userId: userId,
        status: selectedStatus == 'all' ? null : selectedStatus,
        page: 1,
        limit: 10,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders 📦'),
      ),
      body: Column(
        children: [
          // Status Filter
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatusButton('all', 'All'),
                SizedBox(width: 8),
                _buildStatusButton('pending', 'Pending'),
                SizedBox(width: 8),
                _buildStatusButton('completed', 'Completed'),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: futureOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final orders = snapshot.data?['orders'] as List? ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No orders yet'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(order: order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label) {
    return ElevatedButton(
      onPressed: () {
        setState(() => selectedStatus = status);
        _loadOrders();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedStatus == status ? Colors.blue : Colors.grey,
      ),
      child: Text(label),
    );
  }
}

class OrderCard extends StatelessWidget {
  final dynamic order;

  OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['order_id'].substring(0, 8)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order['status'].toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${order['items_count']} items • ₹${order['total_amount']}',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Delivery: ${order['delivery_address']}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Navigate to order details
              },
              child: Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
```

---

## Data Flow Architecture

### Request/Response Pipeline

```
User Action
    ↓
Flutter Widget
    ↓
ApiService Method
    ↓
HTTP Request to Backend
    ↓
Backend Route Handler
    ↓
Database Query (MongoDB/Supabase)
    ↓
Response JSON
    ↓
Model Parsing
    ↓
setState() UI Update
    ↓
Widget Rebuild
```

### API Service Integration Points

1. **Home Page**: `ApiService.getHomeData()`
   - Fetches: Best sellers + all sections
   - Caches: Category hierarchy
   - On update: Reload on pull-down refresh

2. **Subcategory Page**: `ApiService.getSubcategories()`
   - Fetches: Subcategories for selected main category
   - Displays: Grid or list view
   - Navigation: To products page on tap

3. **Products Page**: `ApiService.getProducts()`
   - Fetches: Paginated product list with filters
   - Infinite scroll: Auto-load next page
   - Add to cart: Local state management

4. **Product Details**: `ApiService.getProductDetails()`
   - Fetches: Full product information
   - Displays: Image gallery, description, reviews
   - Actions: Add to cart, add to favorites

5. **Favorites**: `ApiService.getUserFavorites()` / `addToFavorites()` / `removeFromFavorites()`
   - Fetches: User's favorite products
   - Persist: Server-side favorites collection
   - Sync: Real-time updates

6. **Orders**: `ApiService.getUserOrders()` / `createOrder()`
   - Fetches: User's order history with filters
   - Displays: Order status and items
   - Create: From cart with delivery address

---

## Testing & Debugging

### 1. API Testing

**Using FastAPI Docs:**
- Open: `http://localhost:8000/docs`
- Test all endpoints interactively
- View request/response payloads

**Using cURL:**
```bash
# Get home data
curl -s http://localhost:8000/api/flutter/home | jq '.'

# Get subcategories
curl -s 'http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories' | jq '.'

# Get favorites
curl -s http://localhost:8000/api/flutter/favorites/user_123 | jq '.'
```

### 2. Flutter Debugging

**Enable verbose logging:**
```dart
// In api_service.dart
if (response.statusCode != 200) {
  print('Request: ${response.request}');
  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
```

**Use Flutter DevTools:**
```powershell
flutter pub global activate devtools
devtools
```

### 3. Network Monitoring

**Check Docker backend logs:**
```powershell
docker logs -f backend-backend-1
```

**Check API responses:**
```powershell
docker exec backend-backend-1 tail -f /app/logs/app.log
```

---

## Deployment

### 1. Local Development

```powershell
# Terminal 1: Start backend
cd Backend
docker-compose up -d

# Terminal 2: Run Flutter app
cd flutter_preview
flutter run -d chrome
```

### 2. Production Build

**Web Build:**
```powershell
flutter build web --web-port=5000
# Output: build/web/
```

**Update API URL for production:**
```dart
const String BASE_URL = "https://yourdomain.com:8000";
```

### 3. Docker Deployment

**Build custom Docker image:**
```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
```

**Run container:**
```powershell
docker run -p 80:80 almathina-web:latest
```

---

## Common Issues & Solutions

### Issue 1: Backend Connection Refused
**Solution:**
```powershell
# Check if backend is running
docker ps

# Start backend
docker-compose up -d

# Check logs
docker logs backend-backend-1
```

### Issue 2: Image URLs Not Loading
**Solution:**
- Verify `localhost:8000` is accessible
- Check CORS headers in backend
- Verify image files exist in uploads directory

### Issue 3: API Response Empty
**Solution:**
- Check database connection in backend
- Verify database collections exist
- Check API query parameters

### Issue 4: Tamil Text Not Displaying
**Solution:**
- Ensure Flutter app has Tamil font
- Add to `pubspec.yaml`:
```yaml
google_fonts:
  noto-sans-tamil:
    weights: [400, 700]
```

---

## Next Steps

1. Implement user authentication
2. Add shopping cart functionality
3. Integrate payment gateway
4. Implement real-time order tracking
5. Add product reviews and ratings
6. Create admin panel for inventory management
7. Implement push notifications
8. Add offline support with local caching

