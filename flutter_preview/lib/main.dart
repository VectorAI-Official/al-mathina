import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/account_switcher_page.dart';
import 'services/shared_prefs_service.dart';
import 'services/fcm_service.dart';
import 'models/saved_account.dart';
import 'widgets/voice_search_dialog.dart';

const Color kPrimaryColor = Color(0xFF66BB6A); // Colors.green[400]
const String kAppName = 'AL-Madhina';

// Global key for MainScreen to access its state from anywhere
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

const List<String> mockPaymentApps = ['Google Pay', 'PhonePe', 'Paytm'];

const Map<String, Map<String, String>> translations = {
  'en': {
    // Bottom Navigation
    'home': 'Home',
    'cart': 'Cart',
    'favorites': 'Favorites',
    'profile': 'Profile',
    
    // Search & Common
    'search': 'Search Products...',
    'banner_image': 'Banner Image',
    'best_seller': 'Most Bought',
    'loading': 'Loading...',
    'retry': 'Retry',
    'error': 'Error',
    
    // Cart
    'total': 'Total',
    'empty_cart': 'Your cart is empty!',
    'empty_cart_message': 'You will get a response within\na few minutes.',
    'start_shopping': 'Start shopping',
    'clear_cart': 'Clear Cart',
    'clear_cart_confirm': 'Are you sure you want to clear all items?',
    'cancel': 'Cancel',
    'clear': 'Clear',
    'remove': 'Remove',
    'undo': 'UNDO',
    'removed_from_cart': 'removed from cart',
    
    // Product & Cart Actions
    'add_to_cart': 'Add to cart',
    'buy': 'Buy',
    'add': 'Add',
    'out_of_stock': 'Out of stock',
    'in_stock': 'In Stock',
    'stock': 'Stock',
    'added': 'added to cart!',
    'added_to_cart': 'Added to cart!',
    
    // Phone Authentication
    'al_mathina': 'Al-Mathina',
    'traders': 'Agencies',
    'welcome_back': 'Welcome Back',
    'phone_number': 'Phone Number',
    'enter_the_number': 'Enter the Number',
    'change_phone_number': 'Change Phone Number',
    'invalid_phone_number': 'Invalid phone number',
    'please_enter_10_digit': 'Please enter the 10 digit number',
    'verification_failed': 'Verification failed',
    'connection_error': 'Connection error. Please try again.',
    
    // Payment & Checkout
    'payment_upi': 'Pay via UPI/Apps',
    'cod': 'Cash on Delivery',
    'select_payment': 'Select Payment',
    'order_success': 'Order Placed via',
    'order_success_title': 'Order Success',
    'order_success_message': 'Your order was\nsuccessfull !',
    'order_success_subtitle': 'You will get a response within\na few minutes.',
    'order_placed_button': 'Order Placed',
    'proceed': 'Proceed to Checkout',
    'available_apps': 'Available Apps:',
    'order_summary': 'Order Summary',
    'place_order': 'Place Order',
    
    // Favorites
    'my_favorites': 'My Favorites',
    'no_favorites': 'No Favorites Yet!',
    'no_favorites_message': 'Start adding products to your favorites\nby tapping the heart icon',
    'browse_products': 'Browse Products',
    
    // Profile
    'my_profile': 'My Profile',
    'personal_info': 'Personal Information',
    'name': 'Name',
    'phone': 'Phone',
    'email': 'Email',
    'store_details': 'Store Details',
    'store_name': 'Store Name',
    'street': 'Street',
    'city': 'City',
    'state': 'State',
    'pincode': 'Pincode',
    'landmark': 'Landmark',
    'edit': 'Edit',
    'save': 'Save',
    'incomplete_profile': 'Please complete your profile',
    'name_required': 'Please fill out your name',
    'store_required': 'Please fill out your store details',
    'both_required': 'Please fill out your name and store details',
    'complete_profile_first': 'Please complete your profile before checking out',
    'complete_name_first': 'Please add your name before checking out',
    'complete_store_first': 'Please fill in your store details before checking out',
    'logout': 'Logout',
    'logout_confirm': 'Are you sure you want to logout?',
    'please_fill_name': 'Please fill in your name',
    'please_fill_store': 'Please fill in your store details',
    'manage_store': 'Manage your store information',
    'language': 'Language',
    'help_support': 'Help & Support',
    'help_subtitle': 'FAQs, Contact us',
    'contact': 'Contact',
    'about': 'About',
    'about_subtitle': 'App version & information',
    'guest_user': 'Guest User',
    'my_orders': 'My Orders',
    'order_history': 'View your order history',
    'edit_profile': 'Edit Profile',
    'profile_updated': 'Profile updated successfully',
    'select_language': 'Select Language',
    
    // Product Details
    'description': 'Description',
    'price': 'Price',
    'weight': 'Weight',
    
    // Search Results
    'search_results': 'Search Results',
    'no_results': 'No products found',
    'no_results_for': 'No results found for',
    
    // Errors & Messages
    'error_loading': 'Error loading data',
    'no_categories': 'No categories found',
    'no_subcategories': 'No subcategories found',
    'no_products': 'No products found',
    'user_not_logged_in': 'User not logged in',
    'please_login': 'Please login to view your profile',
    'login_now': 'Login Now',
    
    // Shop by Category
    'shop': 'Shop by Category',
    'app_name': 'AL-Madhina',
    'view_cart': 'View Cart',
    
    // Store Details Form
    'store_details_subtitle': 'Fill in your store details below',
    'store_name_hint': 'Enter store name',
    'store_name_required': 'Store name is required',
    'street_address': 'Street Address',
    'street_hint': 'Enter street address',
    'street_required': 'Street address is required',
    'city_hint': 'Enter city',
    'city_required': 'City is required',
    'state_hint': 'Enter state',
    'state_required': 'State is required',
    'pincode_hint': 'Enter pincode',
    'pincode_required': 'Pincode is required',
    'landmark_hint': 'Enter landmark (optional)',
    'store_saved': 'Store details saved successfully',
    'error_saving': 'Error saving',
    
    // Orders
    'view_order': 'View Order',
    'cancel_order': 'Cancel Order',
    'cancel_order_confirm': 'Are you sure you want to cancel this order?',
    'order_cancelled': 'Order cancelled successfully',
    'order_details': 'Order Details',
    'order_id': 'Order ID',
    'order_date': 'Order Date',
    'order_status': 'Order Status',
    'payment_method': 'Payment Method',
    'delivery_address': 'Delivery Address',
    'items': 'Items',
    'item': 'item',
    'subtotal': 'Subtotal',
    'delivery_fee': 'Delivery Fee',
    'free': 'Free',
    'status_pending': 'Pending',
    'status_confirmed': 'Confirmed',
    'status_delivered': 'Delivered',
    'status_cancelled': 'Cancelled',
    'placed_on': 'Placed on',
    'quantity': 'Quantity',
    'qty': 'Qty',
    'no_orders': 'No Orders Yet!',
    'no_orders_message': 'You haven\'t placed any orders yet.\nStart shopping to see your orders here.',
    'checkout': 'Checkout',
  },
  'ta': {
    // Bottom Navigation
    'home': 'முகப்பு',
    'cart': 'வண்டி',
    'favorites': 'விருப்பங்கள்',
    'profile': 'சுயவிவரம்',
    
    // Search & Common
    'search': 'பொருட்களை தேடுக...',
    'banner_image': 'பேனர் படம்',
    'best_seller': 'அதிகம் வாங்கியது',
    'loading': 'ஏற்றுகிறது...',
    'retry': 'மீண்டும் முயற்சிக்கவும்',
    'error': 'பிழை',
    
    // Phone Authentication
    'al_mathina': 'அல்-மதீனா',
    'traders': 'ஏஜென்சிகள்',
    'welcome_back': 'மீண்டும் வருக',
    'phone_number': 'தொலைபேசி எண்',
    'enter_the_number': 'எண்ணை உள்ளிடவும்',
    'change_phone_number': 'தொலைபேசி எண்ணை மாற்று',
    'invalid_phone_number': 'தவறான தொலைபேசி எண்',
    'please_enter_10_digit': 'தயவுசெய்து 10 இலக்க எண்ணை உள்ளிடவும்',
    'verification_failed': 'சரிபார்ப்பு தோல்வியடைந்தது',
    'connection_error': 'இணைப்பு பிழை. மீண்டும் முயற்சிக்கவும்.',
    
    // Cart
    'total': 'தொகை:',
    'empty_cart': 'உங்கள் வண்டி காலியாக உள்ளது!',
    'empty_cart_message': 'சில நிமிடங்களில் பதிலைப்\nபெறுவீர்கள்.',
    'start_shopping': 'ஷாப்பிங் தொடங்குங்கள்',
    'clear_cart': 'வண்டியை காலி செய்',
    'clear_cart_confirm': 'அனைத்து பொருட்களையும் அகற்ற விரும்புகிறீர்களா?',
    'cancel': 'ரத்து செய்',
    'clear': 'காலி செய்',
    'remove': 'அகற்று',
    'undo': 'செயல்தவிர்',
    'removed_from_cart': 'வண்டியிலிருந்து அகற்றப்பட்டது',
    
    // Product & Cart Actions
    'add_to_cart': 'வாங்கு',
    'buy': 'வாங்கு',
    'add': 'சேர்க்கவும்',
    'out_of_stock': 'கையிருப்பில் இல்லை',
    'in_stock': 'கையிருப்பில் உள்ளது',
    'stock': 'கையிருப்பு',
    'added': 'வண்டியில் சேர்க்கப்பட்டது!',
    'added_to_cart': 'வண்டியில் சேர்க்கப்பட்டது!',
    
    // Payment & Checkout
    'payment_upi': 'யுபிஐ மூலம் பணம் செலுத்துங்கள்',
    'cod': 'பணம் செலுத்தி டெலிவரி',
    'select_payment': 'பணம் செலுத்தும் முறை',
    'order_success': 'ஆர்டர் வெற்றிகரமாக',
    'proceed': 'செக்அவுட்டுக்கு தொடரவும்',
    'available_apps': 'கிடைக்கும் பயன்பாடுகள்:',
    'order_summary': 'ஆர்டர் சுருக்கம்',
    'place_order': 'ஆர்டர் செய்',
    'order_success_title': 'ஆர்டர் வெற்றிகரமாக',
    'order_success_message': 'உங்கள் ஆர்டர் வெற்றிகரமாக\nசரிசெய்யப்பட்டது!',
    'order_success_subtitle': 'சில நிமிடங்களில் பதிலைப்\nபெறுவீர்கள்.',
    'order_placed_button': 'ஆர்டர் செய்யப்பட்டது',
    
    // Favorites
    'my_favorites': 'எனது விருப்பங்கள்',
    'no_favorites': 'இன்னும் விருப்பங்கள் இல்லை!',
    'no_favorites_message': 'இதய ஐகானைத் தட்டுவதன் மூலம்\nவிருப்பங்களைச் சேர்க்கத் தொடங்குங்கள்',
    'browse_products': 'தயாரிப்புகளை உலாவவும்',
    
    // Profile
    'my_profile': 'எனது சுயவிவரம்',
    'personal_info': 'தனிப்பட்ட தகவல்',
    'name': 'பெயர்',
    'phone': 'தொலைபேசி',
    'email': 'மின்னஞ்சல்',
    'store_details': 'கடை விவரங்கள்',
    'store_name': 'கடை பெயர்',
    'street': 'தெரு',
    'city': 'நகரம்',
    'state': 'மாநிலம்',
    'pincode': 'பின்கோடு',
    'landmark': 'குறிப்பிடத்தக்க இடம்',
    'edit': 'திருத்து',
    'save': 'சேமி',
    'incomplete_profile': 'உங்கள் சுயவிவரத்தை முடிக்கவும்',
    'name_required': 'உங்கள் பெயரை நிரப்பவும்',
    'store_required': 'கடை விவரங்களை நிரப்பவும்',
    'both_required': 'உங்கள் பெயர் மற்றும் கடை விவரங்களை நிரப்பவும்',
    'logout': 'வெளியேறு',
    'logout_confirm': 'நிச்சயமாக வெளியேற விரும்புகிறீர்களா?',
    'please_fill_name': 'உங்கள் பெயரை நிரப்பவும்',
    'please_fill_store': 'கடை விவரங்களை நிரப்பவும்',
    'manage_store': 'உங்கள் கடை தகவலை நிர்வகிக்கவும்',
    'language': 'மொழி',
    'help_support': 'உதவி & ஆதரவு',
    'help_subtitle': 'கேள்விகள், எங்களை தொடர்பு கொள்ளுங்கள்',
    'contact': 'தொடர்பு',
    'about': 'பற்றி',
    'about_subtitle': 'பயன்பாட்டு பதிப்பு & தகவல்',
    'guest_user': 'விருந்தினர் பயனர்',
    'my_orders': 'எனது ஆர்டர்கள்',
    'order_history': 'உங்கள் ஆர்டர் வரலாற்றைப் பார்க்கவும்',
    'edit_profile': 'சுயவிவரத்தைத் திருத்து',
    'profile_updated': 'சுயவிவரம் வெற்றிகரமாக புதுப்பிக்கப்பட்டது',
    'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
    
    // Product Details
    'description': 'விளக்கம்',
    'price': 'விலை',
    'weight': 'எடை',
    
    // Search Results
    'search_results': 'தேடல் முடிவுகள்',
    'no_results': 'தயாரிப்புகள் எதுவும் கிடைக்கவில்லை',
    'no_results_for': 'முடிவுகள் எதுவும் கிடைக்கவில்லை',
    
    // Errors & Messages
    'error_loading': 'தரவு ஏற்றுவதில் பிழை',
    'no_categories': 'வகைகள் எதுவும் கிடைக்கவில்லை',
    'no_subcategories': 'துணை வகைகள் எதுவும் கிடைக்கவில்லை',
    'no_products': 'தயாரிப்புகள் எதுவும் கிடைக்கவில்லை',
    'user_not_logged_in': 'பயனர் உள்நுழையவில்லை',
    'please_login': 'உங்கள் சுயவிவரத்தைப் பார்க்க உள்நுழையவும்',
    'login_now': 'இப்போது உள்நுழையவும்',
    
    // Shop by Category
    'shop': 'வகை மூலம் வாங்கவும்',
    'app_name': 'அல்-மதீனா',
    'view_cart': 'வண்டி',
    
    // Store Details Form
    'store_details_subtitle': 'கீழே உங்கள் கடை விவரங்களை நிரப்பவும்',
    'store_name_hint': 'கடை பெயரை உள்ளிடவும்',
    'store_name_required': 'கடை பெயர் தேவை',
    'street_address': 'தெரு முகவரி',
    'street_hint': 'தெரு முகவரியை உள்ளிடவும்',
    'street_required': 'தெரு முகவரி தேவை',
    'city_hint': 'நகரத்தை உள்ளிடவும்',
    'city_required': 'நகரம் தேவை',
    'state_hint': 'மாநிலத்தை உள்ளிடவும்',
    'state_required': 'மாநிலம் தேவை',
    'pincode_hint': 'பின்கோடு உள்ளிடவும்',
    'pincode_required': 'பின்கோடு தேவை',
    'landmark_hint': 'குறிப்பிடத்தக்க இடத்தை உள்ளிடவும் (விருப்பம்)',
    'store_saved': 'கடை விவரங்கள் வெற்றிகரமாக சேமிக்கப்பட்டது',
    'error_saving': 'சேமிப்பதில் பிழை',
    
    // Orders
    'view_order': 'ஆர்டரைப் பார்க்கவும்',
    'cancel_order': 'ஆர்டரை ரத்து செய்',
    'cancel_order_confirm': 'இந்த ஆர்டரை ரத்து செய்ய விரும்புகிறீர்களா?',
    'order_cancelled': 'ஆர்டர் வெற்றிகரமாக ரத்து செய்யப்பட்டது',
    'order_details': 'ஆர்டர் விவரங்கள்',
    'order_id': 'ஆர்டர் ஐடி',
    'order_date': 'ஆர்டர் தேதி',
    'order_status': 'ஆர்டர் நிலை',
    'payment_method': 'பணம் செலுத்தும் முறை',
    'delivery_address': 'டெலிவரி முகவரி',
    'items': 'பொருட்கள்',
    'item': 'பொருள்',
    'subtotal': 'துணை மொத்தம்',
    'delivery_fee': 'டெலிவரி கட்டணம்',
    'free': 'இலவசம்',
    'status_pending': 'நிலுவையில்',
    'status_confirmed': 'உறுதிப்படுத்தப்பட்டது',
    'status_delivered': 'டெலிவரி செய்யப்பட்டது',
    'status_cancelled': 'ரத்து செய்யப்பட்டது',
    'placed_on': 'ஆர்டர் செய்த தேதி',
    'quantity': 'அளவு',
    'qty': 'அளவு',
    'no_orders': 'இன்னும் ஆர்டர்கள் இல்லை!',
    'no_orders_message': 'நீங்கள் இன்னும் எந்த ஆர்டரும் செய்யவில்லை.\nஉங்கள் ஆர்டர்களை இங்கே பார்க்க ஷாப்பிங் தொடங்குங்கள்.',
    'checkout': 'செக்அவுட்',
    
    // Profile Completeness
    'complete_profile_first': 'தொடர உங்கள் சுயவிவரத்தை முடிக்கவும்',
    'complete_name_first': 'தொடர உங்கள் பெயரை சேர்க்கவும்',
    'complete_store_first': 'தொடர கடை விவரங்களை சேர்க்கவும்',
  }
};

// Helper function to build cached network image with loading and error states
Widget buildCachedImage(String imageUrl, {BoxFit fit = BoxFit.cover, Widget? placeholder, Widget? errorWidget}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    placeholder: (context, url) => placeholder ?? Container(
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: kPrimaryColor,
        ),
      ),
    ),
    errorWidget: (context, url, error) => errorWidget ?? Container(
      color: Colors.grey[200],
      child: Icon(Icons.image, color: Colors.grey[400]),
    ),
  );
}

class CartItem {
  final String itemId;
  final String? section;
  final String? mainCategory;
  final String? subcategory;
  final String productName;
  final String? productNameTa;
  final String weight;
  int quantity;
  final double price;
  final String imageUrl;

  CartItem({
    required this.itemId,
    this.section,
    this.mainCategory,
    this.subcategory,
    required this.productName,
    this.productNameTa,
    required this.weight,
    this.quantity = 1,
    required this.price,
    required this.imageUrl,
  });

  double get subtotal => quantity * price;
  
  String getLocalizedName(String language) {
    if (language == 'ta' && productNameTa != null && productNameTa!.isNotEmpty) {
      return productNameTa!;
    }
    return productName;
  }
}

class AppProvider with ChangeNotifier {
  String _currentLanguage = 'en';
  final Map<String, CartItem> _cart = {};
  final Set<String> _favorites = {}; // Store item_ids of favorited products

  String get currentLanguage => _currentLanguage;
  List<CartItem> get cartItems => _cart.values.toList();
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);
  Set<String> get favorites => _favorites;

  String text(String key) => translations[_currentLanguage]![key] ?? key;

  // Load saved language preference from SharedPreferences
  Future<void> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('userLanguage');
      if (savedLanguage != null && translations.containsKey(savedLanguage)) {
        _currentLanguage = savedLanguage;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading language preference: $e');
    }
  }

  void setLanguage(String lang) {
    if (translations.containsKey(lang)) {
      _currentLanguage = lang;
      // Save language preference to SharedPreferences
      _saveLanguage(lang);
      notifyListeners();
    }
  }

  // Save language preference to SharedPreferences
  Future<void> _saveLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userLanguage', lang);
    } catch (e) {
      print('Error saving language preference: $e');
    }
  }

  // Favorites methods
  void setFavorites(Set<String> favoriteIds) {
    _favorites.clear();
    _favorites.addAll(favoriteIds);
    notifyListeners();
  }

  bool isFavorite(String itemId) {
    return _favorites.contains(itemId);
  }

  Future<void> toggleFavorite(String phone, String itemId) async {
    try {
      if (_favorites.contains(itemId)) {
        // Remove from favorites
        await ApiService.removeFavorite(phone, itemId);
        _favorites.remove(itemId);
      } else {
        // Add to favorites
        await ApiService.addFavorite(phone, itemId);
        _favorites.add(itemId);
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling favorite: $e');
      // Optionally show error to user
    }
  }

  Future<void> loadFavorites(String phone) async {
    try {
      final favoriteProducts = await ApiService.getFavorites(phone);
      _favorites.clear();
      for (var product in favoriteProducts) {
        if (product.itemId != null) {
          _favorites.add(product.itemId!);
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  void addToCart(Product product) {
    // Generate a unique ID if itemId is null
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    
    if (_cart.containsKey(productId)) {
      _cart[productId]!.quantity++;
    } else {
      _cart[productId] = CartItem(
        itemId: productId,
        section: product.section,
        mainCategory: product.mainCategory,
        subcategory: product.subcategory,
        productName: product.productName,
        productNameTa: product.productNameTa,
        weight: product.weight,
        price: product.price,
        imageUrl: product.imageUrl,
      );
    }
    notifyListeners();
  }

  void updateCartQuantity(CartItem item, int newQuantity) {
    if (newQuantity <= 0) {
      _cart.remove(item.itemId);
    } else {
      _cart[item.itemId]!.quantity = newQuantity;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
}

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background notification: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Cloud Messaging
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FCMService().initialize();

  // Create AppProvider and load saved language preference
  final appProvider = AppProvider();
  await appProvider.loadLanguage();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => appProvider,
      child: const MyApp(),
    ),
  );
}

// Global navigator key for showing snackbars from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up FCM foreground message handler
    FCMService().onMessageReceived = (RemoteMessage message) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.notification?.title ?? 'Al-Mathina',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message.notification?.body ?? ''),
              ],
            ),
            backgroundColor: const Color.fromARGB(255, 40, 167, 69),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };
    
    // Set up notification tap handler
    FCMService().onNotificationTap = (String orderId, String userPhone) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        print('🎯 FCM: Navigating to OrderDetailsScreen with orderId: $orderId');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              userPhone: userPhone,
              orderId: orderId,
            ),
          ),
        );
      } else {
        print('❌ FCM: No navigator context available');
      }
    };
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '$kAppName Wholesale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        // Set homepage/background to #EBEBEB as requested
        scaffoldBackgroundColor: const Color(0xFFFCFFFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kPrimaryColor,
          elevation: 0.5,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final splashStartTime = DateTime.now();
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║              SPLASH SCREEN STARTED                        ║');
    print('║              Backend: $API_BASE');
    print('╚═══════════════════════════════════════════════════════════╝');
    
    // Start the 2-second splash timer
    final splashTimer = Future.delayed(const Duration(seconds: 2));
    
    // Get user info and preload data in parallel with splash display
    final prefsStartTime = DateTime.now();
    print('\n📋 [SPLASH] Loading preferences...');
    final prefs = await SharedPreferences.getInstance();
    final isOldUser = prefs.getBool('isOldUser') ?? false;
    final userPhone = prefs.getString('userPhone');
    final prefsDuration = DateTime.now().difference(prefsStartTime);
    
    print('   ✅ Preferences loaded in ${prefsDuration.inMilliseconds}ms');
    print('   isOldUser: $isOldUser');
    print('   userPhone: ${userPhone ?? "NOT SET"}');
    
    // Get current language for preloading
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.currentLanguage;
    print('   Language: $lang');
    
    // Start preloading data (non-blocking - runs in background)
    final preloadStartTime = DateTime.now();
    print('\n🎯 [SPLASH] Initiating background preload...');
    ApiService.preloadAppData(userPhone: userPhone, lang: lang);
    final preloadInitDuration = DateTime.now().difference(preloadStartTime);
    print('   ✅ Preload initiated in ${preloadInitDuration.inMilliseconds}ms (continues in background)');
    
    // Wait for splash timer to finish
    print('\n⏱️  [SPLASH] Waiting for 2-second timer...');
    await splashTimer;
    final splashDuration = DateTime.now().difference(splashStartTime);
    
    print('\n🚀 [SPLASH] Timer complete - navigating to ${isOldUser ? "Main Screen" : "Login Screen"}');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║  SPLASH SCREEN COMPLETED IN ${splashDuration.inMilliseconds}ms');
    print('╚═══════════════════════════════════════════════════════════╝\n');
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isOldUser ? MainScreen(key: mainScreenKey) : const PhoneAuthScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              kAppName,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: kPrimaryColor),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int currentIndex = 0;
  bool _isProfileIncomplete = true;
  bool _isNavBarVisible = true;
  bool _showScrollToTop = false;
  
  // GlobalKey to access FavoritesScreen state
  final GlobalKey<_FavoritesScreenState> _favoritesKey = GlobalKey<_FavoritesScreenState>();
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
  
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1), // Slide down
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize screens with the keys
    _screens = [
      HomeScreen(
        key: _homeKey,
        onScrollChange: _handleScroll,
      ),
      FavoritesScreen(
        key: _favoritesKey,
        onScrollChange: _handleFavoritesScroll,
      ),
      const ProfileScreen(),
      const CartScreen(),
    ];
    WidgetsBinding.instance.addObserver(this);
    _checkProfileCompleteness();
    _loadUserFavorites();
  }
  
  void _handleScroll(bool isScrollingUp, bool isAtTop, double scrollPercentage) {
    if (currentIndex != 0) return; // Only apply to home screen
    
    // Show scroll-to-top button if scrolled more than 20%
    if (scrollPercentage > 0.20 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (scrollPercentage <= 0.20 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
    
    if (isAtTop) {
      // Always show navbar when at top
      if (!_isNavBarVisible) {
        setState(() => _isNavBarVisible = true);
        _animationController.reverse();
      }
    } else if (isScrollingUp && _isNavBarVisible) {
      // Hide navbar when scrolling up
      setState(() => _isNavBarVisible = false);
      _animationController.forward();
    } else if (!isScrollingUp && !_isNavBarVisible) {
      // Show navbar when scrolling down
      setState(() => _isNavBarVisible = true);
      _animationController.reverse();
    }
  }

  void _handleFavoritesScroll(bool showNavBar) {
    if (currentIndex != 1) return; // Only apply to favorites screen
    
    if (showNavBar && !_isNavBarVisible) {
      setState(() => _isNavBarVisible = true);
      _animationController.reverse();
    } else if (!showNavBar && _isNavBarVisible) {
      setState(() => _isNavBarVisible = false);
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear expired cache entries when app resumes
      ApiService.clearExpiredCache();
      
      _checkProfileCompleteness();
      _loadUserFavorites();
      
      // Refresh the current screen when app resumes
      _refreshCurrentScreen();
    }
  }
  
  void _refreshCurrentScreen() {
    // Refresh based on current tab
    switch (currentIndex) {
      case 0: // Home
        _homeKey.currentState?._loadHomeData();
        break;
      case 1: // Favorites
        _favoritesKey.currentState?.setState(() {});
        break;
      case 3: // Cart
        // Cart screen already has auto-refresh on didChangeDependencies
        break;
    }
  }

  Future<void> _loadUserFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      
      if (phone != null && phone.isNotEmpty && mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        await provider.loadFavorites(phone);
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _checkProfileCompleteness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      
      if (phone == null || phone.isEmpty) {
        setState(() => _isProfileIncomplete = true);
        return;
      }

      bool nameIncomplete = true;
      bool storeIncomplete = true;

      // Check name completeness by fetching profile from API
      try {
        final profileResponse = await ApiService.getUserProfile(phone);
        final userProfile = profileResponse['user'] as Map<String, dynamic>?;
        if (userProfile != null) {
          final name = userProfile['name'];
          nameIncomplete = (name == null || name.toString().trim().isEmpty);
        }
      } catch (e) {
        nameIncomplete = true;
      }

      // Check store details completeness
      try {
        final storeDetails = await ApiService.getStoreDetails(phone);
        
        if (storeDetails.isEmpty) {
          storeIncomplete = true;
        } else {
          // Save store name to SharedPreferences for account switcher
          final storeName = storeDetails['store_name']?.toString();
          if (storeName != null && storeName.trim().isNotEmpty) {
            await prefs.setString('userStoreName', storeName);
            print('💾 Saved store name to SharedPreferences: $storeName');
            
            // CRITICAL: Also update the saved_accounts array!
            print('');
            print('🔵🔵🔵 UPDATING saved_accounts WITH STORE NAME 🔵🔵🔵');
            final uid = 'user_${phone.replaceAll('+', '')}';
            final account = SavedAccount(
              uid: uid,
              phoneNumber: phone,
              storeName: storeName,
            );
            print('🔵 Created SavedAccount: ${account.toJson()}');
            print('🔵 Calling SharedPrefsService.saveAccount()...');
            await SharedPrefsService.saveAccount(account);
            print('🔵 SharedPrefsService.saveAccount() completed!');
            print('🔵🔵🔵 UPDATE COMPLETE 🔵🔵🔵');
            print('');
          }
          
          storeIncomplete = (
            storeDetails['store_name'] == null || storeDetails['store_name'].toString().trim().isEmpty ||
            storeDetails['street'] == null || storeDetails['street'].toString().trim().isEmpty ||
            storeDetails['city'] == null || storeDetails['city'].toString().trim().isEmpty ||
            storeDetails['state'] == null || storeDetails['state'].toString().trim().isEmpty ||
            storeDetails['pincode'] == null || storeDetails['pincode'].toString().trim().isEmpty
          );
        }
      } catch (e) {
        storeIncomplete = true;
      }

      setState(() => _isProfileIncomplete = nameIncomplete || storeIncomplete);
    } catch (e) {
      setState(() => _isProfileIncomplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Use IndexedStack so screens preserve state when switching
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          // Global floating cart (hidden on Cart, Favorites and Profile)
          if (currentIndex != 1 && currentIndex != 2 && currentIndex != 3)
            const FloatingCartButton(bottomPosition: kBottomNavigationBarHeight + 30),
          // Scroll to top button (above navbar)
          if (_showScrollToTop && currentIndex == 0)
            Positioned(
              bottom: 85, // 70px navbar + 15px spacing
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _homeKey.currentState?.scrollToTop();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white, // White background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // Top shadow
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home Icon
              _buildNavItem(
                icon: Icons.home_outlined,
                isSelected: currentIndex == 0,
                onTap: () {
                  setState(() => currentIndex = 0);
                },
              ),
              // Favorites Icon
              _buildNavItem(
                icon: Icons.favorite_border,
                isSelected: currentIndex == 1,
                onTap: () {
                  setState(() => currentIndex = 1);
                  _favoritesKey.currentState?.refreshFavorites();
                  _checkProfileCompleteness();
                },
              ),
              // Profile Icon
              _buildNavItem(
                icon: Icons.person_outline,
                isSelected: currentIndex == 2,
                showBadge: _isProfileIncomplete,
                onTap: () {
                  setState(() => currentIndex = 2);
                  _checkProfileCompleteness();
                },
              ),
              // Cart Icon (Floating)
              GestureDetector(
                onTap: () {
                  setState(() => currentIndex = 3);
                  _checkProfileCompleteness();
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.black : const Color(0xFF9E9E9E),
            ),
            if (showBadge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// HOME SCREEN - Fetches data from backend
class HomeScreen extends StatefulWidget {
  final Function(bool isScrollingUp, bool isAtTop, double scrollPercentage)? onScrollChange;
  
  const HomeScreen({super.key, this.onScrollChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _homeData;
  bool _isLoading = true;
  String? _error;
  String? _lastLanguage; // Track language changes
  
  // Lazy loading state
  bool _bannerLoaded = false;
  int _displayedCategoriesCount = 0;
  final int _categoriesPerBatch = 20;
  
  ScrollController? _scrollController;
  double _lastScrollPosition = 0;
  
  // Search controller for voice search integration
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    
    // Add scroll listener if callback is provided
    if (widget.onScrollChange != null) {
      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when language changes
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_lastLanguage != null && _lastLanguage != provider.currentLanguage) {
      _loadHomeData();
    }
    _lastLanguage = provider.currentLanguage;
  }
  
  void _onScroll() {
    if (_scrollController == null) return;
    
    final currentPosition = _scrollController!.position.pixels;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final isAtTop = currentPosition <= 0;
    final isScrollingUp = currentPosition > _lastScrollPosition;
    
    // Calculate scroll percentage
    final scrollPercentage = maxScroll > 0 ? currentPosition / maxScroll : 0.0;
    
    // Only trigger callback if scroll position changed significantly
    if ((currentPosition - _lastScrollPosition).abs() > 10 || isAtTop) {
      widget.onScrollChange?.call(isScrollingUp, isAtTop, scrollPercentage);
    }
    
    _lastScrollPosition = currentPosition;
  }
  
  void scrollToTop() {
    _scrollController?.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      
      // Step 1: Show banner immediately (it's a local asset, no need to wait)
      setState(() {
        _bannerLoaded = true;
      });
      
      // Step 2: Load data from API
      final data = await ApiService.getHomeData(lang: provider.currentLanguage);
      
      setState(() {
        _homeData = data;
        _isLoading = false;
        // Initialize display count for first section
        _displayedCategoriesCount = _categoriesPerBatch;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      // Keep scaffold background transparent so global theme background (#EBEBEB) shows
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 70, // Increased height for more padding
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0), // Added vertical padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.text('app_name'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor),
              ),
              // Language selector button styled like the image
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                ),
                child: DropdownButton<String>(
                  value: provider.currentLanguage,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
                  underline: Container(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'en',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 6),
                          Text('English', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ta',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 6),
                          Text('தமிழ்', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.language, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 6),
                          Text('English', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.language, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 6),
                          Text('தமிழ்', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                    ];
                  },
                  onChanged: (value) {
                    if (value != null) provider.setLanguage(value);
                  },
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFCFFFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1), // Added slim grey border
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Color(0xFF868889), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: provider.text('search'),
                        hintStyle: const TextStyle(
                          color: Color(0xFF868889),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (query) {
                        if (query.trim().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchResultsScreen(query: query),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  // Voice Search Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Color(0xFF66BB6A),
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => VoiceSearchDialog(
                          currentLanguage: provider.currentLanguage,
                          onSearchQuery: (query) {
                            // Use post frame callback to ensure dialog is closed first
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              // Fill the search text box
                              _searchController.text = query;
                              // Navigate to search results
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchResultsScreen(query: query),
                                ),
                              );
                            });
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: kPrimaryColor, // Green color to match app theme
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            _isLoading
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(), // Enable scroll even when loading
                    padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 90.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner skeleton
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[200],
                        ),
                        child: AspectRatio(
                          aspectRatio: 800 / 400,
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Best Seller section skeleton
                      Container(
                        height: 20,
                        width: 120,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) => _buildSkeletonProductCard(),
                      ),
                      const SizedBox(height: 20),
                      // Regular section skeleton
                      Container(
                        height: 20,
                        width: 100,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: 8,
                        itemBuilder: (context, index) => _buildSkeletonCategoryCard(),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh on error
                      child: Container(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  '${provider.text('error')}: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _loadHomeData(),
                                child: Text(provider.text('retry')),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'or swipe down to refresh',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            // White container with banner - loads immediately
                            if (_bannerLoaded)
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/banner.png',
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image, size: 48, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Banner Image',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Content section with sections hierarchy
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 90.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Most Bought Section
                                  if (_homeData!.bestSellers.mainCategories.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _buildSectionHeader(
                                      provider.text('best_seller'),
                                      _homeData!.bestSellers.icon,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMainCategoryGrid(
                                      _homeData!.bestSellers.mainCategories.take(_displayedCategoriesCount).toList(),
                                      isBestSeller: true,
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // Regular Sections
                                  for (var section in _homeData!.sections) ...[
                                    const SizedBox(height: 12),
                                    _buildSectionHeader(section.title, section.icon),
                                    const SizedBox(height: 12),
                                    _buildMainCategoryGrid(
                                      section.mainCategories.take(_displayedCategoriesCount).toList(),
                                      isBestSeller: false,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          
            // Floating cart button moved to MainScreen
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildMainCategoryGrid(List<MainCategory> categories, {bool isBestSeller = false}) {
    // Use a wider aspect ratio for regular categories so images can appear wider and taller
    final double aspect = isBestSeller ? 0.78 : 0.75; // Reduced to make cards taller
    final int columns = isBestSeller ? 3 : 4; // 4 columns for regular sections, 3 for best seller

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
        childAspectRatio: aspect,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(MainCategory category) {
    // Check if this is a Best Seller category
    final isBestSeller = category.section == "Most Bought";
    
    // For Best Seller section: Main categories should navigate to subcategories
    // These are existing main categories that were starred in the backend
    if (isBestSeller) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubcategoryProductsScreen(
                section: category.section,
                mainCategory: category.mainCategory,
                title: category.name,
              ),
            ),
          );
        },
        // Keep ripple for Most Bought to indicate interactivity
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: category.imageUrl.isNotEmpty
                          ? Image.network(
                              ApiService.getImageUrl(category.imageUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stack) => Container(
                                color: Colors.grey[100],
                                child: Icon(Icons.category, size: 40, color: Colors.grey[400]),
                              ),
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Icon(Icons.category, size: 40, color: Colors.grey[400]),
                            ),
                    ),
                    // Most Bought badge
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFf59e0b), Color(0xFFd97706)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFf59e0b).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '⭐ ${Provider.of<AppProvider>(context, listen: false).text('best_seller')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    // For regular (non-BestSeller) sections: compact, neatly spaced cards with no hover/ripple
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubcategoryProductsScreen(
              section: category.section,
              mainCategory: category.mainCategory,
              title: category.name,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Flexible image area to prevent overflow
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: category.imageUrl.isNotEmpty
                      ? Image.network(
                          ApiService.getImageUrl(category.imageUrl),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stack) => Container(
                            color: Colors.grey[50],
                            child: Icon(Icons.category, size: 36, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          color: Colors.grey[50],
                          child: Icon(Icons.category, size: 36, color: Colors.grey[400]),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Let text size naturally but limit lines to prevent overflow
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Skeleton loading for product cards
  Widget _buildSkeletonProductCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final padding = (cardWidth * 0.05).clamp(4.0, 8.0);
        
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image placeholder with skeleton effect
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Container(
                      width: cardWidth * 0.3,
                      height: cardWidth * 0.3,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              // Content placeholder
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Product name skeleton (2 lines)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: (cardWidth * 0.08).clamp(8.0, 12.0),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          SizedBox(height: padding * 0.5),
                          Container(
                            height: (cardWidth * 0.08).clamp(8.0, 12.0),
                            width: cardWidth * 0.7,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                      // Weight/size skeleton
                      Container(
                        height: (cardWidth * 0.06).clamp(6.0, 9.0),
                        width: cardWidth * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Price skeleton
                      Container(
                        height: (cardWidth * 0.095).clamp(9.0, 13.0),
                        width: cardWidth * 0.5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Skeleton loading for category cards
  Widget _buildSkeletonCategoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// PRODUCT LIST SCREEN - Shows subcategories and products
class ProductListScreen extends StatefulWidget {
  final String section;
  final String mainCategory;

  const ProductListScreen({
    super.key,
    required this.section,
    required this.mainCategory,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Subcategory> _subcategories = [];
  List<Product> _products = [];
  String? _selectedSubcategory;
  bool _isLoadingSubcategories = true;
  bool _isLoadingProducts = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final subcategories = await ApiService.getSubcategories(
        section: widget.section,
        mainCategory: widget.mainCategory,
        lang: provider.currentLanguage,
      );

      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
      });

      // Auto-select first subcategory
      if (subcategories.isNotEmpty) {
        _selectSubcategory(subcategories.first.name);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingSubcategories = false;
      });
    }
  }

  Future<void> _selectSubcategory(String subcategory) async {
    setState(() {
      _selectedSubcategory = subcategory;
      _isLoadingProducts = true;
    });

    try {
      final result = await ApiService.getProductsLegacy(  // ⭐ Use legacy method
        section: widget.section,
        mainCategory: widget.mainCategory,
        subcategory: subcategory,
      );

      setState(() {
        _products = result['products'] as List<Product>;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingProducts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mainCategory,
          style: const TextStyle(color: kPrimaryColor),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Stack(
        children: [
          _isLoadingSubcategories
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : Row(
                      children: [
                        // Left Sidebar - Subcategories (Modern Clean Design)
                        Container(
                      width: MediaQuery.of(context).size.width * 0.25,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Modern header with gradient
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.85)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.category, size: 20, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Categories',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Subcategories list with modern styling
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _subcategories.length,
                              itemBuilder: (context, index) {
                                final subcategory = _subcategories[index];
                                final isSelected = subcategory.name == _selectedSubcategory;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? kPrimaryColor.withOpacity(0.3) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: kPrimaryColor.withOpacity(0.15),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _selectSubcategory(subcategory.name),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                gradient: isSelected
                                                    ? LinearGradient(
                                                        colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
                                                      )
                                                    : LinearGradient(
                                                        colors: [Colors.grey[200]!, Colors.grey[100]!],
                                                      ),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.inventory_2_rounded,
                                                size: 20,
                                                color: isSelected ? Colors.white : Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                subcategory.nameDisplay,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  color: isSelected ? kPrimaryColor : Colors.black87,
                                                  letterSpacing: 0.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: kPrimaryColor.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: kPrimaryColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Side - Products (70%)
                    Expanded(
                      child: Container(
                        color: Colors.grey[50],
                        child: _isLoadingProducts
                            ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                            : _products.isEmpty
                                ? const Center(child: Text('No products found'))
                                : Column(
                                    children: [
                                      // Top bar with sort and brand filter
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                            const SizedBox(width: 16),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.amber[50],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Bestseller',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () {},
                                              icon: const Icon(Icons.sort, size: 16),
                                              label: const Text('Sort', style: TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {},
                                              icon: const Icon(Icons.branding_watermark, size: 16),
                                              label: const Text('Brand', style: TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Products grid (matching Best Seller UI - 3 columns)
                                      Expanded(
                                        child: GridView.builder(
                                          padding: const EdgeInsets.all(12),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 18,
                                            childAspectRatio: 0.65,
                                          ),
                                          itemCount: _products.length,
                                          itemBuilder: (context, index) {
                                            final product = _products[index];
                                            return _buildProductCard(product, provider);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ],
                ),
          
          // Floating cart button moved to MainScreen
          const FloatingCartButton(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Clean white card with full-fit image and centered controls (matching Best Seller UI)
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image (top) - Full fit without cropping sides - Clickable to show details
          Flexible(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                _showProductDetails(product);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Stack(
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: SizedBox.expand(
                        child: product.imageUrl.isNotEmpty
                            ? Image.network(
                                ApiService.getImageUrl(product.imageUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) => Container(
                                  color: Colors.grey[50],
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                color: Colors.grey[50],
                                child: Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
                              ),
                      ),
                    ),
                    // Heart Icon (top right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final phone = prefs.getString('userPhone');
                          if (phone != null && phone.isNotEmpty) {
                            await provider.toggleFavorite(phone, productId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorited ? Icons.favorite : Icons.favorite_border,
                            color: isFavorited ? Colors.red : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content - Flexible to prevent overflow
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      product.getLocalizedName(provider.currentLanguage),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    product.weight,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Price row (removed stock display)
                  Text(
                    '₹${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // Bottom quantity control bar - Centered
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
            ),
          ),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Builder(builder: (context) {
                final existing = provider.cartItems.where((c) => c.productName == product.productName && c.weight == product.weight).toList();
                final CartItem? cartItem = existing.isNotEmpty ? existing.first : null;
                final int qty = cartItem?.quantity ?? 0;

                // Show "Add to cart" button when qty is 0
                if (qty == 0) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: product.inStock
                          ? () {
                              provider.addToCart(product);
                            }
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Add to cart', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }
                // Show quantity controls when qty > 0
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Decrement button - Light green
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC8E6C9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          provider.updateCartQuantity(cartItem!, qty - 1);
                        },
                        icon: const Icon(Icons.remove, size: 14, color: Color(0xFF2E7D32)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    
                    // Quantity input field
                    Container(
                      width: 42,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 7),
                          isDense: true,
                        ),
                        controller: TextEditingController(text: '$qty')..selection = TextSelection.fromPosition(TextPosition(offset: '$qty'.length)),
                        onChanged: (value) {
                          final newQty = int.tryParse(value);
                          if (newQty != null && newQty >= 0) {
                            provider.updateCartQuantity(cartItem!, newQty);
                          }
                        },
                      ),
                    ),

                    // Increment button - Green
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: product.inStock
                            ? () {
                                provider.addToCart(product);
                              }
                            : null,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                );
              }),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ProductDetailsSheet(
          product: product,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// PRODUCT DETAILS SHEET
class ProductDetailsSheet extends StatefulWidget {
  final Product product;
  final ScrollController scrollController;

  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.scrollController,
  });

  @override
  State<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<ProductDetailsSheet> {
  Product? _fetchedProduct;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch fresh product data from backend
      if (widget.product.itemId != null && widget.product.itemId!.isNotEmpty) {
        final fetchedProduct = await ApiService.getProductDetails(widget.product.itemId!);
        setState(() {
          _fetchedProduct = fetchedProduct;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final product = _fetchedProduct ?? widget.product;

    return Container(
      padding: const EdgeInsets.all(20),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : ListView(
              controller: widget.scrollController,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          ApiService.getImageUrl(product.imageUrl),
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            height: 250,
                            color: Colors.grey[200],
                            child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 250,
                          color: Colors.grey[200],
                          child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                        ),
                ),
                const SizedBox(height: 16),

                // Best Seller Badge
                if (product.isBestSeller)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          Provider.of<AppProvider>(context, listen: false).text('best_seller'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Product Name (with Tamil support)
                Text(
                  product.getLocalizedName(provider.currentLanguage),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

          // Weight
          Text(
            product.weight,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),

          // Category Breadcrumb
          if (product.categoryBreadcrumb != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 16, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.categoryBreadcrumb!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Price
          Text(
            '₹${product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),

          // Stock Status
          Row(
            children: [
              Icon(
                product.inStock ? Icons.check_circle : Icons.cancel,
                color: product.inStock ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                product.inStock ? 'In Stock (${product.stock} units)' : 'Out of Stock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: product.inStock ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          if (product.description != null && product.description!.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              product.description!,
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 24),
          ],

          // Add to Cart Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: product.inStock
                  ? () {
                      provider.addToCart(product);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.productName} added to cart!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              child: Text(
                product.inStock ? 'Add to Cart' : 'Out of Stock',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SEARCH RESULTS SCREEN
class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<Product> _results = [];
  bool _isLoading = true;
  String? _error;
  bool _isRegexSearch = false;
  bool _isAdmin = false;  // Track admin status

  @override
  void initState() {
    super.initState();
    _detectRegexPattern();
    _search();
  }
  
  // Detect if the query contains regex special characters
  void _detectRegexPattern() {
    final regexChars = RegExp(r'[\.\*\+\?\^\$\[\]\{\}\(\)\|\\]');
    _isRegexSearch = regexChars.hasMatch(widget.query);
  }

  Future<void> _search() async {
    try {
      print('\n🔍 ========== SEARCH SCREEN ==========');
      // Get user phone for admin check
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('userPhone');
      
      print('🔍 [SEARCH] User phone from prefs: ${userPhone ?? "NULL"}');
      print('🔍 [SEARCH] Query: ${widget.query}');
      print('🔍 [SEARCH] Regex mode: $_isRegexSearch');
      
      final result = await ApiService.searchProducts(
        query: widget.query,
        useRegex: _isRegexSearch,
        userPhone: userPhone,
      );
      
      print('\n🎯 [SEARCH] API Response Received:');
      print('🔍 [SEARCH] isAdmin from API: ${result['isAdmin']}');
      print('🔍 [SEARCH] Results count: ${(result['results'] as List<Product>).length}');
      
      final products = result['results'] as List<Product>;
      if (products.isNotEmpty) {
        print('🔍 [SEARCH] First product name: ${products.first.productName}');
        print('🔍 [SEARCH] First product buyingPrice: ${products.first.buyingPrice}');
        print('🔍 [SEARCH] First product price: ${products.first.price}');
      }
      
      setState(() {
        _results = products;
        _isAdmin = result['isAdmin'] ?? false;
        _isLoading = false;
      });
      
      print('\n✅ [SEARCH] State Updated:');
      print('🔍 [SEARCH] _isAdmin: $_isAdmin');
      print('🔍 [SEARCH] _results count: ${_results.length}');
      if (_results.isNotEmpty) {
        print('🔍 [SEARCH] First result buyingPrice: ${_results.first.buyingPrice}');
      }
      print('🔍 ========== END SEARCH SCREEN ==========\n');
    } catch (e, stackTrace) {
      print('❌ [SEARCH] Error: $e');
      print('❌ [SEARCH] Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${provider.text('search')}: "${widget.query}"', style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _error != null
                  ? Center(child: Text('${provider.text('error')}: $_error'))
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('${provider.text('no_results')} "${widget.query}"'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), // Added bottom padding for floating button
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            return _buildProductCard(product, provider);
                          },
                        ),
          
          // Floating cart button moved to MainScreen
          const FloatingCartButton(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    print('\n🃏 [CARD] Building card for: ${product.productName}');
    print('🃏 [CARD] _isAdmin state: $_isAdmin');
    print('🃏 [CARD] Product buyingPrice: ${product.buyingPrice}');
    print('🃏 [CARD] Product price: ${product.price}');
    
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Horizontal card layout matching Cart page and Favorites style
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(  // ⭐ Allow card to expand based on content
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,  // ⭐ Stretch to fill height
            children: [
              // Product Image (Left) - Fixed size like Cart page
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                  );
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              ApiService.getImageUrl(product.imageUrl),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: Icon(Icons.inventory_2, color: Colors.grey[400]),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: Icon(Icons.inventory_2, color: Colors.grey[400]),
                            ),
                    ),
                    // Heart Icon (top right of image)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final phone = prefs.getString('userPhone');
                          if (phone != null && phone.isNotEmpty) {
                            await provider.toggleFavorite(phone, productId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorited ? Icons.favorite : Icons.favorite_border,
                            color: isFavorited ? Colors.red : Colors.grey[600],
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Product Info (Middle) - Expanded
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.getLocalizedName(provider.currentLanguage),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.weight,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    
                    // ⭐ ADMIN BUYING PRICE & PROFIT (Tamil text)
                    if (_isAdmin) ...[
                      if (product.buyingPrice != null && product.buyingPrice! > 0) ...[
                        const SizedBox(height: 4),
                        // Buying price with icon (Tamil: விலை)
                        Row(
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 11, color: Colors.orange[700]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'விலை: ₹${product.buyingPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Profit with icon (Tamil: இலாபம்)
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 11, color: Colors.green[700]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green[200]!, width: 1),
                                ),
                                child: Text(
                                  'இலாபம்: ₹${(product.price - product.buyingPrice!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Show message for products without buying price
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 10, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                ),
                                child: Text(
                                  'Cost not set',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              // Bottom Control Section (Right) - Add to cart or +/- controls
              Builder(builder: (context) {
                final existing = provider.cartItems.where((c) => c.productName == product.productName && c.weight == product.weight).toList();
                final CartItem? cartItem = existing.isNotEmpty ? existing.first : null;
                final int qty = cartItem?.quantity ?? 0;

                // Show "Add to cart" button when qty is 0
                if (qty == 0) {
                  return SizedBox(
                    width: 90,
                    child: ElevatedButton.icon(
                      onPressed: product.inStock
                          ? () {
                              provider.addToCart(product);
                            }
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                      label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        elevation: 0,
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                }
                // Show quantity controls when qty > 0 (matching Cart page style)
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,  // ⭐ Center vertically
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: kPrimaryColor,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.updateCartQuantity(cartItem!, qty - 1);
                        },
                      ),
                      // Quantity input field
                      Container(
                        width: 42,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: '$qty')..selection = TextSelection.fromPosition(TextPosition(offset: '$qty'.length)),
                          onChanged: (value) {
                            final newQty = int.tryParse(value);
                            if (newQty != null && newQty >= 0) {
                              provider.updateCartQuantity(cartItem!, newQty);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: kPrimaryColor,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: product.inStock
                            ? () {
                                provider.addToCart(product);
                              }
                            : null,
                      ),
                    ],
                  ),
                  Text(
                    '₹${(product.price * qty).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
            ],
          ),
        ),
      ),
    );
  }
}

// CART SCREEN
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  bool _isNameIncomplete = true;
  bool _isStoreIncomplete = true;
  bool _isLoading = true;
  Map<String, Product> _refreshedProducts = {}; // Store fetched products by itemId
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkProfileCompleteness();
    _loadCartProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkProfileCompleteness();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check when dependencies change (e.g., when navigating back to this screen)
    _checkProfileCompleteness();
  }

  Future<void> _loadCartProducts() async {
    setState(() => _isLoadingProducts = true);
    
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final cartItems = provider.cartItems;
      
      Map<String, Product> fetchedProducts = {};
      
      // Fetch fresh product details for each cart item
      for (var cartItem in cartItems) {
        if (cartItem.itemId.isNotEmpty) {
          try {
            final product = await ApiService.getProductDetails(cartItem.itemId);
            fetchedProducts[cartItem.itemId] = product;
          } catch (e) {
            print('Error fetching product ${cartItem.itemId}: $e');
            // Continue with other products even if one fails
          }
        }
      }
      
      setState(() {
        _refreshedProducts = fetchedProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading cart products: $e');
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _checkProfileCompleteness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      
      if (phone == null || phone.isEmpty) {
        setState(() {
          _isNameIncomplete = true;
          _isStoreIncomplete = true;
          _isLoading = false;
        });
        return;
      }

      bool nameIncomplete = true;
      bool storeIncomplete = true;

      // Check name completeness by fetching profile from API
      try {
        final profileResponse = await ApiService.getUserProfile(phone);
        final userProfile = profileResponse['user'] as Map<String, dynamic>?;
        if (userProfile != null) {
          final name = userProfile['name'];
          nameIncomplete = (name == null || name.toString().trim().isEmpty);
        }
      } catch (e) {
        nameIncomplete = true;
      }

      // Check store details completeness
      try {
        final storeDetails = await ApiService.getStoreDetails(phone);
        
        if (storeDetails.isEmpty) {
          storeIncomplete = true;
        } else {
          storeIncomplete = (
            storeDetails['store_name'] == null || storeDetails['store_name'].toString().trim().isEmpty ||
            storeDetails['street'] == null || storeDetails['street'].toString().trim().isEmpty ||
            storeDetails['city'] == null || storeDetails['city'].toString().trim().isEmpty ||
            storeDetails['state'] == null || storeDetails['state'].toString().trim().isEmpty ||
            storeDetails['pincode'] == null || storeDetails['pincode'].toString().trim().isEmpty
          );
        }
      } catch (e) {
        storeIncomplete = true;
      }

      setState(() {
        _isNameIncomplete = nameIncomplete;
        _isStoreIncomplete = storeIncomplete;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isNameIncomplete = true;
        _isStoreIncomplete = true;
        _isLoading = false;
      });
    }
  }

  String _getWarningMessage() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_isNameIncomplete && _isStoreIncomplete) {
      return provider.text('both_required');
    } else if (_isNameIncomplete) {
      return provider.text('name_required');
    } else if (_isStoreIncomplete) {
      return provider.text('store_required');
    }
    return '';
  }

  bool get _isProfileComplete => !_isNameIncomplete && !_isStoreIncomplete;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('cart'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        actions: [
          if (provider.cartCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to clear all items?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.clearCart();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: provider.cartCount == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shopping bag icon
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined, 
                        size: 80, 
                        color: Colors.green[400],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Main message
                    Text(
                      provider.text('empty_cart'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle message
                    Text(
                      provider.text('empty_cart_message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Start shopping button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to home tab
                          final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
                          if (mainScreenState != null) {
                            mainScreenState.setState(() {
                              mainScreenState.currentIndex = 0; // Home tab
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          provider.text('start_shopping'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = provider.cartItems[index];
                      return Dismissible(
                        key: Key('${item.itemId}_${item.weight}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white, size: 32),
                        ),
                        onDismissed: (direction) {
                          final removedItem = item;
                          final removedQuantity = item.quantity;
                          final displayName = _refreshedProducts.containsKey(item.itemId)
                              ? _refreshedProducts[item.itemId]!.getLocalizedName(provider.currentLanguage)
                              : item.getLocalizedName(provider.currentLanguage);
                          
                          provider.updateCartQuantity(item, 0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$displayName removed from cart'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  // Re-add the item with original quantity
                                  provider.addToCart(Product(
                                    itemId: removedItem.itemId,
                                    productName: removedItem.productName,
                                    weight: removedItem.weight,
                                    price: removedItem.price,
                                    imageUrl: removedItem.imageUrl,
                                    stock: 999,
                                    inStock: true,
                                    isBestSeller: false,
                                  ));
                                  // Set the quantity back to what it was
                                  provider.updateCartQuantity(removedItem, removedQuantity);
                                },
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                            children: [
                              // Product Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(
                                        ApiService.getImageUrl(item.imageUrl),
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.inventory_2),
                                        ),
                                      )
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.inventory_2),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _refreshedProducts.containsKey(item.itemId)
                                          ? _refreshedProducts[item.itemId]!.getLocalizedName(provider.currentLanguage)
                                          : item.getLocalizedName(provider.currentLanguage),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      item.weight,
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${item.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity Controls
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: kPrimaryColor,
                                        onPressed: () {
                                          provider.updateCartQuantity(item, item.quantity - 1);
                                        },
                                      ),
                                      // Quantity input field
                                      Container(
                                        width: 50,
                                        height: 32,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!, width: 1),
                                          borderRadius: BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: TextField(
                                          textAlign: TextAlign.center,
                                          textAlignVertical: TextAlignVertical.center,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                                            isDense: true,
                                          ),
                                          controller: TextEditingController(text: '${item.quantity}')..selection = TextSelection.fromPosition(TextPosition(offset: '${item.quantity}'.length)),
                                          onChanged: (value) {
                                            final newQty = int.tryParse(value);
                                            if (newQty != null && newQty >= 0) {
                                              provider.updateCartQuantity(item, newQty);
                                            }
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        color: kPrimaryColor,
                                        onPressed: () {
                                          provider.updateCartQuantity(item, item.quantity + 1);
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      );
                    },
                  ),
                ),
                // Total and Checkout
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  margin: const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 20), // Space for curved navbar
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.text('total'),
                            style: TextStyle(
                              fontSize: provider.currentLanguage == 'ta' ? 16 : 20, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          Text(
                            '₹${provider.cartTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!_isProfileComplete) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getWarningMessage(),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isProfileComplete 
                                ? Colors.green[400]
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProfileComplete
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CheckoutScreen(),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            provider.text('proceed'),
                            style: TextStyle(
                              fontSize: provider.currentLanguage == 'ta' ? 14 : 18, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// CHECKOUT SCREEN
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'upi';
  Map<String, Product> _refreshedProducts = {}; // Store fetched products by itemId
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadCheckoutProducts();
  }

  Future<void> _loadCheckoutProducts() async {
    setState(() => _isLoadingProducts = true);
    
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final cartItems = provider.cartItems;
      
      Map<String, Product> fetchedProducts = {};
      
      // Fetch fresh product details for each cart item
      for (var cartItem in cartItems) {
        if (cartItem.itemId.isNotEmpty) {
          try {
            final product = await ApiService.getProductDetails(cartItem.itemId);
            fetchedProducts[cartItem.itemId] = product;
          } catch (e) {
            print('Error fetching product ${cartItem.itemId}: $e');
            // Continue with other products even if one fails
          }
        }
      }
      
      setState(() {
        _refreshedProducts = fetchedProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading checkout products: $e');
      setState(() => _isLoadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('checkout'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary
                  Text(
                    provider.text('order_summary'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...provider.cartItems.map((item) {
                    final displayName = _refreshedProducts.containsKey(item.itemId)
                        ? _refreshedProducts[item.itemId]!.getLocalizedName(provider.currentLanguage)
                        : item.getLocalizedName(provider.currentLanguage);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$displayName x${item.quantity}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Text(
                            '₹${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(thickness: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.text('total'),
                        style: TextStyle(
                          fontSize: provider.currentLanguage == 'ta' ? 16 : 20, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        '₹${provider.cartTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Payment Method
                  Text(
                    provider.text('select_payment'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: Text(provider.text('payment_upi')),
                    subtitle: Text(provider.text('available_apps') +
                        ' ${mockPaymentApps.join(', ')}'),
                    value: 'upi',
                    groupValue: _selectedPayment,
                    onChanged: (value) => setState(() => _selectedPayment = value!),
                    activeColor: kPrimaryColor,
                  ),
                  RadioListTile<String>(
                    title: Text(provider.text('cod')),
                    value: 'cod',
                    groupValue: _selectedPayment,
                    onChanged: (value) => setState(() => _selectedPayment = value!),
                    activeColor: kPrimaryColor,
                  ),
                ],
              ),
            ),
          ),

          // Place Order Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await _placeOrder(context, provider);
                },
                child: Text(
                  provider.text('place_order'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, AppProvider provider) async {
    try {
      // Get user phone number
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('userPhone') ?? '';
      
      if (userPhone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to place order')),
          );
        }
        return;
      }

      // Fetch user's store details for delivery address
      Map<String, dynamic> storeDetails = {};
      try {
        final storeResponse = await ApiService.getStoreDetails(userPhone);
        // storeResponse is already unwrapped, it returns the inner map directly
        storeDetails = storeResponse is Map<String, dynamic> ? storeResponse : {};
      } catch (e) {
        print('Error fetching store details: $e');
        // Continue with empty store details if fetch fails
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          ),
        );
      }

      // Prepare order items with section, main_category, subcategory, item_id, image_url
      final items = provider.cartItems.map((item) {
        return {
          'item_id': item.itemId,
          'section': item.section ?? '',
          'main_category': item.mainCategory ?? '',
          'subcategory': item.subcategory ?? '',
          'product_name': item.productName,
          'weight': item.weight,
          'quantity': item.quantity,
          'price': item.price,
          'image_url': item.imageUrl, // Store image URL
        };
      }).toList();

      // Debug: Print items to check if all fields are present
      print('Order items being sent: $items');
      print('Store details for delivery: $storeDetails');

      // Create order with real store address
      final paymentMethod = _selectedPayment == 'upi' ? 'UPI' : 'Cash on Delivery';
      
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

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Extract order information from response
      final ordersCreated = orderResponse['orders'] as List? ?? [];
      final totalOrders = orderResponse['total_orders'] ?? ordersCreated.length;

      // Navigate to success screen with order info
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              totalAmount: provider.cartTotal,
              ordersCount: totalOrders,
              orders: ordersCreated,
            ),
          ),
        );
      }

      // Clear cart after successful order
      provider.clearCart();
      
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
      }
    }
  }
}

// ORDER SUCCESS SCREEN
class OrderSuccessScreen extends StatelessWidget {
  final double totalAmount;
  final int ordersCount;
  final List orders;
  
  const OrderSuccessScreen({
    super.key, 
    required this.totalAmount,
    this.ordersCount = 1,
    this.orders = const [],
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(provider.text('order_success_title'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Shopping bag icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green[400]!.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: Colors.green[400],
                ),
              ),
              const SizedBox(height: 40),
              // Success message
              Text(
                provider.text('order_success_message'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              // Orders info
              if (ordersCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Split into $ordersCount orders by section',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                provider.text('order_success_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              // Show order details if available
              if (orders.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, color: Colors.green[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['order_id'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${order['section']} - ${order['items_count']} items',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${order['total_amount'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const Spacer(),
              const Spacer(),
              // Track Order button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    provider.text('order_placed_button'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// CATEGORY / BESTSELLER GRID LISTING SCREEN
class CategoryProductsScreen extends StatefulWidget {
  final String section;
  final String mainCategory;
  final bool isBestSeller;
  final String title;

  const CategoryProductsScreen({
    super.key,
    required this.section,
    required this.mainCategory,
    this.isBestSeller = false,
    required this.title,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      if (widget.isBestSeller) {
        // Best seller functionality removed - Most Bought now uses main categories
        setState(() => _products = []);
      } else {
        final result = await ApiService.getProductsLegacy(  // ⭐ Use legacy method
          section: widget.section,
          mainCategory: widget.mainCategory,
          subcategory: null,
        );
        setState(() => _products = result['products'] as List<Product>);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBestSeller ? '⭐ ${provider.text('best_seller')}' : widget.title,
            style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _products.isEmpty
                  ? const Center(child: Text('No products found'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return _buildProductCard(product, provider);
                      },
                    ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    // Reuse the same product card layout used elsewhere for consistency
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showProductDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        ApiService.getImageUrl(product.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.isBestSeller)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⭐ ${provider.text('best_seller')}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    product.weight,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        product.inStock ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: product.inStock ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.inStock ? 'In Stock' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: product.inStock ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: product.inStock
                          ? () {
                              provider.addToCart(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.productName} added to cart!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
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

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ProductDetailsSheet(
          product: product,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// SUBCATEGORY PRODUCTS SCREEN - Two-panel layout (1/5 left sidebar, 4/5 right products)
class SubcategoryProductsScreen extends StatefulWidget {
  final String section;
  final String mainCategory;
  final String title;

  const SubcategoryProductsScreen({
    super.key,
    required this.section,
    required this.mainCategory,
    required this.title,
  });

  @override
  State<SubcategoryProductsScreen> createState() => _SubcategoryProductsScreenState();
}

class _SubcategoryProductsScreenState extends State<SubcategoryProductsScreen> {
  List<Subcategory> _subcategories = [];
  List<Product> _products = [];
  Subcategory? _selectedSubcategory;
  bool _isLoadingSubcategories = true;
  bool _isLoadingProducts = false;
  String? _error;
  String? _lastLanguage;
  
  // ⭐ NEW - Admin system
  bool _isAdmin = false;
  String? _userPhone;
  
  // Lazy loading for products
  int _displayedProductsCount = 0;
  final int _productsPerBatch = 20;
  bool _isLoadingMoreProducts = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserPhone();  // ⭐ NEW - Load user phone for admin check
    _loadSubcategories();
    _scrollController.addListener(_onScroll);
  }
  
  // ⭐ NEW - Load user phone from SharedPreferences
  Future<void> _loadUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      if (mounted) {
        setState(() {
          _userPhone = phone;
        });
        print('📱 [ADMIN] User phone loaded: ${phone ?? "NOT LOGGED IN"}');
      }
    } catch (e) {
      print('❌ [ADMIN] Error loading user phone: $e');
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    final scrollPercentage = _scrollController.position.pixels / _scrollController.position.maxScrollExtent;
    if (scrollPercentage > 0.7 && !_isLoadingMoreProducts && _displayedProductsCount < _products.length) {
      _loadMoreProducts();
    }
  }
  
  void _loadMoreProducts() {
    if (_isLoadingMoreProducts || _displayedProductsCount >= _products.length) return;
    
    setState(() {
      _isLoadingMoreProducts = true;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedProductsCount = 
              (_displayedProductsCount + _productsPerBatch).clamp(0, _products.length);
          _isLoadingMoreProducts = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload subcategories and products when language changes
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_lastLanguage != null && _lastLanguage != provider.currentLanguage) {
      _loadSubcategories();
    }
    _lastLanguage = provider.currentLanguage;
  }

  Future<void> _loadSubcategories() async {
    setState(() {
      _isLoadingSubcategories = true;
      _error = null;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      print('DEBUG: Loading subcategories for section="${widget.section}" mainCategory="${widget.mainCategory}" lang="${provider.currentLanguage}"');
      final subcategories = await ApiService.getSubcategories(
        section: widget.section,
        mainCategory: widget.mainCategory,
        lang: provider.currentLanguage,
      );
      
      print('DEBUG: Received ${subcategories.length} subcategories');
      if (subcategories.isNotEmpty) {
        print('DEBUG: First subcategory: name="${subcategories[0].name}" id="${subcategories[0].subcategoryId}" productCount=${subcategories[0].productCount}');
      }
      
      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
        
        // Auto-select first subcategory
        if (_subcategories.isNotEmpty) {
          _selectedSubcategory = _subcategories[0];
          _loadProducts(_selectedSubcategory!);
        }
      });
    } catch (e) {
      print('DEBUG: Error loading subcategories: $e');
      setState(() {
        _error = e.toString();
        _isLoadingSubcategories = false;
      });
    }
  }

  Future<void> _loadProducts(Subcategory subcategory) async {
    setState(() {
      _isLoadingProducts = true;
      _selectedSubcategory = subcategory;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      print('DEBUG: Loading products for subcategory: name="${subcategory.name}" id="${subcategory.subcategoryId}"');
      print('DEBUG: API params: section="${widget.section}" mainCategory="${widget.mainCategory}" subcategoryId="${subcategory.subcategoryId}" subcategory="${subcategory.name}"');
      print('👤 [ADMIN] Calling API with user_phone: ${_userPhone ?? "NOT PROVIDED"}');
      
      // ⭐ NEW - Use ProductsResponse with userPhone
      final result = await ApiService.getProducts(
        section: widget.section,
        mainCategory: widget.mainCategory,
        subcategoryId: subcategory.subcategoryId,
        subcategory: subcategory.name,  // Fallback to name if ID is not available
        userPhone: _userPhone,  // ⭐ NEW - Pass user phone for admin check
        lang: provider.currentLanguage,
      );
      
      print('DEBUG: Received ${result.products.length} products');
      print('✅ [ADMIN] Is Admin: ${result.isAdmin}');
      if (result.isAdmin && result.products.isNotEmpty) {
        print('💰 [ADMIN] Buying prices available: ${result.products.where((p) => p.buyingPrice != null).length}/${result.products.length}');
      }
      
      setState(() {
        _products = result.products;  // ⭐ CHANGED - Use result.products
        _isAdmin = result.isAdmin;    // ⭐ NEW - Store admin status
        _displayedProductsCount = _productsPerBatch.clamp(0, result.products.length);
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('DEBUG: Error loading products: $e');
      setState(() {
        _error = e.toString();
        _isLoadingProducts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
        elevation: 0,
        // ⭐ NEW - Show admin badge
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoadingSubcategories
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('${provider.text('error')}: $_error', textAlign: TextAlign.center),
                        ],
                      ),
                    )
              : _subcategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(provider.text('no_subcategories')),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // LEFT SIDEBAR - Subcategories (1/5 of screen)
                        Container(
                          width: MediaQuery.of(context).size.width / 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border(
                              right: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                          ),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemCount: _subcategories.length,
                            itemBuilder: (context, index) {
                              final subcategory = _subcategories[index];
                              final isSelected = _selectedSubcategory?.name == subcategory.name;
                              
                              return InkWell(
                                onTap: () => _loadProducts(subcategory),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    border: Border(
                                      left: BorderSide(
                                        color: isSelected ? kPrimaryColor : Colors.transparent,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: subcategory.imageUrl.isNotEmpty
                                            ? Image.network(
                                                ApiService.getImageUrl(subcategory.imageUrl),
                                                width: 38,
                                                height: 38,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stack) => Container(
                                                  width: 38,
                                                  height: 38,
                                                  color: Colors.grey[200],
                                                  child: Text(
                                                    subcategory.icon,
                                                    style: const TextStyle(fontSize: 24),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                width: 38,
                                                height: 38,
                                                color: Colors.grey[200],
                                                child: Text(
                                                  subcategory.icon,
                                                  style: const TextStyle(fontSize: 24),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subcategory.nameDisplay,  // Use localized name for display
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? kPrimaryColor : Colors.black87,
                                        ),
                                      ),
                                      if (subcategory.productCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${subcategory.productCount}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // RIGHT CONTENT - Products (4/5 of screen)
                        Expanded(
                          child: _isLoadingProducts
                              ? GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
                                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.45,
                                  ),
                                  itemCount: 6,
                                  itemBuilder: (context, index) => _buildSkeletonCard(),
                                )
                              : _products.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                                          SizedBox(height: 16),
                                          Text('No products found'),
                                        ],
                                      ),
                                    )
                                  : GridView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
                                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: _isAdmin ? 0.40 : 0.45,  // ⭐ Smaller ratio (taller cards) for admin to fit cost/profit
                                      ),
                                      itemCount: _displayedProductsCount + (_isLoadingMoreProducts ? 2 : 0),
                                      itemBuilder: (context, index) {
                                        // Show skeleton for loading more
                                        if (index >= _displayedProductsCount) {
                                          return _buildSkeletonCard();
                                        }
                                        final product = _products[index];
                                        return _buildProductCard(product, provider, _isAdmin);  // ⭐ Pass isAdmin
                                      },
                                    ),
                        ),
                      ],
                    ),
          
          // Floating cart button moved to MainScreen
          const FloatingCartButton(),
        ],
      ),
    );
  }

  // Skeleton loading for product cards in SubcategoryProductsScreen
  Widget _buildSkeletonCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final padding = (cardWidth * 0.05).clamp(4.0, 8.0);
        
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image placeholder
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Container(
                      width: cardWidth * 0.3,
                      height: cardWidth * 0.3,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Content placeholder - Use Flexible with tight fit
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: cardWidth * 0.08,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(height: padding * 0.5),
                            Container(
                              height: cardWidth * 0.08,
                              width: cardWidth * 0.6,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: cardWidth * 0.065,
                        width: cardWidth * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: cardWidth * 0.095,
                        width: cardWidth * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom divider and button placeholder
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!, width: 0.5),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(padding, 1, padding, 1),
                child: Container(
                  height: cardWidth * 0.22,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider, bool isAdmin) {  // ⭐ Add isAdmin parameter
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Clean white card with full-fit image and centered controls - FULLY RESPONSIVE
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic sizing based on card width
        final cardWidth = constraints.maxWidth;
        final fontSize = (cardWidth * 0.10).clamp(10.0, 14.0); // Increased for better visibility
        final weightFontSize = (cardWidth * 0.07).clamp(7.0, 10.0);
        final priceFontSize = (cardWidth * 0.10).clamp(10.0, 14.0);
        final iconSize = (cardWidth * 0.12).clamp(12.0, 16.0);
        final padding = (cardWidth * 0.05).clamp(4.0, 8.0);
        final buttonFontSize = (cardWidth * 0.085).clamp(8.0, 11.0);
        final buttonIconSize = (cardWidth * 0.12).clamp(12.0, 16.0);
        
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0, // No shadow
          color: Colors.transparent, // Transparent background
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image (top) - Full fit without cropping sides - Clickable to show details
              Expanded(
                flex: isAdmin ? 2 : 3,  // ⭐ Reduce image space for admin to make room for cost/profit
                child: GestureDetector(
                  onTap: () {
                    // Open full product page when image is clicked
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                    );
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white, // White background for image
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: SizedBox.expand(
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    ApiService.getImageUrl(product.imageUrl),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stack) => Container(
                                      color: Colors.grey[50],
                                      padding: EdgeInsets.all(padding),
                                      child: Icon(Icons.inventory_2, size: iconSize * 2, color: Colors.grey[400]),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[50],
                                    child: Icon(Icons.inventory_2, size: iconSize * 2, color: Colors.grey[400]),
                                  ),
                          ),
                        ),
                        // Heart Icon (top right)
                        Positioned(
                          top: padding,
                          right: padding,
                          child: GestureDetector(
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final phone = prefs.getString('userPhone');
                              if (phone != null && phone.isNotEmpty) {
                                await provider.toggleFavorite(phone, productId);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(padding * 0.6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavorited ? Icons.favorite : Icons.favorite_border,
                                color: isFavorited ? Colors.red : Colors.grey[600],
                                size: iconSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content - Use Flexible with tight fit to prevent overflow
              Flexible(
                flex: isAdmin ? 3 : 2,  // ⭐ More space for admin content (cost/profit display)
                fit: FlexFit.tight,
                child: Container(
                  color: Colors.white, // White background for content
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.5),  // ⭐ Reduced vertical padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Product name - constrained to exactly 2 lines with ellipsis
                      Flexible(
                        child: Text(
                          product.getLocalizedName(provider.currentLanguage),
                          maxLines: isAdmin ? 3 : 2,  // ⭐ Allow 3 lines for admin, 2 for regular
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.black87, 
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: padding * 0.3),  // ⭐ Reduced spacing
                      // Weight
                      Text(
                        product.weight,
                        style: TextStyle(fontSize: weightFontSize, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: padding * 0.3),  // ⭐ Reduced spacing
                      // Price
                      Text(
                        '₹${product.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: priceFontSize, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      // ⭐ ADMIN BUYING PRICE & MARGIN
                      if (isAdmin) ...[
                        if (product.buyingPrice != null && product.buyingPrice! > 0) ...[
                          SizedBox(height: padding * 0.5),  // ⭐ Reduced spacing
                          // Buying price with icon (Tamil: விலை)
                          Row(
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: weightFontSize, color: Colors.orange[700]),
                              SizedBox(width: padding * 0.5),
                              Text(
                                'விலை: ₹${product.buyingPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: weightFontSize,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          SizedBox(height: padding * 0.4),  // ⭐ Reduced spacing
                          // Margin with icon and colored background (Tamil: இலாபம்)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: padding * 0.8, vertical: padding * 0.4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, size: weightFontSize, color: Colors.green[700]),
                                SizedBox(width: padding * 0.5),
                                Text(
                                  'இலாபம்: ₹${(product.price - product.buyingPrice!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: weightFontSize,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Show message for products without buying price
                          SizedBox(height: padding * 0.8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: padding * 0.8, vertical: padding * 0.4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: weightFontSize, color: Colors.grey[600]),
                                SizedBox(width: padding * 0.5),
                                Text(
                                  'Cost price not set',
                                  style: TextStyle(
                                    fontSize: weightFontSize * 0.9,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom quantity control bar - Centered (minimal spacing)
              Container(
                  padding: EdgeInsets.zero, // No padding - stick to card edges
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Builder(builder: (context) {
                    final existing = provider.cartItems.where((c) => c.productName == product.productName && c.weight == product.weight).toList();
                    final CartItem? cartItem = existing.isNotEmpty ? existing.first : null;
                    final int qty = cartItem?.quantity ?? 0;

                    // Show "Add to cart" button when qty is 0
                    if (qty == 0) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: product.inStock
                              ? () {
                                  provider.addToCart(product);
                                }
                              : null,
                          icon: Icon(Icons.shopping_bag_outlined, size: buttonIconSize),
                          label: Text(provider.text('add_to_cart'), style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: padding * 0.25, horizontal: padding * 0.5),
                            elevation: 0,
                            minimumSize: Size(0, cardWidth * 0.22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      );
                    }
                    // Show quantity controls when qty > 0
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Decrement button - Light green
                        Container(
                          width: cardWidth * 0.22,
                          height: cardWidth * 0.22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC8E6C9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              provider.updateCartQuantity(cartItem!, qty - 1);
                            },
                            icon: Icon(Icons.remove, size: (cardWidth * 0.11).clamp(10.0, 14.0), color: const Color(0xFF2E7D32)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        
                        // Quantity input field
                        Container(
                          width: cardWidth * 0.3,
                          height: cardWidth * 0.22,
                          margin: EdgeInsets.symmetric(horizontal: padding * 0.6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!, width: 0.5),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: (cardWidth * 0.095).clamp(9.0, 12.0), fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: padding * 0.6),
                              isDense: true,
                            ),
                            controller: TextEditingController(text: '$qty')..selection = TextSelection.fromPosition(TextPosition(offset: '$qty'.length)),
                            onChanged: (value) {
                              final newQty = int.tryParse(value);
                              if (newQty != null && newQty >= 0) {
                                provider.updateCartQuantity(cartItem!, newQty);
                              }
                            },
                          ),
                        ),

                        // Increment button - Green
                        Container(
                          width: cardWidth * 0.22,
                          height: cardWidth * 0.22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: product.inStock
                                ? () {
                                    provider.addToCart(product);
                                  }
                                : null,
                            icon: Icon(Icons.add, size: (cardWidth * 0.11).clamp(10.0, 14.0), color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    );
                  }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductDetails(Product product) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              ApiService.getImageUrl(product.imageUrl),
                              height: 250,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                height: 250,
                                color: Colors.grey[200],
                                child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                              ),
                            )
                          : Container(
                              height: 250,
                              color: Colors.grey[200],
                              child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Product Name
                    Text(
                      product.getLocalizedName(provider.currentLanguage),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    // Weight & Best Seller Badge
                    Row(
                      children: [
                        Text(
                          product.weight,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (product.isBestSeller) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⭐ ${provider.text('best_seller')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Price
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Stock Status
                    Row(
                      children: [
                        Icon(
                          product.inStock ? Icons.check_circle : Icons.cancel,
                          color: product.inStock ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.inStock ? 'In Stock (${product.stock})' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 14,
                            color: product.inStock ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    
                    if (product.description != null && product.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Add to Cart Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: product.inStock
                            ? () {
                                provider.addToCart(product);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${product.productName} ${provider.text('added')}'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: kPrimaryColor,
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.shopping_cart),
                        label: Text(
                          provider.text('buy'),
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full page product details route (push navigation)
class ProductDetailsPage extends StatefulWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  Product? _fetchedProduct;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch fresh product data from backend
      if (widget.product.itemId != null && widget.product.itemId!.isNotEmpty) {
        final fetchedProduct = await ApiService.getProductDetails(widget.product.itemId!);
        setState(() {
          _fetchedProduct = fetchedProduct;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final product = _fetchedProduct ?? widget.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.getLocalizedName(provider.currentLanguage), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('${provider.text('error')}: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: const TextStyle(color: Colors.white)),
          ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    ApiService.getImageUrl(product.imageUrl),
                                    height: 260,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) => Container(
                                      height: 260,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    height: 260,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            product.getLocalizedName(provider.currentLanguage),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(product.weight, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('₹${product.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                              Text(product.inStock ? 'Stock: ${product.stock}' : 'Out of Stock', style: TextStyle(color: product.inStock ? Colors.grey[700] : Colors.red[700])),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (product.description != null && product.description!.isNotEmpty) ...[
                            Text(provider.text('description'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(product.description!, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                            const SizedBox(height: 16),
                          ],
                          // Add to cart button or quantity controls
                          Builder(builder: (context) {
                            final existing = provider.cartItems.where((c) => c.productName == product.productName && c.weight == product.weight).toList();
                            final CartItem? cartItem = existing.isNotEmpty ? existing.first : null;
                            final int qty = cartItem?.quantity ?? 0;

                            // Show "Add to cart" button when qty is 0
                            if (qty == 0) {
                              return SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: product.inStock
                                      ? () {
                                          provider.addToCart(product);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${product.getLocalizedName(provider.currentLanguage)} ${provider.text('added_to_cart')}'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                                  label: Text(
                                    product.inStock ? provider.text('add_to_cart') : provider.text('out_of_stock'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                ),
                              );
                            }

                            // Show quantity controls when qty > 0
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kPrimaryColor.withOpacity(0.3), width: 2),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Decrement button
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC8E6C9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            provider.updateCartQuantity(cartItem!, qty - 1);
                                          },
                                          icon: const Icon(Icons.remove, size: 20, color: Color(0xFF2E7D32)),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      // Quantity input field
                                      Container(
                                        width: 80,
                                        height: 44,
                                        margin: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: kPrimaryColor, width: 2),
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: TextField(
                                          textAlign: TextAlign.center,
                                          textAlignVertical: TextAlignVertical.center,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                                            isDense: true,
                                          ),
                                          controller: TextEditingController(text: '$qty')..selection = TextSelection.fromPosition(TextPosition(offset: '$qty'.length)),
                                          onChanged: (value) {
                                            final newQty = int.tryParse(value);
                                            if (newQty != null && newQty >= 0) {
                                              provider.updateCartQuantity(cartItem!, newQty);
                                            }
                                          },
                                        ),
                                      ),
                                      // Increment button
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: product.inStock
                                              ? () {
                                                  provider.addToCart(product);
                                                }
                                              : null,
                                          icon: const Icon(Icons.add, size: 20, color: Colors.white),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Total price display
                                  Text(
                                    'Total: ₹${(product.price * qty).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Floating cart button moved to MainScreen
                  ],
                ),
    );
  }
}

// FAVORITES SCREEN
class FavoritesScreen extends StatefulWidget {
  final Function(bool showNavBar)? onScrollChange;
  
  const FavoritesScreen({super.key, this.onScrollChange});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _showNavBar = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      final maxOffset = _scrollController.position.maxScrollExtent;
      
      // Show navbar when scrolling up or at the top
      // Hide navbar when scrolling down and not at bottom
      if (currentOffset <= 0) {
        // At the top
        if (!_showNavBar) {
          setState(() => _showNavBar = true);
          widget.onScrollChange?.call(true);
        }
      } else if (currentOffset >= maxOffset - 100) {
        // Near the bottom
        if (!_showNavBar) {
          setState(() => _showNavBar = true);
          widget.onScrollChange?.call(true);
        }
      } else {
        // In the middle - check scroll direction
        if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
          // Scrolling up
          if (!_showNavBar) {
            setState(() => _showNavBar = true);
            widget.onScrollChange?.call(true);
          }
        } else if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
          // Scrolling down
          if (_showNavBar) {
            setState(() => _showNavBar = false);
            widget.onScrollChange?.call(false);
          }
        }
      }
    }
  }

  // Public method to refresh favorites from outside
  Future<void> refreshFavorites() async {
    await _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      
      if (phone == null || phone.isEmpty) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final favorites = await ApiService.getFavorites(phone);
      
      // Fetch fresh product details for each favorite to get Tamil names
      List<Product> refreshedProducts = [];
      for (var product in favorites) {
        try {
          if (product.itemId != null && product.itemId!.isNotEmpty) {
            final freshProduct = await ApiService.getProductDetails(product.itemId!);
            refreshedProducts.add(freshProduct);
          } else {
            refreshedProducts.add(product); // Fallback to original
          }
        } catch (e) {
          refreshedProducts.add(product); // Fallback if fetch fails
        }
      }
      
      setState(() {
        _favoriteProducts = refreshedProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Skeleton loading widget
  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image skeleton (left)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            // Content skeleton (middle)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Controls skeleton (right)
            Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: Text(
          provider.text('my_favorites'),
          style: const TextStyle(
            color: kPrimaryColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          _isLoading
              ? ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, kBottomNavigationBarHeight + 20),
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  itemCount: 5, // Show 5 skeleton cards while loading
                  itemBuilder: (context, index) => _buildSkeletonCard(),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('${provider.text('error')}: $_error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadFavorites(),
                            child: Text(provider.text('retry')),
                          ),
                        ],
                      ),
                    )
                  : _favoriteProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_border,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                provider.text('no_favorites'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.text('no_favorites_message'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to home tab
                                    final mainScreen = context.findAncestorStateOfType<_MainScreenState>();
                                    mainScreen?.setState(() {
                                      mainScreen.currentIndex = 0;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    provider.text('browse_products'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, kBottomNavigationBarHeight + 20),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _favoriteProducts.length,
                          itemBuilder: (context, index) {
                            final product = _favoriteProducts[index];
                            return _buildProductCard(product, provider);
                          },
                        ),          // Floating cart button - positioned above nav bar
          const FloatingCartButton(bottomPosition: kBottomNavigationBarHeight + 30),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Horizontal card layout matching Cart page style with clickable card and left alignment
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to full product details page when card is tapped
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Product Image (Left) - Fixed size like Cart page
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            ApiService.getImageUrl(product.imageUrl),
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey[200],
                              child: Icon(Icons.inventory_2, color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[200],
                            child: Icon(Icons.inventory_2, color: Colors.grey[400]),
                          ),
                  ),
                  // Heart Icon (top right of image)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final phone = prefs.getString('userPhone');
                        if (phone != null && phone.isNotEmpty) {
                          // Toggle favorite - provider will update immediately
                          await provider.toggleFavorite(phone, productId);
                          // Reload the favorites list from API
                          if (mounted) {
                            await _loadFavorites();
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: isFavorited ? Colors.red : Colors.grey[600],
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Product Info (Middle) - Expanded with LEFT alignment
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Changed to start for left alignment
                  children: [
                    Text(
                      product.getLocalizedName(provider.currentLanguage), // Use localized name
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left, // Explicit left alignment
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      product.weight,
                      textAlign: TextAlign.left, // Explicit left alignment
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      textAlign: TextAlign.left, // Explicit left alignment
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Control Section (Right) - Add to cart or +/- controls
              Builder(builder: (context) {
                final existing = provider.cartItems.where((c) => c.productName == product.productName && c.weight == product.weight).toList();
                final CartItem? cartItem = existing.isNotEmpty ? existing.first : null;
                final int qty = cartItem?.quantity ?? 0;

                // Show "Add to cart" button when qty is 0
                if (qty == 0) {
                  return SizedBox(
                    width: 100,
                    child: ElevatedButton.icon(
                      onPressed: product.inStock
                          ? () {
                              provider.addToCart(product);
                            }
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: Text(provider.text('buy'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }
                // Show quantity controls when qty > 0 (matching Cart page style)
                return Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: kPrimaryColor,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            provider.updateCartQuantity(cartItem!, qty - 1);
                          },
                        ),
                        // Quantity input field
                        Container(
                          width: 42,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.0),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              isDense: true,
                            ),
                            controller: TextEditingController(text: '$qty')..selection = TextSelection.fromPosition(TextPosition(offset: '$qty'.length)),
                            onChanged: (value) {
                              final newQty = int.tryParse(value);
                              if (newQty != null && newQty >= 0) {
                                provider.updateCartQuantity(cartItem!, newQty);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: kPrimaryColor,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: product.inStock
                              ? () {
                                  provider.addToCart(product);
                                }
                              : null,
                        ),
                      ],
                    ),
                    Text(
                      '₹${(product.price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// PROFILE SCREEN
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _storeDetails;
  bool _isLoading = true;
  String? _error;
  bool _isNameIncomplete = false;
  bool _isStoreIncomplete = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';
      
      print('DEBUG: Retrieved phone from SharedPreferences: "$phone"');
      
      if (phone.isEmpty) {
        setState(() {
          _error = 'No phone number found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      print('DEBUG: Calling API with phone: $phone');
      
      // Run both API calls in parallel for faster loading
      final results = await Future.wait([
        ApiService.getUserProfile(phone),
        ApiService.getStoreDetails(phone).catchError((e) {
          print('DEBUG: Store details error (non-critical): $e');
          return <String, dynamic>{}; // Return empty map on error
        }),
      ]);
      
      final response = results[0] as Map<String, dynamic>;
      final storeDetails = (results[1] as Map<String, dynamic>).isEmpty ? null : results[1] as Map<String, dynamic>;
      
      print('DEBUG: API Response: $response');
      
      setState(() {
        _userProfile = response['user'];
        _storeDetails = storeDetails;
        _isNameIncomplete = _checkNameIncomplete();
        _isStoreIncomplete = _checkStoreIncomplete();
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error loading profile: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _checkNameIncomplete() {
    final name = _userProfile?['name'];
    return name == null || name.toString().trim().isEmpty;
  }

  bool _checkStoreIncomplete() {
    if (_storeDetails == null) return true;
    
    final storeName = _storeDetails?['store_name'];
    final street = _storeDetails?['street'];
    final city = _storeDetails?['city'];
    final state = _storeDetails?['state'];
    final pincode = _storeDetails?['pincode'];
    
    return storeName == null || storeName.toString().trim().isEmpty ||
           street == null || street.toString().trim().isEmpty ||
           city == null || city.toString().trim().isEmpty ||
           state == null || state.toString().trim().isEmpty ||
           pincode == null || pincode.toString().trim().isEmpty;
  }

  bool get isProfileIncomplete => _isNameIncomplete || _isStoreIncomplete;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(provider.text('my_profile'), style: const TextStyle(color: kPrimaryColor, fontSize: 26, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(provider.text('my_profile'), style: const TextStyle(color: kPrimaryColor, fontSize: 26, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!.contains('No phone number') 
                      ? provider.text('please_login') 
                      : '${provider.text('error')}: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (_error!.contains('No phone number')) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                      );
                    },
                    child: Text(provider.text('login_now'), style: const TextStyle(fontSize: 16)),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => _loadUserProfile(),
                    child: const Text('Retry', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final userName = _userProfile?['name'] ?? provider.text('guest_user');
    final userPhone = _userProfile?['phone'] ?? '';
    final userEmail = _userProfile?['email'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('my_profile'), style: const TextStyle(color: kPrimaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: kPrimaryColor),
            tooltip: 'Switch Account',
            onPressed: () => _showAccountSwitcherDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: kPrimaryColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for navbar
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: kPrimaryColor,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Edit icon positioned at bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showEditProfileDialog(
                            context,
                            userName,
                            userEmail,
                            userPhone,
                            onProfileUpdated: _loadUserProfile,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      if (_isNameIncomplete)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (_isNameIncomplete) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      ],
                    ],
                  ),
                  if (_isNameIncomplete) ...[
                    const SizedBox(height: 4),
                    Text(
                      provider.text('please_fill_name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    userPhone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // My Orders
            _buildProfileOption(
              context,
              icon: Icons.shopping_bag_outlined,
              title: provider.text('my_orders'),
              subtitle: provider.text('order_history'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyOrdersScreen(userPhone: userPhone)),
              ),
            ),
            
            const Divider(height: 1),
            
            // Store Details
            _buildProfileOption(
              context,
              icon: Icons.store_outlined,
              title: provider.text('store_details'),
              subtitle: _isStoreIncomplete 
                  ? provider.text('please_fill_store') 
                  : provider.text('manage_store'),
              showWarning: _isStoreIncomplete,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoreDetailsScreen(userPhone: userPhone)),
                );
                // If store details were saved, refresh the profile
                if (result == true) {
                  _loadUserProfile();
                }
              },
            ),
            
            const Divider(height: 1),
            
            // Language
            _buildProfileOption(
              context,
              icon: Icons.language,
              title: provider.text('language'),
              subtitle: provider.currentLanguage == 'en' ? 'English' : 'தமிழ்',
              onTap: () => _showLanguageDialog(context, provider),
            ),
            
            const Divider(height: 1),
            
            // Help & Support
            _buildProfileOption(
              context,
              icon: Icons.help_outline,
              title: provider.text('help_support'),
              subtitle: provider.text('help_subtitle'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${provider.text('contact')}: +91 1234567890')),
                );
              },
            ),
            
            const Divider(height: 1),
            
            // About
            _buildProfileOption(
              context,
              icon: Icons.info_outline,
              title: provider.text('about'),
              subtitle: provider.text('about_subtitle'),
              onTap: () => _showAboutDialog(context, provider),
            ),
            
            const SizedBox(height: 32),
            
            // Logout Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout', style: const TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showWarning = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
          if (showWarning)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (showWarning) ...[
            const SizedBox(width: 6),
            const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    String currentName,
    String currentEmail,
    String phone,
    {VoidCallback? onProfileUpdated}
  ) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nameController = TextEditingController(text: currentName);
    
    // Extract only the digits after +91 for editing
    final phoneDigits = phone.startsWith('+91') ? phone.substring(3) : phone;
    final phoneController = TextEditingController(text: phoneDigits);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(provider.text('edit_profile')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: provider.text('name'),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter your name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: provider.currentLanguage == 'ta' ? 'தொலைபேசி எண்' : 'Phone Number',
                  border: const OutlineInputBorder(),
                  hintText: 'XXXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone, color: kPrimaryColor),
                  prefixText: '+91 ',
                  prefixStyle: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(provider.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phoneDigits = phoneController.text.trim();
              
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.text('name_required')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (phoneDigits.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.currentLanguage == 'ta' ? 'தொலைபேசி எண் தேவை' : 'Phone number is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Validate phone number format (must have exactly 10 digits)
              if (phoneDigits.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(phoneDigits)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.currentLanguage == 'ta' 
                        ? 'சரியான 10 இலக்க தொலைபேசி எண்ணை உள்ளிடவும்'
                        : 'Please enter a valid 10-digit phone number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Prepend +91 to create full phone number
              final newPhone = '+91$phoneDigits';

              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                // If phone number changed, update via backend API first
                if (newPhone != phone) {
                  print('📱 [PROFILE] Phone changed: $phone → $newPhone, calling API...');
                  try {
                    await ApiService.updatePhoneNumber(phone, newPhone);
                    print('✅ [PROFILE] Phone updated in database');
                    
                    // Update SharedPreferences only if API succeeds
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('userPhone', newPhone);
                    
                    // Update saved accounts list with new phone number
                    print('📝 [PROFILE] Updating saved accounts with new phone...');
                    final savedAccounts = await SharedPrefsService.getSavedAccounts();
                    final oldAccountIndex = savedAccounts.indexWhere((acc) => acc.phoneNumber == phone);
                    if (oldAccountIndex != -1) {
                      // Remove old account and add updated one
                      final oldAccount = savedAccounts[oldAccountIndex];
                      await SharedPrefsService.removeAccount(phone);
                      await SharedPrefsService.saveAccount(SavedAccount(
                        uid: oldAccount.uid,
                        phoneNumber: newPhone,
                        storeName: oldAccount.storeName,
                      ));
                      print('✅ [PROFILE] Saved accounts updated: $phone → $newPhone');
                    }
                    
                    // Clear cache so new data is fetched
                    ApiService.clearCache();
                    
                    print('✅ [PROFILE] SharedPreferences updated with new phone');
                  } catch (phoneError) {
                    // Phone update failed - close loading and show specific error
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog
                      
                      String errorMessage;
                      if (phoneError.toString().contains('already registered')) {
                        errorMessage = provider.currentLanguage == 'ta' 
                            ? 'இந்த தொலைபேசி எண் ஏற்கனவே பதிவு செய்யப்பட்டுள்ளது'
                            : 'This phone number is already registered to another user';
                      } else if (phoneError.toString().contains('Invalid phone format')) {
                        errorMessage = provider.currentLanguage == 'ta'
                            ? 'தவறான தொலைபேசி எண் வடிவம்'
                            : 'Invalid phone number format';
                      } else {
                        errorMessage = provider.currentLanguage == 'ta'
                            ? 'தொலைபேசி எண்ணைப் புதுப்பிக்க முடியவில்லை: $phoneError'
                            : 'Failed to update phone number: $phoneError';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                      return; // Don't proceed with profile update
                    }
                  }
                }

                // Update profile via API (name and email)
                await ApiService.updateUserProfile(
                  newPhone, // Use newPhone in case it changed
                  name,
                  null,
                );

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  Navigator.pop(context); // Close edit dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.text('profile_updated')),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Reload profile to show updated data
                  _loadUserProfile();
                  
                  // Notify parent to update validation state
                  if (onProfileUpdated != null) {
                    onProfileUpdated();
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${provider.text('error_saving')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: Text(provider.text('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(provider.text('select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'en',
                groupValue: provider.currentLanguage,
                onChanged: (value) {
                  provider.setLanguage('en');
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                provider.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('தமிழ் (Tamil)'),
              leading: Radio<String>(
                value: 'ta',
                groupValue: provider.currentLanguage,
                onChanged: (value) {
                  provider.setLanguage('ta');
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                provider.setLanguage('ta');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('About AL-Madhina'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AL-Madhina Wholesale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 16),
            Text('Your trusted wholesale partner for quality products at the best prices.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAccountSwitcherDialog(BuildContext context) async {
    final savedAccounts = await SharedPrefsService.getSavedAccounts();
    
    // Get the currently active phone number from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentPhone = prefs.getString('userPhone') ?? '';

    if (!context.mounted) return;

    // Search controller
    final searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Filter accounts based on search query
          final searchQuery = searchController.text.toLowerCase();
          final filteredAccounts = savedAccounts.where((account) {
            final phone = account.phoneNumber.toLowerCase();
            final name = (account.storeName ?? '').toLowerCase();
            return phone.contains(searchQuery) || name.contains(searchQuery);
          }).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Switch Account', style: TextStyle(fontWeight: FontWeight.bold)),
            contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search bar
                  if (savedAccounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by phone or name...',
                          hintStyle: const TextStyle(fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                          ),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Scrollable list of saved accounts
                  if (savedAccounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No saved accounts', style: TextStyle(color: Colors.grey)),
                    )
                  else if (filteredAccounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No matching accounts', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredAccounts.length,
                          itemBuilder: (context, index) {
                            final account = filteredAccounts[index];
                            final isCurrentAccount = account.phoneNumber == currentPhone;
                            
                            return ListTile(
                          leading: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              // Get provider for language
                              final provider = Provider.of<AppProvider>(dialogContext, listen: false);
                              
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: dialogContext,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: Text(
                                    provider.currentLanguage == 'ta' ? 'கணக்கை நீக்கு' : 'Delete Account',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    provider.currentLanguage == 'ta'
                                        ? '${account.storeName ?? account.phoneNumber} இந்த சாதனத்திலிருந்து நீக்க விரும்புகிறீர்களா?\n\nஇது சேமிக்கப்பட்ட உள்நுழைவை மட்டுமே நீக்கும், கணக்கை நீக்காது.'
                                        : 'Are you sure you want to remove ${account.storeName ?? account.phoneNumber} from this device?\n\nThis will only remove the saved login, not delete the account.',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(
                                        provider.currentLanguage == 'ta' ? 'ரத்து செய்' : 'Cancel',
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: Text(
                                        provider.currentLanguage == 'ta' ? 'நீக்கு' : 'Delete',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                await SharedPrefsService.removeAccount(account.phoneNumber);
                                Navigator.pop(dialogContext);
                                // Re-show dialog with updated list
                                if (context.mounted) {
                                  _showAccountSwitcherDialog(context);
                                }
                              }
                            },
                          ),
                          title: Text(
                            account.storeName != null && account.storeName!.isNotEmpty
                                ? account.storeName!
                                : account.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            account.phoneNumber,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          trailing: isCurrentAccount
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: isCurrentAccount
                              ? null
                              : () async {
                                  print('\n╔═══════════════════════════════════════════════════════════╗');
                                  print('║         ACCOUNT SWITCH FROM DIALOG STARTED                ║');
                                  print('╚═══════════════════════════════════════════════════════════╝');
                                  print('🔄 [DIALOG SWITCH] Switching to: ${account.phoneNumber}');
                                  print('🔄 [DIALOG SWITCH] Store: ${account.storeName ?? "N/A"}');
                                  
                                  print('📋 [DIALOG SWITCH] Updating userPhone in SharedPreferences...');
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('userPhone', account.phoneNumber);
                                  print('✅ [DIALOG SWITCH] userPhone set to: ${account.phoneNumber}');
                                  
                                  print('🗑️  [DIALOG SWITCH] Clearing API cache...');
                                  ApiService.clearCache();
                                  print('✅ [DIALOG SWITCH] Cache cleared');
                                  
                                  // Close dialog and navigate immediately (don't wait)
                                  Navigator.pop(dialogContext);
                                  print('✅ [DIALOG SWITCH] Dialog closed');
                                  
                                  // Navigate immediately using the outer context
                                  print('🚀 [DIALOG SWITCH] Navigating to MainScreen...');
                                  print('   Context mounted: ${context.mounted}');
                                  
                                  if (context.mounted) {
                                    // Use pushAndRemoveUntil to clear stack and go to MainScreen
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) {
                                          print('🏗️  [DIALOG SWITCH] Building MainScreen...');
                                          return const MainScreen();
                                        },
                                      ),
                                      (route) => false,
                                    );
                                    print('✅ [DIALOG SWITCH] Navigation completed');
                                  } else {
                                    print('⚠️ [DIALOG SWITCH] Context not mounted after dialog close');
                                  }
                                  
                                  print('╔═══════════════════════════════════════════════════════════╗');
                                  print('║  ACCOUNT SWITCH FROM DIALOG COMPLETED                     ║');
                                  print('╚═══════════════════════════════════════════════════════════╝\n');
                                },
                        );
                      },
                    ),
                  ),
                ),
              const Divider(),
              // Add Account button
              ListTile(
                leading: const Icon(Icons.add_circle, color: kPrimaryColor),
                title: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(dialogContext); // Close dialog
                  
                  // Navigate to PhoneAuthScreen with cancel button (keep navigation stack)
                  if (context.mounted) {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhoneAuthScreen(showCancelButton: true),
                      ),
                    );
                    
                    // If login was successful, the PhoneAuthScreen will navigate away
                    // If user canceled, we just stay here (result will be null)
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(provider.text('logout')),
        content: Text(provider.text('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(provider.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear local storage
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(provider.text('logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// MY ORDERS SCREEN
class MyOrdersScreen extends StatefulWidget {
  final String userPhone;
  
  const MyOrdersScreen({super.key, required this.userPhone});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final response = await ApiService.getUserOrders(widget.userPhone);
      setState(() {
        _orders = response['orders'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('my_orders'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('${provider.text('error')}: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: const TextStyle(color: Colors.white)),
          ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            provider.text('no_orders'),
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.text('no_orders_message'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), // Added bottom padding
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order);
                      },
                    ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final orderId = order['order_id'] ?? '';
    final totalAmount = order['total_amount'] ?? 0.0;
    final status = order['status'] ?? 'pending';
    final items = order['items'] as List? ?? [];
    final createdAt = order['created_at'] != null
        ? DateTime.parse(order['created_at'])
        : DateTime.now();

    // Format date with localization
    final monthNamesEn = ['January', 'February', 'March', 'April', 'May', 'June', 
                          'July', 'August', 'September', 'October', 'November', 'December'];
    final monthNamesTa = ['ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
                          'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்'];
    final monthNames = provider.currentLanguage == 'ta' ? monthNamesTa : monthNamesEn;
    final formattedDate = '${provider.text('placed_on')} ${monthNames[createdAt.month - 1]} ${createdAt.day} ${createdAt.year}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              userPhone: widget.userPhone,
              orderId: orderId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon on the left
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9), // Slightly darker green circle
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: Color(0xFF2E7D32), // Dark green icon
                  ),
                ),
                const SizedBox(width: 16),
                // Order details
                Expanded(
                  child: Column(
                    crossAxisAlignment: provider.currentLanguage == 'ta' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.text('order_id')} #$orderId',
                        textAlign: provider.currentLanguage == 'ta' ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedDate,
                        textAlign: provider.currentLanguage == 'ta' ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      provider.currentLanguage == 'ta'
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${provider.text('items')}: ${items.length}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${provider.text('total')}: ₹${totalAmount.toStringAsFixed(2)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Text(
                                  '${provider.text('items')}: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  '${provider.text('total')}: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
            // Status and Cancel button at bottom
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: provider.currentLanguage == 'ta' ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                // Cancel button for pending orders (left side)
                if (status == 'pending')
                  TextButton.icon(
                    onPressed: () => _showCancelOrderDialog(orderId),
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    label: Text(
                      provider.text('cancel'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Colors.red[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (provider.currentLanguage == 'ta' && status == 'pending')
                  const SizedBox(width: 16),
                // Status badge (right side or center for Tamil)
                if (status == 'delivered')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Text(
                      provider.text('status_delivered'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                else if (status == 'cancelled')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      provider.text('status_cancelled'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      provider.text('status_pending'),
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelOrderDialog(String orderId) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(provider.text('cancel_order')),
        content: Text(provider.text('cancel_order_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(provider.text('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(provider.text('cancel_order')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cancelOrder(orderId);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );

      // Call API to cancel order using production backend URL
      const String backendUrl = 'https://al-mathina-upcraft.onrender.com';
      final response = await http.put(
        Uri.parse('$backendUrl/api/admin/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': 'cancelled'}),
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        // Reload orders
        await _loadOrders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to cancel order');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ORDER DETAILS SCREEN
class OrderDetailsScreen extends StatefulWidget {
  final String userPhone;
  final String orderId;
  
  const OrderDetailsScreen({
    super.key,
    required this.userPhone,
    required this.orderId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  String? _error;
  Map<String, Product> _refreshedProducts = {}; // Store fetched products by itemId
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final response = await ApiService.getOrderDetails(widget.userPhone, widget.orderId);
      setState(() {
        _order = response['order'];
        _isLoading = false;
      });
      
      // After loading order details, fetch product details for Tamil names
      if (_order != null) {
        await _loadOrderProducts();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrderProducts() async {
    setState(() => _isLoadingProducts = true);
    
    try {
      final items = _order!['items'] as List? ?? [];
      Map<String, Product> fetchedProducts = {};
      
      // Fetch fresh product details for each order item
      for (var item in items) {
        final itemId = item['item_id'];
        if (itemId != null && itemId.toString().isNotEmpty) {
          try {
            final product = await ApiService.getProductDetails(itemId.toString());
            fetchedProducts[itemId.toString()] = product;
          } catch (e) {
            print('Error fetching product $itemId: $e');
            // Continue with other products even if one fails
          }
        }
      }
      
      setState(() {
        _refreshedProducts = fetchedProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading order products: $e');
      setState(() => _isLoadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${provider.text('order_id')} #${widget.orderId}', style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('${provider.text('error')}: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: const TextStyle(color: Colors.white)),
          ),
                    ],
                  ),
                )
              : _buildOrderDetails(provider),
    );
  }

  Widget _buildOrderDetails(AppProvider provider) {
    if (_order == null) return const SizedBox.shrink();

    final orderId = _order!['order_id'] ?? '';
    final totalAmount = _order!['total_amount'] ?? 0.0;
    final status = _order!['status'] ?? 'pending';
    final paymentMethod = _order!['payment_method'] ?? 'Cash on Delivery';
    final items = _order!['items'] as List? ?? [];
    final deliveryAddress = _order!['delivery_address'] as Map<String, dynamic>? ?? {};
    final createdAt = _order!['created_at'] != null
        ? DateTime.parse(_order!['created_at'])
        : DateTime.now();

    // Format date
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                        'July', 'August', 'September', 'October', 'November', 'December'];
    final formattedDate = '${monthNames[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';

    // Status color
    Color statusColor = Colors.orange;
    if (status == 'delivered') statusColor = Colors.green;
    if (status == 'cancelled') statusColor = Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), // Added bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.text('order_status'),
                      style: TextStyle(
                        fontSize: provider.currentLanguage == 'ta' ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: provider.currentLanguage == 'ta' ? 11 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.text('placed_on')} $formattedDate',
                      style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 12 : 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.text('items'),
                  style: TextStyle(
                    fontSize: provider.currentLanguage == 'ta' ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map((item) {
                  final itemId = item['item_id']?.toString() ?? '';
                  final displayName = _refreshedProducts.containsKey(itemId)
                      ? _refreshedProducts[itemId]!.getLocalizedName(provider.currentLanguage)
                      : (item['product_name'] ?? 'Product');
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                ? Image.network(
                                    ApiService.getImageUrl(item['image_url']),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.shopping_bag_outlined, color: kPrimaryColor);
                                    },
                                  )
                                : const Icon(Icons.shopping_bag_outlined, color: kPrimaryColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: provider.currentLanguage == 'ta' ? 13 : 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['weight'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${item['quantity']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${(item['price'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.text('payment_method'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.text('payment_method'),
                      style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 12 : 14, color: Colors.grey[700]),
                    ),
                    Expanded(
                      child: Text(
                        _getLocalizedPaymentMethod(paymentMethod, provider),
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 12 : 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.text('total'),
                      style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 14 : 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: provider.currentLanguage == 'ta' ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Delivery Address Card
          if (deliveryAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 20, color: kPrimaryColor),
                      const SizedBox(width: 8),
                      Text(
                        provider.text('delivery_address'),
                        style: TextStyle(
                          fontSize: provider.currentLanguage == 'ta' ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deliveryAddress['street'] ?? '',
                    style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 12 : 14, height: 1.5),
                  ),
                  Text(
                    '${deliveryAddress['city']}, ${deliveryAddress['state']} - ${deliveryAddress['pincode']}',
                    style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 12 : 14, height: 1.5),
                  ),
                  if (deliveryAddress['landmark'] != null && deliveryAddress['landmark'].toString().isNotEmpty)
                    Text(
                      'Landmark: ${deliveryAddress['landmark']}',
                      style: TextStyle(fontSize: provider.currentLanguage == 'ta' ? 11 : 13, color: Colors.grey[600], height: 1.5),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get localized payment method
  String _getLocalizedPaymentMethod(String paymentMethod, AppProvider provider) {
    if (paymentMethod.toLowerCase() == 'upi' || paymentMethod.toLowerCase() == 'pay via upi/apps') {
      return provider.text('payment_upi');
    } else if (paymentMethod.toLowerCase() == 'cash on delivery' || paymentMethod.toLowerCase().contains('cash')) {
      return provider.text('cod');
    }
    return paymentMethod;
  }
}

// MANAGE ADDRESSES SCREEN
class ManageAddressesScreen extends StatefulWidget {
  final String userPhone;
  
  const ManageAddressesScreen({super.key, required this.userPhone});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final response = await ApiService.getUserProfile(widget.userPhone);
      setState(() {
        _userProfile = response['user'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _userProfile?['addresses'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No saved addresses', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Add an address for faster checkout', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _buildAddressCard(address, index);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressDialog(context),
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address, int index) {
    final isDefault = address['is_default'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('DEFAULT', style: TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditAddressDialog(context, address, index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteAddress(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(address['street'] ?? '', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (address['landmark'] != null && address['landmark'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Landmark: ${address['landmark']}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAddressDialog(BuildContext context) async {
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final pincodeController = TextEditingController();
    final landmarkController = TextEditingController();
    bool isDefault = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(labelText: 'Street Address', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stateController,
                  decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pincodeController,
                  decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: landmarkController,
                  decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Set as default address'),
                  value: isDefault,
                  onChanged: (value) => setState(() => isDefault = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: const TextStyle(color: Colors.white)),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAddressDialog(BuildContext context, Map<String, dynamic> address, int index) async {
    final streetController = TextEditingController(text: address['street'] ?? '');
    final cityController = TextEditingController(text: address['city'] ?? '');
    final stateController = TextEditingController(text: address['state'] ?? '');
    final pincodeController = TextEditingController(text: address['pincode'] ?? '');
    final landmarkController = TextEditingController(text: address['landmark'] ?? '');
    bool isDefault = address['is_default'] ?? false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(labelText: 'Street Address', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stateController,
                  decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pincodeController,
                  decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: landmarkController,
                  decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Set as default address'),
                  value: isDefault,
                  onChanged: (value) => setState(() => isDefault = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              await prefs.remove('userPhone');

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: const TextStyle(color: Colors.white)),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAddress(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteAddress(widget.userPhone, index);
        _loadAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// STORE DETAILS SCREEN
class StoreDetailsScreen extends StatefulWidget {
  final String userPhone;
  
  const StoreDetailsScreen({super.key, required this.userPhone});

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStoreDetails();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreDetails() async {
    try {
      // getStoreDetails now returns the store_details map directly (already unwrapped)
      final storeDetails = await ApiService.getStoreDetails(widget.userPhone);
      
      setState(() {
        _storeNameController.text = storeDetails['store_name']?.toString() ?? '';
        _streetController.text = storeDetails['street']?.toString() ?? '';
        _cityController.text = storeDetails['city']?.toString() ?? '';
        _stateController.text = storeDetails['state']?.toString() ?? '';
        _pincodeController.text = storeDetails['pincode']?.toString() ?? '';
        _landmarkController.text = storeDetails['landmark']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading store details: $e')),
        );
      }
    }
  }

  Future<void> _saveStoreDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      
      await ApiService.updateStoreDetails(widget.userPhone, {
        'store_name': _storeNameController.text.trim(),
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'landmark': _landmarkController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.text('store_saved')),
            backgroundColor: kPrimaryColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate save was successful
      }
    } catch (e) {
      if (mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${provider.text('error_saving')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(provider.text('store_details'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      provider.text('store_details'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.text('store_details_subtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Store Name
                    Text(
                      provider.text('store_name'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _storeNameController,
                      decoration: InputDecoration(
                        hintText: provider.text('store_name_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return provider.text('store_name_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Street Address
                    Text(
                      provider.text('street_address'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _streetController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: provider.text('street_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return provider.text('street_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // City
                    Text(
                      provider.text('city'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: provider.text('city_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return provider.text('city_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // State
                    Text(
                      provider.text('state'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        hintText: provider.text('state_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return provider.text('state_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Pincode
                    Text(
                      provider.text('pincode'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: provider.text('pincode_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return provider.text('pincode_required');
                        }
                        if (value.length != 6) {
                          return provider.currentLanguage == 'ta' ? 'பின்கோடு 6 இலக்கங்களாக இருக்க வேண்டும்' : 'Pincode must be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Landmark (Optional)
                    Text(
                      provider.text('landmark'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: InputDecoration(
                        hintText: provider.text('landmark_hint'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveStoreDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                provider.text('save'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// FLOATING CART BUTTON WIDGET
class FloatingCartButton extends StatelessWidget {
  final double? bottomPosition;
  
  const FloatingCartButton({super.key, this.bottomPosition});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    if (provider.cartCount == 0) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    
    // Get localized text lengths for dynamic width calculation
    final viewCartText = provider.text('view_cart');
    final itemText = provider.cartCount == 1 ? 'item' : 'items'; // Keep items in English for now or add translation
    final displayText = '${provider.cartCount} $itemText';
    
    // Dynamic width based on language and cart count
    // Tamil text is typically longer, so we need more space
    double calculateButtonWidth() {
      final isTamil = provider.currentLanguage == 'ta';
      final baseWidth = isTamil ? 280.0 : 240.0;
      
      if (provider.cartCount < 10) {
        return baseWidth;
      } else if (provider.cartCount < 100) {
        return baseWidth + 25.0;
      } else {
        return baseWidth + 45.0;
      }
    }
    
    final buttonWidth = screenWidth > 600 ? 320.0 : calculateButtonWidth();
    
    // Calculate proper bottom position: bottom nav bar height (56) + desired gap (5)
    final calculatedBottom = bottomPosition ?? (kBottomNavigationBarHeight + 5);

  return Positioned(
      bottom: calculatedBottom,
      left: (screenWidth - buttonWidth) / 2,
      child: GestureDetector(
        onTap: () {
          // Always push CartScreen so system back returns to the previous page
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
        child: Container(
          width: buttonWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart, color: Color(0xFF4CAF50), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${provider.cartCount} ${provider.cartCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    provider.text('view_cart'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}




