"""
Fix Database Hierarchy - Align all data with proper Section → Main Category → Sub Category structure
"""
from pymongo import MongoClient
from config_local import Settings
from bson.objectid import ObjectId

settings = Settings()
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

def fix_product_categories():
    """Fix product categorization to match proper hierarchy"""
    print("\n=== FIXING PRODUCT CATEGORIES ===\n")
    
    # Fix Lux Soap - should be in Beauty & Personal Care → Bath & Body → Soap
    lux_result = db.products.update_one(
        {"_id": ObjectId("68edfea84b30a58236fe02be")},
        {"$set": {
            "category_section": "Beauty & Personal Care",
            "category_main": "Bath & Body",
            "category_sub": "Soap",
            "product_name": "Lux Soap"  # Ensure proper name
        }}
    )
    if lux_result.modified_count > 0:
        print("✅ Fixed Lux Soap categorization: Beauty & Personal Care → Bath & Body → Soap")
    else:
        print("⚠️ Lux Soap not found or already correct")
    
    # Verify Aashirvaad Atta - should be in Grocery & Kitchen → Atta, Rice & Dal → Atta
    aashirvaad_result = db.products.update_one(
        {"_id": ObjectId("68edfea84b30a58236fe02ba")},
        {"$set": {
            "category_section": "Grocery & Kitchen",
            "category_main": "Atta, Rice & Dal",
            "category_sub": "Atta",
            "product_name": "Aashirvaad Atta"
        }}
    )
    if aashirvaad_result.modified_count > 0:
        print("✅ Fixed Aashirvaad Atta categorization: Grocery & Kitchen → Atta, Rice & Dal → Atta")
    else:
        print("⚠️ Aashirvaad Atta not found or already correct")

def cleanup_test_data():
    """Remove test categories and invalid entries"""
    print("\n=== CLEANING UP TEST DATA ===\n")
    
    # Remove test categories named "summa"
    summa_result = db.category_metadata.delete_many({"name": "summa"})
    print(f"✅ Removed {summa_result.deleted_count} test categories named 'summa'")
    
    # Remove invalid section name "[object PointerEvent]"
    pointer_result = db.category_metadata.delete_one({"section": "[object PointerEvent]"})
    if pointer_result.deleted_count > 0:
        print("✅ Removed invalid section: '[object PointerEvent]'")
    
    # Fix invalid image URL for Drinks & Juices section
    drinks_result = db.category_metadata.update_one(
        {
            "section": "Drinks & Juices",
            "type": "section",
            "image_url": {"$regex": "dashboard"}
        },
        {"$unset": {"image_url": ""}}  # Remove invalid URL, will need re-upload
    )
    if drinks_result.modified_count > 0:
        print("✅ Fixed invalid image URL for 'Drinks & Juices' section (needs re-upload)")

def verify_category_hierarchy():
    """Verify and display the corrected hierarchy"""
    print("\n=== VERIFYING CATEGORY HIERARCHY ===\n")
    
    sections = db.category_hierarchy.find()
    
    for section_doc in sections:
        section_name = section_doc.get("section")
        main_categories = section_doc.get("main_categories", {})
        
        print(f"📁 {section_name}")
        
        if not main_categories:
            print("   └── (empty)")
            continue
        
        for main_cat, subcategories in main_categories.items():
            print(f"   ├── {main_cat}")
            
            if isinstance(subcategories, list):
                for i, sub_cat in enumerate(subcategories):
                    is_last = (i == len(subcategories) - 1)
                    connector = "└──" if is_last else "├──"
                    print(f"   │   {connector} {sub_cat}")
            else:
                print(f"   │   └── (invalid structure)")
        
        print()

def show_fixed_products():
    """Show products with their corrected categories"""
    print("\n=== PRODUCTS WITH PROPER HIERARCHY ===\n")
    
    # Show only products with new schema (category_section field)
    products = db.products.find({"category_section": {"$exists": True}})
    
    count = 0
    for product in products:
        count += 1
        name = product.get("product_name", "Unknown")
        section = product.get("category_section", "?")
        main = product.get("category_main", "?")
        sub = product.get("category_sub", "?")
        image = product.get("image", "No image")
        
        print(f"{count}. {name}")
        print(f"   Hierarchy: {section} → {main} → {sub}")
        print(f"   Image: {image}")
        print()
    
    if count == 0:
        print("⚠️ No products found with new category structure")

def cleanup_best_seller_summa():
    """Remove 'summa' from Best Seller main_categories"""
    print("\n=== CLEANING BEST SELLER HIERARCHY ===\n")
    
    result = db.category_hierarchy.update_one(
        {"section": "Best Seller"},
        {"$unset": {"main_categories.summa": ""}}
    )
    
    if result.modified_count > 0:
        print("✅ Removed 'summa' test category from Best Seller section")
    else:
        print("⚠️ No 'summa' category found in Best Seller")

def main():
    print("=" * 60)
    print("DATABASE HIERARCHY FIX SCRIPT")
    print("=" * 60)
    
    # Step 1: Clean up test data
    cleanup_test_data()
    cleanup_best_seller_summa()
    
    # Step 2: Fix product categories
    fix_product_categories()
    
    # Step 3: Verify hierarchy
    verify_category_hierarchy()
    
    # Step 4: Show fixed products
    show_fixed_products()
    
    print("\n" + "=" * 60)
    print("✅ DATABASE HIERARCHY FIX COMPLETED!")
    print("=" * 60)
    print("\nNext Steps:")
    print("1. Re-upload image for 'Drinks & Juices' section (if needed)")
    print("2. Verify products display correctly in dashboard")
    print("3. Migrate remaining 22 legacy products")
    print()

if __name__ == "__main__":
    main()
