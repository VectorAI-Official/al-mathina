#!/usr/bin/env python
"""Fix Soft Drinks subcategory and rebuild hierarchy"""

from database.mongodb_client import get_mongo_db
from collections import defaultdict

db = get_mongo_db()

print("🔧 FIXING SOFT DRINKS SUBCATEGORY...")

# Fix the Soft Drinks subcategory to point to Drinks main category
result = db.category_metadata.update_one(
    {'name': 'Soft Drinks', 'type': 'subcategory', 'section': 'Snacks & Drinks'},
    {'$set': {'main_category': 'Drinks'}}
)

print(f"✅ Updated {result.modified_count} document(s)")

# Verify
doc = db.category_metadata.find_one({'name': 'Soft Drinks', 'type': 'subcategory'})
print(f"   Soft Drinks now: Type={doc.get('type')}, Section={doc.get('section')}, Main={doc.get('main_category')}")

# Now rebuild hierarchy
print("\n🔨 REBUILDING HIERARCHY...")

main_categories_by_section = defaultdict(list)
subcategories_by_main = defaultdict(lambda: defaultdict(list))

metadata_docs = db.category_metadata.find({'type': {'$in': ['main_category', 'subcategory']}})

for doc in metadata_docs:
    doc_type = doc.get('type')
    section = doc.get('section')
    name = doc.get('name')
    
    if doc_type == 'main_category' and section and name:
        if name not in main_categories_by_section[section]:
            main_categories_by_section[section].append(name)
    
    elif doc_type == 'subcategory' and section and name:
        main_category = doc.get('main_category')
        if main_category and name not in subcategories_by_main[main_category][section]:
            subcategories_by_main[main_category][section].append(name)

# Clear and rebuild
db.category_hierarchy.delete_many({})

for section, main_cats in main_categories_by_section.items():
    main_categories_dict = {}
    for main_cat in main_cats:
        subs = subcategories_by_main.get(main_cat, {}).get(section, [])
        main_categories_dict[main_cat] = subs
    
    hierarchy_doc = {
        'section': section,
        'main_categories': main_categories_dict
    }
    
    result = db.category_hierarchy.insert_one(hierarchy_doc)
    print(f"\n✅ {section}:")
    for main_cat, subs in main_categories_dict.items():
        print(f"   • {main_cat}: {subs}")

print("\n✅ HIERARCHY FIXED AND REBUILT!")
