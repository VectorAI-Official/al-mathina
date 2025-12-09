"""Check MongoDB connection and database status"""
import os
from pymongo import MongoClient

# Get MongoDB URI from environment
mongo_uri = os.getenv('MONGODB_URI')

print("=" * 70)
print("MONGODB CONNECTION CHECK")
print("=" * 70)

if not mongo_uri:
    print("❌ MONGODB_URI not set in environment variables")
    print("   Using default: mongodb://localhost:27017/")
    mongo_uri = "mongodb://localhost:27017/"
else:
    # Mask password in URI for security
    masked_uri = mongo_uri
    if "@" in masked_uri:
        parts = masked_uri.split("@")
        credentials = parts[0].split("//")[1]
        if ":" in credentials:
            user = credentials.split(":")[0]
            masked_uri = masked_uri.replace(credentials, f"{user}:****")
    print(f"✅ MONGODB_URI found: {masked_uri}")

print()

try:
    client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
    
    # Test connection
    client.admin.command('ping')
    print("✅ Successfully connected to MongoDB")
    
    # Get database info
    db = client['almathina']
    collections = db.list_collection_names()
    
    print(f"\n📊 Database: almathina")
    print(f"   Collections: {len(collections)}")
    print(f"   Names: {', '.join(collections)}")
    
    # Check orders collection
    if 'orders' in collections:
        orders_count = db['orders'].count_documents({})
        print(f"\n📦 Orders Collection:")
        print(f"   Total orders: {orders_count}")
        
        if orders_count > 0:
            # Get most recent order
            recent = db['orders'].find_one(sort=[('created_at', -1)])
            print(f"   Most recent order: {recent.get('order_id')}")
            print(f"   Created at: {recent.get('created_at')}")
        else:
            print("   ⚠️  No orders in database!")
    
    # Check users collection
    if 'users' in collections:
        users_count = db['users'].count_documents({})
        print(f"\n👥 Users Collection:")
        print(f"   Total users: {users_count}")
    
    # Check products collection  
    if 'products' in collections:
        products_count = db['products'].count_documents({})
        print(f"\n🛍️  Products Collection:")
        print(f"   Total products: {products_count}")
    
    print("\n" + "=" * 70)
    
except Exception as e:
    print(f"\n❌ Connection failed: {e}")
    print("\n💡 This might be a local database, not production!")
    print("=" * 70)
