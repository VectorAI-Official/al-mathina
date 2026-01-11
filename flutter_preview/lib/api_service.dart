// API Service for AL-Madhina Flutter App
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

// LOCAL TESTING: Go backend on port 9000
// For Android Emulator/USB Debugging: 10.0.2.2 maps to host machine's localhost
// For iOS Simulator: use localhost
// For physical device on same WiFi: use your computer's local IP (e.g., 192.168.1.x)
const String BASE_URL = "http://192.168.1.6:9000";  // Physical USB device - use Windows host IP on LAN
const String API_BASE = "$BASE_URL/api/flutter";

// PRODUCTION: Backend URL on Render (uncomment for production)
// const String BASE_URL = "https://al-mathina-upcraft.onrender.com";
// const String API_BASE = "$BASE_URL/api/flutter";

// Fallback: Direct localhost (for iOS simulator or browser testing)
const String FALLBACK_URL = "http://10.0.2.2:9000";
const String FALLBACK_API_BASE = "$FALLBACK_URL/api/flutter";

// Simple in-memory cache with TTL
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;
  
  _CacheEntry(this.data, this.ttl) : timestamp = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class _ApiCache {
  static final Map<String, _CacheEntry> _cache = {};
  
  static T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T;
  }
  
  static void set<T>(String key, T data, Duration ttl) {
    _cache[key] = _CacheEntry(data, ttl);
  }
  
  static void clear([String? key]) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }
  
  static void clearExpired() {
    _cache.removeWhere((key, value) => value.isExpired);
  }
}

// Helper function to make HTTP requests with retry and fallback
Future<http.Response> _makeRequest(Uri uri, {Map<String, String>? headers, int retries = 2}) async {
  Exception? lastError;
  
  // Try primary URL first
  for (int i = 0; i < retries; i++) {
    try {
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );
      return response;
    } on SocketException catch (e) {
      lastError = e;
      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: 1));
      }
    } on TimeoutException catch (e) {
      lastError = e;
      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      lastError = Exception(e.toString());
      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }
  
  // If primary failed, try fallback URL (replace domain)
  try {
    final fallbackUri = Uri.parse(uri.toString().replaceFirst(BASE_URL, FALLBACK_URL));
    final response = await http.get(
      fallbackUri, 
      headers: {
        ...?headers,
        'Host': 'al-mathina-upcraft.onrender.com', // Keep original host header
      }
    ).timeout(const Duration(seconds: 15));
    return response;
  } catch (e) {
    // Both failed, throw the original error with helpful message
    throw Exception(
      'Cannot connect to server. Please:\n'
      '• Check your internet connection\n'
      '• Try switching between WiFi and Mobile Data\n'
      '• Or contact support if issue persists'
    );
  }
}

class MainCategory {
  final String id;
  final String name;
  final String imageUrl;
  final int productCount;
  final String section;
  final String mainCategory;
  final String? sectionId;  // New: ID-based reference
  final String? mainCategoryId;  // New: ID-based reference

  MainCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.productCount,
    required this.section,
    required this.mainCategory,
    this.sectionId,
    this.mainCategoryId,
  });

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    return MainCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      productCount: json['product_count'] ?? 0,
      section: json['section'] ?? '',
      mainCategory: json['main_category'] ?? '',
      sectionId: json['section_id'],
      mainCategoryId: json['main_category_id'],
    );
  }
}

class Section {
  final String title;
  final String icon;
  final String sectionName;
  final List<MainCategory> mainCategories;

  Section({
    required this.title,
    required this.icon,
    required this.sectionName,
    required this.mainCategories,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
      sectionName: json['section_name'] ?? '',
      mainCategories: (json['main_categories'] as List?)
          ?.map((item) => MainCategory.fromJson(item))
          .toList() ?? [],
    );
  }
}

class BestSellersSection {
  final String title;
  final String icon;
  final List<MainCategory> mainCategories;

  BestSellersSection({
    required this.title,
    required this.icon,
    required this.mainCategories,
  });

  factory BestSellersSection.fromJson(Map<String, dynamic> json) {
    return BestSellersSection(
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
      mainCategories: (json['main_categories'] as List?)
          ?.map((item) => MainCategory.fromJson(item))
          .toList() ?? [],
    );
  }
}

class HomeData {
  final BestSellersSection bestSellers;
  final List<Section> sections;

  HomeData({
    required this.bestSellers,
    required this.sections,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      bestSellers: json['best_sellers'] != null 
          ? BestSellersSection.fromJson(json['best_sellers'])
          : BestSellersSection(title: '', icon: '', mainCategories: []),
      sections: (json['sections'] as List?)
          ?.map((item) => Section.fromJson(item))
          .toList() ?? [],
    );
  }
}

class Subcategory {
  final String name;  // English name for API queries
  final String nameDisplay;  // Localized name for display
  final int productCount;
  final String icon;
  final String imageUrl;
  final String? subcategoryId;  // New: ID-based reference

  Subcategory({
    required this.name,
    required this.nameDisplay,
    required this.productCount,
    required this.icon,
    required this.imageUrl,
    this.subcategoryId,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      name: json['name'] ?? '',
      nameDisplay: json['name_display'] ?? json['name'] ?? '',  // Fallback to name if no display name
      productCount: json['product_count'] ?? 0,
      icon: json['icon'] ?? '',
      imageUrl: json['image_url'] ?? '',
      subcategoryId: json['subcategory_id'],
    );
  }
}

class Product {
  final String? itemId;  // Product ID
  final String? section;
  final String? mainCategory;
  final String? subcategory;
  final String productName;
  final String? productNameTa;
  final String weight;
  final double price;
  final double? buyingPrice;  // ⭐ NEW - Admin buying price (nullable)
  final String imageUrl;
  final int stock;
  final bool inStock;
  final bool isBestSeller;
  final String? description;
  final String? categorySection;
  final String? categoryMain;
  final String? categoryBreadcrumb;
  // New: ID-based references
  final String? categorySectionId;
  final String? categoryMainId;
  final String? categorySubId;

  Product({
    this.itemId,
    this.section,
    this.mainCategory,
    this.subcategory,
    required this.productName,
    this.productNameTa,
    required this.weight,
    required this.price,
    this.buyingPrice,  // ⭐ NEW - Optional admin field
    required this.imageUrl,
    required this.stock,
    required this.inStock,
    required this.isBestSeller,
    this.description,
    this.categorySection,
    this.categoryMain,
    this.categoryBreadcrumb,
    this.categorySectionId,
    this.categoryMainId,
    this.categorySubId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemId: json['item_id']?.toString(),
      section: json['section']?.toString(),
      mainCategory: json['main_category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      productName: json['product_name'] ?? 'Unknown Product',
      productNameTa: json['product_name_ta'],
      weight: json['weight'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      buyingPrice: json['buying_price'] != null   // ⭐ NEW - Parse buying price
          ? (json['buying_price'] as num).toDouble()
          : null,
      imageUrl: json['image_url'] ?? '',
      stock: json['stock'] ?? 0,
      inStock: json['in_stock'] ?? false,
      isBestSeller: json['is_best_seller'] ?? false,
      description: json['description'],
      categorySection: json['category_section'],
      categoryMain: json['category_main'],
      categoryBreadcrumb: json['category_breadcrumb'],
      categorySectionId: json['category_section_id'],
      categoryMainId: json['category_main_id'],
      categorySubId: json['category_sub_id'],
    );
  }

  // Get localized product name based on current language
  String getLocalizedName(String currentLanguage) {
    if (currentLanguage == 'ta' && productNameTa != null && productNameTa!.isNotEmpty) {
      return productNameTa!;
    }
    return productName;
  }
}

class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrev;

  PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalItems: json['total_items'] ?? json['total_products'] ?? 0, // Handle both field names
      hasNext: json['has_next'] ?? false,
      hasPrev: json['has_prev'] ?? false,
    );
  }
}

// ⭐ NEW - Admin-aware products response
class ProductsResponse {
  final List<Product> products;
  final bool isAdmin;
  final PaginationInfo pagination;
  final String? section;
  final String? mainCategory;
  final String? subcategory;

  ProductsResponse({
    required this.products,
    required this.isAdmin,
    required this.pagination,
    this.section,
    this.mainCategory,
    this.subcategory,
  });

  factory ProductsResponse.fromJson(Map<String, dynamic> json) {
    return ProductsResponse(
      products: (json['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList(),
      isAdmin: json['is_admin'] ?? false,
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
      section: json['section'],
      mainCategory: json['main_category'],
      subcategory: json['subcategory'],
    );
  }
}

class ApiService {
  // Cache management methods
  static void clearCache() {
    _ApiCache.clear();
    print('🗑️ All API cache cleared');
  }
  
  static void clearUserCache(String phone) {
    _ApiCache.clear('user_profile_$phone');
    _ApiCache.clear('store_details_$phone');
    print('🗑️ Cache cleared for user: $phone');
  }
  
  static void clearExpiredCache() {
    _ApiCache.clearExpired();
    print('🗑️ Expired cache entries cleared');
  }
  
  // Preload critical data at app startup
  static Future<void> preloadAppData({String? userPhone, String lang = 'en'}) async {
    final startTime = DateTime.now();
    print('\n═══════════════════════════════════════════════════════════');
    print('🚀 PRELOAD START at ${startTime.toIso8601String()}');
    print('   User Phone: ${userPhone ?? "NOT LOGGED IN"}');
    print('   Language: $lang');
    print('═══════════════════════════════════════════════════════════');
    
    try {
      // Preload home data (runs in background)
      final homeStartTime = DateTime.now();
      print('\n📡 [PRELOAD] Starting home data fetch...');
      
      getHomeData(lang: lang).then((data) {
        final duration = DateTime.now().difference(homeStartTime);
        print('✅ [PRELOAD] Home data preloaded successfully in ${duration.inMilliseconds}ms');
        print('   Sections: ${data.sections?.length ?? 0}');
        print('   Best Sellers: ${data.bestSellers?.mainCategories?.length ?? 0}');
      }).catchError((e) {
        final duration = DateTime.now().difference(homeStartTime);
        print('❌ [PRELOAD] Home data preload FAILED after ${duration.inMilliseconds}ms');
        print('   Error: $e');
      });
      
      // If user is logged in, preload their profile data
      if (userPhone != null && userPhone.isNotEmpty) {
        final userStartTime = DateTime.now();
        print('\n👤 [PRELOAD] Starting user data fetch for: $userPhone');
        
        // Run profile and store details in parallel
        Future.wait([
          getUserProfile(userPhone),
          getStoreDetails(userPhone).catchError((_) => <String, dynamic>{}),
        ]).then((results) {
          final duration = DateTime.now().difference(userStartTime);
          print('✅ [PRELOAD] User data preloaded successfully in ${duration.inMilliseconds}ms');
          print('   Profile: ${results[0] != null ? "Loaded" : "Failed"}');
          print('   Store: ${results[1].isNotEmpty ? "Loaded" : "Not found"}');
        }).catchError((e) {
          final duration = DateTime.now().difference(userStartTime);
          print('❌ [PRELOAD] User data preload FAILED after ${duration.inMilliseconds}ms');
          print('   Error: $e');
        });
      } else {
        print('\n⏭️  [PRELOAD] Skipping user data - not logged in');
      }
      
      final totalDuration = DateTime.now().difference(startTime);
      print('\n═══════════════════════════════════════════════════════════');
      print('✅ [PRELOAD] Preload initiated in ${totalDuration.inMilliseconds}ms');
      print('   (Background loading continues...)');
      print('═══════════════════════════════════════════════════════════\n');
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('\n❌ [PRELOAD] CRITICAL ERROR after ${duration.inMilliseconds}ms: $e');
      print('═══════════════════════════════════════════════════════════\n');
    }
  }

  // Update phone number
  static Future<Map<String, dynamic>> updatePhoneNumber(
      String oldPhone, String newPhone) async {
    try {
      print('📱 [API] Updating phone number: $oldPhone → $newPhone');
      final startTime = DateTime.now();

      final response = await http.put(
        Uri.parse('$BASE_URL/api/phone/$oldPhone'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'new_phone': newPhone}),
      );

      final duration = DateTime.now().difference(startTime);
      print('📡 [API] Phone update response: ${response.statusCode} in ${duration.inMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [API] Phone updated successfully: ${data['message']}');
        return data;
      } else if (response.statusCode == 409) {
        print('⚠️ [API] Phone number already exists');
        throw Exception('Phone number already registered to another user');
      } else if (response.statusCode == 404) {
        print('❌ [API] User not found');
        throw Exception('User not found');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        print('⚠️ [API] Invalid phone format: ${error['detail']}');
        throw Exception(error['detail'] ?? 'Invalid phone number format');
      } else {
        print('❌ [API] Unexpected status: ${response.statusCode}');
        throw Exception('Failed to update phone: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [API] Phone update error: $e');
      rethrow;
    }
  }
  
  static Future<HomeData> getHomeData({String lang = 'en'}) async {
    final startTime = DateTime.now();
    final cacheKey = 'home_data_$lang';
    
    try {
      // Check cache first (30 seconds TTL)
      print('\n🔍 [HOME] Checking cache for key: $cacheKey');
      final cached = _ApiCache.get<HomeData>(cacheKey);
      
      if (cached != null) {
        final duration = DateTime.now().difference(startTime);
        print('⚡ [HOME] CACHE HIT! Returned in ${duration.inMilliseconds}ms');
        print('   Sections: ${cached.sections?.length ?? 0}');
        print('   Lang: $lang');
        return cached;
      }
      
      print('💾 [HOME] Cache miss - fetching from server...');
      print('   Language: $lang');
      print('   URL: \$API_BASE/home');
      
      final fetchStartTime = DateTime.now();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecond;
      final response = await _makeRequest(
        Uri.parse('$API_BASE/home?lang=$lang&t=$timestamp&_=$random'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'Expires': '0',
          'If-Modified-Since': 'Thu, 1 Jan 1970 00:00:00 GMT',
        },
      );
      
      final fetchDuration = DateTime.now().difference(fetchStartTime);
      print('🌐 [HOME] Network request completed in ${fetchDuration.inMilliseconds}ms');
      print('   Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final parseStartTime = DateTime.now();
        final data = json.decode(response.body);
        final homeData = HomeData.fromJson(data);
        final parseDuration = DateTime.now().difference(parseStartTime);
        
        print('📦 [HOME] Data parsed in ${parseDuration.inMilliseconds}ms');
        print('   Sections: ${homeData.sections?.length ?? 0}');
        print('   Best Sellers: ${homeData.bestSellers?.mainCategories?.length ?? 0}');
        
        // Cache for 30 seconds
        _ApiCache.set(cacheKey, homeData, const Duration(seconds: 30));
        
        final totalDuration = DateTime.now().difference(startTime);
        print('✅ [HOME] Complete in ${totalDuration.inMilliseconds}ms (fetch: ${fetchDuration.inMilliseconds}ms, parse: ${parseDuration.inMilliseconds}ms)');
        print('   Cached with 30s TTL');
        
        return homeData;
      } else {
        print('❌ [HOME] Server error: ${response.statusCode}');
        throw Exception('Failed to load home data: ${response.statusCode}');
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [HOME] ERROR after ${duration.inMilliseconds}ms: $e');
      throw Exception('Error loading home data: $e');
    }
  }

  static Future<List<Subcategory>> getSubcategories({
    required String section,
    required String mainCategory,
    String lang = 'en',
  }) async {
    try {
      final response = await _makeRequest(
        Uri.parse('$API_BASE/main-category/$section/$mainCategory/subcategories?lang=$lang'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['subcategories'] as List)
            .map((item) => Subcategory.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load subcategories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading subcategories: $e');
    }
  }

  // ⭐ NEW - Admin-aware getProducts with userPhone parameter
  static Future<ProductsResponse> getProducts({
    String? section,
    String? mainCategory,
    String? subcategory,
    String? sectionId,  // New: ID-based filtering
    String? mainCategoryId,  // New: ID-based filtering
    String? subcategoryId,  // New: ID-based filtering
    String? userPhone,  // ⭐ NEW - Required for admin check
    int page = 1,
    int limit = 50,
    String lang = 'en',
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'lang': lang,
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // ⭐ NEW - Add user_phone for admin check
      if (userPhone != null && userPhone.isNotEmpty) {
        queryParams['user_phone'] = userPhone;
      }
      
      // Prefer ID-based queries over name-based queries
      if (sectionId != null) {
        queryParams['section_id'] = sectionId;
      } else if (section != null) {
        queryParams['section'] = section;
      }
      
      if (mainCategoryId != null) {
        queryParams['main_category_id'] = mainCategoryId;
      } else if (mainCategory != null) {
        queryParams['main_category'] = mainCategory;
      }
      
      if (subcategoryId != null) {
        queryParams['subcategory_id'] = subcategoryId;
      } else if (subcategory != null) {
        queryParams['subcategory'] = subcategory;
      }

      final uri = Uri.parse('$API_BASE/products').replace(queryParameters: queryParams);
      print('🔍 [ADMIN] Fetching products: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final productsResponse = ProductsResponse.fromJson(data);
        
        print('✅ [ADMIN] Products loaded: ${productsResponse.products.length}');
        print('👤 [ADMIN] Is Admin: ${productsResponse.isAdmin}');
        if (productsResponse.isAdmin && productsResponse.products.isNotEmpty) {
          final firstProduct = productsResponse.products.first;
          print('💰 [ADMIN] Sample buying price: ${firstProduct.buyingPrice}');
        }
        
        return productsResponse;
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ADMIN] Error loading products: $e');
      throw Exception('Error loading products: $e');
    }
  }

  // Legacy method for backward compatibility - returns Map
  static Future<Map<String, dynamic>> getProductsLegacy({
    String? section,
    String? mainCategory,
    String? subcategory,
    String? sectionId,
    String? mainCategoryId,
    String? subcategoryId,
    int page = 1,
    int limit = 50,
    String lang = 'en',
  }) async {
    final response = await getProducts(
      section: section,
      mainCategory: mainCategory,
      subcategory: subcategory,
      sectionId: sectionId,
      mainCategoryId: mainCategoryId,
      subcategoryId: subcategoryId,
      page: page,
      limit: limit,
      lang: lang,
    );
    return {
      'products': response.products,
      'pagination': response.pagination,
    };
  }

  static Future<Product> getProductDetails(String itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE/product/$itemId?t=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Product.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Product not found');
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading product details: $e');
    }
  }

  static Future<Map<String, dynamic>> searchProducts({
    required String query,
    int page = 1,
    int limit = 50,
    bool useRegex = false,
    String? userPhone,
  }) async {
    try {
      print('\n🔍 ========== SEARCH API CALL ==========');
      print('🔍 Query: $query');
      print('🔍 User Phone: ${userPhone ?? "NOT PROVIDED"}');
      
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'regex': useRegex.toString(),
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // Add user_phone if provided (for admin buying price display)
      if (userPhone != null && userPhone.isNotEmpty) {
        queryParams['user_phone'] = userPhone;
        print('✅ User phone added to query params');
      } else {
        print('❌ User phone NOT added (null or empty)');
      }
      
      final uri = Uri.parse('$API_BASE/search').replace(queryParameters: queryParams);
      print('🌐 Request URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      
      print('📡 Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response Data Keys: ${data.keys.toList()}');
        print('🔐 is_admin from backend: ${data['is_admin']}');
        print('📊 Results count: ${(data['results'] as List).length}');
        
        final productsList = (data['results'] as List)
            .map((item) => Product.fromJson(item))
            .toList();
            
        if (productsList.isNotEmpty) {
          final firstProduct = productsList.first;
          print('🔍 First Product: ${firstProduct.productName}');
          print('💰 First Product buying_price: ${firstProduct.buyingPrice}');
          print('💵 First Product price: ${firstProduct.price}');
        }
        
        final isAdmin = data['is_admin'] ?? false;
        print('✅ Final isAdmin value: $isAdmin');
        print('🔍 ========== END SEARCH API ==========\n');
        
        return {
          'results': productsList,
          'pagination': PaginationInfo.fromJson(data['pagination']),
          'query': data['query'],
          'isAdmin': isAdmin,  // Parse admin status
        };
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching products: $e');
    }
  }

  static String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    final trimmed = imagePath.trim();
    // If already absolute (http or https), return as-is
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    // Ensure leading slash for relative paths
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$BASE_URL$normalized';
  }

  // User Profile APIs
  static Future<Map<String, dynamic>> getUserProfile(String phone) async {
    final startTime = DateTime.now();
    final cacheKey = 'user_profile_$phone';
    
    try {
      print('\n🔍 [PROFILE] Checking cache for: $phone');
      final cached = _ApiCache.get<Map<String, dynamic>>(cacheKey);
      
      if (cached != null) {
        final duration = DateTime.now().difference(startTime);
        print('⚡ [PROFILE] CACHE HIT! Returned in ${duration.inMilliseconds}ms');
        return cached;
      }
      
      print('💾 [PROFILE] Cache miss - fetching from server...');
      final fetchStartTime = DateTime.now();
      final response = await http.get(Uri.parse('$BASE_URL/api/profile/$phone'));
      final fetchDuration = DateTime.now().difference(fetchStartTime);
      
      print('🌐 [PROFILE] Network request completed in ${fetchDuration.inMilliseconds}ms');
      print('   Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Cache for 60 seconds
        _ApiCache.set(cacheKey, data, const Duration(seconds: 60));
        
        final totalDuration = DateTime.now().difference(startTime);
        print('✅ [PROFILE] Complete in ${totalDuration.inMilliseconds}ms - Cached with 60s TTL');
        
        return data;
      } else {
        print('❌ [PROFILE] Server error: ${response.statusCode}');
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [PROFILE] ERROR after ${duration.inMilliseconds}ms: $e');
      throw Exception('Error loading user profile: $e');
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile(String phone, String? name, String? email) async {
    try {
      final response = await http.put(
        Uri.parse('$BASE_URL/api/profile/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        }),
      );
      if (response.statusCode == 200) {
        // Clear cache after update
        _ApiCache.clear('user_profile_$phone');
        _ApiCache.clear('store_details_$phone');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  static Future<Map<String, dynamic>> addAddress(String phone, Map<String, dynamic> address) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/api/address/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(address),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding address: $e');
    }
  }

  static Future<Map<String, dynamic>> updateAddress(String phone, int index, Map<String, dynamic> address) async {
    try {
      final response = await http.put(
        Uri.parse('$BASE_URL/api/address/$phone/$index'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(address),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating address: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteAddress(String phone, int index) async {
    try {
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/address/$phone/$index'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to delete address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting address: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserOrders(String phone) async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/api/orders/$phone'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading orders: $e');
    }
  }

  static Future<Map<String, dynamic>> createOrder({
    required String userPhone,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      print('\n🛒 [ORDER] Creating order...');
      print('📱 [ORDER] User phone: $userPhone');
      print('💰 [ORDER] Total amount: ₹$totalAmount');
      print('📦 [ORDER] Items count: ${items.length}');
      print('💳 [ORDER] Payment method: $paymentMethod');
      
      final orderData = {
        'user_phone': userPhone,
        'items': items,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'delivery_address': deliveryAddress,
        'status': 'pending',
      };
      
      final url = '$BASE_URL/api/orders';
      print('🌐 [ORDER] POST URL: $url');
      print('📤 [ORDER] Request body: ${json.encode(orderData).substring(0, 200)}...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );
      
      print('📡 [ORDER] Response status: ${response.statusCode}');
      print('📥 [ORDER] Response body: ${response.body.substring(0, min(500, response.body.length))}');
      
      if (response.statusCode == 200) {
        print('✅ [ORDER] Order created successfully!');
        return json.decode(response.body);
      } else {
        print('❌ [ORDER] Failed with status ${response.statusCode}');
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ORDER] Error: $e');
      throw Exception('Error creating order: $e');
    }
  }

  // Get order details
  static Future<Map<String, dynamic>> getOrderDetails(String phone, String orderId) async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/api/orders/$phone/$orderId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load order details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading order details: $e');
    }
  }

  // Store Details APIs
  static Future<Map<String, dynamic>> getStoreDetails(String phone) async {
    try {
      // Check cache first (60 seconds TTL)
      final cacheKey = 'store_details_$phone';
      final cached = _ApiCache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        print('✅ Returning cached store details for: $phone');
        return cached;
      }
      
      print('📡 Fetching fresh store details for: $phone');
      final response = await http.get(Uri.parse('$BASE_URL/api/store-details/$phone'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns {"success": true, "store_details": {...}}.
        // Unwrap and return the inner store_details map if present so callers
        // receive the address fields directly (street, city, state, pincode, landmark).
        Map<String, dynamic> result;
        if (data is Map && data.containsKey('store_details')) {
          result = Map<String, dynamic>.from(data['store_details'] ?? {});
        } else {
          // Fallback: return top-level map as a map<string,dynamic>
          result = Map<String, dynamic>.from(data);
        }
        
        // Cache for 60 seconds
        _ApiCache.set(cacheKey, result, const Duration(seconds: 60));
        print('✅ Cached store details for: $phone');
        
        return result;
      } else {
        throw Exception('Failed to load store details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading store details: $e');
    }
  }

  static Future<Map<String, dynamic>> updateStoreDetails(String phone, Map<String, dynamic> storeDetails) async {
    try {
      final response = await http.put(
        Uri.parse('$BASE_URL/api/store-details/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(storeDetails),
      );
      if (response.statusCode == 200) {
        // Clear cache after update
        _ApiCache.clear('store_details_$phone');
        _ApiCache.clear('user_profile_$phone');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update store details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating store details: $e');
    }
  }

  // Favorites APIs
  static Future<List<Product>> getFavorites(String phone) async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/api/favorites/$phone'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> favorites = data['favorites'] ?? [];
        return favorites.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load favorites: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading favorites: $e');
    }
  }

  static Future<Map<String, dynamic>> addFavorite(String phone, String itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/api/favorites/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_id': itemId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add favorite: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding favorite: $e');
    }
  }

  static Future<Map<String, dynamic>> removeFavorite(String phone, String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/favorites/$phone/$itemId'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to remove favorite: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error removing favorite: $e');
    }
  }
}
