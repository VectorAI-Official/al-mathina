"""
Update existing products to add is_best_seller field (default false)
"""
from pymongo import MongoClient
from config_local import Settings

settings = Settings()
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

def add_best_seller_field():
    """Add is_best_seller field to all products that don't have it"""
    print("\n=== ADDING is_best_seller FIELD TO PRODUCTS ===\n")
    
    # Update all products without is_best_seller field
    result = db.products.update_many(
        {"is_best_seller": {"$exists": False}},
        {"$set": {"is_best_seller": False}}
    )
    
    print(f"✅ Updated {result.modified_count} products with is_best_seller=false")
    
    # Show current status
    total = db.products.count_documents({})
    best_sellers = db.products.count_documents({"is_best_seller": True})
    
    print(f"\n📊 Current Status:")
    print(f"   Total Products: {total}")
    print(f"   Best Seller Products: {best_sellers}")
    print(f"   Regular Products: {total - best_sellers}")
    print()

if __name__ == "__main__":
    add_best_seller_field()
