"""
Migration script to convert name-based references to ID-based system.

This will:
1. Add unique IDs to all sections, main categories, and subcategories
2. Update all products to reference IDs instead of names
3. Update hierarchy to use IDs
4. Keep name fields for display purposes
"""

from database.mongodb_client import get_mongo_db
from datetime import datetime
import hashlib

def generate_id(name):
    """Generate a consistent ID from name"""
    return hashlib.md5(name.lower().encode()).hexdigest()[:16]

def migrate():
    db = get_mongo_db()
    
    print("="*80)
    print("MIGRATION: Converting to ID-based system")
    print("="*80)
    
    # Step 1: Add section_id to hierarchy documents
    print("\n📋 STEP 1: Adding section_id to hierarchy documents...")
    hierarchy_docs = list(db.category_hierarchy.find())
    
    for doc in hierarchy_docs:
        # Handle both old (sections array) and new (section field) structure
        if 'section' in doc:
            section_name = doc['section']
            section_id = generate_id(section_name)
            
            result = db.category_hierarchy.update_one(
                {'_id': doc['_id']},
                {'$set': {'section_id': section_id}}
            )
            print(f"   ✓ Added section_id '{section_id}' for section '{section_name}'")
        
        elif 'sections' in doc and isinstance(doc['sections'], list):
            # Old structure with array
            for section_name in doc['sections']:
                section_id = generate_id(section_name)
                # For old structure, we'll add a mapping
                db.category_hierarchy.update_one(
                    {'_id': doc['_id']},
                    {'$set': {f'section_id_map.{section_name}': section_id}}
                )
                print(f"   ✓ Added section_id '{section_id}' for section '{section_name}' (old structure)")
        
        # Add IDs to main categories
        if 'main_categories' in doc:
            for main_cat_name, main_cat_data in doc['main_categories'].items():
                main_cat_id = generate_id(f"{doc.get('section', '')}_{main_cat_name}")
                
                # Add main_category_id
                db.category_hierarchy.update_one(
                    {'_id': doc['_id']},
                    {'$set': {f'main_categories.{main_cat_name}.main_category_id': main_cat_id}}
                )
                print(f"   ✓ Added main_category_id '{main_cat_id}' for '{main_cat_name}'")
                
                # Add IDs to subcategories
                if 'subcategories' in main_cat_data:
                    for sub_cat_name in main_cat_data['subcategories']:
                        sub_cat_id = generate_id(f"{doc.get('section', '')}_{main_cat_name}_{sub_cat_name}")
                        
                        db.category_hierarchy.update_one(
                            {'_id': doc['_id']},
                            {'$set': {f'main_categories.{main_cat_name}.subcategory_id_map.{sub_cat_name}': sub_cat_id}}
                        )
                        print(f"      ✓ Added subcategory_id '{sub_cat_id}' for '{sub_cat_name}'")
    
    # Step 2: Add IDs to metadata documents
    print("\n📋 STEP 2: Adding IDs to metadata documents...")
    metadata_docs = list(db.category_metadata.find())
    
    for doc in metadata_docs:
        doc_type = doc.get('type')
        
        if doc_type == 'section':
            section_name = doc.get('section')
            if section_name:
                section_id = generate_id(section_name)
                db.category_metadata.update_one(
                    {'_id': doc['_id']},
                    {'$set': {'section_id': section_id}}
                )
                print(f"   ✓ Added section_id to metadata for section '{section_name}'")
        
        elif doc_type == 'main_category' or doc_type == 'main':
            section_name = doc.get('section')
            main_cat_name = doc.get('name') or doc.get('main_category')
            if section_name and main_cat_name:
                main_cat_id = generate_id(f"{section_name}_{main_cat_name}")
                db.category_metadata.update_one(
                    {'_id': doc['_id']},
                    {'$set': {'main_category_id': main_cat_id}}
                )
                print(f"   ✓ Added main_category_id to metadata for '{main_cat_name}'")
        
        elif doc_type == 'subcategory':
            section_name = doc.get('section')
            main_cat_name = doc.get('main_category')
            sub_cat_name = doc.get('name') or doc.get('subcategory')
            if section_name and main_cat_name and sub_cat_name:
                sub_cat_id = generate_id(f"{section_name}_{main_cat_name}_{sub_cat_name}")
                db.category_metadata.update_one(
                    {'_id': doc['_id']},
                    {'$set': {'subcategory_id': sub_cat_id}}
                )
                print(f"   ✓ Added subcategory_id to metadata for '{sub_cat_name}'")
    
    # Step 3: Add ID fields to products
    print("\n📋 STEP 3: Adding ID fields to products...")
    products = list(db.products.find())
    
    for product in products:
        section_name = product.get('category_section')
        main_cat_name = product.get('category_main')
        sub_cat_name = product.get('category_sub')
        
        update_doc = {}
        
        if section_name:
            section_id = generate_id(section_name)
            update_doc['category_section_id'] = section_id
        
        if section_name and main_cat_name:
            main_cat_id = generate_id(f"{section_name}_{main_cat_name}")
            update_doc['category_main_id'] = main_cat_id
        
        if section_name and main_cat_name and sub_cat_name:
            sub_cat_id = generate_id(f"{section_name}_{main_cat_name}_{sub_cat_name}")
            update_doc['category_sub_id'] = sub_cat_id
        
        if update_doc:
            db.products.update_one(
                {'_id': product['_id']},
                {'$set': update_doc}
            )
            print(f"   ✓ Added IDs to product '{product.get('product_name', 'UNKNOWN')}'")
    
    # Step 4: Update most_bought collection
    print("\n📋 STEP 4: Adding IDs to most_bought entries...")
    most_bought = list(db.most_bought.find())
    
    for entry in most_bought:
        section_name = entry.get('section')
        main_cat_name = entry.get('main_category')
        
        update_doc = {}
        
        if section_name:
            section_id = generate_id(section_name)
            update_doc['section_id'] = section_id
        
        if section_name and main_cat_name:
            main_cat_id = generate_id(f"{section_name}_{main_cat_name}")
            update_doc['main_category_id'] = main_cat_id
        
        if update_doc:
            db.most_bought.update_one(
                {'_id': entry['_id']},
                {'$set': update_doc}
            )
            print(f"   ✓ Added IDs to most_bought entry for '{main_cat_name}'")
    
    print("\n" + "="*80)
    print("✅ MIGRATION COMPLETE!")
    print("="*80)
    print("\nSummary:")
    print(f"  - Hierarchy documents: {len(hierarchy_docs)}")
    print(f"  - Metadata documents: {len(metadata_docs)}")
    print(f"  - Products: {len(products)}")
    print(f"  - Most bought entries: {len(most_bought)}")
    print("\nNext steps:")
    print("  1. Update backend APIs to use IDs for queries")
    print("  2. Update frontend to send IDs in requests")
    print("  3. Keep name fields for display/backwards compatibility")

if __name__ == "__main__":
    migrate()
