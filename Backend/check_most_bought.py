"""
Check Most Bought collection
"""
from pymongo import MongoClient
from config_local import settings

# Connect to MongoDB
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

print("=== CHECKING MOST BOUGHT COLLECTION ===\n")

# Check if collection exists
collections = db.list_collection_names()
print(f"All collections: {collections}\n")

if "most_bought" in collections:
    print("✅ most_bought collection exists\n")
    
    # Count documents
    count = db.most_bought.count_documents({})
    print(f"Total items in most_bought: {count}\n")
    
    if count > 0:
        print("Items in most_bought:\n")
        for item in db.most_bought.find():
            print(f"  - Section: {item.get('section')}")
            print(f"    Main Category: {item.get('main_category')}")
            print(f"    Starred At: {item.get('starred_at')}")
            print(f"    ID: {item.get('_id')}\n")
    else:
        print("⚠️ most_bought collection is empty\n")
else:
    print("❌ most_bought collection does NOT exist\n")
    print("Run migrate_to_most_bought.py first to create it\n")

# Also check if old is_best_seller field still exists
print("=== CHECKING OLD BEST SELLER FIELD ===\n")
products_with_best_seller = db.products.count_documents({"is_best_seller": {"$exists": True}})
print(f"Products with is_best_seller field: {products_with_best_seller}")

if products_with_best_seller > 0:
    print("⚠️ Warning: Some products still have is_best_seller field")
    print("   Run migrate_to_most_bought.py to clean up\n")
else:
    print("✅ No products have is_best_seller field (clean)\n")

client.close()
