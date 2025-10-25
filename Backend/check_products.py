"""
Check product structure in database
"""

from config_local import get_database

def check_products():
    db = get_database()
    products_collection = db['products']
    
    # Get a sample product
    product = products_collection.find_one()
    
    print("Sample product structure:")
    for key, value in product.items():
        print(f"  {key}: {value}")
    
    print("\n\nChecking products for section/main_category/subcategory fields:")
    
    # Count products with these fields
    total = products_collection.count_documents({})
    with_section = products_collection.count_documents({"section": {"$exists": True, "$ne": None}})
    with_main = products_collection.count_documents({"main_category": {"$exists": True, "$ne": None}})
    with_sub = products_collection.count_documents({"subcategory": {"$exists": True, "$ne": None}})
    
    print(f"Total products: {total}")
    print(f"Products with section: {with_section}")
    print(f"Products with main_category: {with_main}")
    print(f"Products with subcategory: {with_sub}")

if __name__ == "__main__":
    check_products()
