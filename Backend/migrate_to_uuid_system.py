"""
Migration script to convert category system from name-based to UUID-based IDs
This ensures proper referential integrity when renaming categories
"""
import uuid
import os
from datetime import datetime
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

MONGODB_URI = os.getenv("MONGO_URI")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "almadhinadb")

def generate_category_id(section, main_category=None, subcategory=None):
    """Generate consistent UUID for a category"""
    key = f"{section}|{main_category or ''}|{subcategory or ''}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, key))

def migrate_to_uuid_system():
    """Migrate entire database to UUID-based category system"""
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    
    print("🚀 Starting UUID-based category system migration...")
    
    # Step 1: Create ID mappings for all categories
    print("\n📋 Step 1: Creating UUID mappings...")
    section_map = {}
    main_category_map = {}
    subcategory_map = {}
    
    # Get all unique sections
    sections = db.products.distinct("section")
    for section in sections:
        section_id = generate_category_id(section)
        section_map[section] = section_id
        print(f"  Section: {section} → {section_id}")
    
    # Get all unique main categories
    main_cats = db.products.aggregate([
        {"$match": {"section": {"$exists": True}, "main_category": {"$exists": True}}},
        {"$group": {"_id": {"section": "$section", "main_category": "$main_category"}}}
    ])
    for item in main_cats:
        if "_id" not in item or item["_id"] is None:
            continue
        section = item["_id"].get("section", "")
        main_cat = item["_id"].get("main_category", "")
        if not section or not main_cat:
            continue
        main_cat_id = generate_category_id(section, main_cat)
        main_category_map[(section, main_cat)] = main_cat_id
        print(f"  Main Cat: {section}/{main_cat} → {main_cat_id}")
    
    # Get all unique subcategories
    subcats = db.products.aggregate([
        {"$match": {"section": {"$exists": True}, "main_category": {"$exists": True}, "subcategory": {"$exists": True}}},
        {"$group": {"_id": {
            "section": "$section",
            "main_category": "$main_category",
            "subcategory": "$subcategory"
        }}}
    ])
    for item in subcats:
        if "_id" not in item or item["_id"] is None:
            continue
        section = item["_id"].get("section", "")
        main_cat = item["_id"].get("main_category", "")
        subcat = item["_id"].get("subcategory", "")
        if not section or not main_cat or not subcat:
            continue
        subcat_id = generate_category_id(section, main_cat, subcat)
        subcategory_map[(section, main_cat, subcat)] = subcat_id
        print(f"  Subcat: {section}/{main_cat}/{subcat} → {subcat_id}")
    
    # Step 2: Add UUID fields to products
    print(f"\n📦 Step 2: Updating products with UUIDs...")
    products = db.products.find()
    updated_count = 0
    
    for product in products:
        section = product.get("section", "")
        main_cat = product.get("main_category", "")
        subcat = product.get("subcategory", "")
        
        update_doc = {
            "category_section_id": section_map.get(section),
            "category_main_id": main_category_map.get((section, main_cat)),
            "category_sub_id": subcategory_map.get((section, main_cat, subcat)),
            "updated_at": datetime.utcnow()
        }
        
        db.products.update_one(
            {"_id": product["_id"]},
            {"$set": update_doc}
        )
        updated_count += 1
        if updated_count % 100 == 0:
            print(f"  Updated {updated_count} products...")
    
    print(f"✅ Updated {updated_count} products with UUIDs")
    
    # Step 3: Add UUIDs to category_metadata
    print(f"\n📂 Step 3: Updating category_metadata with UUIDs...")
    
    # Update section metadata
    for section, section_id in section_map.items():
        db.category_metadata.update_one(
            {"section": section, "type": "section"},
            {
                "$set": {
                    "category_id": section_id,
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
    print(f"  Updated {len(section_map)} sections")
    
    # Update main category metadata
    for (section, main_cat), main_cat_id in main_category_map.items():
        db.category_metadata.update_one(
            {
                "section": section,
                "name": main_cat,
                "type": "main_category"
            },
            {
                "$set": {
                    "category_id": main_cat_id,
                    "section_id": section_map.get(section),
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
    print(f"  Updated {len(main_category_map)} main categories")
    
    # Update subcategory metadata
    for (section, main_cat, subcat), subcat_id in subcategory_map.items():
        db.category_metadata.update_one(
            {
                "section": section,
                "main_category": main_cat,
                "name": subcat,
                "type": "subcategory"
            },
            {
                "$set": {
                    "category_id": subcat_id,
                    "section_id": section_map.get(section),
                    "main_category_id": main_category_map.get((section, main_cat)),
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
    print(f"  Updated {len(subcategory_map)} subcategories")
    
    # Step 4: Create indexes on UUID fields
    print(f"\n🔍 Step 4: Creating indexes on UUID fields...")
    db.products.create_index("category_section_id")
    db.products.create_index("category_main_id")
    db.products.create_index("category_sub_id")
    # Create sparse index for category_id (allows null values)
    db.category_metadata.create_index("category_id", unique=True, sparse=True)
    print("✅ Indexes created")
    
    print("\n✨ Migration completed successfully!")
    print("\nSummary:")
    print(f"  - Sections: {len(section_map)}")
    print(f"  - Main Categories: {len(main_category_map)}")
    print(f"  - Subcategories: {len(subcategory_map)}")
    print(f"  - Products: {updated_count}")
    print("\n⚠️  NOTE: The old name-based fields are kept for backward compatibility")
    print("   New queries should use ID-based fields for proper referential integrity")
    
    client.close()

if __name__ == "__main__":
    migrate_to_uuid_system()
