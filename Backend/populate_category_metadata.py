"""Populate category_metadata for all existing categories"""
from pymongo import MongoClient
from datetime import datetime

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['almadhinadb']

metadata_collection = db['category_metadata']
hierarchy_collection = db['category_hierarchy']

print("=" * 60)
print("POPULATING CATEGORY METADATA")
print("=" * 60)

# Get all sections and their main categories from category_hierarchy
hierarchy_docs = list(hierarchy_collection.find())

added_count = 0
existing_count = 0

for hierarchy_doc in hierarchy_docs:
    section = hierarchy_doc.get('section')
    main_categories = hierarchy_doc.get('main_categories', {})
    
    print(f"\n📁 Section: {section}")
    
    # Check if section metadata exists
    section_metadata = metadata_collection.find_one({
        "section": section,
        "type": "section"
    })
    
    if not section_metadata:
        metadata_collection.insert_one({
            "section": section,
            "type": "section",
            "created_at": datetime.now()
        })
        print(f"  ✅ Added section metadata for: {section}")
        added_count += 1
    else:
        print(f"  ⏭️  Section metadata already exists")
        existing_count += 1
    
    # Add metadata for each main category
    for main_category, subcategories in main_categories.items():
        main_cat_metadata = metadata_collection.find_one({
            "section": section,
            "main_category": main_category,
            "type": "main_category"
        })
        
        if not main_cat_metadata:
            # Insert with empty image_url - admin can upload later
            metadata_collection.insert_one({
                "section": section,
                "main_category": main_category,
                "name": main_category,
                "type": "main_category",
                "image_url": "",
                "created_at": datetime.now()
            })
            print(f"  ✅ Added main category metadata: {main_category}")
            added_count += 1
        else:
            print(f"  ⏭️  Main category metadata already exists: {main_category}")
            existing_count += 1
        
        # Add metadata for subcategories
        for subcategory in subcategories:
            sub_cat_metadata = metadata_collection.find_one({
                "section": section,
                "main_category": main_category,
                "subcategory": subcategory,
                "type": "subcategory"
            })
            
            if not sub_cat_metadata:
                metadata_collection.insert_one({
                    "section": section,
                    "main_category": main_category,
                    "subcategory": subcategory,
                    "name": subcategory,
                    "type": "subcategory",
                    "image_url": "",
                    "created_at": datetime.now()
                })
                print(f"    ✅ Added subcategory metadata: {subcategory}")
                added_count += 1
            else:
                print(f"    ⏭️  Subcategory metadata exists: {subcategory}")
                existing_count += 1

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"✅ Added: {added_count} documents")
print(f"⏭️  Existing: {existing_count} documents")
print(f"📊 Total metadata documents: {metadata_collection.count_documents({})}")

# Show sample of what was added
print("\n" + "=" * 60)
print("SAMPLE METADATA DOCUMENTS")
print("=" * 60)
sample_docs = list(metadata_collection.find({"type": "main_category"}).limit(5))
import json
for doc in sample_docs:
    print(json.dumps(doc, indent=2, default=str))
    print("-" * 60)
