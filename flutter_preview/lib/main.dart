import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'api_service.dart';

const Color kPrimaryColor = Color(0xFF004D40);
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
    'best_seller': 'Best Seller',
    'loading': 'Loading...',
    'retry': 'Retry',
    'error': 'Error',
    
    // Cart
    'total': 'Grand Total:',
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
    'add': 'Add',
    'out_of_stock': 'Out of stock',
    'in_stock': 'In Stock',
    'stock': 'Stock',
    'added': 'added to cart!',
    'added_to_cart': 'Added to cart!',
    
    // Payment & Checkout
    'payment_upi': 'Pay via UPI/Apps',
    'cod': 'Cash on Delivery',
    'select_payment': 'Select Payment',
    'order_success': 'Order Placed via',
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
    'best_seller': 'சிறந்த விற்பனையாளர்',
    'loading': 'ஏற்றுகிறது...',
    'retry': 'மீண்டும் முயற்சிக்கவும்',
    'error': 'பிழை',
    
    // Cart
    'total': 'மொத்த தொகை:',
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
    'add_to_cart': 'வண்டியில் சேர்க்கவும்',
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
    required this.weight,
    this.quantity = 1,
    required this.price,
    required this.imageUrl,
  });

  double get subtotal => quantity * price;
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

  void setLanguage(String lang) {
    if (translations.containsKey(lang)) {
      _currentLanguage = lang;
      notifyListeners();
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (context) => AppProvider(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$kAppName Wholesale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        // Set homepage/background to #EBEBEB as requested
        scaffoldBackgroundColor: const Color(0xFFF4F5F9),
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
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final isOldUser = prefs.getBool('isOldUser') ?? false;
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

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _showOtp = false;
  Timer? _autoFillTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _autoFillTimer?.cancel();
    super.dispose();
  }

  void _sendOtp() {
    if (_phoneController.text.length == 10) {
      setState(() => _showOtp = true);
      _autoFillTimer = Timer(const Duration(milliseconds: 500), () {
        for (int i = 0; i < 6; i++) {
          _otpControllers[i].text = '${(i + 1) % 10}';
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOldUser', true);
    await prefs.setString('userPhone', _phoneController.text.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainScreen(key: mainScreenKey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Authentication', style: TextStyle(color: kPrimaryColor)),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Welcome to AL-Madhina',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: const Icon(Icons.phone, color: kPrimaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_showOtp)
              ElevatedButton(
                onPressed: _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Send OTP', style: TextStyle(fontSize: 18)),
              ),
            if (_showOtp) ...[
              const SizedBox(height: 24),
              const Text(
                'Enter OTP',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verify OTP', style: TextStyle(fontSize: 18)),
              ),
            ],
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
      FavoritesScreen(key: _favoritesKey),
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

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkProfileCompleteness();
      _loadUserFavorites();
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
        final response = await ApiService.getStoreDetails(phone);
        final storeDetails = response['store_details'] as Map<String, dynamic>?;
        
        if (storeDetails == null) {
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
            const FloatingCartButton(bottomPosition: kBottomNavigationBarHeight + 15),
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
            color: const Color(0xFFF5F5F5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
  List<Product> _bestSellerProducts = [];
  bool _isLoading = true;
  String? _error;
  
  ScrollController? _scrollController;
  double _lastScrollPosition = 0;

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
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    try {
      final data = await ApiService.getHomeData();
      final bestSellersData = await ApiService.getBestSellers(limit: 20);
      setState(() {
        _homeData = data;
        _bestSellerProducts = bestSellersData['products'] as List<Product>;
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
      // Keep scaffold background transparent so global theme background (#EBEBEB) shows
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              kAppName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Color(0xFF868889), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? SingleChildScrollView(
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('${provider.text('error')}: $_error', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _loadHomeData();
                            },
                            child: Text(provider.text('retry')),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHomeData,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            // White container with banner
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
                            // Content section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 90.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Best Sellers Section - Display Products Directly
                                  if (_bestSellerProducts.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      'Best Seller',
                                      '🌟',
                                    ),
                                    const SizedBox(height: 6),
                                    _buildBestSellerProductsGrid(),
                                    const SizedBox(height: 0),
                                  ],

                                  // Regular Sections
                                  ..._homeData!.sections.map((section) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(section.title, section.icon),
                                        const SizedBox(height: 8),
                                        _buildMainCategoryGrid(section.mainCategories, isBestSeller: false),
                                        const SizedBox(height: 0),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          
          // Floating cart button moved to MainScreen
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMainCategoryGrid(List<MainCategory> categories, {bool isBestSeller = false}) {
    // Use a wider aspect ratio for regular categories so images can appear wider
    final double aspect = isBestSeller ? 0.78 : 0.82; // slightly bigger cards for 4 columns
    final int columns = isBestSeller ? 3 : 4; // 4 columns for regular sections, 3 for best seller

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
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
    final isBestSeller = category.section == "Best Seller";
    
    // For Best Seller section keep the larger card visual (image-first with subtle shadow)
    if (isBestSeller) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProductsScreen(
                section: category.section,
                mainCategory: category.mainCategory,
                isBestSeller: true,
                title: category.name,
              ),
            ),
          );
        },
        // Keep ripple for Best Seller to indicate interactivity
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: category.imageUrl.isNotEmpty
                      ? Image.network(
                          ApiService.getImageUrl(category.imageUrl),
                          fit: BoxFit.cover,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Flexible image area to prevent overflow
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: category.imageUrl.isNotEmpty
                    ? Image.network(
                        ApiService.getImageUrl(category.imageUrl),
                        fit: BoxFit.cover,
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
          const SizedBox(height: 6),
          // Let text size naturally but limit lines to prevent overflow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellerProductsGrid() {
    final provider = Provider.of<AppProvider>(context);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.65,
      ),
      itemCount: _bestSellerProducts.length,
      itemBuilder: (context, index) {
        final product = _bestSellerProducts[index];
        return _buildProductCard(product, provider);
      },
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Clean white card with full-fit image and centered controls
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                // Open full product page when image is clicked
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                      product.productName,
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

  // Skeleton loading for product cards
  Widget _buildSkeletonProductCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ),
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
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
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
      final subcategories = await ApiService.getSubcategories(
        section: widget.section,
        mainCategory: widget.mainCategory,
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
      final result = await ApiService.getProducts(
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
                        // Left Sidebar - Subcategories (30%)
                        Container(
                      width: MediaQuery.of(context).size.width * 0.25,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey[200]!, width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filters header
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list, size: 18, color: Colors.black87),
                                const SizedBox(width: 8),
                                const Text(
                                  'Filters',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // Subcategories list
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _subcategories.length,
                              itemBuilder: (context, index) {
                                final subcategory = _subcategories[index];
                                final isSelected = subcategory.name == _selectedSubcategory;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? kPrimaryColor.withOpacity(0.05) : Colors.transparent,
                                    border: Border(
                                      left: BorderSide(
                                        color: isSelected ? kPrimaryColor : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.category_outlined,
                                        size: 20,
                                        color: isSelected ? kPrimaryColor : Colors.grey[600],
                                      ),
                                    ),
                                    title: Text(
                                      subcategory.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? kPrimaryColor : Colors.black87,
                                      ),
                                    ),
                                    onTap: () => _selectSubcategory(subcategory.name),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                      product.productName,
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
class ProductDetailsSheet extends StatelessWidget {
  final Product product;
  final ScrollController scrollController;

  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Best Seller',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Product Name
          Text(
            product.productName,
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

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    try {
      final result = await ApiService.searchProducts(query: widget.query);
      setState(() {
        _results = result['results'] as List<Product>;
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
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), // Added bottom padding for floating button
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 18,
                            childAspectRatio: 0.65,
                          ),
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
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Clean white card with full-fit image and centered controls (matching Best Seller UI)
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                      product.productName,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkProfileCompleteness();
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
        final response = await ApiService.getStoreDetails(phone);
        final storeDetails = response['store_details'] as Map<String, dynamic>?;
        
        if (storeDetails == null) {
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
    if (_isNameIncomplete && _isStoreIncomplete) {
      return 'Please fill out your name and store details';
    } else if (_isNameIncomplete) {
      return 'Please fill out your name';
    } else if (_isStoreIncomplete) {
      return 'Please fill out your store details';
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
                          provider.updateCartQuantity(item, 0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.productName} removed from cart'),
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
                                      item.productName,
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
                                      Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
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
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                ? const Color(0xFF6CC51D) 
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(color: kPrimaryColor)),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} x${item.quantity}',
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  backgroundColor: const Color(0xFF6CC51D),
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
      final storeDetails = await ApiService.getStoreDetails(userPhone);

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

      // Create order with real store address
      final paymentMethod = _selectedPayment == 'upi' ? 'UPI' : 'Cash on Delivery';
      
      await ApiService.createOrder(
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

      // Navigate to success screen
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              totalAmount: provider.cartTotal,
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
  
  const OrderSuccessScreen({super.key, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Success', style: TextStyle(color: kPrimaryColor)),
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
                  color: const Color(0xFF6CC51D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: Color(0xFF6CC51D),
                ),
              ),
              const SizedBox(height: 40),
              // Success message
              const Text(
                'Your order was\nsuccessfull !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                'You will get a response within\na few minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const Spacer(),
              // Track Order button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6CC51D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Order Placed',
                    style: TextStyle(
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
        final result = await ApiService.getBestSellers();
        setState(() => _products = result['products'] as List<Product>);
      } else {
        final result = await ApiService.getProducts(
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
        title: Text(widget.isBestSeller ? '⭐ Best Sellers' : widget.title,
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
                      child: const Text(
                        '⭐ Best Seller',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
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
    setState(() {
      _isLoadingSubcategories = true;
      _error = null;
    });

    try {
      final subcategories = await ApiService.getSubcategories(
        section: widget.section,
        mainCategory: widget.mainCategory,
      );
      
      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
        
        // Auto-select first subcategory
        if (_subcategories.isNotEmpty) {
          _selectedSubcategory = _subcategories[0].name;
          _loadProducts(_selectedSubcategory!);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingSubcategories = false;
      });
    }
  }

  Future<void> _loadProducts(String subcategory) async {
    setState(() {
      _isLoadingProducts = true;
      _selectedSubcategory = subcategory;
    });

    try {
      final result = await ApiService.getProducts(
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
          widget.title,
          style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
        elevation: 0,
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
                            itemCount: _subcategories.length,
                            itemBuilder: (context, index) {
                              final subcategory = _subcategories[index];
                              final isSelected = _selectedSubcategory == subcategory.name;
                              
                              return InkWell(
                                onTap: () => _loadProducts(subcategory.name),
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
                                        subcategory.name,
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
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.72,
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
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 0.72,
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
          
          // Floating cart button moved to MainScreen
          const FloatingCartButton(),
        ],
      ),
    );
  }

  // Skeleton loading for product cards in SubcategoryProductsScreen
  Widget _buildSkeletonCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ),
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
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    // Clean white card matching Best Seller UI
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image (top) - Full fit without cropping sides - Only image is clickable
          Flexible(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                    // Heart icon for favorites
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
                      product.productName,
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
                      product.productName,
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
                            child: const Text(
                              '⭐ Best Seller',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          provider.text('add_to_cart'),
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
class ProductDetailsPage extends StatelessWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(product.productName, style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for floating button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(ApiService.getImageUrl(product.imageUrl), height: 260, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 260, color: Colors.grey[200]),
                ),
                const SizedBox(height: 12),
                Text(product.productName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: product.inStock
                        ? () {
                            provider.addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.productName} ${provider.text('added_to_cart')}')));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(product.inStock ? provider.text('add_to_cart') : provider.text('out_of_stock'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
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
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
      setState(() {
        _favoriteProducts = favorites;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ),
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
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0.5,
      ),
      body: _isLoading
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, kBottomNavigationBarHeight + 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.65,
              ),
              itemCount: 9, // Show 9 skeleton cards while loading
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
                        onPressed: _loadFavorites,
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
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, kBottomNavigationBarHeight + 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _favoriteProducts.length,
                      itemBuilder: (context, index) {
                        final product = _favoriteProducts[index];
                        return _buildProductCard(product, provider);
                      },
                    ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ?? 
        '${product.productName}_${product.weight}'.replaceAll(' ', '_').toLowerCase();
    final bool isFavorited = provider.isFavorite(productId);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailsPage(product: product)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                    // Heart icon for favorites
                    Positioned(
                      top: 8,
                      right: 8,
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
                            color: isFavorited ? Colors.red : Colors.grey[400],
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
                      product.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.weight,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
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

              if (qty == 0) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: product.inStock
                        ? () {
                            provider.addToCart(product);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: product.inStock ? const Color(0xFF4CAF50) : Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.white),
                    label: Text(
                      product.inStock ? 'Add to cart' : 'Out of stock',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              } else {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kPrimaryColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.remove, size: 16, color: kPrimaryColor),
                        onPressed: () {
                          if (qty > 1) {
                            provider.updateCartQuantity(cartItem!, qty - 1);
                          } else {
                            provider.updateCartQuantity(cartItem!, 0);
                          }
                        },
                      ),
                      Text(
                        '$qty',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.add, size: 16, color: kPrimaryColor),
                        onPressed: () {
                          provider.updateCartQuantity(cartItem!, qty + 1);
                        },
                      ),
                    ],
                  ),
                );
              }
            }),
          ),
        ],
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
      final response = await ApiService.getUserProfile(phone);
      final storeResponse = await ApiService.getStoreDetails(phone);
      print('DEBUG: API Response: $response');
      
      setState(() {
        _userProfile = response['user'];
        _storeDetails = storeResponse['store_details'];
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
          title: Text(provider.text('profile'), style: const TextStyle(color: kPrimaryColor)),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(provider.text('profile'), style: const TextStyle(color: kPrimaryColor)),
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
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: Text(provider.text('login_now'), style: const TextStyle(fontSize: 16)),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _loadUserProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
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
        title: Text(provider.text('profile'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: kPrimaryColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for navbar
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
                          onTap: () => _showEditProfileDialog(context, userName, userEmail, userPhone),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StoreDetailsScreen(userPhone: userPhone)),
              ),
            ),
            
            const Divider(height: 1),
            
            // Language
            _buildProfileOption(
              context,
              icon: Icons.language,
              title: 'Language',
              subtitle: provider.currentLanguage == 'en' ? 'English' : 'தமிழ்',
              onTap: () => _showLanguageDialog(context, provider),
            ),
            
            const Divider(height: 1),
            
            // Help & Support
            _buildProfileOption(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs, Contact us',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact: +91 1234567890')),
                );
              },
            ),
            
            const Divider(height: 1),
            
            // About
            _buildProfileOption(
              context,
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version & information',
              onTap: () => _showAboutDialog(context),
            ),
            
            const SizedBox(height: 32),
            
            // Logout Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout', style: TextStyle(fontSize: 16, color: Colors.white)),
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

  Future<void> _showEditProfileDialog(BuildContext context, String currentName, String currentEmail, String phone) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nameController = TextEditingController(text: currentName);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(provider.text('edit_profile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: provider.text('name'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(provider.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Only update name; email is intentionally omitted per design
                await ApiService.updateUserProfile(
                  phone,
                  nameController.text.trim(),
                  null,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadUserProfile();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.text('profile_updated'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${provider.text('error')}: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: Text(provider.text('save')),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  void _showLogoutDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(provider.text('logout')),
        content: Text(provider.text('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(provider.text('cancel')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: kPrimaryColor)),
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
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                        child: const Text('Retry'),
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
                            'No orders yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start shopping to see your orders here',
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
    final orderId = order['order_id'] ?? '';
    final totalAmount = order['total_amount'] ?? 0.0;
    final status = order['status'] ?? 'pending';
    final items = order['items'] as List? ?? [];
    final createdAt = order['created_at'] != null
        ? DateTime.parse(order['created_at'])
        : DateTime.now();

    // Format date as "Placed on October 19 2021"
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                        'July', 'August', 'September', 'October', 'November', 'December'];
    final formattedDate = 'Placed on ${monthNames[createdAt.month - 1]} ${createdAt.day} ${createdAt.year}';

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Items: ',
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
                            'Total: ',
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
                // Cancel button for pending orders (top right)
                if (status == 'pending')
                  IconButton(
                    onPressed: () => _showCancelOrderDialog(orderId),
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Cancel Order',
                  ),
              ],
            ),
            // Status at bottom right
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'delivered')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: const Text(
                      'Closed',
                      style: TextStyle(
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
                    child: const Text(
                      'Cancelled',
                      style: TextStyle(
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
                    child: const Text(
                      'Pending',
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cancelOrder(orderId);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );

      // Call API to cancel order
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/api/admin/orders/$orderId/status'),
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Order #${widget.orderId}', style: const TextStyle(color: kPrimaryColor)),
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
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrderDetails,
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildOrderDetails(),
    );
  }

  Widget _buildOrderDetails() {
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
                    const Text(
                      'Order Status',
                      style: TextStyle(
                        fontSize: 16,
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
                          fontSize: 13,
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
                      'Placed on $formattedDate',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map((item) => Padding(
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
                              item['product_name'] ?? 'Product',
                              style: const TextStyle(
                                fontSize: 15,
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
                )),
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
                const Text(
                  'Payment Information',
                  style: TextStyle(
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
                      'Payment Method',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      paymentMethod,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
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
                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deliveryAddress['street'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  Text(
                    '${deliveryAddress['city']}, ${deliveryAddress['state']} - ${deliveryAddress['pincode']}',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  if (deliveryAddress['landmark'] != null && deliveryAddress['landmark'].toString().isNotEmpty)
                    Text(
                      'Landmark: ${deliveryAddress['landmark']}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
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
                try {
                  await ApiService.addAddress(widget.userPhone, {
                    'street': streetController.text.trim(),
                    'city': cityController.text.trim(),
                    'state': stateController.text.trim(),
                    'pincode': pincodeController.text.trim(),
                    'landmark': landmarkController.text.trim(),
                    'is_default': isDefault,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadAddresses();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address added successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Save'),
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
                try {
                  await ApiService.updateAddress(widget.userPhone, index, {
                    'street': streetController.text.trim(),
                    'city': cityController.text.trim(),
                    'state': stateController.text.trim(),
                    'pincode': pincodeController.text.trim(),
                    'landmark': landmarkController.text.trim(),
                    'is_default': isDefault,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadAddresses();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Update'),
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
            child: const Text('Delete'),
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
      final response = await ApiService.getStoreDetails(widget.userPhone);
      final storeDetails = response['store_details'] as Map<String, dynamic>;
      
      setState(() {
        _storeNameController.text = storeDetails['store_name'] ?? '';
        _streetController.text = storeDetails['street'] ?? '';
        _cityController.text = storeDetails['city'] ?? '';
        _stateController.text = storeDetails['state'] ?? '';
        _pincodeController.text = storeDetails['pincode'] ?? '';
        _landmarkController.text = storeDetails['landmark'] ?? '';
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
          const SnackBar(
            content: Text('Store details saved successfully'),
            backgroundColor: kPrimaryColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Store Details', style: TextStyle(color: kPrimaryColor)),
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
                    const Text(
                      'Store Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your store details below',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Store Name
                    const Text(
                      'Store Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _storeNameController,
                      decoration: InputDecoration(
                        hintText: 'Enter store name',
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
                          return 'Store name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Street Address
                    const Text(
                      'Street Address',
                      style: TextStyle(
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
                        hintText: 'Enter street address',
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
                          return 'Street address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // City
                    const Text(
                      'City',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: 'Enter city',
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
                          return 'City is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // State
                    const Text(
                      'State',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        hintText: 'Enter state',
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
                          return 'State is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Pincode
                    const Text(
                      'Pincode',
                      style: TextStyle(
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
                        hintText: 'Enter pincode',
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
                          return 'Pincode is required';
                        }
                        if (value.length != 6) {
                          return 'Pincode must be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Landmark (Optional)
                    const Text(
                      'Landmark (Optional)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: InputDecoration(
                        hintText: 'Enter nearby landmark',
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
                            : const Text(
                                'Save Store Details',
                                style: TextStyle(
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
    final buttonWidth = screenWidth > 600 ? 280.0 : screenWidth * 0.55;
    
    // Calculate proper bottom position: bottom nav bar height (56) + desired gap (5)
    final calculatedBottom = bottomPosition ?? (kBottomNavigationBarHeight + 5);

    return Positioned(
      bottom: calculatedBottom,
      left: (screenWidth - buttonWidth) / 2,
      child: GestureDetector(
        onTap: () {
          // Try to find MainScreen in the widget tree first
          final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
          
          if (mainScreenState != null) {
            // We're inside MainScreen, just switch tab
            mainScreenState.setState(() {
              mainScreenState.currentIndex = 1; // Switch to cart tab (index 1)
            });
          } else {
            // We're in a pushed route (like subcategory page)
            // Use the global key to access MainScreen and pop back to it
            if (mainScreenKey.currentState != null) {
              // Pop back to MainScreen
              Navigator.of(context).popUntil((route) => route.isFirst);
              // Switch to cart tab
              mainScreenKey.currentState!.setState(() {
                mainScreenKey.currentState!.currentIndex = 1;
              });
            }
          }
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
                  const Text(
                    'View cart',
                    style: TextStyle(
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
