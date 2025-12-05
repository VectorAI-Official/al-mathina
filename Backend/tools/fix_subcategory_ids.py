#!/usr/bin/env python3
"""
Fix Subcategory ID System
Ensures all products have proper category_sub_id field
"""

import sys
import os
import uuid
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.mongodb_client import get_mongo_db
from datetime import datetime

def generate_category_id(section: str, main_category: str = None, subcategory: str = None) -> str:
    """Generate consistent UUID for a category based on its path"""
    key = f"{section}|{main_category or ''}|{subcategory or ''}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, key))

def fix_subcategory_ids():
    """Add or fix category_sub_id for all products"""
    db = get_mongo_db()
    products_collection = db.products
    
    print("🔍 Checking products for missing subcategory IDs...")
    
    # Find all products
    all_products = list(products_collection.find())
    print(f"📊 Found {len(all_products)} total products")
    
    fixed_count = 0
    already_ok = 0
    errors = []
    
    for product in all_products:
        product_name = product.get('product_name', 'UNKNOWN')
        section = product.get('category_section')
        main_cat = product.get('category_main')
        sub_cat = product.get('category_sub')
        current_sub_id = product.get('category_sub_id')
        
        if not (section and main_cat and sub_cat):
            errors.append(f"❌ {product_name}: Missing category fields")
            continue
        
        # Generate correct IDs
        expected_section_id = generate_category_id(section)
        expected_main_id = generate_category_id(section, main_cat)
        expected_sub_id = generate_category_id(section, main_cat, sub_cat)
        
        # Check if IDs are correct
        needs_update = False
        update_fields = {}
        
        if product.get('category_section_id') != expected_section_id:
            update_fields['category_section_id'] = expected_section_id
            needs_update = True
        
        if product.get('category_main_id') != expected_main_id:
            update_fields['category_main_id'] = expected_main_id
            needs_update = True
        
        if product.get('category_sub_id') != expected_sub_id:
            update_fields['category_sub_id'] = expected_sub_id
            needs_update = True
        
        if needs_update:
            update_fields['updated_at'] = datetime.utcnow()
            
            result = products_collection.update_one(
                {'_id': product['_id']},
                {'$set': update_fields}
            )
            
            if result.modified_count > 0:
                print(f"✅ Fixed: {product_name} ({section}/{main_cat}/{sub_cat})")
                print(f"   → subcategory_id: {expected_sub_id}")
                fixed_count += 1
        else:
            already_ok += 1
    
    print(f"\n📊 Summary:")
    print(f"   ✅ Fixed: {fixed_count} products")
    print(f"   👍 Already OK: {already_ok} products")
    print(f"   ❌ Errors: {len(errors)} products")
    
    if errors:
        print(f"\n❌ Products with errors:")
        for error in errors:
            print(f"   {error}")
    
    print(f"\n🎉 Done! All products now have proper subcategory IDs")
    
    # Show some examples
    print(f"\n📋 Sample products with IDs:")
    sample_products = list(products_collection.find().limit(5))
    for p in sample_products:
        print(f"   • {p.get('product_name')}")
        print(f"     section_id: {p.get('category_section_id', 'MISSING')}")
        print(f"     main_id: {p.get('category_main_id', 'MISSING')}")
        print(f"     sub_id: {p.get('category_sub_id', 'MISSING')}")

if __name__ == "__main__":
    try:
        fix_subcategory_ids()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
