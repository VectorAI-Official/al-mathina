// API Service for AL-Madhina Flutter App
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Production backend URL on Render (with Cloudflare CDN)
const String BASE_URL = "https://al-mathina.onrender.com";
const String API_BASE = "$BASE_URL/api/flutter";

// Fallback: Direct Cloudflare origin (in case main domain fails)
const String FALLBACK_URL = "https://gcp-us-west1-1.origin.onrender.com";
const String FALLBACK_API_BASE = "$FALLBACK_URL/api/flutter";

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
        'Host': 'al-mathina.onrender.com', // Keep original host header
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

class ApiService {
  static Future<HomeData> getHomeData({String lang = 'en'}) async {
    try {
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
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HomeData.fromJson(data);
      } else {
        throw Exception('Failed to load home data: ${response.statusCode}');
      }
    } catch (e) {
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

  static Future<Map<String, dynamic>> getProducts({
    String? section,
    String? mainCategory,
    String? subcategory,
    String? sectionId,  // New: ID-based filtering
    String? mainCategoryId,  // New: ID-based filtering
    String? subcategoryId,  // New: ID-based filtering
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
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'products': (data['products'] as List)
              .map((item) => Product.fromJson(item))
              .toList(),
          'pagination': PaginationInfo.fromJson(data['pagination']),
        };
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading products: $e');
    }
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
  }) async {
    try {
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'regex': useRegex.toString(),
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      final uri = Uri.parse('$API_BASE/search').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'results': (data['results'] as List)
              .map((item) => Product.fromJson(item))
              .toList(),
          'pagination': PaginationInfo.fromJson(data['pagination']),
          'query': data['query'],
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
    try {
      final response = await http.get(Uri.parse('$API_BASE/user/profile/$phone'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading user profile: $e');
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile(String phone, String? name, String? email) async {
    try {
      final response = await http.put(
        Uri.parse('$API_BASE/user/profile/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        }),
      );
      if (response.statusCode == 200) {
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
        Uri.parse('$API_BASE/user/address/$phone'),
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
        Uri.parse('$API_BASE/user/address/$phone/$index'),
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
        Uri.parse('$API_BASE/user/address/$phone/$index'),
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
      final response = await http.get(Uri.parse('$API_BASE/user/orders/$phone'));
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
      final orderData = {
        'user_phone': userPhone,
        'items': items,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'delivery_address': deliveryAddress,
        'status': 'pending',
      };
      
      final response = await http.post(
        Uri.parse('$API_BASE/user/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // Get order details
  static Future<Map<String, dynamic>> getOrderDetails(String phone, String orderId) async {
    try {
      final response = await http.get(Uri.parse('$API_BASE/user/orders/$phone/$orderId'));
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
      final response = await http.get(Uri.parse('$API_BASE/user/store-details/$phone'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns {"success": true, "store_details": {...}}.
        // Unwrap and return the inner store_details map if present so callers
        // receive the address fields directly (street, city, state, pincode, landmark).
        if (data is Map && data.containsKey('store_details')) {
          return Map<String, dynamic>.from(data['store_details'] ?? {});
        }
        // Fallback: return top-level map as a map<string,dynamic>
        return Map<String, dynamic>.from(data);
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
        Uri.parse('$API_BASE/user/store-details/$phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(storeDetails),
      );
      if (response.statusCode == 200) {
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
      final response = await http.get(Uri.parse('$API_BASE/user/favorites/$phone'));
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
        Uri.parse('$API_BASE/user/favorites/$phone'),
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
        Uri.parse('$API_BASE/user/favorites/$phone/$itemId'),
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
