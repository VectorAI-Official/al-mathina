# Flutter Frontend - Backend Integration Guide

This guide explains how to integrate the AL-Madhina Flutter app with the FastAPI backend.

## 🎯 Overview

The Flutter app now includes an `api_service.dart` file that handles all communication with the FastAPI backend running at `http://127.0.0.1:8000`.

## 📦 Setup

### 1. Install Dependencies

```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview
flutter pub get
```

This will install the `http` package that was added to `pubspec.yaml`.

### 2. Verify Backend is Running

Before running the Flutter app, make sure the backend is running:

```powershell
# In a separate terminal, navigate to Backend folder
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Activate Python environment
.\venv\Scripts\Activate.ps1

# Start FastAPI
uvicorn main:app --reload
```

You should see:
```
✅ Backend Ready - Listening on http://127.0.0.1:8000
```

### 3. Run the Flutter App

```powershell
# In the flutter_preview directory
flutter run -d chrome
```

## 🔌 API Service Usage

The `api_service.dart` file provides methods to interact with the backend. Here's how to use them:

### Get Categories

```dart
import 'api_service.dart';

// Fetch all categories from MongoDB
final categories = await ApiService.getCategories();

for (var category in categories) {
  print('${category.name} - ${category.nameTa}');
}
```

### Get Products

```dart
// Get all products
final allProducts = await ApiService.getProducts();

// Get products by category
final attaProducts = await ApiService.getProducts(category: 'Atta');

// Get specific product
final product = await ApiService.getProduct('Atta', 'Aashirvaad');
print('Price: ₹${product.price}');
print('Stock: ${product.stock}');
```

### Cart Operations

```dart
// Add to cart
await ApiService.addToCart(
  userId: 'test_user',
  category: 'Atta',
  brand: 'Aashirvaad',
  quantity: 2,
);

// Get cart
final cart = await ApiService.getCart('test_user');
print('Total items: ${cart['total_items']}');
print('Total amount: ₹${cart['total_amount']}');

// Update cart item quantity
await ApiService.updateCartQuantity(
  cartItemId: 1,
  quantity: 5,
);

// Clear cart
await ApiService.clearCart('test_user');
```

### Order Management

```dart
// Create order
final order = await ApiService.createOrder(
  userId: 'test_user',
  items: [
    {
      'category': 'Atta',
      'brand': 'Aashirvaad',
      'quantity': 2,
      'price': 45.99,
    }
  ],
  paymentMethod: 'COD',
  totalAmount: 91.98,
);

print('Order created: ${order['order_number']}');

// Get order history
final orders = await ApiService.getOrders('test_user');
print('You have ${orders.length} orders');
```

### Health Check

```dart
// Check if backend is running
try {
  final health = await ApiService.healthCheck();
  print('Backend status: ${health['status']}');
} catch (e) {
  print('Backend is not running: $e');
}
```

## 🔄 Migration from Mock Data

Your current Flutter app uses mock data (`mockBrands`). Here's how to migrate to use the backend API:

### Before (Mock Data)
```dart
const Map<String, List<String>> mockBrands = {
  'Atta': ['Aashirvaad', 'Pillsbury', 'Fortune', 'Patanjali'],
  // ...
};
```

### After (Backend API)
```dart
import 'api_service.dart';

class BrandListingScreen extends StatefulWidget {
  // ...
}

class _BrandListingScreenState extends State<BrandListingScreen> {
  List<Product> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final fetchedProducts = await ApiService.getProducts(
        category: widget.categoryName,
      );
      setState(() {
        products = fetchedProducts;
        loading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          child: Column(
            children: [
              Text(product.brand),
              Text('₹${product.price}'),
              Text('Stock: ${product.stock}'),
              // ... rest of UI
            ],
          ),
        );
      },
    );
  }
}
```

## 🧪 Testing the Integration

### 1. Test Backend Connectivity

Add this to your app's startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test backend connection
  try {
    final health = await ApiService.healthCheck();
    print('✅ Backend connected: ${health['status']}');
  } catch (e) {
    print('❌ Backend not available: $e');
  }
  
  runApp(MyApp());
}
```

### 2. Test API Endpoints

Create a test screen:

```dart
class ApiTestScreen extends StatelessWidget {
  Future<void> runTests(BuildContext context) async {
    try {
      // Test 1: Get categories
      print('Test 1: Getting categories...');
      final categories = await ApiService.getCategories();
      print('✅ Got ${categories.length} categories');

      // Test 2: Get products
      print('Test 2: Getting products...');
      final products = await ApiService.getProducts(category: 'Atta');
      print('✅ Got ${products.length} products');

      // Test 3: Add to cart
      print('Test 3: Adding to cart...');
      await ApiService.addToCart(
        userId: 'test_user',
        category: 'Atta',
        brand: 'Aashirvaad',
        quantity: 1,
      );
      print('✅ Added to cart');

      // Test 4: Get cart
      print('Test 4: Getting cart...');
      final cart = await ApiService.getCart('test_user');
      print('✅ Cart has ${cart['total_items']} items');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All tests passed!')),
      );
    } catch (e) {
      print('❌ Test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('API Tests')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => runTests(context),
          child: Text('Run API Tests'),
        ),
      ),
    );
  }
}
```

## 🔍 Debugging

### Common Issues

#### 1. "Connection refused" or "Failed to load"

**Cause**: Backend is not running or wrong URL

**Solution**:
```powershell
# Check if backend is running
curl http://127.0.0.1:8000/health

# If not, start the backend
cd Backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload
```

#### 2. "CORS error" in browser console

**Cause**: CORS not configured properly (should be fine with current setup)

**Solution**: The FastAPI backend already has CORS configured to allow `http://127.0.0.1:*` and `http://localhost:*`

#### 3. Empty response or "Product not found"

**Cause**: Database not initialized with sample data

**Solution**: Restart the FastAPI server - it will automatically populate sample data

## 📱 User Authentication

The current API uses a simple `user_id` string. For production, you should implement proper authentication:

### Simple Approach (Current)
```dart
// Use a unique device ID as user_id
final userId = await getDeviceId(); // Use device_info_plus package
```

### Production Approach
```dart
// Use Supabase Auth (already included in backend)
// 1. Login with phone number (already implemented in Flutter)
// 2. Get auth token from Supabase
// 3. Pass token with API requests
// 4. Backend validates token
```

## 🚀 Next Steps

1. **Replace Mock Data**: Update `HomeScreen` and `BrandListingScreen` to use `ApiService`
2. **Update Cart**: Sync cart operations with backend
3. **Update Orders**: Save orders to backend instead of just clearing cart
4. **Add Loading States**: Show spinners while fetching data
5. **Add Error Handling**: Show user-friendly error messages
6. **Add Offline Support**: Cache data locally using `shared_preferences` or `sqflite`

## 💡 Best Practices

### 1. Use FutureBuilder

```dart
FutureBuilder<List<Product>>(
  future: ApiService.getProducts(category: 'Atta'),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    final products = snapshot.data!;
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  },
)
```

### 2. Handle Errors Gracefully

```dart
try {
  final products = await ApiService.getProducts();
  // Use products
} catch (e) {
  if (e.toString().contains('Connection refused')) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Backend Offline'),
        content: Text('Please start the backend server'),
      ),
    );
  }
}
```

### 3. Show Loading Indicators

```dart
setState(() => isLoading = true);
try {
  final data = await ApiService.getCategories();
  // Process data
} finally {
  setState(() => isLoading = false);
}
```

## 📚 Additional Resources

- **HTTP Package**: https://pub.dev/packages/http
- **FutureBuilder**: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
- **Error Handling**: https://dart.dev/guides/language/language-tour#exceptions

## ✅ Checklist

Before considering the integration complete:

- [ ] Backend is running and accessible
- [ ] Flutter app can fetch categories
- [ ] Flutter app can fetch products
- [ ] Add to cart works
- [ ] Cart display shows backend data
- [ ] Orders are created in backend
- [ ] Loading states are shown
- [ ] Errors are handled gracefully
- [ ] User gets feedback for all actions

---

**Need Help?** Check the FastAPI backend logs and Flutter debug console for detailed error messages.
