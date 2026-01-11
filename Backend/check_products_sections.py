#!/usr/bin/env python3
"""Check unique sections and main categories in products collection"""
from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/')
db = client['AL-Mathina']

# Get unique sections
sections = db['products'].distinct('category_section')
print(f'Total unique sections in products: {len(sections)}')
print('=' * 60)

for i, section in enumerate(sections[:20], 1):
    # Count main categories in this section
    main_cats = db['products'].distinct('category_main', {'category_section': section})
    print(f"{i}. Section: '{section}'")
    print(f"   Main categories: {len(main_cats)}")
    if main_cats:
        print(f"   Examples: {main_cats[:3]}")
    print()

print(f"\nTotal products: {db['products'].count_documents({})}")
