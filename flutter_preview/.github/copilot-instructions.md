# Flutter Preview Copilot Instructions - AL-Madhina

## Project Overview
Flutter web/mobile preview app for AL-Madhina wholesale ordering system. Connects to FastAPI backend for product catalog, cart management, and order placement.

## Technology Stack
- **Framework**: Flutter 3.x (Dart)
- **Target**: Web (Chrome preview), Android/iOS
- **State Management**: Provider pattern (custom AppProvider)
- **Backend**: FastAPI REST API (`https://al-mathina.onrender.com`)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Authentication**: Phone-based (Supabase backend)

## Critical File Structure

```
flutter_preview/
├── lib/
│   ├── main.dart                 # Main app UI, navigation, cart (8956 lines!)
│   ├── api_service.dart          # API client, data models, HTTP helpers
│   ├── services/
│   │   └── fcm_service.dart      # FCM token management
│   ├── screens/
│   │   └── phone_auth_screen.dart # Phone authentication
│   └── models/                   # (if any)
├── web/
│   └── index.html               # Web entry point, FCM config
├── android/
│   └── app/
│       └── google-services.json # Firebase config (Android)
└── pubspec.yaml                 # Dependencies
```

## App Architecture

### State Management (AppProvider)
**File**: `main.dart` - `AppProvider` class

**Key State**:
```dart
class AppProvider extends ChangeNotifier {
  List<CartItem> _cart = [];
  String _currentLanguage = 'en';  // 'en' or 'ta' (Tamil)
  String? _userPhone;
  Map<String, dynamic>? _storeDetails;
  String _selectedSection = 'All';
  String _searchQuery = '';
  
  // Cart operations
  void addToCart(Product product) { ... }
  void updateQuantity(String itemId, int delta) { ... }
  void removeFromCart(String itemId) { ... }
  double get cartTotal { ... }
  
  // Language switching
  String text(String key) { ... }  // Returns translation
}
```

### Navigation Flow
```
PhoneAuthScreen
  ↓ (after login)
HomeScreen (main.dart)
  ├─→ SubcategoryProductsScreen
  │     ├─→ ProductDetailsScreen
  │     └─→ CartScreen
  │           └─→ OrderSuccessScreen
  └─→ ProfileScreen
```

## Backend API Integration

### Base URLs
```dart
const String BASE_URL = "https://al-mathina.onrender.com";
const String API_BASE = "$BASE_URL/api/flutter";
```

### Key API Methods

#### 1. **Home Data** (Sections, Main Categories, Most Bought)
```dart
static Future<Map<String, dynamic>> fetchHomeData() async {
  final url = '$API_BASE/home';
  // Returns: {sections: [...], best_sellers: {...}}
}
```

#### 2. **Subcategories**
```dart
static Future<List<Subcategory>> fetchSubcategories(
  String section, 
  String mainCategory
) async {
  final url = '$API_BASE/main-category/$section/$mainCategory/subcategories';
}
```

#### 3. **Products**
```dart
static Future<List<Product>> fetchProducts({
  required String section,
  required String mainCategory,
  String? subcategory,
}) async {
  // Returns list of products with product_name, weight, price, imageUrl
}
```

#### 4. **Create Order** ⚠️ CRITICAL
```dart
static Future<Map<String, dynamic>> createOrder({
  required String userPhone,
  required List<Map<String, dynamic>> items,
  required double totalAmount,
  required String paymentMethod,
  required Map<String, dynamic> deliveryAddress,
}) async {
  final orderData = {
    'user_phone': userPhone,
    'items': items,  // ⚠️ Contains product_name, not productName!
    'total_amount': totalAmount,
    'payment_method': paymentMethod,
    'delivery_address': deliveryAddress,
    'status': 'pending',
  };
  
  await http.post('$API_BASE/user/orders', body: json.encode(orderData));
}
```

**⚠️ Item Structure from Cart**:
```dart
final items = provider.cart.map((item) {
  return {
    'section': item.section,
    'main_category': item.mainCategory,
    'subcategory': item.subcategory ?? '',
    'product_name': item.productName,  // ⚠️ snake_case for backend
    'weight': item.weight,
    'quantity': item.quantity,
    'price': item.price,
    'image_url': item.imageUrl,
  };
}).toList();
```

## Data Models

### Product
```dart
class Product {
  final String itemId;
  final String productName;  // Can contain Tamil characters
  final String weight;       // e.g., "25kg", "1L"
  final double price;
  final String imageUrl;
  final String section;
  final String mainCategory;
  final String? subcategory;
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemId: json['item_id'] ?? '',
      productName: json['product_name'] ?? json['productName'] ?? '',
      weight: json['weight'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: getImageUrl(json['image_url'] ?? json['imageUrl']),
      section: json['section'] ?? '',
      mainCategory: json['main_category'] ?? json['mainCategory'] ?? '',
      subcategory: json['subcategory'],
    );
  }
}
```

### CartItem
```dart
class CartItem {
  final String itemId;
  final String productName;
  final String weight;
  final double price;
  final String imageUrl;
  int quantity;
  final String section;
  final String mainCategory;
  final String? subcategory;
  
  double get totalPrice => price * quantity;
}
```

## Tamil Language Support

### Translation System
```dart
// Translations defined in AppProvider
final Map<String, String> _englishTexts = {
  'app_title': 'AL-Madhina',
  'welcome': 'Welcome',
  'cart': 'Cart',
  'place_order': 'Place Order',
  // ... 50+ keys
};

final Map<String, String> _tamilTexts = {
  'app_title': 'அல்-மதீனா',
  'welcome': 'வரவேற்பு',
  'cart': 'கூடை',
  'place_order': 'ஆர்டர் செய்',
  // ... 50+ keys
};

// Usage in UI
Text(provider.text('welcome'))  // Shows "Welcome" or "வரவேற்பு"
```

### Language Toggle
```dart
// Switch language
provider.setLanguage('ta');  // Tamil
provider.setLanguage('en');  // English
```

## Firebase Cloud Messaging (FCM)

### Token Management
**File**: `services/fcm_service.dart`

```dart
class FCMService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  
  // Get token
  static Future<String?> getToken() async {
    return await messaging.getToken();
  }
  
  // Save token to backend
  static Future<void> saveTokenToBackend(String phone, String token) async {
    await http.post(
      '$API_BASE/fcm/token',
      body: json.encode({'phone': phone, 'fcm_token': token}),
    );
  }
  
  // Refresh token on login
  static Future<void> refreshToken(String phone) async {
    final token = await getToken();
    if (token != null) {
      await saveTokenToBackend(phone, token);
    }
  }
}
```

### Notification Handling
```dart
// Listen for notifications
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('📱 Notification received: ${message.notification?.title}');
  // Show in-app notification
});

// Handle notification tap
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('📱 Notification tapped');
  // Navigate to order details
});
```

## Cart Operations

### Add to Cart
```dart
void _addToCart(Product product) {
  final cartItem = CartItem(
    itemId: product.itemId,
    productName: product.productName,
    weight: product.weight,
    price: product.price,
    imageUrl: product.imageUrl,
    quantity: 1,
    section: product.section,
    mainCategory: product.mainCategory,
    subcategory: product.subcategory,
  );
  provider.addToCart(cartItem);
  
  // Show snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${product.productName} added to cart')),
  );
}
```

### Update Quantity
```dart
void _updateQuantity(CartItem item, int delta) {
  provider.updateQuantity(item.itemId, delta);
}
```

### Remove from Cart
```dart
void _removeFromCart(CartItem item) {
  provider.removeFromCart(item.itemId);
}
```

## Order Placement Flow

### 1. Get Store Details
```dart
final storeDetails = await ApiService.getStoreDetails(userPhone);
// Returns: {street, city, state, pincode, landmark, store_name}
```

### 2. Prepare Order Items
```dart
final items = provider.cart.map((item) {
  return {
    'section': item.section,
    'main_category': item.mainCategory,
    'subcategory': item.subcategory ?? '',
    'product_name': item.productName,  // ⚠️ Use product_name (snake_case)
    'weight': item.weight,
    'quantity': item.quantity,
    'price': item.price,
    'image_url': item.imageUrl,
  };
}).toList();
```

### 3. Create Order
```dart
final orderResponse = await ApiService.createOrder(
  userPhone: userPhone,
  items: items,
  totalAmount: provider.cartTotal,
  paymentMethod: paymentMethod,
  deliveryAddress: {
    'street': storeDetails['street'] ?? '',
    'city': storeDetails['city'] ?? '',
    'state': storeDetails['state'] ?? '',
    'pincode': storeDetails['pincode'] ?? '',
    'landmark': storeDetails['landmark'] ?? '',
  },
);
```

### 4. Handle Response
```dart
// Backend returns: {success: true, orders: [...], total_orders: 2}
final ordersCreated = orderResponse['orders'] as List? ?? [];

// Clear cart
provider.clearCart();

// Navigate to success screen
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => OrderSuccessScreen(
      totalAmount: provider.cartTotal,
      ordersCount: ordersCreated.length,
      orders: ordersCreated,
    ),
  ),
);
```

## Image Handling

### Image URL Helper
```dart
static String getImageUrl(String? path) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/200?text=No+Image';
  }
  
  // Cloudinary URLs are absolute
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  
  // Relative paths from backend
  if (path.startsWith('/static/')) {
    return '$BASE_URL$path';
  }
  
  return path;
}
```

### Display with Fallback
```dart
Image.network(
  product.imageUrl,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.image_not_supported, size: 50);
  },
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
)
```

## Responsive Design

### Screen Breakpoints
```dart
final screenWidth = MediaQuery.of(context).size.width;

// Mobile
if (screenWidth < 600) {
  return MobileLayout();
}
// Tablet
else if (screenWidth < 900) {
  return TabletLayout();
}
// Desktop
else {
  return DesktopLayout();
}
```

### Grid Layouts
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2),
    childAspectRatio: 0.7,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  ),
  itemBuilder: (context, index) => ProductCard(product: products[index]),
)
```

## Local Development

### Run in Chrome
```powershell
cd flutter_preview
flutter run -d chrome
```

### Hot Reload
- Press `r` in terminal for hot reload
- Press `R` for full restart

### Debug Console
```dart
print('🔍 Debug: $variable');
debugPrint('Long text...');
```

## Common Issues & Solutions

### Issue: Images not loading
**Cause**: Wrong URL format or CORS
**Fix**: Use `getImageUrl()` helper, ensure backend sends absolute URLs

### Issue: Tamil text showing boxes
**Cause**: Missing Tamil font
**Fix**: Add Google Fonts to `pubspec.yaml`:
```yaml
dependencies:
  google_fonts: ^6.1.0
```

### Issue: Cart state lost on refresh
**Cause**: Web doesn't persist state
**Fix**: Implement SharedPreferences or localStorage

### Issue: FCM token not saved
**Cause**: Token refresh not called after login
**Fix**: Call `FCMService.refreshToken(phone)` in `PhoneAuthScreen` after successful login

## Testing

### Manual Testing Checklist
- [ ] Browse products in each section
- [ ] Add items to cart (mixed quantities)
- [ ] Update cart quantities
- [ ] Remove items from cart
- [ ] Switch language (English ↔ Tamil)
- [ ] Place order with COD
- [ ] Place order with UPI
- [ ] Receive FCM notification
- [ ] Tap notification → navigate to order
- [ ] Test on mobile (Chrome DevTools responsive mode)

### Test Order Payload
```dart
print('📦 Order items: ${json.encode(items)}');
print('📍 Delivery address: ${json.encode(deliveryAddress)}');
```

## Critical Anti-Patterns to Avoid

### ❌ Wrong Field Name
```dart
// DON'T: Backend expects product_name (snake_case)
'productName': item.productName  // WRONG!
```

### ✅ Correct Field Name
```dart
// DO: Use snake_case for backend compatibility
'product_name': item.productName  // CORRECT
```

### ❌ Missing Error Handling
```dart
// DON'T: No try-catch
final data = await ApiService.fetchProducts();
```

### ✅ Proper Error Handling
```dart
// DO: Handle errors gracefully
try {
  final data = await ApiService.fetchProducts();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to load products: $e')),
  );
}
```

## Performance Tips

1. **Cache API responses** (already implemented in `api_service.dart`)
2. **Lazy load images** with `CachedNetworkImage`
3. **Use const constructors** where possible
4. **Limit cart operations** (debounce quantity updates)
5. **Profile with DevTools** to find bottlenecks

## Quick Reference

**Add to cart**: `provider.addToCart(cartItem)`  
**Cart total**: `provider.cartTotal`  
**Translation**: `provider.text('key')`  
**API base**: `$API_BASE = https://al-mathina.onrender.com/api/flutter`  
**Item field**: Use `product_name` (snake_case) for backend  
**Store name**: From `storeDetails['store_name']`

## Related Files
- Backend API docs: `Backend/.github/copilot-instructions.md`
- Main project guide: `.github/copilot-instructions.md`
