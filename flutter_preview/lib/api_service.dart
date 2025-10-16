// API Service for AL-Madhina Flutter App
import 'dart:convert';
import 'package:http/http.dart' as http;

const String BASE_URL = "http://127.0.0.1:8000";
const String API_BASE = "$BASE_URL/api/flutter";

class MainCategory {
  final String id;
  final String name;
  final String imageUrl;
  final int productCount;
  final String section;
  final String mainCategory;

  MainCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.productCount,
    required this.section,
    required this.mainCategory,
  });

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    return MainCategory(
      id: json['id'],
      name: json['name'],
      imageUrl: json['image_url'] ?? '',
      productCount: json['product_count'],
      section: json['section'],
      mainCategory: json['main_category'],
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
      title: json['title'],
      icon: json['icon'],
      sectionName: json['section_name'],
      mainCategories: (json['main_categories'] as List)
          .map((item) => MainCategory.fromJson(item))
          .toList(),
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
      title: json['title'],
      icon: json['icon'],
      mainCategories: (json['main_categories'] as List)
          .map((item) => MainCategory.fromJson(item))
          .toList(),
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
      bestSellers: BestSellersSection.fromJson(json['best_sellers']),
      sections: (json['sections'] as List)
          .map((item) => Section.fromJson(item))
          .toList(),
    );
  }
}

class Subcategory {
  final String name;
  final int productCount;
  final String icon;

  Subcategory({
    required this.name,
    required this.productCount,
    required this.icon,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      name: json['name'],
      productCount: json['product_count'],
      icon: json['icon'],
    );
  }
}

class Product {
  final String? itemId;  // Changed to nullable
  final String productName;
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

  Product({
    this.itemId,  // Changed to optional
    required this.productName,
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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemId: json['item_id']?.toString(),  // Convert to string or null
      productName: json['product_name'] ?? 'Unknown Product',
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
    );
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
  static Future<HomeData> getHomeData() async {
    try {
      final response = await http.get(Uri.parse('$API_BASE/home'));
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
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE/main-category/$section/$mainCategory/subcategories'),
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
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (section != null) queryParams['section'] = section;
      if (mainCategory != null) queryParams['main_category'] = mainCategory;
      if (subcategory != null) queryParams['subcategory'] = subcategory;

      final uri = Uri.parse('$API_BASE/products').replace(queryParameters: queryParams);
      final response = await http.get(uri);
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
      final response = await http.get(Uri.parse('$API_BASE/product/$itemId'));
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
  }) async {
    try {
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = Uri.parse('$API_BASE/search').replace(queryParameters: queryParams);
      final response = await http.get(uri);
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

  static Future<Map<String, dynamic>> getBestSellers({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = Uri.parse('$API_BASE/best-sellers').replace(queryParameters: queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'products': (data['products'] as List)
              .map((item) => Product.fromJson(item))
              .toList(),
          'pagination': PaginationInfo.fromJson(data['pagination']),
        };
      } else {
        throw Exception('Failed to load best sellers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading best sellers: $e');
    }
  }

  static String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    return '$BASE_URL$imagePath';
  }
}
