#!/usr/bin/env python3
"""Check category_hierarchy collection to see all sections"""
from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/')
db = client['almadhinadb']

docs = list(db['category_hierarchy'].find({}, {'section': 1, 'main_categories': 1}))

print(f'Total sections in hierarchy: {len(docs)}')
print('=' * 60)

for i, doc in enumerate(docs, 1):
    section = doc.get('section', 'NO SECTION')
    main_cats = doc.get('main_categories', {})
    print(f"{i}. Section: '{section}'")
    print(f"   Main categories count: {len(main_cats)}")
    if main_cats:
        print(f"   Main categories: {list(main_cats.keys())[:5]}")
    print()
