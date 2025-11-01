#!/usr/bin/env python
"""Debug script to check hierarchy structure"""

from database.mongodb_client import get_mongo_db

db = get_mongo_db()

print("=== METADATA COLLECTION ===")
soft_drinks_meta = db.category_metadata.find_one({"name": "Soft Drinks"})
if soft_drinks_meta:
    print(f"Soft Drinks: type={soft_drinks_meta.get('type')}, section={soft_drinks_meta.get('section')}")
else:
    print("Soft Drinks not found in metadata")

print("\n=== CATEGORY_HIERARCHY COLLECTION ===")
hierarchy = db.category_hierarchy.find_one({})
if hierarchy:
    print(f"_id: {hierarchy.get('_id')}")
    print(f"sections: {hierarchy.get('sections')}")
    print(f"main_categories keys: {list(hierarchy.get('main_categories', {}).keys())}")
    print(f"main_categories structure:")
    for section, cats in hierarchy.get("main_categories", {}).items():
        print(f"  {section}: {cats}")
else:
    print("No hierarchy document found")

print("\n=== ALL HIERARCHY DOCS ===")
for doc in db.category_hierarchy.find({}):
    print(f"\nDoc ID: {doc.get('_id')}")
    print(f"  sections: {doc.get('sections')}")
    print(f"  main_categories: {doc.get('main_categories', {})}")
    
# Check specific section
print("\n=== LOOKING FOR SNACKS & DRINKS ===")
snacks_doc = db.category_hierarchy.find_one({"main_categories": {"$exists": True}})
if snacks_doc and snacks_doc.get("main_categories"):
    main_cats = snacks_doc.get("main_categories", {})
    for key in main_cats.keys():
        if "Snacks" in key or "Drinks" in key:
            print(f"Found in {key}: {main_cats[key]}")
