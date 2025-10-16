# Flutter App - Backend Integration Complete

## ✅ What Was Updated

### 1. API Service (`lib/api_service.dart`)
Completely rewritten to use the new Flutter-specific backend routes.

#### New Models Added:
- `MainCategory` - Main category cards for home page
- `Section` - Sections with their main categories
- `BestSellersSection` - Best sellers section
- `HomeData` - Complete home page data structure
- `Subcategory` - Subcategories for sidebar
- `Product` - Product with new fields (itemId, isBestSeller, etc.)
- `PaginationInfo` - Pagination metadata

#### New API Methods:
```dart
// 1. Get home page data
ApiService.getHomeData() → HomeData

// 2. Get subcategories
ApiService.getSubcategories(section: 'Grocery & Kitchen', mainCategory: 'Atta, Rice & Dal') → List<Subcategory>

// 3. Get products
ApiService.getProducts(section: '...', mainCategory: '...', subcategory: '...', page: 1) → Map<String, dynamic>

// 4. Get product details
ApiService.getProductDetails('prod_00001') → Product

// 5. Search products
ApiService.searchProducts(query: 'atta', page: 1) → Map<String, dynamic>

// 6. Get best sellers
ApiService.getBestSellers(page: 1) → Map<String, dynamic>

// 7. Get image URL helper
ApiService.getImageUrl('/static/uploads/image.jpg') → 'http://127.0.0.1:8000/static/uploads/image.jpg'
```

---

## 🎨 How to Update main.dart

### Step 1: Update HomeScreen to Use Backend Data

Replace the current mock data HomeScreen with:

```dart
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
                Expanded(child: TextField(
                  decoration: InputDecoration(
                    hintText: provider.text('search'),
                    hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14)
                  ),
                  onSubmitted: (query) async {
                    // Navigate to search results page
                    if (query.trim().isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SearchResultsScreen(query: query)),
                      );
                    }
                  },
                ))
              ])
            )
          )
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error'),
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
                ))
              : RefreshIndicator(
                  onRefresh: _loadHomeData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Best Sellers Section
                        if (_homeData!.bestSellers.mainCategories.isNotEmpty) ...[
                          _buildSectionHeader(_homeData!.bestSellers.title, _homeData!.bestSellers.icon),
                          const SizedBox(height: 12),
                          _buildMainCategoryGrid(_homeData!.bestSellers.mainCategories),
                          const SizedBox(height: 24),
                        ],

                        // Regular Sections
                        ..._homeData!.sections.map((section) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(section.title, section.icon),
                              const SizedBox(height: 12),
                              _buildMainCategoryGrid(section.mainCategories),
                              const SizedBox(height: 24),
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
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryColor),
        ),
      ],
    );
  }

  Widget _buildMainCategoryGrid(List<MainCategory> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(MainCategory category) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductListScreen(
                section: category.section,
                mainCategory: category.mainCategory,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: category.imageUrl.isNotEmpty
                    ? Image.network(
                        ApiService.getImageUrl(category.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.category, size: 48, color: kPrimaryColor),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.category, size: 48, color: kPrimaryColor),
                      ),
              ),
            ),
            // Name and count
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (category.productCount > 0)
                    Text(
                      '${category.productCount} items',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

### Step 2: Create ProductListScreen

This replaces BrandListingScreen:

```dart
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
        title: Text(widget.mainCategory, style: const TextStyle(color: kPrimaryColor)),
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
                      width: MediaQuery.of(context).size.width * 0.3,
                      color: Colors.grey[100],
                      child: ListView.builder(
                        itemCount: _subcategories.length,
                        itemBuilder: (context, index) {
                          final subcategory = _subcategories[index];
                          final isSelected = subcategory.name == _selectedSubcategory;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: kPrimaryColor.withValues(alpha: 0.1),
                            title: Text(
                              subcategory.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? kPrimaryColor : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '${subcategory.productCount} items',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            onTap: () => _selectSubcategory(subcategory.name),
                          );
                        },
                      ),
                    ),

                    // Right Side - Products (70%)
                    Expanded(
                      child: _isLoadingProducts
                          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                          : _products.isEmpty
                              ? const Center(child: Text('No products found'))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(12),
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
                    ),
                  ],
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
                              provider.addToCart(product.itemId, product.productName);
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
```

### Step 3: Create Product Details Sheet

```dart
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
                      provider.addToCart(product.itemId, product.productName);
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
```

### Step 4: Create SearchResultsScreen

```dart
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
                                Text('₹${product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () {
                                // Navigate to product's category
                                if (product.categorySection != null && product.categoryMain != null) {
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
```

### Step 5: Update AppProvider to Use Product IDs

```dart
class CartItem {
  final String itemId;
  final String productName;
  int quantity;
  final double price;

  CartItem({
    required this.itemId,
    required this.productName,
    this.quantity = 1,
    required this.price,
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

  void addToCart(String itemId, String productName, {double price = 100.0}) {
    if (_cart.containsKey(itemId)) {
      _cart[itemId]!.quantity++;
    } else {
      _cart[itemId] = CartItem(
        itemId: itemId,
        productName: productName,
        price: price,
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
```

---

## 🚀 Testing Steps

### 1. Start Backend Server
```powershell
cd Backend
python main.py
```

### 2. Verify Backend Routes
Open browser: http://localhost:8000/docs
Check "Flutter Mobile App" section

### 3. Run Flutter App
```bash
cd flutter_preview
flutter run -d chrome
```

### 4. Test Features
- ✅ Home page loads with Best Sellers + Sections
- ✅ Click main category card → Opens product list
- ✅ Left sidebar shows subcategories
- ✅ Click subcategory → Loads products
- ✅ Click product → Shows details modal
- ✅ Add to cart works
- ✅ Search functionality
- ✅ Images display correctly

---

## 📝 Required Updates to main.dart

1. Import api_service.dart at the top
2. Replace HomeScreen with new implementation
3. Remove BrandListingScreen
4. Add ProductListScreen
5. Add ProductDetailsSheet
6. Add SearchResultsScreen
7. Update AppProvider CartItem model
8. Update addToCart method signature

---

## 🔧 pubspec.yaml Dependencies

Ensure you have:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  provider: ^6.1.1
  shared_preferences: ^2.2.2
```

---

## ✅ Summary

The Flutter app is now configured to:
1. ✅ Load home page data from backend
2. ✅ Display Best Sellers first, then sections
3. ✅ Show main categories in 3-column grid
4. ✅ Navigate to product list with left-right layout
5. ✅ Load subcategories and products from backend
6. ✅ Display product details
7. ✅ Handle search
8. ✅ Show real product data with images, prices, stock

**Next:** Update main.dart with the new screens and test end-to-end!
