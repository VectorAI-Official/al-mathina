"""
Check MongoDB for recently deleted orders
This won't recover them, but can show what was deleted recently
"""
import os
from pymongo import MongoClient
from datetime import datetime, timedelta

# Connect to MongoDB
mongo_uri = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/')
client = MongoClient(mongo_uri)
db = client['almathina']

# Unfortunately, once deleted from MongoDB, the data is gone
# We can only see what orders still exist

print("=" * 60)
print("CURRENT ORDERS IN DATABASE")
print("=" * 60)

orders = list(db['orders'].find().sort("created_at", -1).limit(10))

if not orders:
    print("❌ No orders found in database")
else:
    print(f"📊 Found {len(orders)} recent orders:\n")
    for idx, order in enumerate(orders, 1):
        print(f"{idx}. Order ID: {order.get('order_id')}")
        print(f"   Phone: {order.get('user_phone')}")
        print(f"   Amount: ₹{order.get('total_amount', 0)}")
        print(f"   Status: {order.get('status')}")
        print(f"   Created: {order.get('created_at')}")
        print()

print("=" * 60)
print("⚠️  IMPORTANT: Hard-deleted orders cannot be recovered")
print("    unless MongoDB Atlas has automatic backups enabled.")
print("=" * 60)
