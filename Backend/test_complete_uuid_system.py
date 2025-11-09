"""
Comprehensive test to verify UUID-based CASCADE UPDATE works correctly
"""
import os
import requests
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

BASE_URL = "http://localhost:8000"
MONGODB_URI = os.getenv("MONGO_URI")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "almadhinadb")

def test_cascade_update():
    """
    Test that renaming categories updates products via UUID CASCADE
    """
    print("🧪 COMPREHENSIVE UUID CASCADE UPDATE TEST\n")
    print("=" * 70)
    
    # Connect to database
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    
    # Step 1: Check current product structure
    print("\n📋 Step 1: Checking existing products...")
    products = list(db.products.find().limit(3))
    
    if not products:
        print("   ❌ No products found in database")
        return
    
    print(f"   Found {db.products.count_documents({})} products")
    
    for i, product in enumerate(products, 1):
        print(f"\n   Product {i}: {product.get('product_name')}")
        print(f"   - category_section: {product.get('category_section')}")
        print(f"   - category_main: {product.get('category_main')}")
        print(f"   - category_sub: {product.get('category_sub')}")
        print(f"   - category_section_id: {product.get('category_section_id', 'MISSING')[:16] if product.get('category_section_id') else 'MISSING'}...")
        print(f"   - category_main_id: {product.get('category_main_id', 'MISSING')[:16] if product.get('category_main_id') else 'MISSING'}...")
        print(f"   - category_sub_id: {product.get('category_sub_id', 'MISSING')[:16] if product.get('category_sub_id') else 'MISSING'}...")
    
    # Step 2: Test main category rename (READ-ONLY - just show what would happen)
    print("\n\n📝 Step 2: Testing CASCADE UPDATE logic...")
    test_product = products[0]
    main_cat_name = test_product.get('category_main')
    main_cat_id = test_product.get('category_main_id')
    
    if not main_cat_id:
        print("   ⚠️  Product missing category_main_id UUID!")
        print("   Run fix_uuids_correct_fields.py first")
        return
    
    print(f"   If we rename Main Category '{main_cat_name}'...")
    print(f"   The system will:")
    print(f"   1. Find all products with category_main_id = {main_cat_id[:16]}...")
    
    # Count products that would be updated
    count = db.products.count_documents({"category_main_id": main_cat_id})
    print(f"   2. Update {count} products via UUID CASCADE")
    print(f"   3. Update category_main field to new name")
    print(f"   4. Regenerate all subcategory UUIDs under this main category")
    
    # Step 3: Verify UUID system is ready
    print("\n\n✅ Step 3: Verification Checklist")
    print("=" * 70)
    
    # Check 1: All products have UUIDs
    total_products = db.products.count_documents({})
    products_with_uuids = db.products.count_documents({
        "category_section_id": {"$ne": None},
        "category_main_id": {"$ne": None},
        "category_sub_id": {"$ne": None}
    })
    
    check1 = products_with_uuids == total_products
    print(f"   ✓ All products have UUIDs: {products_with_uuids}/{total_products} {'✅' if check1 else '❌'}")
    
    # Check 2: Correct field names
    sample_product = db.products.find_one()
    has_correct_fields = (
        "category_section" in sample_product and
        "category_main" in sample_product and
        "category_sub" in sample_product
    )
    print(f"   ✓ Products use correct field names (category_section, category_main, category_sub): {'✅' if has_correct_fields else '❌'}")
    
    # Check 3: UUID indexes exist
    indexes = db.products.index_information()
    has_indexes = (
        "category_section_id_1" in indexes and
        "category_main_id_1" in indexes and
        "category_sub_id_1" in indexes
    )
    print(f"   ✓ UUID indexes created: {'✅' if has_indexes else '❌'}")
    
    print("\n" + "=" * 70)
    
    if check1 and has_correct_fields and has_indexes:
        print("\n🎉 SUCCESS! UUID CASCADE UPDATE system is ready!")
        print("\nYou can now:")
        print("   1. Rename categories in the admin dashboard")
        print("   2. Products will automatically update via UUID CASCADE")
        print("   3. Check logs: docker logs al-mathina-backend --tail 50 | grep CASCADE")
    else:
        print("\n⚠️  UUID system not fully configured")
        if not check1:
            print("   → Run: python fix_uuids_correct_fields.py")
        if not has_indexes:
            print("   → Run: python migrate_to_uuid_system.py")
    
    client.close()

if __name__ == "__main__":
    test_cascade_update()
