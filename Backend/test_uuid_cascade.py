"""
Test script to verify UUID-based CASCADE UPDATE works correctly
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = "http://localhost:8000"

def test_main_category_rename():
    """Test that renaming main category updates all products via UUID"""
    
    print("🧪 Testing UUID-based CASCADE UPDATE for Main Category Rename\n")
    
    # Step 1: Get current main categories
    print("📋 Step 1: Fetching current main categories...")
    response = requests.get(f"{BASE_URL}/admin/api/main-categories?section=UNKNOWN")
    if response.status_code == 200:
        main_cats = response.json().get("main_categories", [])
        print(f"   Found {len(main_cats)} main categories")
        if main_cats:
            print(f"   First main category: {main_cats[0]['name']}")
    else:
        print(f"   ❌ Failed to fetch main categories: {response.status_code}")
        return
    
    # Step 2: Get products in first main category
    if main_cats:
        first_cat = main_cats[0]['name']
        print(f"\n📦 Step 2: Fetching products in main category '{first_cat}'...")
        
        response = requests.get(
            f"{BASE_URL}/admin/api/products/all",
            params={"section": "UNKNOWN", "main_category": first_cat}
        )
        
        if response.status_code == 200:
            products = response.json().get("products", [])
            print(f"   Found {len(products)} products")
            if products:
                print(f"   First product: {products[0]['product_name']}")
                print(f"   Product main_category: {products[0]['main_category']}")
                
                # Check if UUID fields exist
                if 'category_main_id' in products[0]:
                    print(f"   ✅ Product has UUID field: category_main_id = {products[0]['category_main_id']}")
                else:
                    print(f"   ⚠️  Product missing UUID field 'category_main_id'")
        else:
            print(f"   ❌ Failed to fetch products: {response.status_code}")
    
    # Step 3: Rename the main category (you can uncomment to test)
    # WARNING: This will actually rename the category in the database!
    # print(f"\n🔄 Step 3: Renaming main category '{first_cat}' to 'RENAMED_TEST'...")
    # response = requests.put(
    #     f"{BASE_URL}/admin/api/main-category/UNKNOWN/{first_cat}",
    #     json={"name": "RENAMED_TEST"}
    # )
    # 
    # if response.status_code == 200:
    #     print("   ✅ Main category renamed successfully")
    #     
    #     # Step 4: Verify products updated
    #     print(f"\n✔️  Step 4: Verifying products updated to 'RENAMED_TEST'...")
    #     response = requests.get(
    #         f"{BASE_URL}/admin/api/products/all",
    #         params={"section": "UNKNOWN", "main_category": "RENAMED_TEST"}
    #     )
    #     
    #     if response.status_code == 200:
    #         products = response.json().get("products", [])
    #         print(f"   Found {len(products)} products under 'RENAMED_TEST'")
    #         if products:
    #             print(f"   ✅ SUCCESS: Products updated via UUID CASCADE!")
    #         else:
    #             print(f"   ❌ FAILED: No products found under new name")
    #     else:
    #         print(f"   ❌ Failed to verify: {response.status_code}")
    # else:
    #     print(f"   ❌ Failed to rename category: {response.status_code}")
    
    print("\n✅ Test completed!")
    print("\n📝 Note: To test actual CASCADE UPDATE, uncomment Step 3 in the script")
    print("   This will rename a real category and verify products update correctly")

if __name__ == "__main__":
    test_main_category_rename()
