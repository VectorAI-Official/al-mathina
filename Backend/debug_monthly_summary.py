"""Debug script to check why Monthly Summary shows zero orders"""
from database.mongodb_client import get_mongo_db
from datetime import datetime, timedelta
import sys

def check_orders_by_date():
    """Check orders for recent dates"""
    db = get_mongo_db()
    orders_collection = db['orders']
    
    # Total orders
    total_orders = orders_collection.count_documents({})
    print(f"\n📊 Total Orders in Database: {total_orders}")
    
    # Get recent orders
    recent_orders = list(orders_collection.find().sort('created_at', -1).limit(10))
    print(f"\n🕒 Most Recent 10 Orders:")
    for i, order in enumerate(recent_orders, 1):
        created_at = order.get('created_at')
        print(f"  {i}. Phone: {order.get('user_phone', 'N/A'):12s} | "
              f"Date: {created_at} | "
              f"Amount: ₹{order.get('total_amount', 0):,.2f} | "
              f"Status: {order.get('status', 'N/A')}")
    
    # Check date range for December 2025
    print(f"\n📅 Checking December 2025 Orders:")
    for day in range(17, 23):  # Dec 17-22
        start_date = datetime(2025, 12, day, 0, 0, 0)
        end_date = datetime(2025, 12, day, 23, 59, 59)
        
        query = {"created_at": {"$gte": start_date, "$lte": end_date}}
        count = orders_collection.count_documents(query)
        
        if count > 0:
            orders = list(orders_collection.find(query))
            total_revenue = sum(o.get('total_amount', 0) for o in orders)
            print(f"  Dec {day:2d}: {count:3d} orders, ₹{total_revenue:,.2f} revenue")
        else:
            print(f"  Dec {day:2d}: {count:3d} orders, ₹0.00 revenue ⚠️")
    
    # Check API date format (what the frontend sends)
    print(f"\n🔍 Testing API Date Query Format:")
    test_date_str = "2025-12-22"
    start_dt = datetime.fromisoformat(test_date_str)
    end_dt = start_dt + timedelta(days=1)
    
    print(f"  Date String: {test_date_str}")
    print(f"  Start DateTime: {start_dt}")
    print(f"  End DateTime: {end_dt}")
    
    query = {"created_at": {"$gte": start_dt, "$lte": end_dt}}
    count = orders_collection.count_documents(query)
    print(f"  Orders Found: {count}")
    
    if count > 0:
        sample_orders = list(orders_collection.find(query).limit(3))
        print(f"\n  Sample Orders for {test_date_str}:")
        for order in sample_orders:
            print(f"    - {order.get('created_at')}: ₹{order.get('total_amount', 0)}")
    
    # Check created_at field type
    print(f"\n🔍 Checking created_at Field Types:")
    sample = orders_collection.find_one({})
    if sample:
        created_at = sample.get('created_at')
        print(f"  Type: {type(created_at)}")
        print(f"  Value: {created_at}")
        print(f"  Is datetime?: {isinstance(created_at, datetime)}")

if __name__ == "__main__":
    try:
        check_orders_by_date()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
