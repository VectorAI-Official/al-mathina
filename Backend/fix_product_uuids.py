"""
Check and fix UUID fields for all products
"""
import os
import uuid
from datetime import datetime
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

MONGODB_URI = os.getenv("MONGO_URI")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "almadhinadb")

def generate_category_id(section: str, main_category: str = None, subcategory: str = None) -> str:
    """Generate consistent UUID for a category based on its path"""
    key = f"{section}|{main_category or ''}|{subcategory or ''}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, key))

def fix_product_uuids():
    """Add UUIDs to ALL products, even those missing category fields"""
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    
    print("🔍 Checking all products for UUID fields...\n")
    
    # Get all products
    total_products = db.products.count_documents({})
    print(f"Total products in database: {total_products}")
    
    # Check how many have UUIDs
    with_uuids = db.products.count_documents({
        "category_section_id": {"$exists": True},
        "category_main_id": {"$exists": True},
        "category_sub_id": {"$exists": True}
    })
    print(f"Products with UUIDs: {with_uuids}")
    print(f"Products missing UUIDs: {total_products - with_uuids}\n")
    
    # Update all products
    print("🔄 Adding UUIDs to all products...\n")
    
    products = db.products.find()
    updated_count = 0
    skipped_count = 0
    
    for product in products:
        section = product.get("section")
        main_cat = product.get("main_category")
        subcat = product.get("subcategory")
        
        # Skip if any category field is missing
        if not section or not main_cat or not subcat:
            print(f"⚠️  Skipping product {product.get('product_name', 'Unknown')}: Missing category fields")
            print(f"   Section: {section}, Main: {main_cat}, Sub: {subcat}")
            skipped_count += 1
            continue
        
        # Generate UUIDs
        section_id = generate_category_id(section)
        main_cat_id = generate_category_id(section, main_cat)
        subcat_id = generate_category_id(section, main_cat, subcat)
        
        # Update product
        db.products.update_one(
            {"_id": product["_id"]},
            {
                "$set": {
                    "category_section_id": section_id,
                    "category_main_id": main_cat_id,
                    "category_sub_id": subcat_id,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        updated_count += 1
        
        if updated_count % 10 == 0:
            print(f"✓ Updated {updated_count} products...")
    
    print(f"\n✅ Updated {updated_count} products with UUIDs")
    print(f"⚠️  Skipped {skipped_count} products (missing category fields)")
    
    # Verify
    print(f"\n🔍 Verification:")
    final_with_uuids = db.products.count_documents({
        "category_section_id": {"$exists": True},
        "category_main_id": {"$exists": True},
        "category_sub_id": {"$exists": True}
    })
    print(f"Products with UUIDs: {final_with_uuids}/{total_products}")
    
    # Show sample product
    sample = db.products.find_one({"category_section_id": {"$exists": True}})
    if sample:
        print(f"\n📋 Sample product:")
        print(f"   Name: {sample.get('product_name')}")
        print(f"   Section: {sample.get('section')}")
        print(f"   Main Category: {sample.get('main_category')}")
        print(f"   Subcategory: {sample.get('subcategory')}")
        print(f"   Section ID: {sample.get('category_section_id')}")
        print(f"   Main ID: {sample.get('category_main_id')}")
        print(f"   Sub ID: {sample.get('category_sub_id')}")
    
    client.close()

if __name__ == "__main__":
    fix_product_uuids()
