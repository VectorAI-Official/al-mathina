import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

const Color kPrimaryColor = Color(0xFF004D40);
const String kAppName = 'AL-Madhina';

const Map<String, List<String>> mockBrands = {
  'Atta': ['Aashirvaad', 'Pillsbury', 'Fortune', 'Patanjali'],
  'Soap': ['Lux', 'Dove', 'Lifebuoy', 'Santoor'],
  'Shampoo': ['Clinic Plus', 'Head & Shoulders', 'Tresemmé', 'Vatika'],
  'Paste': ['Colgate', 'Pepsodent', 'Dabur Red', 'Sensodyne'],
  'Oil': ['Sundrop', 'Saffola', 'Freedom', 'Gold Winner'],
  'Brush': ['Colgate', 'Oral-B', 'Pepsodent', 'Sensodyne'],
};

const List<String> mockPaymentApps = ['Google Pay', 'PhonePe', 'Paytm'];

const Map<String, Map<String, String>> translations = {
  'en': {
    'home': 'Home',
    'cart': 'Cart',
    'profile': 'Profile',
    'search': 'Search Products...',
    'brands': 'Brands',
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
    'category': 'Category:',
    'order_summary': 'Order Summary',
    'place_order': 'Place Order',
  },
  'ta': {
    'home': 'முகப்பு',
    'cart': 'வண்டி',
    'profile': 'சுயவிவரம்',
    'search': 'பொருட்களை தேடுக...',
    'brands': 'பிராண்டுகள்',
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
    'category': 'வகை:',
    'order_summary': 'ஆர்டர் சுருக்கம்',
    'place_order': 'ஆர்டர் செய்',
  }
};

class CartItem {
  final String category;
  final String brand;
  int quantity;
  final double price;

  CartItem({required this.category, required this.brand, this.quantity = 1, this.price = 100.0});
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

  void addToCart(String category, String brand) {
    String key = '$category-$brand';
    if (_cart.containsKey(key)) {
      _cart[key]!.quantity++;
    } else {
      _cart[key] = CartItem(category: category, brand: brand, price: 100.0 + (_cart.length * 5));
    }
    notifyListeners();
  }

  void updateCartQuantity(CartItem item, int newQuantity) {
    String key = '${item.category}-${item.brand}';
    if (newQuantity <= 0) {
      _cart.remove(key);
    } else {
      _cart[key]!.quantity = newQuantity;
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
  // Debug: try to eagerly load the Atta asset and log the result. This helps
  // diagnose missing asset issues in terminal logs when running on web/mobile.
  rootBundle.load('assets/categories/atta.png').then((_) {
    debugPrint('Atta asset loaded successfully');
  }).catchError((e) {
    debugPrint('Atta asset load failed: $e');
  });

  runApp(ChangeNotifierProvider(create: (context) => AppProvider(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$kAppName Wholesale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: kPrimaryColor, scaffoldBackgroundColor: Colors.grey[50], appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kPrimaryColor, elevation: 0.5), colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor), useMaterial3: true),
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => isOldUser ? const MainScreen() : const PhoneAuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text(kAppName, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kPrimaryColor)), SizedBox(height: 24), CircularProgressIndicator(color: kPrimaryColor)])),
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
    for (var controller in _otpControllers) { controller.dispose(); }
    for (var node in _otpFocusNodes) { node.dispose(); }
    _autoFillTimer?.cancel();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 10) {
      setState(() => _showOtp = true);
      _autoFillTimer = Timer(const Duration(seconds: 2), () {
        for (int i = 0; i < 6; i++) { _otpControllers[i].text = '123456'[i]; }
        _login();
      });
    }
  }

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOldUser', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(kAppName, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                  const SizedBox(height: 8),
                  const Text('Wholesale Authentication', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 48),
                  if (!_showOtp) Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Enter Mobile Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kPrimaryColor)), const SizedBox(height: 20), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)), child: const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))), const SizedBox(width: 12), Expanded(child: TextField(controller: _phoneController, keyboardType: TextInputType.phone, maxLength: 10, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(hintText: '10-digit number', counterText: ''), onChanged: _onPhoneChanged))])]))),
                  if (_showOtp) Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Enter OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kPrimaryColor)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (index) => SizedBox(width: 45, child: TextField(controller: _otpControllers[index], focusNode: _otpFocusNodes[index], keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(counterText: ''), onChanged: (value) { if (value.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus(); })))), const SizedBox(height: 16), const Center(child: Text('Auto-filling in 2 seconds...', style: TextStyle(fontSize: 12, color: Colors.grey)))]))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final screens = [const HomeScreen(), const CartScreen(), const ProfileScreen()];

    return Scaffold(
      body: Stack(
        children: [
          screens[_selectedIndex],
          // Floating Cart Summary Section
          if (provider.cartCount > 0)
            Positioned(
              // place the floating summary closer to the bottom nav to avoid large gap
              bottom: kBottomNavigationBarHeight - 40,
              left: 100,
              right: 100,
              child: GestureDetector(
                onTap: () {
                  // Navigate to CartScreen when tapping the floating section (excluding button)
                  setState(() => _selectedIndex = 1);
                },
                child: Container(
                  // slightly larger vertical padding so the panel doesn't visually overlap the nav
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Items: ${provider.cartCount}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${provider.cartTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: provider.cartCount == 0
                            ? null
                            : () {
                                // Navigate to CheckoutScreen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CheckoutScreen(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF4CAF50), // Green color matching the image
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: provider.text('home')),
          BottomNavigationBarItem(icon: Stack(children: [const Icon(Icons.shopping_cart), if (provider.cartCount > 0) Positioned(right: 0, child: Container(padding: const EdgeInsets.all(1), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)), constraints: const BoxConstraints(minWidth: 12, minHeight: 12), child: Text(provider.cartCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center)))]), label: provider.text('cart')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: provider.text('profile')),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(kAppName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor)),
            DropdownButton<String>(
              value: provider.currentLanguage,
              icon: const Icon(Icons.language, color: kPrimaryColor),
              underline: Container(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: kPrimaryColor, fontSize: 14))),
                DropdownMenuItem(value: 'ta', child: Text('தமிழ்', style: TextStyle(color: kPrimaryColor, fontSize: 14)))
              ],
              onChanged: (value) { if (value != null) provider.setLanguage(value); }
            )
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Colors.grey, size: 22),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: InputDecoration(hintText: provider.text('search'), hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14))))
              ])
            )
          )
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(provider.text('shop'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
              itemCount: mockBrands.keys.length,
              itemBuilder: (context, index) {
                final category = mockBrands.keys.elementAt(index);
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: InkWell(
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BrandListingScreen(categoryName: category))); },
                    borderRadius: BorderRadius.circular(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image / icon area fills available card space
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: Container(
                              color: Colors.grey[200],
                              width: double.infinity,
                              child: category == 'Atta'
                                  ? Image.asset(
                                      'assets/categories/atta.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => Center(child: Icon(_getIcon(category), size: 64, color: kPrimaryColor)),
                                    )
                                  : Center(child: Icon(_getIcon(category), size: 56, color: kPrimaryColor)),
                            ),
                          ),
                        ),

                        // Label area below image
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(category, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String category) {
    switch (category) {
      case 'Atta': return Icons.local_dining;
      case 'Soap': return Icons.soap;
      case 'Shampoo': return Icons.spa;
      case 'Paste': return Icons.paste;
      case 'Oil': return Icons.oil_barrel;
      case 'Brush': return Icons.brush;
      default: return Icons.category;
    }
  }
}

class BrandListingScreen extends StatelessWidget {
  final String categoryName;
  const BrandListingScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final brands = mockBrands[categoryName] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('$categoryName ${provider.text('brands')}'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButton<String>(
              value: provider.currentLanguage,
              icon: const Icon(Icons.language, color: kPrimaryColor),
              underline: Container(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: kPrimaryColor, fontSize: 14))),
                DropdownMenuItem(value: 'ta', child: Text('தமிழ்', style: TextStyle(color: kPrimaryColor, fontSize: 14)))
              ],
              onChanged: (value) { if (value != null) provider.setLanguage(value); }
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.text('brands'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: brands.length,
                    itemBuilder: (context, index) {
                      final brand = brands[index];
                      final itemKey = '$categoryName-$brand';
                      final cartItem = provider._cart[itemKey];
                      final currentQty = cartItem?.quantity ?? 0;
                      
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Product image area
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/brands/${brand.toLowerCase().replaceAll(' ', '_')}.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stack) => Container(
                                      color: Colors.grey[100],
                                      child: const Icon(Icons.image, size: 64, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Product info area
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Product title
                                    Text(
                                      brand,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    
                                    // Weight/size
                                    Text(
                                      '10kg box',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 4),
                                    
                                    // Price and stock row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '₹45.99',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Stock: 120',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Quantity controls
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Decrease button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                              onTap: currentQty > 0
                                                  ? () => provider.updateCartQuantity(cartItem!, currentQty - 1)
                                                  : null,
                                              child: Container(
                                                width: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                                                  ),
                                                ),
                                                child: const Text(
                                                  '-',
                                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          // Quantity input field
                                          Expanded(
                                            child: TextField(
                                              controller: TextEditingController(text: currentQty.toString())
                                                ..selection = TextSelection.fromPosition(
                                                  TextPosition(offset: currentQty.toString().length),
                                                ),
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              onSubmitted: (value) {
                                                final newQty = int.tryParse(value) ?? 0;
                                                if (newQty == 0 && currentQty > 0) {
                                                  provider.updateCartQuantity(cartItem!, 0);
                                                } else if (newQty > 0) {
                                                  if (currentQty == 0) {
                                                    provider.addToCart(categoryName, brand);
                                                    if (newQty > 1) {
                                                      final key = '$categoryName-$brand';
                                                      final item = provider._cart[key];
                                                      if (item != null) {
                                                        provider.updateCartQuantity(item, newQty);
                                                      }
                                                    }
                                                  } else {
                                                    provider.updateCartQuantity(cartItem!, newQty);
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                          
                                          // Increase button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                              onTap: () {
                                                if (currentQty == 0) {
                                                  provider.addToCart(categoryName, brand);
                                                } else {
                                                  provider.updateCartQuantity(cartItem!, currentQty + 1);
                                                }
                                              },
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF2196F3), // Blue color for + button
                                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                                                ),
                                                child: const Text(
                                                  '+',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
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
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom navigation bar — show the same tabs as MainScreen
          Container(
            color: Colors.white,
            child: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: const Icon(Icons.home), label: provider.text('home')),
                BottomNavigationBarItem(icon: const Icon(Icons.shopping_cart), label: provider.text('cart')),
                BottomNavigationBarItem(icon: const Icon(Icons.person), label: provider.text('profile')),
              ],
              currentIndex: 0,
              selectedItemColor: kPrimaryColor,
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                // open MainScreen with the selected tab
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(provider.text('cart'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor))),
      body: provider.cartItems.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.remove_shopping_cart, size: 80, color: Colors.grey), const SizedBox(height: 16), Text(provider.text('empty_cart'), style: const TextStyle(fontSize: 18, color: Colors.grey))]))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: provider.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = provider.cartItems[index];
                        
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Product image area
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/brands/${item.brand.toLowerCase().replaceAll(' ', '_')}.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stack) => Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.shopping_bag, size: 64, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Product info area
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Product title
                                      Text(
                                        item.brand,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      
                                      // Weight/size
                                      Text(
                                        '10kg box',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Price and stock row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${item.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            'Stock: 120',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Quantity controls
                                      Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Decrease button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                                onTap: () => provider.updateCartQuantity(item, item.quantity - 1),
                                                child: Container(
                                                  width: 40,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      right: BorderSide(color: Colors.grey[300]!, width: 1),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    '-',
                                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            
                                            // Quantity input field
                                            Expanded(
                                              child: TextField(
                                                controller: TextEditingController(text: item.quantity.toString())
                                                  ..selection = TextSelection.fromPosition(
                                                    TextPosition(offset: item.quantity.toString().length),
                                                  ),
                                                textAlign: TextAlign.center,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.zero,
                                                  isDense: true,
                                                ),
                                                onSubmitted: (value) {
                                                  final newQty = int.tryParse(value) ?? 0;
                                                  provider.updateCartQuantity(item, newQty);
                                                },
                                              ),
                                            ),
                                            
                                            // Increase button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                                onTap: () => provider.updateCartQuantity(item, item.quantity + 1),
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  alignment: Alignment.center,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF2196F3), // Blue color for + button
                                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                                                  ),
                                                  child: const Text(
                                                    '+',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                                  ),
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
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Add padding at bottom to prevent content from being hidden by floating cart
                const SizedBox(height: 100),
              ],
            ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    void processOrder(String method) {
      provider.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.text('order_success')} $method!'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      // Navigate back to home screen
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.text('proceed')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.text('order_summary'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: provider.cartItems.length,
                itemBuilder: (context, index) {
                  final item = provider.cartItems[index];
                  
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Product image area
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/brands/${item.brand.toLowerCase().replaceAll(' ', '_')}.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) => Container(
                                  color: Colors.grey[100],
                                  child: const Icon(Icons.shopping_bag, size: 64, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Product info area (read-only)
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.brand,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '10kg box',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${item.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      'Qty: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Subtotal: ₹${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimaryColor,
                                    ),
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
              ),
            ),
            const Divider(height: 30, thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.text('total'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${provider.cartTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              provider.text('select_payment'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => processOrder('UPI/Apps'),
              icon: const Icon(Icons.payment),
              label: Text(provider.text('payment_upi')),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueGrey,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => processOrder('COD'),
              icon: const Icon(Icons.money),
              label: Text(provider.text('cod')),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: kPrimaryColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              provider.text('available_apps'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: mockPaymentApps.map((app) => Chip(label: Text(app))).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(provider.text('profile'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor))),
      body: Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), Text(provider.text('profile'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('View orders and settings', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)), const SizedBox(height: 30), ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.history), label: const Text('Order History', style: TextStyle(fontSize: 16)), style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]))),
    );
  }
}
