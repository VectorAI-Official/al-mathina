#!/usr/bin/env python
"""Rebuild category hierarchy from metadata"""

from database.mongodb_client import get_mongo_db
from collections import defaultdict

db = get_mongo_db()

print("🔨 REBUILDING HIERARCHY FROM METADATA...\n")

# Step 1: Get all main categories from metadata
main_categories_by_section = defaultdict(list)
subcategories_by_main = defaultdict(lambda: defaultdict(list))

metadata_docs = db.category_metadata.find({"type": {"$in": ["main_category", "subcategory"]}})

for doc in metadata_docs:
    doc_type = doc.get("type")
    section = doc.get("section")
    name = doc.get("name")
    
    if doc_type == "main_category" and section and name:
        if name not in main_categories_by_section[section]:
            main_categories_by_section[section].append(name)
            print(f"✅ Main category: {section} → {name}")
    
    elif doc_type == "subcategory" and section and name:
        main_category = doc.get("main_category")
        if main_category and name not in subcategories_by_main[main_category][section]:
            subcategories_by_main[main_category][section].append(name)
            print(f"✅ Subcategory: {main_category} → {name}")

print("\n🔄 BUILDING NEW HIERARCHY DOCUMENTS...\n")

# Step 2: Clear old hierarchy
db.category_hierarchy.delete_many({})
print("🗑️  Cleared old hierarchy documents")

# Step 3: Create new hierarchy documents
for section, main_cats in main_categories_by_section.items():
    # Build main_categories structure
    main_categories_dict = {}
    for main_cat in main_cats:
        # Get subcategories for this main category
        subs = subcategories_by_main.get(main_cat, {}).get(section, [])
        main_categories_dict[main_cat] = subs
    
    # Create hierarchy document
    hierarchy_doc = {
        "section": section,
        "main_categories": main_categories_dict
    }
    
    result = db.category_hierarchy.insert_one(hierarchy_doc)
    print(f"\n📝 Created hierarchy for '{section}':")
    print(f"   Main categories: {list(main_categories_dict.keys())}")
    for main_cat, subs in main_categories_dict.items():
        print(f"     • {main_cat}: {subs}")

print("\n✅ HIERARCHY REBUILT SUCCESSFULLY!")

# Verify
print("\n🔍 VERIFICATION...\n")
for doc in db.category_hierarchy.find({}):
    print(f"Section: {doc.get('section')}")
    print(f"  Main categories: {list(doc.get('main_categories', {}).keys())}")
    for main_cat, subs in doc.get("main_categories", {}).items():
        print(f"    • {main_cat}: {len(subs)} subcategories - {subs}")
