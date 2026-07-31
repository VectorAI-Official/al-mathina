import 'package:flutter/foundation.dart';
import '../api_service.dart';
import '../utils/weight_utils.dart';

/// A single item added to the return cart.
///
/// Mirrors the shape of `CartItem` in `main.dart` but lives in its own
/// provider so the return flow is completely isolated from the regular
/// order cart (`AppProvider._cart`).
class ReturnCartItem {
  final String itemId;
  final String? section;
  final String? mainCategory;
  final String? subcategory;
  final String productName;
  final String? productNameTa;
  final String weight;
  final String unit; // e.g., "kg", "liters", "pieces"
  int quantity;
  final double price;
  final String imageUrl;

  ReturnCartItem({
    required this.itemId,
    this.section,
    this.mainCategory,
    this.subcategory,
    required this.productName,
    this.productNameTa,
    required this.weight,
    this.unit = '',
    this.quantity = 1,
    required this.price,
    required this.imageUrl,
  });

  double get subtotal {
    final effectivePrice = calculateEffectivePrice(price, weight, unit);
    return quantity * effectivePrice;
  }

  String getLocalizedName(String language) {
    if (language == 'ta' && productNameTa != null && productNameTa!.isNotEmpty) {
      return productNameTa!;
    }
    return productName;
  }
}

/// Manages the return cart used by the "Return Item" flow.
///
/// This is deliberately isolated from `AppProvider._cart` — it is never
/// read or written by checkout or order creation.
class ReturnCartProvider extends ChangeNotifier {
  final Map<String, ReturnCartItem> _returnCart = {};

  List<ReturnCartItem> get returnCartItems => _returnCart.values.toList();

  int get returnCartCount =>
      _returnCart.values.fold(0, (sum, item) => sum + item.quantity);

  double get returnCartTotal =>
      _returnCart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _returnCart.isEmpty;

  int quantityOf(String itemId) => _returnCart[itemId]?.quantity ?? 0;

  void addToReturnCart(Product product) {
    final String productId = product.itemId ??
        '${product.productName}_${product.weight}'
            .replaceAll(' ', '_')
            .toLowerCase();

    if (_returnCart.containsKey(productId)) {
      _returnCart[productId]!.quantity++;
    } else {
      _returnCart[productId] = ReturnCartItem(
        itemId: productId,
        section: product.section,
        mainCategory: product.mainCategory,
        subcategory: product.subcategory,
        productName: product.productName,
        productNameTa: product.productNameTa,
        weight: product.weight,
        unit: product.unit,
        price: product.price,
        imageUrl: product.imageUrl,
      );
    }
    notifyListeners();
  }

  void updateReturnQuantity(String id, int newQuantity) {
    final item = _returnCart[id];
    if (item == null) return;

    if (newQuantity <= 0) {
      _returnCart.remove(id);
    } else {
      item.quantity = newQuantity;
    }
    notifyListeners();
  }

  void removeFromReturnCart(String id) {
    if (_returnCart.remove(id) != null) {
      notifyListeners();
    }
  }

  void clearReturnCart() {
    _returnCart.clear();
    notifyListeners();
  }
}
