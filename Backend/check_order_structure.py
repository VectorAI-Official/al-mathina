"""Check actual MongoDB order structure to debug email issues"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pymongo import MongoClient

# MongoDB connection
mongo_uri = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/')
client = MongoClient(mongo_uri)
db = client['almathina']

# Get the most recent order
order = db['orders'].find_one(sort=[('created_at', -1)])

if order:
    print('='*60)
    print('📦 Latest Order Structure:')
    print('='*60)
    print(f'Order ID: {order.get("order_id")}')
    print(f'User Phone: {order.get("user_phone")}')
    print(f'Total Amount: {order.get("total_amount")}')
    print(f'\n📋 Items in order ({len(order.get("items", []))} items):')
    print('='*60)
    
    for idx, item in enumerate(order.get('items', []), 1):
        print(f'\n🔸 Item {idx}:')
        for key, value in item.items():
            # Handle Tamil characters properly
            if isinstance(value, str):
                print(f'  {key}: {repr(value)}')
            else:
                print(f'  {key}: {value}')
    
    print('\n' + '='*60)
    print('🔍 Field Names Present:')
    if order.get('items'):
        field_names = list(order['items'][0].keys())
        print(f'  {field_names}')
    print('='*60)
else:
    print('❌ No orders found in database')
