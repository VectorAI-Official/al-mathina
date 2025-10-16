// API Service for AL-Madhina Flutter App// API Service for AL-Madhina Flutter App

// Handles all HTTP communication with the FastAPI backend.// Handles all HTTP communication with the FastAPI backend.



import 'dart:convert';import 'dart:convert';

import 'package:http/http.dart' as http;import 'package:http/http.dart' as http;



// Base URL for the FastAPI backend running on localhost// Base URL for the FastAPI backend running on localhost

const String BASE_URL = "http://127.0.0.1:8000";const String BASE_URL = "http://127.0.0.1:8000";

const String API_BASE = "$BASE_URL/api/flutter";const String API_BASE = "$BASE_URL/api/flutter";



/// Main Category model for home page cards/// Main Category model for home page cards

class MainCategory {class MainCategory {

  final String id;  final String id;

  final String name;  final String name;

  final String imageUrl;  final String imageUrl;

  final int productCount;  final int productCount;

  final String section;  final String section;

  final String mainCategory;  final String mainCategory;



  MainCategory({  MainCategory({

    required this.id,    required this.id,

    required this.name,    required this.name,

    required this.imageUrl,    required this.imageUrl,

    required this.productCount,    required this.productCount,

    required this.section,    required this.section,

    required this.mainCategory,    required this.mainCategory,

  });  });



  factory MainCategory.fromJson(Map<String, dynamic> json) {  factory MainCategory.fromJson(Map<String, dynamic> json) {

    return MainCategory(    return MainCategory(

      id: json['id'],      id: json['id'],

      name: json['name'],      name: json['name'],

      imageUrl: json['image_url'] ?? '',      imageUrl: json['image_url'] ?? '',

      productCount: json['product_count'],      productCount: json['product_count'],

      section: json['section'],      section: json['section'],

      mainCategory: json['main_category'],      mainCategory: json['main_category'],

    );    );

  }  }

}}



/// Section model for home page/// Section model for home page

class Section {class Section {

  final String title;  final String title;

  final String icon;  final String icon;

  final String sectionName;  final String sectionName;

  final List<MainCategory> mainCategories;  final List<MainCategory> mainCategories;



  Section({  Section({

    required this.title,    required this.title,

    required this.icon,    required this.icon,

    required this.sectionName,    required this.sectionName,

    required this.mainCategories,    required this.mainCategories,

  });  });



  factory Section.fromJson(Map<String, dynamic> json) {  factory Section.fromJson(Map<String, dynamic> json) {

    return Section(    return Section(

      title: json['title'],      title: json['title'],

      icon: json['icon'],      icon: json['icon'],

      sectionName: json['section_name'],      sectionName: json['section_name'],

      mainCategories: (json['main_categories'] as List)      mainCategories: (json['main_categories'] as List)

          .map((cat) => MainCategory.fromJson(cat))          .map((cat) => MainCategory.fromJson(cat))

          .toList(),          .toList(),

    );    );

  }  }

}}



/// Best Sellers section model/// Best Sellers section model

class BestSellersSection {class BestSellersSection {

  final String title;  final String title;

  final String icon;  final String icon;

  final List<MainCategory> mainCategories;  final List<MainCategory> mainCategories;



  BestSellersSection({  BestSellersSection({

    required this.title,    required this.title,

    required this.icon,    required this.icon,

    required this.mainCategories,    required this.mainCategories,

  });  });



  factory BestSellersSection.fromJson(Map<String, dynamic> json) {  factory BestSellersSection.fromJson(Map<String, dynamic> json) {

    return BestSellersSection(    return BestSellersSection(

      title: json['title'],      title: json['title'],

      icon: json['icon'],      icon: json['icon'],

      mainCategories: (json['main_categories'] as List)      mainCategories: (json['main_categories'] as List)

          .map((cat) => MainCategory.fromJson(cat))          .map((cat) => MainCategory.fromJson(cat))

          .toList(),          .toList(),

    );    );

  }  }

}}



/// Home page data model/// Home page data model

class HomeData {class HomeData {

  final BestSellersSection bestSellers;  final BestSellersSection bestSellers;

  final List<Section> sections;  final List<Section> sections;



  HomeData({  HomeData({

    required this.bestSellers,    required this.bestSellers,

    required this.sections,    required this.sections,

  });  });



  factory HomeData.fromJson(Map<String, dynamic> json) {  factory HomeData.fromJson(Map<String, dynamic> json) {

    return HomeData(    return HomeData(

      bestSellers: BestSellersSection.fromJson(json['best_sellers']),      bestSellers: BestSellersSection.fromJson(json['best_sellers']),

      sections: (json['sections'] as List)      sections: (json['sections'] as List)

          .map((sec) => Section.fromJson(sec))          .map((sec) => Section.fromJson(sec))

          .toList(),          .toList(),

    );    );

  }  }

}}



/// Subcategory model/// Subcategory model

class Subcategory {class Subcategory {

  final String name;  final String name;

  final int productCount;  final int productCount;

  final String icon;  final String icon;



  Subcategory({  Subcategory({

    required this.name,    required this.name,

    required this.productCount,    required this.productCount,

    required this.icon,    required this.icon,

  });  });



  factory Subcategory.fromJson(Map<String, dynamic> json) {  factory Subcategory.fromJson(Map<String, dynamic> json) {

    return Subcategory(    return Subcategory(

      name: json['name'],      name: json['name'],

      productCount: json['product_count'],      productCount: json['product_count'],

      icon: json['icon'] ?? '📦',      icon: json['icon'] ?? '📦',

    );    );

  }  }

}}



/// Product model matching the backend response/// Product model matching the backend response

class Product {class Product {

  final String itemId;  final String itemId;

  final String productName;  final String productName;

  final String weight;  final String weight;

  final double price;  final double price;

  final String imageUrl;  final String imageUrl;

  final int stock;  final int stock;

  final bool inStock;  final bool inStock;

  final bool isBestSeller;  final bool isBestSeller;

  final String? description;  final String? description;

  final String? categorySection;  final String? categorySection;

  final String? categoryMain;  final String? categoryMain;

  final String? categorySub;  final String? categorySub;

  final String? categoryBreadcrumb;

  Product({

  Product({    required this.itemId,

    required this.itemId,    required this.productName,

    required this.productName,    required this.weight,

    required this.weight,    required this.price,

    required this.price,    required this.imageUrl,

    required this.imageUrl,    required this.stock,

    required this.stock,    required this.inStock,

    required this.inStock,    required this.isBestSeller,

    required this.isBestSeller,    this.description,

    this.description,    this.categorySection,

    this.categorySection,    this.categoryMain,

    this.categoryMain,    this.categorySub,

    this.categorySub,  });

    this.categoryBreadcrumb,

  });  factory Product.fromJson(Map<String, dynamic> json) {

    return Product(

  factory Product.fromJson(Map<String, dynamic> json) {      itemId: json['item_id'],

    return Product(      productName: json['product_name'],

      itemId: json['item_id'],      weight: json['weight'] ?? '',

      productName: json['product_name'],      price: (json['price'] as num).toDouble(),

      weight: json['weight'] ?? '',      imageUrl: json['image_url'] ?? '',

      price: (json['price'] as num).toDouble(),      stock: json['stock'],

      imageUrl: json['image_url'] ?? '',      inStock: json['in_stock'] ?? (json['stock'] > 0),

      stock: json['stock'],      isBestSeller: json['is_best_seller'] ?? false,

      inStock: json['in_stock'] ?? (json['stock'] > 0),      description: json['description'],

      isBestSeller: json['is_best_seller'] ?? false,      categorySection: json['section'],

      description: json['description'],      categoryMain: json['main_category'],

      categorySection: json['section'],      categorySub: json['subcategory'],

      categoryMain: json['main_category'],    );

      categorySub: json['subcategory'],  }

      categoryBreadcrumb: json['category_breadcrumb'],}

    );

  }/// API Service class for backend communication

}class ApiService {

  /// Get all categories from MongoDB

/// Pagination info  static Future<List<Category>> getCategories() async {

class PaginationInfo {    try {

  final int currentPage;      final response = await http.get(

  final int totalPages;        Uri.parse('$BASE_URL/api/inventory/sections'),

  final int totalProducts;      );

  final int perPage;

  final bool hasNext;      if (response.statusCode == 200) {

  final bool hasPrev;        final data = json.decode(response.body);

        final categories = (data['categories'] as List)

  PaginationInfo({            .map((cat) => Category.fromJson(cat))

    required this.currentPage,            .toList();

    required this.totalPages,        return categories;

    required this.totalProducts,      } else {

    required this.perPage,        throw Exception('Failed to load categories: ${response.statusCode}');

    required this.hasNext,      }

    required this.hasPrev,    } catch (e) {

  });      print('Error fetching categories: $e');

      rethrow;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {    }

    return PaginationInfo(  }

      currentPage: json['current_page'],

      totalPages: json['total_pages'],  /// Get products, optionally filtered by category and/or brand

      totalProducts: json['total_products'] ?? json['total_results'] ?? 0,  static Future<List<Product>> getProducts({

      perPage: json['per_page'],    String? category,

      hasNext: json['has_next'],    String? brand,

      hasPrev: json['has_prev'],  }) async {

    );    try {

  }      var uri = Uri.parse('$BASE_URL/api/inventory/products');

}      

      // Add query parameters

/// API Service class for backend communication      final queryParams = <String, String>{};

class ApiService {      if (category != null) queryParams['category'] = category;

  /// Get home page data (Best Sellers + All Sections with Main Categories)      if (brand != null) queryParams['brand'] = brand;

  static Future<HomeData> getHomeData() async {      

    try {      uri = uri.replace(queryParameters: queryParams);

      final response = await http.get(

        Uri.parse('$API_BASE/home'),      final response = await http.get(uri);

      );

      if (response.statusCode == 200) {

      if (response.statusCode == 200) {        final data = json.decode(response.body);

        final data = json.decode(response.body);        final products = (data['products'] as List)

        return HomeData.fromJson(data);            .map((prod) => Product.fromJson(prod))

      } else {            .toList();

        throw Exception('Failed to load home data: ${response.statusCode}');        return products;

      }      } else {

    } catch (e) {        throw Exception('Failed to load products: ${response.statusCode}');

      print('Error fetching home data: $e');      }

      rethrow;    } catch (e) {

    }      print('Error fetching products: $e');

  }      rethrow;

    }

  /// Get subcategories for a main category  }

  static Future<List<Subcategory>> getSubcategories({

    required String section,  /// Get a specific product by category and brand

    required String mainCategory,  static Future<Product> getProduct(String category, String brand) async {

  }) async {    try {

    try {      final response = await http.get(

      final encodedSection = Uri.encodeComponent(section);        Uri.parse('$BASE_URL/api/inventory/products/$category/$brand'),

      final encodedMain = Uri.encodeComponent(mainCategory);      );

      

      final response = await http.get(      if (response.statusCode == 200) {

        Uri.parse('$API_BASE/main-category/$encodedSection/$encodedMain/subcategories'),        return Product.fromJson(json.decode(response.body));

      );      } else {

        throw Exception('Failed to load product: ${response.statusCode}');

      if (response.statusCode == 200) {      }

        final data = json.decode(response.body);    } catch (e) {

        final subcategories = (data['subcategories'] as List)      print('Error fetching product: $e');

            .map((sub) => Subcategory.fromJson(sub))      rethrow;

            .toList();    }

        return subcategories;  }

      } else {

        throw Exception('Failed to load subcategories: ${response.statusCode}');  /// Add item to cart

      }  static Future<void> addToCart({

    } catch (e) {    required String userId,

      print('Error fetching subcategories: $e');    required String category,

      rethrow;    required String brand,

    }    required int quantity,

  }  }) async {

    try {

  /// Get products for a subcategory with pagination      final response = await http.post(

  static Future<Map<String, dynamic>> getProducts({        Uri.parse('$BASE_URL/api/cart/add'),

    required String section,        headers: {'Content-Type': 'application/json'},

    required String mainCategory,        body: json.encode({

    required String subcategory,          'user_id': userId,

    int page = 1,          'category': category,

    int limit = 20,          'brand': brand,

  }) async {          'quantity': quantity,

    try {        }),

      final queryParams = {      );

        'section': section,

        'main_category': mainCategory,      if (response.statusCode != 200) {

        'subcategory': subcategory,        throw Exception('Failed to add to cart: ${response.statusCode}');

        'page': page.toString(),      }

        'limit': limit.toString(),    } catch (e) {

      };      print('Error adding to cart: $e');

      rethrow;

      final uri = Uri.parse('$API_BASE/products').replace(queryParameters: queryParams);    }

      final response = await http.get(uri);  }



      if (response.statusCode == 200) {  /// Get user's cart

        final data = json.decode(response.body);  static Future<Map<String, dynamic>> getCart(String userId) async {

        final products = (data['products'] as List)    try {

            .map((prod) => Product.fromJson(prod))      final response = await http.get(

            .toList();        Uri.parse('$BASE_URL/api/cart/$userId'),

        final pagination = PaginationInfo.fromJson(data['pagination']);      );

        

        return {      if (response.statusCode == 200) {

          'products': products,        return json.decode(response.body);

          'pagination': pagination,      } else {

        };        throw Exception('Failed to load cart: ${response.statusCode}');

      } else {      }

        throw Exception('Failed to load products: ${response.statusCode}');    } catch (e) {

      }      print('Error fetching cart: $e');

    } catch (e) {      rethrow;

      print('Error fetching products: $e');    }

      rethrow;  }

    }

  }  /// Update cart item quantity

  static Future<void> updateCartQuantity({

  /// Get a specific product by item ID    required int cartItemId,

  static Future<Product> getProductDetails(String itemId) async {    required int quantity,

    try {  }) async {

      final response = await http.get(    try {

        Uri.parse('$API_BASE/product/$itemId'),      final response = await http.put(

      );        Uri.parse('$BASE_URL/api/cart/$cartItemId'),

        headers: {'Content-Type': 'application/json'},

      if (response.statusCode == 200) {        body: json.encode({'quantity': quantity}),

        final data = json.decode(response.body);      );

        return Product.fromJson(data);

      } else {      if (response.statusCode != 200 && response.statusCode != 204) {

        throw Exception('Failed to load product: ${response.statusCode}');        throw Exception('Failed to update cart: ${response.statusCode}');

      }      }

    } catch (e) {    } catch (e) {

      print('Error fetching product details: $e');      print('Error updating cart: $e');

      rethrow;      rethrow;

    }    }

  }  }



  /// Search products globally  /// Clear user's cart

  static Future<Map<String, dynamic>> searchProducts({  static Future<void> clearCart(String userId) async {

    required String query,    try {

    int page = 1,      final response = await http.delete(

    int limit = 20,        Uri.parse('$BASE_URL/api/cart/$userId/clear'),

  }) async {      );

    try {

      final queryParams = {      if (response.statusCode != 200) {

        'q': query,        throw Exception('Failed to clear cart: ${response.statusCode}');

        'page': page.toString(),      }

        'limit': limit.toString(),    } catch (e) {

      };      print('Error clearing cart: $e');

      rethrow;

      final uri = Uri.parse('$API_BASE/search').replace(queryParameters: queryParams);    }

      final response = await http.get(uri);  }



      if (response.statusCode == 200) {  /// Create a new order

        final data = json.decode(response.body);  static Future<Map<String, dynamic>> createOrder({

        final results = (data['results'] as List)    required String userId,

            .map((prod) => Product.fromJson(prod))    required List<Map<String, dynamic>> items,

            .toList();    required String paymentMethod,

        final pagination = PaginationInfo.fromJson(data['pagination']);    required double totalAmount,

          }) async {

        return {    try {

          'query': data['query'],      final response = await http.post(

          'results': results,        Uri.parse('$BASE_URL/api/orders/create'),

          'pagination': pagination,        headers: {'Content-Type': 'application/json'},

        };        body: json.encode({

      } else {          'user_id': userId,

        throw Exception('Failed to search products: ${response.statusCode}');          'items': items,

      }          'payment_method': paymentMethod,

    } catch (e) {          'total_amount': totalAmount,

      print('Error searching products: $e');        }),

      rethrow;      );

    }

  }      if (response.statusCode == 200) {

        return json.decode(response.body);

  /// Get all best seller products      } else {

  static Future<Map<String, dynamic>> getBestSellers({        throw Exception('Failed to create order: ${response.statusCode}');

    int page = 1,      }

    int limit = 20,    } catch (e) {

  }) async {      print('Error creating order: $e');

    try {      rethrow;

      final queryParams = {    }

        'page': page.toString(),  }

        'limit': limit.toString(),

      };  /// Get user's order history

  static Future<List<dynamic>> getOrders(String userId) async {

      final uri = Uri.parse('$API_BASE/best-sellers').replace(queryParameters: queryParams);    try {

      final response = await http.get(uri);      final response = await http.get(

        Uri.parse('$BASE_URL/api/orders/user/$userId'),

      if (response.statusCode == 200) {      );

        final data = json.decode(response.body);

        final products = (data['products'] as List)      if (response.statusCode == 200) {

            .map((prod) => Product.fromJson(prod))        final data = json.decode(response.body);

            .toList();        return data['orders'];

        final pagination = PaginationInfo.fromJson(data['pagination']);      } else {

                throw Exception('Failed to load orders: ${response.statusCode}');

        return {      }

          'products': products,    } catch (e) {

          'pagination': pagination,      print('Error fetching orders: $e');

        };      rethrow;

      } else {    }

        throw Exception('Failed to load best sellers: ${response.statusCode}');  }

      }

    } catch (e) {  /// Health check - verify backend is running

      print('Error fetching best sellers: $e');  static Future<Map<String, dynamic>> healthCheck() async {

      rethrow;    try {

    }      final response = await http.get(

  }        Uri.parse('$BASE_URL/health'),

      );

  /// Helper method to get full image URL

  static String getImageUrl(String imagePath) {      if (response.statusCode == 200) {

    if (imagePath.isEmpty) return '';        return json.decode(response.body);

    if (imagePath.startsWith('http')) return imagePath;      } else {

    return '$BASE_URL$imagePath';        throw Exception('Health check failed: ${response.statusCode}');

  }      }

}    } catch (e) {

      print('Error in health check: $e');
      rethrow;
    }
  }
}
