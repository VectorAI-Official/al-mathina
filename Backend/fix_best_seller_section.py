"""
Fix Best Seller Section - Remove from category hierarchy
Best Seller should be a special section that shows featured products, not a regular category
"""
from pymongo import MongoClient
from config_local import Settings

settings = Settings()
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

def fix_best_seller_section():
    print("\n=== FIXING BEST SELLER SECTION ===\n")
    
    # Step 1: Remove Best Seller from category_hierarchy
    result = db.category_hierarchy.delete_many({"section": "Best Seller"})
    print(f"✅ Removed Best Seller from category_hierarchy: {result.deleted_count} document(s)")
    
    # Step 2: Remove any Best Seller metadata
    result = db.category_metadata.delete_many({"section": "Best Seller"})
    print(f"✅ Removed Best Seller metadata: {result.deleted_count} document(s)")
    
    # Step 3: Verify - show remaining sections
    sections = db.category_hierarchy.find({}, {"section": 1})
    print(f"\n📊 Remaining sections in category_hierarchy:")
    for sec in sections:
        print(f"   - {sec.get('section')}")
    
    # Step 4: Ensure all products have is_best_seller field
    result = db.products.update_many(
        {"is_best_seller": {"$exists": False}},
        {"$set": {"is_best_seller": False}}
    )
    print(f"\n✅ Added is_best_seller field to {result.modified_count} products")
    
    # Step 5: Show products in Best Seller (should be 0 initially)
    best_seller_count = db.products.count_documents({"is_best_seller": True})
    print(f"📊 Products with is_best_seller=true: {best_seller_count}")
    
    print("\n" + "=" * 70)
    print("✅ BEST SELLER SECTION FIXED!")
    print("=" * 70)
    print("\nWhat changed:")
    print("1. ✅ Best Seller removed from category_hierarchy")
    print("2. ✅ Best Seller will NOT show main categories anymore")
    print("3. ✅ Best Seller will show featured products directly")
    print("4. ✅ All products have is_best_seller field")
    print("\nHow it works now:")
    print("1. Open dashboard → Click '☆ Best Seller' on any product")
    print("2. Open Mobile View → Click 'Best Seller'")
    print("3. You'll see featured products directly (no main categories)")
    print("4. Click product card → Navigate to original category")
    print()

if __name__ == "__main__":
    fix_best_seller_section()
