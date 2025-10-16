import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';

const Color kPrimaryColor = Color(0xFF004D40);
const String kAppName = 'AL-Madhina';

const List<String> mockPaymentApps = ['Google Pay', 'PhonePe', 'Paytm'];

const Map<String, Map<String, String>> translations = {
  'en': {
    'home': 'Home',
    'cart': 'Cart',
    'profile': 'Profile',
    'search': 'Search Products...',
    'total': 'Grand Total:',
    'empty_cart': 'Your cart is empty!',
    'payment_upi': 'Pay via UPI/Apps',
    'cod': 'Cash on Delivery',
    'add_to_cart': 'Add to Cart',
    'shop': 'Shop by Category',
    'select_payment': 'Select Payment',
    'order_success': 'Order Placed via',
    'proceed': 'Proceed to Checkout',
    'available_apps': 'Available Apps:',
    'added': 'added to cart!',
    'order_summary': 'Order Summary',
    'place_order': 'Place Order',
  },
  'ta': {
    'home': 'முகப்பு',
    'cart': 'வண்டி',
    'profile': 'சுயவிவரம்',
    'search': 'பொருட்களை தேடுக...',
    'total': 'மொத்த தொகை:',
    'empty_cart': 'உங்கள் வண்டி காலியாக உள்ளது!',
    'payment_upi': 'யுபிஐ மூலம் பணம் செலுத்துங்கள்',
    'cod': 'பணம் செலுத்தி டெலிவரி',
    'add_to_cart': 'சேர்க்கவும்',
    'shop': 'வகை மூலம் வாங்கவும்',
    'select_payment': 'பணம் செலுத்தும் முறை',
    'order_success': 'ஆர்டர் வெற்றிகரமாக',
    'proceed': 'செக்அவுட்டுக்கு தொடரவும்',
    'available_apps': 'கிடைக்கும் பயன்பாடுகள்:',
    'added': 'வண்டியில் சேர்க்கப்பட்டது!',
    'order_summary': 'ஆர்டர் சுருக்கம்',
    'place_order': 'ஆர்டர் செய்',
  }
};

class CartItem {
  final String itemId;
  final String productName;
  final String weight;
  int quantity;
  final double price;
  final String imageUrl;

  CartItem({
    required this.itemId,
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

  String get currentLanguage => _currentLanguage;
  List<CartItem> get cartItems => _cart.values.toList();
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  String text(String key) => translations[_currentLanguage]![key] ?? key;

  void setLanguage(String lang) {
    if (translations.containsKey(lang)) {
      _currentLanguage = lang;
      notifyListeners();
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
        scaffoldBackgroundColor: Colors.grey[50],
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
        builder: (_) => isOldUser ? const MainScreen() : const PhoneAuthScreen(),
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
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Authentication'), centerTitle: true),
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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: provider.text('home'),
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (provider.cartCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${provider.cartCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: provider.text('cart'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: provider.text('profile'),
          ),
        ],
      ),
    );
  }
}

// HOME SCREEN - Fetches data from backend
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _homeData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final data = await ApiService.getHomeData();
      setState(() {
        _homeData = data;
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              kAppName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor),
            ),
            DropdownButton<String>(
              value: provider.currentLanguage,
              icon: const Icon(Icons.language, color: kPrimaryColor),
              underline: Container(),
              items: const [
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English', style: TextStyle(color: kPrimaryColor, fontSize: 14)),
                ),
                DropdownMenuItem(
                  value: 'ta',
                  child: Text('தமிழ்', style: TextStyle(color: kPrimaryColor, fontSize: 14)),
                ),
              ],
              onChanged: (value) {
                if (value != null) provider.setLanguage(value);
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade600, width: 1.25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: provider.text('search'),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadHomeData();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHomeData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Best Sellers Section
                        if (_homeData!.bestSellers.mainCategories.isNotEmpty) ...[
                          _buildSectionHeader(
                            _homeData!.bestSellers.title,
                            _homeData!.bestSellers.icon,
                          ),
                          const SizedBox(height: 12),
                          _buildMainCategoryGrid(_homeData!.bestSellers.mainCategories),
                          const SizedBox(height: 20),
                        ],

                        // Regular Sections
                        ..._homeData!.sections.map((section) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(section.title, section.icon),
                              const SizedBox(height: 12),
                              _buildMainCategoryGrid(section.mainCategories),
                              const SizedBox(height: 20),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, String icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

  Widget _buildMainCategoryGrid(List<MainCategory> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Changed to 4 columns to match the uploaded image
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.72, // Adjusted to prevent overflow - gives more vertical space
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
    
    return InkWell(
      onTap: () {
        if (isBestSeller) {
          // For Best Sellers, show all best seller products regardless of category
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BestSellerProductsScreen(),
            ),
          );
        } else {
          // For regular categories, navigate to product list with subcategories
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductListScreen(
                section: category.section,
                mainCategory: category.mainCategory,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image container with rounded corners and subtle shadow
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
          // Category name - clean and minimal
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              height: 1.2,
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
      body: _isLoadingSubcategories
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
                                      // Products grid
                                      Expanded(
                                        child: GridView.builder(
                                          padding: const EdgeInsets.all(12),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 0.58, // Reduced to give more vertical space
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
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          _showProductDetails(product);
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with bestseller badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            ApiService.getImageUrl(product.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey[100],
                              child: Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
                          ),
                  ),
                ),
                if (product.isBestSeller)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Bestseller',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.weight,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 3),
                  // Rating stars (compact)
                  Row(
                    children: [
                      ...List.generate(
                        4,
                        (index) => Icon(Icons.star, size: 10, color: Colors.orange[700]),
                      ),
                      Icon(Icons.star_border, size: 10, color: Colors.orange[700]),
                      const SizedBox(width: 3),
                      Text(
                        '(${product.stock})',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Price
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MRP ₹${(product.price * 1.2).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Discount badge (smaller)
                  if (product.inStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '20% OFF',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // ADD button (compact)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: product.inStock ? Colors.green : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        elevation: 0,
                      ),
                      onPressed: product.inStock
                          ? () {
                              provider.addToCart(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.productName} added to cart!'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        product.inStock ? 'ADD' : 'Out of Stock',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Search: "${widget.query}"'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No results found for "${widget.query}"'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final product = _results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(
                                      ApiService.getImageUrl(product.imageUrl),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.inventory_2),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.inventory_2),
                                    ),
                            ),
                            title: Text(product.productName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.categoryBreadcrumb != null)
                                  Text(
                                    product.categoryBreadcrumb!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                Text(
                                  '₹${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () {
                                // Navigate to product's category
                                if (product.categorySection != null &&
                                    product.categoryMain != null) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductListScreen(
                                        section: product.categorySection!,
                                        mainCategory: product.categoryMain!,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// CART SCREEN
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    provider.text('empty_cart'),
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                      );
                    },
                  ),
                ),
                // Total and Checkout
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
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckoutScreen(),
                              ),
                            );
                          },
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
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  _placeOrder(context, provider);
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

  void _placeOrder(BuildContext context, AppProvider provider) {
    final paymentMethod = _selectedPayment == 'upi'
        ? mockPaymentApps.first
        : provider.text('cod');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text(provider.text('order_success')),
          ],
        ),
        content: Text('$paymentMethod\n\nTotal: ₹${provider.cartTotal.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearCart();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// BEST SELLER PRODUCTS SCREEN
class BestSellerProductsScreen extends StatefulWidget {
  const BestSellerProductsScreen({super.key});

  @override
  State<BestSellerProductsScreen> createState() => _BestSellerProductsScreenState();
}

class _BestSellerProductsScreenState extends State<BestSellerProductsScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBestSellers();
  }

  Future<void> _loadBestSellers() async {
    try {
      final result = await ApiService.getBestSellers();
      setState(() {
        _products = result['products'] as List<Product>;
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
        title: const Text('⭐ Best Sellers', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _products.isEmpty
                  ? const Center(child: Text('No best sellers found'))
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showProductDetails(product);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
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

// PROFILE SCREEN
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('profile'), style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: kPrimaryColor,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'User Name',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '+91 9876543210',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.shopping_bag, color: kPrimaryColor),
            title: const Text('My Orders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: kPrimaryColor),
            title: const Text('Addresses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language, color: kPrimaryColor),
            title: const Text('Language'),
            subtitle: Text(provider.currentLanguage == 'en' ? 'English' : 'தமிழ்'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help, color: kPrimaryColor),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isOldUser');
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
