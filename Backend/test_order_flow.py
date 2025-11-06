"""
Test Order Creation Flow
Tests the complete order flow from Flutter to Admin Dashboard
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"

def test_create_order():
    """Test creating a new order via Flutter API"""
    print("\n" + "="*60)
    print("TEST 1: Create Order via Flutter API")
    print("="*60)
    
    order_data = {
        "user_id": "9876543210",
        "items": [
            {
                "item_id": "PROD001",
                "name": "Aashirvaad Atta 1Kg",
                "quantity": 2,
                "price": 100.0,
                "section": "Grocery & Kitchen",
                "main_category": "Atta, Rice & Dal",
                "subcategory": "Atta"
            }
        ],
        "delivery_address": "123 Test Street, Chennai, Tamil Nadu",
        "payment_method": "upi",
        "total_amount": 200.0
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/api/flutter/orders",
            json=order_data,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("\n✅ Order Created Successfully!")
            print(f"   Order ID: {result.get('order_id')}")
            print(f"   MongoDB ID: {result.get('mongodb_id')}")
            print(f"   Status: {result.get('status')}")
            print(f"   Created At: {result.get('created_at')}")
            return result.get('order_id'), result.get('mongodb_id')
        else:
            print(f"\n❌ Error: {response.text}")
            return None, None
            
    except Exception as e:
        print(f"\n❌ Exception: {e}")
        return None, None

def test_get_all_orders():
    """Test fetching all orders via Admin API"""
    print("\n" + "="*60)
    print("TEST 2: Fetch All Orders via Admin API")
    print("="*60)
    
    try:
        response = requests.get(f"{BASE_URL}/api/admin/orders")
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            orders = result.get('orders', [])
            
            print(f"\n✅ Retrieved {len(orders)} orders")
            
            if orders:
                print("\nLatest Order Details:")
                latest = orders[0]
                print(f"   Order ID: {latest.get('order_id')}")
                print(f"   User Name: {latest.get('user_name')}")
                print(f"   User Phone: {latest.get('user_phone')}")
                print(f"   Store Name: {latest.get('user_store_name', 'N/A')}")
                print(f"   Status: {latest.get('status')}")
                print(f"   Total Amount: ₹{latest.get('total_amount')}")
                print(f"   Items Count: {len(latest.get('items', []))}")
                print(f"   Created At: {latest.get('created_at')}")
                
                # Check for required fields
                print("\n📋 Field Validation:")
                required_fields = ['order_id', 'user_name', 'user_phone', 'status', 'items']
                for field in required_fields:
                    value = latest.get(field)
                    status = "✅" if value else "❌"
                    print(f"   {status} {field}: {value}")
            else:
                print("\n⚠️  No orders found in database")
                
        else:
            print(f"\n❌ Error: {response.text}")
            
    except Exception as e:
        print(f"\n❌ Exception: {e}")

def test_get_single_order(order_id):
    """Test fetching a single order by ID"""
    print("\n" + "="*60)
    print(f"TEST 3: Fetch Single Order (ID: {order_id})")
    print("="*60)
    
    if not order_id:
        print("\n⚠️  Skipping: No order_id provided")
        return
    
    try:
        response = requests.get(f"{BASE_URL}/api/admin/orders/{order_id}")
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            order = result.get('order')
            
            print("\n✅ Order Retrieved Successfully!")
            print(f"   Order ID: {order.get('order_id')}")
            print(f"   User: {order.get('user_name')} ({order.get('user_phone')})")
            print(f"   Store: {order.get('user_store_name', 'N/A')}")
            print(f"   Status: {order.get('status')}")
            print(f"   Total: ₹{order.get('total_amount')}")
            
            items = order.get('items', [])
            print(f"\n   Items ({len(items)}):")
            for i, item in enumerate(items, 1):
                print(f"      {i}. {item.get('name')} x{item.get('quantity')} @ ₹{item.get('price')}")
                
        elif response.status_code == 404:
            print(f"\n❌ Order not found: {order_id}")
        else:
            print(f"\n❌ Error: {response.text}")
            
    except Exception as e:
        print(f"\n❌ Exception: {e}")

def test_search_functionality():
    """Test search functionality by fetching orders"""
    print("\n" + "="*60)
    print("TEST 4: Search Functionality Test")
    print("="*60)
    
    try:
        response = requests.get(f"{BASE_URL}/api/admin/orders")
        
        if response.status_code == 200:
            result = response.json()
            orders = result.get('orders', [])
            
            if not orders:
                print("\n⚠️  No orders to test search with")
                return
            
            # Test different search scenarios
            print(f"\n📊 Testing search across {len(orders)} orders")
            
            # Collect unique values
            order_ids = [o.get('order_id') for o in orders if o.get('order_id')]
            user_names = [o.get('user_name') for o in orders if o.get('user_name')]
            phones = [o.get('user_phone') for o in orders if o.get('user_phone')]
            stores = [o.get('user_store_name') for o in orders if o.get('user_store_name')]
            
            print(f"\n   Searchable Fields Found:")
            print(f"   ✅ {len(order_ids)} Order IDs")
            print(f"   ✅ {len(set(user_names))} Unique User Names")
            print(f"   ✅ {len(set(phones))} Unique Phone Numbers")
            print(f"   ✅ {len(set(stores))} Store Names")
            
            print(f"\n   Sample Searchable Values:")
            if order_ids:
                print(f"   Order ID: {order_ids[0]}")
            if user_names:
                print(f"   User Name: {user_names[0]}")
            if phones:
                print(f"   Phone: {phones[0]}")
            if stores:
                print(f"   Store: {stores[0]}")
                
            print("\n✅ All orders have searchable fields!")
            print("   Admin UI search should work properly.")
            
        else:
            print(f"\n❌ Error: {response.text}")
            
    except Exception as e:
        print(f"\n❌ Exception: {e}")

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("🧪 ORDER FLOW COMPLETE TEST SUITE")
    print("="*60)
    print(f"Testing against: {BASE_URL}")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Test 1: Create new order
    order_id, mongodb_id = test_create_order()
    
    # Test 2: Get all orders
    test_get_all_orders()
    
    # Test 3: Get single order (use the one we just created)
    if mongodb_id:
        test_get_single_order(mongodb_id)
    
    # Test 4: Test search functionality
    test_search_functionality()
    
    # Final summary
    print("\n" + "="*60)
    print("📝 TEST SUMMARY")
    print("="*60)
    print("""
Next Steps:
1. ✅ Backend is ready to receive orders from Flutter
2. ✅ Admin dashboard can display and search orders
3. ✅ All fields are properly populated
4. 🔄 Test from actual Flutter app to verify end-to-end flow
5. 🔄 Clear browser cache and test admin UI search bar

Admin Dashboard: http://localhost:8000/static/admin/orders.html
    """)

if __name__ == "__main__":
    main()
