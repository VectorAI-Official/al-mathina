import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/return_cart_provider.dart';
import '../screens/return_cart_screen.dart';

/// Floating return cart button, shown on the return search results screen.
///
/// Deep-orange styled to avoid any visual confusion with the green
/// checkout cart button.
class FloatingReturnCartButton extends StatelessWidget {
  final double? bottomPosition;

  const FloatingReturnCartButton({super.key, this.bottomPosition});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReturnCartProvider>(context);

    if (provider.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;

    double calculateButtonWidth() {
      final baseWidth = 250.0;
      if (provider.returnCartCount < 10) {
        return baseWidth;
      } else if (provider.returnCartCount < 100) {
        return baseWidth + 25.0;
      } else {
        return baseWidth + 45.0;
      }
    }

    final buttonWidth = screenWidth > 600 ? 320.0 : calculateButtonWidth();
    final calculatedBottom = bottomPosition ?? (kBottomNavigationBarHeight + 5);

    return Positioned(
      bottom: calculatedBottom,
      left: (screenWidth - buttonWidth) / 2,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReturnCartScreen()),
          );
        },
        child: Container(
          width: buttonWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_return,
                        color: Colors.deepOrange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${provider.returnCartCount} ${provider.returnCartCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  Text(
                    'Return Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
