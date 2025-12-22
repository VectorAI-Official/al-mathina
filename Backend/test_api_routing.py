"""
Admin System API Routing Test
Tests the exact API contract between Backend and Flutter app
"""
import requests
import json
from datetime import datetime

# Test configuration
BASE_URL = "http://127.0.0.1:8000"
ADMIN_PHONES = ["7339651541", "8870503350", "9487715568"]
REGULAR_PHONE = "9876543210"

def print_section(title):
    """Print formatted section header"""
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80 + "\n")

def print_response(response_data, is_admin):
    """Print formatted API response"""
    print(f"Response Status: {response_data.get('status_code', 'N/A')}")
    print(f"Is Admin: {response_data.get('is_admin', False)}")
    print(f"Total Products: {len(response_data.get('products', []))}")
    
    if response_data.get('products'):
        print("\nFirst Product Sample:")
        product = response_data['products'][0]
        print(f"  Product Name: {product.get('product_name')}")
        print(f"  Price: ₹{product.get('price', 0):.2f}")
        
        if 'buying_price' in product:
            print(f"  ✅ Buying Price: ₹{product.get('buying_price', 0):.2f} (ADMIN ONLY)")
            print(f"  ✅ Margin: ₹{product.get('price', 0) - product.get('buying_price', 0):.2f}")
        else:
            print(f"  ❌ Buying Price: NOT INCLUDED (Regular User)")
    
    print(f"\nPagination Info:")
    pagination = response_data.get('pagination', {})
    print(f"  Current Page: {pagination.get('current_page')}")
    print(f"  Total Products: {pagination.get('total_products')}")
    print(f"  Per Page: {pagination.get('per_page')}")

def test_admin_user(phone):
    """Test API response for admin user"""
    print_section(f"TEST: Admin User - {phone}")
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    params = {
        "user_phone": phone,
        "limit": 5
    }
    
    try:
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        result = {
            "status_code": response.status_code,
            **data
        }
        
        print_response(result, True)
        
        # Verify admin response structure
        print("\n📋 VERIFICATION:")
        checks = [
            ("is_admin field present", 'is_admin' in data),
            ("is_admin is True", data.get('is_admin') == True),
            ("products array present", 'products' in data),
            ("buying_price in first product", 'buying_price' in data['products'][0] if data.get('products') else False),
            ("pagination present", 'pagination' in data),
        ]
        
        for check_name, passed in checks:
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"  {status}: {check_name}")
        
        return all(passed for _, passed in checks)
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_regular_user():
    """Test API response for regular user"""
    print_section(f"TEST: Regular User - {REGULAR_PHONE}")
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    params = {
        "user_phone": REGULAR_PHONE,
        "limit": 5
    }
    
    try:
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        result = {
            "status_code": response.status_code,
            **data
        }
        
        print_response(result, False)
        
        # Verify regular user response structure
        print("\n📋 VERIFICATION:")
        checks = [
            ("is_admin field present", 'is_admin' in data),
            ("is_admin is False", data.get('is_admin') == False),
            ("products array present", 'products' in data),
            ("buying_price NOT in first product", 'buying_price' not in data['products'][0] if data.get('products') else True),
            ("pagination present", 'pagination' in data),
        ]
        
        for check_name, passed in checks:
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"  {status}: {check_name}")
        
        return all(passed for _, passed in checks)
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_no_user_phone():
    """Test API response without user_phone parameter"""
    print_section("TEST: No user_phone parameter")
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    params = {
        "limit": 5
    }
    
    try:
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        result = {
            "status_code": response.status_code,
            **data
        }
        
        print_response(result, False)
        
        # Verify response without user_phone
        print("\n📋 VERIFICATION:")
        checks = [
            ("is_admin field present", 'is_admin' in data),
            ("is_admin is False", data.get('is_admin') == False),
            ("products array present", 'products' in data),
            ("buying_price NOT in first product", 'buying_price' not in data['products'][0] if data.get('products') else True),
        ]
        
        for check_name, passed in checks:
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"  {status}: {check_name}")
        
        return all(passed for _, passed in checks)
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_with_filters(phone, is_admin=True):
    """Test API with category filters"""
    print_section(f"TEST: With Filters - {'Admin' if is_admin else 'Regular'} User")
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    params = {
        "user_phone": phone,
        "section": "மளிகை பொருள்",  # Use actual section name from database
        "limit": 3
    }
    
    try:
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        print(f"Response Status: {response.status_code}")
        print(f"Is Admin: {data.get('is_admin')}")
        print(f"Section Filter: {data.get('section', 'N/A')}")
        print(f"Total Products: {len(data.get('products', []))}")
        
        if data.get('products'):
            print("\nProducts:")
            for i, product in enumerate(data['products'][:3], 1):
                print(f"\n  {i}. {product.get('product_name')}")
                print(f"     Section: {product.get('section')}")
                print(f"     Price: ₹{product.get('price', 0):.2f}")
                if 'buying_price' in product:
                    print(f"     ✅ Buying Price: ₹{product.get('buying_price', 0):.2f}")
        
        # Verify filters work correctly
        print("\n📋 VERIFICATION:")
        checks = [
            ("is_admin matches expectation", data.get('is_admin') == is_admin),
            ("section filter applied", data.get('section') == "மளிகை பொருள்"),
            ("products returned", len(data.get('products', [])) > 0),
        ]
        
        if is_admin:
            checks.append(("buying_price in products", 'buying_price' in data['products'][0] if data.get('products') else False))
        else:
            checks.append(("buying_price NOT in products", 'buying_price' not in data['products'][0] if data.get('products') else True))
        
        for check_name, passed in checks:
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"  {status}: {check_name}")
        
        return all(passed for _, passed in checks)
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def generate_flutter_sample():
    """Generate Flutter code samples based on API response"""
    print_section("FLUTTER INTEGRATION SAMPLES")
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    params = {
        "user_phone": ADMIN_PHONES[0],
        "limit": 1
    }
    
    try:
        response = requests.get(endpoint, params=params)
        data = response.json()
        
        print("📱 Expected API Response (Admin User):")
        print("```json")
        print(json.dumps(data, indent=2, default=str))
        print("```")
        
        print("\n📱 Flutter Dart Model:")
        print("```dart")
        print("""
class ProductsResponse {
  final List<Product> products;
  final bool isAdmin;
  final Map<String, dynamic> pagination;
  
  ProductsResponse({
    required this.products,
    required this.isAdmin,
    required this.pagination,
  });
  
  factory ProductsResponse.fromJson(Map<String, dynamic> json) {
    return ProductsResponse(
      products: (json['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList(),
      isAdmin: json['is_admin'] ?? false,
      pagination: json['pagination'] ?? {},
    );
  }
}

class Product {
  final String productName;
  final double price;
  final double? buyingPrice;  // Only present for admin users
  
  Product({
    required this.productName,
    required this.price,
    this.buyingPrice,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      buyingPrice: json['buying_price'] != null
          ? (json['buying_price'] as num).toDouble()
          : null,
    );
  }
}
        """.strip())
        print("```")
        
        print("\n📱 Flutter API Call:")
        print("```dart")
        print("""
// Get user phone from auth state
final userPhone = await AuthService.getUserPhone();

// Make API call
final response = await http.get(
  Uri.parse('$baseUrl/api/flutter/products').replace(
    queryParameters: {
      'user_phone': userPhone,
      'subcategory': 'Rice',
      'limit': '20',
    },
  ),
);

// Parse response
final data = json.decode(response.body);
final productsResponse = ProductsResponse.fromJson(data);

// Check if user is admin
if (productsResponse.isAdmin) {
  print('User is admin - showing buying prices');
} else {
  print('Regular user - hiding buying prices');
}

// Display products
for (var product in productsResponse.products) {
  print('${product.productName}: ₹${product.price}');
  if (productsResponse.isAdmin && product.buyingPrice != null) {
    print('  Buying: ₹${product.buyingPrice}');
  }
}
        """.strip())
        print("```")
        
    except Exception as e:
        print(f"❌ ERROR generating samples: {e}")

def check_backend_connectivity():
    """Check if backend is running"""
    print_section("BACKEND CONNECTIVITY CHECK")
    
    try:
        response = requests.get(f"{BASE_URL}/docs", timeout=5)
        if response.status_code == 200:
            print("✅ Backend is running")
            return True
        else:
            print(f"❌ Backend responded with status {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to backend at {BASE_URL}")
        print("   Make sure backend is running:")
        print("   cd Backend && python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def check_supabase_migration():
    """Check if Supabase migration ran (by testing one admin user)"""
    print_section("SUPABASE MIGRATION CHECK")
    
    try:
        response = requests.get(f"{BASE_URL}/api/flutter/products", params={"user_phone": ADMIN_PHONES[0], "limit": 1})
        if response.status_code == 200:
            data = response.json()
            if data.get('is_admin') == True:
                print("✅ Supabase migration complete - admin users detected")
                return True
            else:
                print("⚠️  WARNING: Supabase migration NOT run yet!")
                print("   Run this in Supabase SQL Editor:")
                print("   ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;")
                print("   UPDATE users SET is_admin = true WHERE phone IN ('7339651541', '8870503350', '9487715568');")
                print("\n   Tests will continue but admin tests will fail...\n")
                return False
        else:
            print(f"❌ API error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error checking migration: {e}")
        return False

def main():
    """Run all tests"""
    print("\n" + "=" * 80)
    print("  🧪 ADMIN SYSTEM API ROUTING TEST")
    print(f"  Backend: {BASE_URL}")
    print(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)
    
    # Pre-flight checks
    if not check_backend_connectivity():
        return False
    
    migration_status = check_supabase_migration()
    
    results = {}
    
    # Test all admin users
    for phone in ADMIN_PHONES:
        results[f"admin_{phone}"] = test_admin_user(phone)
    
    # Test regular user
    results["regular_user"] = test_regular_user()
    
    # Test without user_phone
    results["no_user_phone"] = test_no_user_phone()
    
    # Test with filters (admin)
    results["filters_admin"] = test_with_filters(ADMIN_PHONES[0], is_admin=True)
    
    # Test with filters (regular)
    results["filters_regular"] = test_with_filters(REGULAR_PHONE, is_admin=False)
    
    # Generate Flutter samples
    generate_flutter_sample()
    
    # Summary
    print_section("TEST SUMMARY")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    print(f"Tests Passed: {passed}/{total}")
    print(f"Success Rate: {(passed/total)*100:.1f}%\n")
    
    for test_name, passed_test in results.items():
        status = "✅ PASS" if passed_test else "❌ FAIL"
        print(f"  {status}: {test_name}")
    
    print("\n" + "=" * 80)
    
    if passed == total:
        print("🎉 ALL TESTS PASSED - Backend is ready for Flutter integration!")
        print("\n📱 Next Steps:")
        print("   1. Copy the Flutter code samples above")
        print("   2. Update your Flutter app's api_service.dart")
        print("   3. Test with admin phone: 7339651541")
    elif not migration_status:
        print("⚠️  SUPABASE MIGRATION REQUIRED!")
        print("\n🔧 To fix:")
        print("   1. Open Supabase SQL Editor")
        print("   2. Run: Backend/manual_admin_setup.sql")
        print("   3. Run this test again")
    else:
        print("⚠️  Some tests failed - review errors above")
    
    print("=" * 80 + "\n")
    
    return passed == total

if __name__ == "__main__":
    import sys
    
    print("\n🚀 Starting API Routing Tests...\n")
    
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
