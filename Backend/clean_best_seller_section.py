"""
Clean Best Seller Section - Remove all products from Best Seller and reset is_best_seller field
"""
from pymongo import MongoClient
from config_local import Settings

settings = Settings()
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

def clean_best_seller():
    """Set is_best_seller = False for all products"""
    print("\n=== CLEANING BEST SELLER SECTION ===\n")
    
    # Set is_best_seller = False for all products
    result = db.products.update_many(
        {},
        {"$set": {"is_best_seller": False}}
    )
    
    print(f"✅ Updated {result.modified_count} products")
    print(f"✅ Set is_best_seller = False for all products")
    
    # Verify the update
    best_seller_count = db.products.count_documents({"is_best_seller": True})
    print(f"\n📊 Products in Best Seller: {best_seller_count}")
    
    if best_seller_count == 0:
        print("✅ Best Seller section is now empty!")
    
    print("\n" + "=" * 60)
    print("✅ BEST SELLER SECTION CLEANED!")
    print("=" * 60)
    print("\nNow you can:")
    print("1. Open the dashboard")
    print("2. Click '☆ Best Seller' button on any product")
    print("3. Product will be added to Best Seller section")
    print("4. View it in Mobile View → Best Seller")
    print("5. Click the product card to navigate to original category")
    print()

if __name__ == "__main__":
    clean_best_seller()
