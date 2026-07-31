import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../main.dart';
import '../providers/return_cart_provider.dart';
import '../utils/weight_utils.dart';
import '../widgets/quantity_stepper_with_input.dart';

/// Return cart screen.
///
/// Shows the items the user wants to return and submits a return request
/// via `ApiService.submitReturnRequest`. It does NOT call
/// `ApiService.createOrder`, touch `AppProvider`, or affect inventory.
class ReturnCartScreen extends StatefulWidget {
  const ReturnCartScreen({super.key});

  @override
  State<ReturnCartScreen> createState() => _ReturnCartScreenState();
}

class _ReturnCartScreenState extends State<ReturnCartScreen> {
  bool _isSubmitting = false;

  static const String _noticeText =
      '⚠️ இது பொருட்களைத் திரும்பப் பெறுவதற்கான கார்ட். இது ஒரு ஆர்டர் அல்ல. இங்கு சேர்க்கப்படும் பொருட்கள் உங்கள் வழக்கமான ஆர்டர் கார்ட்டில் சேர்க்கப்படாது.';

  Future<void> _confirmSubmit(ReturnCartProvider returnProvider) async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          provider.text('confirm_return_title'),
          style: const TextStyle(color: Colors.deepOrange),
        ),
        content: Text(provider.text('confirm_return_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(provider.text('no')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              provider.text('yes'),
              style: const TextStyle(color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _submit(provider, returnProvider);
  }

  Future<void> _submit(
      AppProvider provider, ReturnCartProvider returnProvider) async {
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('userPhone') ?? '';

      final items = returnProvider.returnCartItems.map((item) {
        return {
          'item_id': item.itemId,
          'product_name': item.productName,
          'weight': item.weight,
          'price': calculateEffectivePrice(item.price, item.weight, item.unit),
          'quantity': item.quantity,
        };
      }).toList();

      await ApiService.submitReturnRequest(
        userPhone: userPhone,
        items: items,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.text('return_success')),
          backgroundColor: Colors.deepOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      returnProvider.clearReturnCart();

      // Pop back to the profile screen (root route = MainScreen, profile tab).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.text('return_failed')}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final returnProvider = Provider.of<ReturnCartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          provider.text('return_cart_title'),
          style: const TextStyle(color: Colors.deepOrange),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepOrange),
      ),
      body: returnProvider.returnCartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_return,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    provider.text('empty_return_cart'),
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Pure Tamil notice banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.deepOrange.withOpacity(0.4)),
                  ),
                  child: Text(
                    _noticeText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBF360C),
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                    itemCount: returnProvider.returnCartItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = returnProvider.returnCartItems[index];
                      return _buildReturnItemRow(
                          provider, returnProvider, item);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: returnProvider.returnCartItems.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.text('total'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${returnProvider.returnCartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _confirmSubmit(returnProvider),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.assignment_return, size: 18),
                        label: Text(
                          provider.text('proceed_to_return'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReturnItemRow(
      AppProvider provider, ReturnCartProvider returnProvider, ReturnCartItem item) {
    final effectivePrice =
        calculateEffectivePrice(item.price, item.weight, item.unit);

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      ApiService.getImageUrl(item.imageUrl),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: Icon(Icons.inventory_2,
                            color: Colors.grey[400]),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child:
                          Icon(Icons.inventory_2, color: Colors.grey[400]),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.getLocalizedName(provider.currentLanguage),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.weight,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${effectivePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () =>
                      returnProvider.removeFromReturnCart(item.itemId),
                ),
                QuantityStepperWithInput(
                  value: item.quantity,
                  min: 1,
                  accentColor: Colors.deepOrange,
                  onChanged: (newQty) => returnProvider.updateReturnQuantity(
                      item.itemId, newQty),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${(effectivePrice * item.quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
