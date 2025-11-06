"""
Check Orders in Database
Shows the structure of orders and identifies any missing fields
"""

from database.mongodb_client import get_mongo_db
from datetime import datetime

def check_orders():
    """Check all orders in database"""
    db = get_mongo_db()
    orders_collection = db['orders']
    
    print("\n" + "="*70)
    print("📊 ORDERS DATABASE ANALYSIS")
    print("="*70)
    
    # Get total count
    total = orders_collection.count_documents({})
    print(f"\n📦 Total Orders: {total}")
    
    if total == 0:
        print("\n⚠️  No orders found in database")
        return
    
    # Get sample orders
    orders = list(orders_collection.find().sort("created_at", -1).limit(10))
    
    print(f"\n📋 Analyzing last {len(orders)} orders...\n")
    
    # Track field availability
    fields_stats = {
        'order_id': {'present': 0, 'missing': 0},
        'user_id': {'present': 0, 'missing': 0},
        'user_phone': {'present': 0, 'missing': 0},
        'items': {'present': 0, 'missing': 0},
        'status': {'present': 0, 'missing': 0},
        'total_amount': {'present': 0, 'missing': 0},
        'created_at': {'present': 0, 'missing': 0},
    }
    
    # Analyze each order
    for i, order in enumerate(orders, 1):
        print(f"Order {i}:")
        print(f"   MongoDB ID: {order['_id']}")
        
        # Check each field
        for field in fields_stats.keys():
            if field in order and order[field] is not None:
                fields_stats[field]['present'] += 1
                value = order[field]
                if field == 'items':
                    value = f"{len(value)} items"
                elif field == 'created_at':
                    value = value.strftime("%Y-%m-%d %H:%M") if hasattr(value, 'strftime') else str(value)
                elif field == 'total_amount':
                    value = f"₹{value}"
                print(f"   ✅ {field}: {value}")
            else:
                fields_stats[field]['missing'] += 1
                print(f"   ❌ {field}: MISSING")
        
        print()
    
    # Summary
    print("="*70)
    print("📊 FIELD AVAILABILITY SUMMARY (Last 10 Orders)")
    print("="*70)
    
    for field, stats in fields_stats.items():
        present = stats['present']
        missing = stats['missing']
        total_checked = present + missing
        percentage = (present / total_checked * 100) if total_checked > 0 else 0
        
        status = "✅" if percentage == 100 else "⚠️" if percentage > 0 else "❌"
        print(f"{status} {field:15} | Present: {present:2}/{total_checked} ({percentage:5.1f}%)")
    
    # Check for old format orders
    print("\n" + "="*70)
    print("🔍 BACKWARD COMPATIBILITY CHECK")
    print("="*70)
    
    old_orders = orders_collection.count_documents({"order_id": {"$exists": False}})
    new_orders = orders_collection.count_documents({"order_id": {"$exists": True}})
    
    print(f"\n📦 Orders without order_id field: {old_orders}")
    print(f"✅ Orders with order_id field: {new_orders}")
    
    if old_orders > 0:
        print(f"\n⚠️  {old_orders} old-format orders detected")
        print("   These will use MongoDB _id as fallback order_id")
    else:
        print("\n✅ All orders have order_id field!")
    
    # Check user_phone field
    no_phone = orders_collection.count_documents({"user_phone": {"$exists": False}})
    has_phone = orders_collection.count_documents({"user_phone": {"$exists": True}})
    
    print(f"\n📞 Orders without user_phone field: {no_phone}")
    print(f"✅ Orders with user_phone field: {has_phone}")
    
    if no_phone > 0:
        print(f"\n⚠️  {no_phone} orders missing user_phone")
        print("   Admin API will look up phone from user_id")
    else:
        print("\n✅ All orders have user_phone field!")
    
    # Status distribution
    print("\n" + "="*70)
    print("📈 ORDER STATUS DISTRIBUTION")
    print("="*70)
    
    statuses = orders_collection.distinct("status")
    for status in statuses:
        count = orders_collection.count_documents({"status": status})
        percentage = (count / total * 100) if total > 0 else 0
        print(f"   {status.upper():12} | {count:3} orders ({percentage:5.1f}%)")
    
    print("\n" + "="*70)
    print("✅ DATABASE CHECK COMPLETE")
    print("="*70)
    
    # Recommendations
    print("\n💡 RECOMMENDATIONS:")
    if old_orders > 0:
        print("   • Old orders will work with fallback mechanism")
    if no_phone > 0:
        print("   • Orders without user_phone will look up user data dynamically")
    if total > 0:
        print("   • Admin dashboard should display all orders correctly")
        print("   • Search functionality should work for all fields")
    
    print("\n🔗 View orders at: http://localhost:8000/static/admin/orders.html\n")

if __name__ == "__main__":
    check_orders()
