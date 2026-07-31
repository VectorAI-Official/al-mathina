import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../main.dart';
import '../providers/return_cart_provider.dart';
import '../utils/weight_utils.dart';
import '../widgets/floating_return_cart_button.dart';
import '../widgets/quantity_stepper_with_input.dart';

/// Search results screen for the return flow.
///
/// Near-identical clone of `SearchResultsScreen` with the action button
/// labelled "Return Item" instead of "Add to Cart", adding products to
/// `ReturnCartProvider` instead of `AppProvider`.
class ReturnSearchResultsScreen extends StatefulWidget {
  final String query;

  const ReturnSearchResultsScreen({super.key, required this.query});

  @override
  State<ReturnSearchResultsScreen> createState() =>
      _ReturnSearchResultsScreenState();
}

class _ReturnSearchResultsScreenState extends State<ReturnSearchResultsScreen> {
  List<Product> _results = [];
  bool _isLoading = true;
  String? _error;
  bool _isRegexSearch = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _detectRegexPattern();
    _search();
  }

  void _detectRegexPattern() {
    final regexChars = RegExp(r'[\.\*\+\?\^\$\[\]\{\}\(\)\|\\]');
    _isRegexSearch = regexChars.hasMatch(widget.query);
  }

  Future<void> _search() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('userPhone');

      final result = await ApiService.searchProducts(
        query: widget.query,
        useRegex: _isRegexSearch,
        userPhone: userPhone,
      );

      final products = result['results'] as List<Product>;

      if (!mounted) return;
      setState(() {
        _results = products;
        _isAdmin = result['isAdmin'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        title: Text(
          '${provider.text('search')}: "${widget.query}"',
          style: const TextStyle(color: kPrimaryColor),
        ),
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
                              const Icon(Icons.search_off,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                  '${provider.text('no_results')} "${widget.query}"'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            return _buildProductCard(product, provider);
                          },
                        ),

          const FloatingReturnCartButton(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    final String productId = product.itemId ??
        '${product.productName}_${product.weight}'
            .replaceAll(' ', '_')
            .toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image (Left)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsPage(product: product),
                    ),
                  );
                },
                child: ClipRRect(
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
                            child: Icon(Icons.inventory_2,
                                color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: Icon(Icons.inventory_2,
                              color: Colors.grey[400]),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Product Info (Middle)
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
                    if (_isAdmin) ...[
                      if (product.buyingPrice != null &&
                          product.buyingPrice! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 11, color: Colors.orange[700]),
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
                        Row(
                          children: [
                            Icon(Icons.trending_up,
                                size: 11, color: Colors.green[700]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.green[200]!,
                                          width: 1),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 10, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.grey[300]!,
                                          width: 1),
                                ),
                                child: const Text(
                                  'Cost not set',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
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
              // Bottom Control Section (Right) - Return Item or +/− controls
              Builder(builder: (context) {
                final returnProvider =
                    Provider.of<ReturnCartProvider>(context);
                final qty = returnProvider.quantityOf(productId);

                if (qty == 0) {
                  return SizedBox(
                    width: 100,
                    child: ElevatedButton.icon(
                      onPressed: product.inStock
                          ? () {
                              returnProvider.addToReturnCart(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product.getLocalizedName(provider.currentLanguage)} ${provider.text('return_added')}',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.assignment_return, size: 16),
                      label: Text(
                        provider.text('return_item_action'),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }

                // Show quantity controls when qty > 0
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QuantityStepperWithInput(
                      value: qty,
                      min: 1,
                      canIncrement: product.inStock,
                      accentColor: Colors.deepOrange,
                      onChanged: (newQty) {
                        returnProvider.updateReturnQuantity(productId, newQty);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${(calculateEffectivePrice(product.price, product.weight, product.unit) * qty).toStringAsFixed(2)}',
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
