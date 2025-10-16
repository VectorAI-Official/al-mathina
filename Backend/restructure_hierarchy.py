"""
Complete Database Hierarchy Restructure
Fixes the mismatched Section → Main Category → Sub Category structure
"""
from pymongo import MongoClient
from config_local import Settings
from bson.objectid import ObjectId

settings = Settings()
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

def create_correct_hierarchy():
    """Create the correct 3-level category hierarchy"""
    print("\n=== CREATING CORRECT CATEGORY HIERARCHY ===\n")
    
    # Define the CORRECT hierarchy structure
    correct_hierarchy = [
        {
            "section": "Best Seller",
            "main_categories": {
                "Drinks & Juices": ["Soft Drinks", "Juices", "Energy Drinks", "Water"],
                "Atta, Rice & Dal": ["Basmati Rice", "Non-Basmati Rice", "Wheat Flour", "Pulses", "Atta"]
            }
        },
        {
            "section": "Grocery & Kitchen",
            "main_categories": {
                "Cooking Essentials": ["Cooking Oil", "Ghee", "Salt", "Sugar", "Spices"],
                "Atta, Rice & Dal": ["Wheat Flour", "Rice Varieties", "Pulses & Lentils"],
                "Snacks & Beverages": ["Biscuits", "Namkeen", "Chips", "Tea & Coffee"]
            }
        },
        {
            "section": "Snacks & Drinks",
            "main_categories": {
                "Biscuits & Cookies": ["Cream Biscuits", "Glucose Biscuits", "Cookies"],
                "Chips & Namkeen": ["Potato Chips", "Namkeen", "Popcorn"],
                "Chocolates & Candies": ["Chocolates", "Candies", "Toffees"],
                "Beverages": ["Tea", "Coffee", "Health Drinks", "Soft Drinks"]
            }
        },
        {
            "section": "Beauty & Personal Care",
            "main_categories": {
                "Bath & Body": ["Soap", "Body Wash", "Bath Accessories", "Bathing Essentials"],
                "Hair Care": ["Shampoo", "Conditioner", "Hair Oil", "Hair Color"],
                "Oral Care": ["Toothpaste", "Toothbrush", "Mouthwash"],
                "Skin Care": ["Face Wash", "Moisturizer", "Sunscreen"]
            }
        },
        {
            "section": "Household Essentials",
            "main_categories": {
                "Cleaning Supplies": ["Detergent", "Dishwash", "Floor Cleaner", "Toilet Cleaner"],
                "Kitchen Accessories": ["Containers", "Utensils", "Cookware"],
                "Home Care": ["Air Freshener", "Insect Repellent", "Garbage Bags"]
            }
        }
    ]
    
    # Clear existing hierarchy
    db.category_hierarchy.delete_many({})
    print("🗑️  Cleared old hierarchy")
    
    # Insert correct hierarchy
    for section_data in correct_hierarchy:
        db.category_hierarchy.insert_one(section_data)
        print(f"✅ Created: {section_data['section']}")
    
    print(f"\n✅ Successfully created {len(correct_hierarchy)} sections with correct hierarchy\n")

def fix_existing_products():
    """Fix the 2 existing products to match correct hierarchy"""
    print("=== FIXING EXISTING PRODUCTS ===\n")
    
    # Fix Lux Soap → Beauty & Personal Care → Bath & Body → Soap
    lux_result = db.products.update_one(
        {"product_name": {"$regex": "Lux.*Soap", "$options": "i"}},
        {"$set": {
            "category_section": "Beauty & Personal Care",
            "category_main": "Bath & Body",
            "category_sub": "Soap",
            "product_name": "Lux Soap"
        }}
    )
    if lux_result.modified_count > 0 or lux_result.matched_count > 0:
        print("✅ Fixed: Lux Soap → Beauty & Personal Care → Bath & Body → Soap")
    
    # Fix Aashirvaad Atta → Grocery & Kitchen → Atta, Rice & Dal → Wheat Flour (Atta)
    aashirvaad_result = db.products.update_one(
        {"product_name": {"$regex": "Aashirvaad.*Atta", "$options": "i"}},
        {"$set": {
            "category_section": "Grocery & Kitchen",
            "category_main": "Atta, Rice & Dal",
            "category_sub": "Wheat Flour",
            "product_name": "Aashirvaad Atta"
        }}
    )
    if aashirvaad_result.modified_count > 0 or aashirvaad_result.matched_count > 0:
        print("✅ Fixed: Aashirvaad Atta → Grocery & Kitchen → Atta, Rice & Dal → Wheat Flour")

def display_hierarchy():
    """Display the corrected hierarchy in tree format"""
    print("\n=== CORRECTED CATEGORY HIERARCHY ===\n")
    
    sections = db.category_hierarchy.find()
    
    for section_doc in sections:
        section_name = section_doc.get("section")
        main_categories = section_doc.get("main_categories", {})
        
        print(f"📁 Section: {section_name}")
        
        if not main_categories:
            print("   └── (empty)")
            continue
        
        main_cat_list = list(main_categories.items())
        for idx, (main_cat, subcategories) in enumerate(main_cat_list):
            is_last_main = (idx == len(main_cat_list) - 1)
            main_connector = "└──" if is_last_main else "├──"
            
            print(f"   {main_connector} Main Category: {main_cat}")
            
            if isinstance(subcategories, list):
                for i, sub_cat in enumerate(subcategories):
                    is_last_sub = (i == len(subcategories) - 1)
                    sub_connector = "└──" if is_last_sub else "├──"
                    indent = "       " if is_last_main else "   │   "
                    print(f"{indent}{sub_connector} Sub: {sub_cat}")
        
        print()

def verify_products():
    """Verify products with corrected categories"""
    print("=== PRODUCTS WITH CORRECTED HIERARCHY ===\n")
    
    products = db.products.find({"category_section": {"$exists": True}})
    
    count = 0
    for product in products:
        count += 1
        name = product.get("product_name", "Unknown")
        section = product.get("category_section", "?")
        main = product.get("category_main", "?")
        sub = product.get("category_sub", "?")
        
        print(f"{count}. {name}")
        print(f"   📁 Section: {section}")
        print(f"   📂 Main Category: {main}")
        print(f"   📄 Sub Category: {sub}")
        print()
    
    if count == 0:
        print("⚠️ No products found with new category structure")
    else:
        print(f"✅ Total products with correct structure: {count}\n")

def main():
    print("=" * 70)
    print("DATABASE HIERARCHY RESTRUCTURE")
    print("Fixing: Section → Main Category → Sub Category → Products")
    print("=" * 70)
    
    # Step 1: Create correct hierarchy
    create_correct_hierarchy()
    
    # Step 2: Fix existing products
    fix_existing_products()
    
    # Step 3: Display corrected hierarchy
    display_hierarchy()
    
    # Step 4: Verify products
    verify_products()
    
    print("=" * 70)
    print("✅ HIERARCHY RESTRUCTURE COMPLETED!")
    print("=" * 70)
    print("\nNext Steps:")
    print("1. ✅ Hierarchy structure is now correct")
    print("2. ✅ Existing products have been recategorized")
    print("3. ⏳ Test in dashboard to verify navigation works")
    print("4. ⏳ Migrate remaining 22 legacy products when ready")
    print()

if __name__ == "__main__":
    main()
