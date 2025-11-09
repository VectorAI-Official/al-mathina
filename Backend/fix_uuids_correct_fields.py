"""
Fix UUID fields for products using correct field names
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

def fix_product_uuids_correct_fields():
    """Add UUIDs using the CORRECT field names: category_section, category_main, category_sub"""
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    
    print("🔍 Fixing UUID fields for all products...\n")
    
    products = db.products.find()
    updated_count = 0
    skipped_count = 0
    
    for product in products:
        # Use CORRECT field names
        section = product.get("category_section")
        main_cat = product.get("category_main")
        subcat = product.get("category_sub")
        
        if not section or not main_cat or not subcat:
            print(f"⚠️  Skipping {product.get('product_name')}: Missing category fields")
            print(f"   category_section: {section}, category_main: {main_cat}, category_sub: {subcat}")
            skipped_count += 1
            continue
        
        # Generate UUIDs
        section_id = generate_category_id(section)
        main_cat_id = generate_category_id(section, main_cat)
        subcat_id = generate_category_id(section, main_cat, subcat)
        
        # Update product with UUIDs
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
        
        print(f"✓ Updated: {product.get('product_name')}")
        print(f"  {section}/{main_cat}/{subcat}")
        print(f"  UUIDs: section={section_id[:8]}..., main={main_cat_id[:8]}..., sub={subcat_id[:8]}...")
        updated_count += 1
    
    print(f"\n✅ Updated {updated_count} products with UUIDs")
    print(f"⚠️  Skipped {skipped_count} products (missing category fields)")
    
    # Verify
    print(f"\n🔍 Verification:")
    with_uuids = db.products.count_documents({
        "category_section_id": {"$ne": None},
        "category_main_id": {"$ne": None},
        "category_sub_id": {"$ne": None}
    })
    total = db.products.count_documents({})
    print(f"Products with valid UUIDs: {with_uuids}/{total}")
    
    client.close()

if __name__ == "__main__":
    fix_product_uuids_correct_fields()
