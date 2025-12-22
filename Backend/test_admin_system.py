"""
Test Script: Verify Admin User System
Tests that admin users get buying_price in product responses
"""
import requests
import json

BASE_URL = "http://127.0.0.1:8000"  # Change to production URL when deployed

# Admin phone numbers (should see buying_price)
ADMIN_PHONES = ["7339651541", "8870503350", "9487715568"]

# Regular user phone (should NOT see buying_price)
REGULAR_PHONE = "9876543210"

def test_admin_product_fetch():
    """Test that admin users receive buying_price in product responses"""
    
    print("=" * 80)
    print("🧪 TESTING ADMIN USER SYSTEM - Product Fetch")
    print("=" * 80)
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    
    # Test 1: Admin user should see buying_price
    print("\n📋 Test 1: Admin User - Should receive buying_price")
    print("-" * 80)
    
    for admin_phone in ADMIN_PHONES:
        params = {
            "user_phone": admin_phone,
            "limit": 5
        }
        
        response = requests.get(endpoint, params=params)
        
        print(f"\n👑 Admin: {admin_phone}")
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Is Admin: {data.get('is_admin', False)}")
            print(f"Products Returned: {len(data.get('products', []))}")
            
            if data.get('products'):
                first_product = data['products'][0]
                print(f"\n📦 First Product:")
                print(f"   Name: {first_product.get('product_name')}")
                print(f"   Price: ₹{first_product.get('price', 0):.2f}")
                print(f"   Buying Price: ₹{first_product.get('buying_price', 'NOT INCLUDED')}")
                
                if 'buying_price' in first_product:
                    print(f"   ✅ PASS: buying_price is included for admin")
                else:
                    print(f"   ❌ FAIL: buying_price is MISSING for admin")
        else:
            print(f"❌ Error: {response.text}")
    
    # Test 2: Regular user should NOT see buying_price
    print("\n" + "=" * 80)
    print("📋 Test 2: Regular User - Should NOT receive buying_price")
    print("-" * 80)
    
    params = {
        "user_phone": REGULAR_PHONE,
        "limit": 5
    }
    
    response = requests.get(endpoint, params=params)
    
    print(f"\n👤 Regular User: {REGULAR_PHONE}")
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"Is Admin: {data.get('is_admin', False)}")
        print(f"Products Returned: {len(data.get('products', []))}")
        
        if data.get('products'):
            first_product = data['products'][0]
            print(f"\n📦 First Product:")
            print(f"   Name: {first_product.get('product_name')}")
            print(f"   Price: ₹{first_product.get('price', 0):.2f}")
            print(f"   Buying Price: {first_product.get('buying_price', 'NOT INCLUDED')}")
            
            if 'buying_price' not in first_product:
                print(f"   ✅ PASS: buying_price is correctly excluded for regular user")
            else:
                print(f"   ❌ FAIL: buying_price should NOT be included for regular user")
    else:
        print(f"❌ Error: {response.text}")
    
    # Test 3: No user_phone parameter - should NOT see buying_price
    print("\n" + "=" * 80)
    print("📋 Test 3: No user_phone - Should NOT receive buying_price")
    print("-" * 80)
    
    params = {"limit": 5}
    response = requests.get(endpoint, params=params)
    
    print(f"\nStatus Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"Is Admin: {data.get('is_admin', False)}")
        print(f"Products Returned: {len(data.get('products', []))}")
        
        if data.get('products'):
            first_product = data['products'][0]
            print(f"\n📦 First Product:")
            print(f"   Name: {first_product.get('product_name')}")
            print(f"   Price: ₹{first_product.get('price', 0):.2f}")
            print(f"   Buying Price: {first_product.get('buying_price', 'NOT INCLUDED')}")
            
            if 'buying_price' not in first_product:
                print(f"   ✅ PASS: buying_price correctly excluded when no user_phone")
            else:
                print(f"   ❌ FAIL: buying_price should NOT be included without user_phone")
    
    print("\n" + "=" * 80)
    print("🏁 TESTING COMPLETE")
    print("=" * 80 + "\n")

def test_admin_with_filters():
    """Test admin user with subcategory filters"""
    
    print("=" * 80)
    print("🧪 TESTING ADMIN WITH SUBCATEGORY FILTER")
    print("=" * 80)
    
    endpoint = f"{BASE_URL}/api/flutter/products"
    
    params = {
        "user_phone": ADMIN_PHONES[0],
        "section": "Provisions",
        "limit": 5
    }
    
    response = requests.get(endpoint, params=params)
    
    print(f"\n👑 Admin: {ADMIN_PHONES[0]}")
    print(f"Filter: Section = {params['section']}")
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\nIs Admin: {data.get('is_admin')}")
        print(f"Section: {data.get('section')}")
        print(f"Products Returned: {len(data.get('products', []))}")
        
        if data.get('products'):
            for i, product in enumerate(data['products'][:3], 1):
                print(f"\n📦 Product {i}:")
                print(f"   Name: {product.get('product_name')}")
                print(f"   Section: {product.get('section')}")
                print(f"   Price: ₹{product.get('price', 0):.2f}")
                
                if 'buying_price' in product:
                    print(f"   Buying Price: ₹{product.get('buying_price', 0):.2f}")
                    print(f"   ✅ buying_price included")
                else:
                    print(f"   ❌ buying_price MISSING")
    else:
        print(f"❌ Error: {response.text}")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    print("\n🚀 Starting Admin User System Tests...\n")
    
    try:
        test_admin_product_fetch()
        test_admin_with_filters()
        
        print("✅ All tests completed!")
        
    except requests.exceptions.ConnectionError:
        print("\n❌ ERROR: Could not connect to backend server")
        print("Make sure the backend is running at", BASE_URL)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
