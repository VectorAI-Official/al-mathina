"""
Script to drop the problematic category_1_brand_1 unique index from products collection.

This index is preventing multiple products from having the same category and brand,
which is not the desired behavior. Products should be able to share categories and brands.
"""

from pymongo import MongoClient
from config_local import Settings

def drop_index():
    try:
        # Load settings
        settings = Settings()
        
        # Connect to MongoDB
        client = MongoClient(settings.mongo_uri)
        db = client[settings.mongo_db_name]
        
        # Get products collection
        products = db.products
        
        # List all indexes
        print("\n=== CURRENT INDEXES ===")
        indexes = products.list_indexes()
        for idx in indexes:
            print(f"Index: {idx}")
        
        # Drop the problematic index
        print("\n=== DROPPING INDEX ===")
        try:
            products.drop_index("category_1_brand_1")
            print("✅ Successfully dropped index: category_1_brand_1")
        except Exception as e:
            print(f"⚠️ Could not drop index: {e}")
            print("(This is OK if the index doesn't exist)")
        
        # List indexes after dropping
        print("\n=== INDEXES AFTER DROPPING ===")
        indexes = products.list_indexes()
        for idx in indexes:
            print(f"Index: {idx}")
        
        print("\n✅ Index management complete!")
        print("You can now add products with the same category and brand combination.")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    print("=" * 60)
    print("MongoDB Index Management - Drop category_1_brand_1")
    print("=" * 60)
    drop_index()
