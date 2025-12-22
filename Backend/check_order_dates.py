"""
Check order dates distribution in database
Helps understand when orders were created for analytics
"""

from database.mongodb_client import get_mongo_db
from datetime import datetime
from collections import defaultdict
import sys

def analyze_order_dates():
    """Analyze order creation dates in the database"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        users_collection = db['users']
        
        print("=" * 80)
        print("📊 ORDER DATE DISTRIBUTION ANALYSIS")
        print("=" * 80)
        print()
        
        # Get total counts
        total_orders = orders_collection.count_documents({})
        total_users = users_collection.count_documents({})
        
        print(f"📦 Total Orders: {total_orders}")
        print(f"👥 Total Users: {total_users}")
        print()
        
        # Get all orders with dates
        orders = list(orders_collection.find({}, {
            "created_at": 1,
            "user_phone": 1,
            "total_amount": 1,
            "_id": 0
        }).sort("created_at", 1))
        
        if not orders:
            print("❌ No orders found in database")
            return
        
        # Find earliest and latest orders
        earliest_order = orders[0]['created_at']
        latest_order = orders[-1]['created_at']
        
        print(f"📅 Date Range:")
        print(f"   Earliest Order: {earliest_order.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"   Latest Order:   {latest_order.strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Group by year
        by_year = defaultdict(lambda: {"count": 0, "revenue": 0, "users": set()})
        by_month = defaultdict(lambda: {"count": 0, "revenue": 0, "users": set()})
        by_date = defaultdict(lambda: {"count": 0, "revenue": 0, "users": set()})
        
        for order in orders:
            created_at = order['created_at']
            user_phone = order.get('user_phone', 'unknown')
            amount = order.get('total_amount', 0)
            
            year = created_at.year
            month = f"{created_at.year}-{created_at.month:02d}"
            date = created_at.strftime('%Y-%m-%d')
            
            by_year[year]["count"] += 1
            by_year[year]["revenue"] += amount
            by_year[year]["users"].add(user_phone)
            
            by_month[month]["count"] += 1
            by_month[month]["revenue"] += amount
            by_month[month]["users"].add(user_phone)
            
            by_date[date]["count"] += 1
            by_date[date]["revenue"] += amount
            by_date[date]["users"].add(user_phone)
        
        # Display by year
        print("📊 BY YEAR:")
        print("-" * 80)
        for year in sorted(by_year.keys()):
            data = by_year[year]
            print(f"   {year}:")
            print(f"      Orders: {data['count']}")
            print(f"      Revenue: ₹{data['revenue']:,.2f}")
            print(f"      Unique Stores: {len(data['users'])}")
            print()
        
        # Display by month (last 12 months)
        print("📊 BY MONTH (Recent 12 Months):")
        print("-" * 80)
        months = sorted(by_month.keys(), reverse=True)[:12]
        for month in reversed(months):
            data = by_month[month]
            print(f"   {month}:")
            print(f"      Orders: {data['count']}")
            print(f"      Revenue: ₹{data['revenue']:,.2f}")
            print(f"      Unique Stores: {len(data['users'])}")
            print()
        
        # Display by date (last 30 days)
        print("📊 BY DATE (Recent 30 Days):")
        print("-" * 80)
        dates = sorted(by_date.keys(), reverse=True)[:30]
        for date in reversed(dates):
            data = by_date[date]
            print(f"   {date}:")
            print(f"      Orders: {data['count']}")
            print(f"      Revenue: ₹{data['revenue']:,.2f}")
            print(f"      Unique Stores: {len(data['users'])}")
        print()
        
        # Check current year (2025)
        current_year = datetime.now().year
        current_month = datetime.now().strftime('%Y-%m')
        current_date = datetime.now().strftime('%Y-%m-%d')
        
        print("=" * 80)
        print(f"🎯 CURRENT PERIOD VERIFICATION (Year: {current_year})")
        print("=" * 80)
        
        if current_year in by_year:
            data = by_year[current_year]
            print(f"Current Year ({current_year}):")
            print(f"   Orders: {data['count']}")
            print(f"   Revenue: ₹{data['revenue']:,.2f}")
            print(f"   Unique Stores: {len(data['users'])}")
        else:
            print(f"❌ No orders found for current year ({current_year})")
        print()
        
        if current_month in by_month:
            data = by_month[current_month]
            print(f"Current Month ({current_month}):")
            print(f"   Orders: {data['count']}")
            print(f"   Revenue: ₹{data['revenue']:,.2f}")
            print(f"   Unique Stores: {len(data['users'])}")
        else:
            print(f"❌ No orders found for current month ({current_month})")
        print()
        
        if current_date in by_date:
            data = by_date[current_date]
            print(f"Today ({current_date}):")
            print(f"   Orders: {data['count']}")
            print(f"   Revenue: ₹{data['revenue']:,.2f}")
            print(f"   Unique Stores: {len(data['users'])}")
        else:
            print(f"❌ No orders found for today ({current_date})")
        print()
        
        # Check which users have orders
        print("=" * 80)
        print("👥 USER STATISTICS")
        print("=" * 80)
        
        # Count users by order activity
        users_with_orders = orders_collection.distinct("user_phone")
        all_user_phones = users_collection.distinct("phone")
        
        print(f"Total Users in DB: {len(all_user_phones)}")
        print(f"Users with Orders: {len(users_with_orders)}")
        print(f"Users without Orders: {len(all_user_phones) - len(users_with_orders)}")
        print()
        
        print("=" * 80)
        
    except Exception as e:
        print(f"❌ Error analyzing order dates: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    analyze_order_dates()
