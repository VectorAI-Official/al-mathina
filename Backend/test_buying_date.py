"""Test script to verify buying_date field is working correctly"""
from database.mongodb_client import get_mongo_db
from datetime import datetime

def test_buying_date_feature():
    """Test buying_date field in products collection"""
    db = get_mongo_db()
    products_collection = db['products']
    
    print("\n🧪 Testing Buying Date Feature\n")
    
    # 1. Check total products
    total_products = products_collection.count_documents({})
    print(f"📊 Total products in database: {total_products}")
    
    # 2. Check products WITH buying_date
    with_date = products_collection.count_documents({"buying_date": {"$exists": True, "$ne": None}})
    print(f"✅ Products WITH buying_date: {with_date}")
    
    # 3. Check products WITHOUT buying_date
    without_date = products_collection.count_documents({"buying_date": {"$exists": False}})
    print(f"⚠️  Products WITHOUT buying_date: {without_date}")
    
    # 4. Sample products with buying_date
    print(f"\n📋 Sample Products WITH Buying Date:")
    sample_with_date = list(products_collection.find(
        {"buying_date": {"$exists": True, "$ne": None}}
    ).limit(5))
    
    for i, product in enumerate(sample_with_date, 1):
        print(f"\n  {i}. {product.get('product_name', 'N/A')}")
        print(f"     Buying Price: ₹{product.get('buying_price', 0):.2f}")
        print(f"     Buying Date: {product.get('buying_date', 'N/A')}")
        print(f"     Selling Price: ₹{product.get('price', 0):.2f}")
        print(f"     Stock: {product.get('stock', 0)}")
    
    # 5. Sample products without buying_date (old products)
    print(f"\n📋 Sample Products WITHOUT Buying Date (Old Products):")
    sample_without_date = list(products_collection.find(
        {"buying_date": {"$exists": False}}
    ).limit(3))
    
    for i, product in enumerate(sample_without_date, 1):
        print(f"\n  {i}. {product.get('product_name', 'N/A')}")
        print(f"     Buying Price: ₹{product.get('buying_price', 0):.2f}")
        print(f"     Buying Date: N/A (will show as 'N/A' in UI)")
        print(f"     Selling Price: ₹{product.get('price', 0):.2f}")
    
    # 6. Test product with today's date
    print(f"\n🔍 Testing Product Creation with Today's Date:")
    today = datetime.now().strftime("%Y-%m-%d")
    print(f"   Today's Date: {today}")
    
    test_product = {
        "item_id": "TEST_" + str(int(datetime.now().timestamp())),
        "product_name": "Test Product with Buying Date",
        "category_section": "Test Section",
        "category_main": "Test Category",
        "category_sub": "Test Subcategory",
        "weight": "1kg",
        "price": 100.0,
        "buying_price": 80.0,
        "buying_date": today,  # CRITICAL: New field
        "stock": 50,
        "active": True,
        "created_at": datetime.now(),
        "updated_at": datetime.now()
    }
    
    try:
        result = products_collection.insert_one(test_product)
        print(f"   ✅ Test product created with ID: {result.inserted_id}")
        
        # Verify it was saved correctly
        saved_product = products_collection.find_one({"_id": result.inserted_id})
        print(f"   ✅ Verified - Buying Date saved: {saved_product.get('buying_date')}")
        
        # Clean up test product
        products_collection.delete_one({"_id": result.inserted_id})
        print(f"   🗑️  Test product deleted")
        
    except Exception as e:
        print(f"   ❌ Error creating test product: {e}")
    
    # 7. Summary
    print(f"\n📊 Summary:")
    print(f"   Total Products: {total_products}")
    print(f"   With Buying Date: {with_date} ({(with_date/total_products*100) if total_products > 0 else 0:.1f}%)")
    print(f"   Without Buying Date: {without_date} ({(without_date/total_products*100) if total_products > 0 else 0:.1f}%)")
    
    if without_date > 0:
        print(f"\n💡 Note: {without_date} old products don't have buying_date.")
        print(f"   They will display 'N/A' in the admin dashboard table.")
        print(f"   Edit and save them to add a buying date.")

if __name__ == "__main__":
    try:
        test_buying_date_feature()
        print(f"\n✅ Buying Date Feature Test Complete!\n")
    except Exception as e:
        print(f"\n❌ Test Error: {e}")
        import traceback
        traceback.print_exc()
