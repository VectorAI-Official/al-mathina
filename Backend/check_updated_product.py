"""
Check which product was updated with the new URL
"""
from database.mongodb_client import get_mongo_db
import json

def check_updated_product():
    db = get_mongo_db()
    
    # Find the product with the new URL
    doc = db.products.find_one({
        'image_url': {'$regex': 'al-mathina.*690e4c592ba9e5019c958faf'}
    })
    
    if not doc:
        print("❌ No product found with new URL!")
        return
    
    print("=" * 80)
    print("✅ UPDATED PRODUCT FOUND")
    print("=" * 80)
    print()
    
    print("📋 PRODUCT DETAILS:")
    print(f"   Collection:      products")
    print(f"   Product ID:      {doc['_id']}")
    print(f"   Section:         {doc.get('section', 'N/A')}")
    print(f"   Main Category:   {doc.get('main_category', 'N/A')}")
    print(f"   Subcategory:     {doc.get('subcategory', 'N/A')}")
    print(f"   Product Name:    {doc.get('name', 'N/A')}")
    print(f"   Price:           ₹{doc.get('price', 'N/A')}")
    print()
    
    print("🔗 URL INFORMATION:")
    print()
    print("   OLD URL:")
    print("   https://res.cloudinary.com/vectorai/image/upload/v1762544730/almathina/products/690e4c592ba9e5019c958faf.jpg")
    print()
    print("   NEW URL (UPDATED):")
    print(f"   {doc.get('image_url', 'N/A')}")
    print()
    
    print("=" * 80)
    print("📄 FULL PRODUCT DOCUMENT")
    print("=" * 80)
    print(json.dumps(doc, indent=2, default=str))
    print()
    
    print("=" * 80)
    print("🔍 HOW TO VERIFY MANUALLY")
    print("=" * 80)
    print()
    print("1. Open MongoDB Atlas: https://cloud.mongodb.com")
    print("2. Navigate to Database: almadhinadb")
    print("3. Go to Collection: products")
    print("4. Search/Filter:")
    print(f"   {{\"_id\": ObjectId(\"{doc['_id']}\") }}")
    print("   OR")
    print(f"   {{\"name\": \"{doc.get('name', 'N/A')}\" }}")
    print()
    print("5. Check 'image_url' field - should contain:")
    print("   https://res.cloudinary.com/al-mathina/...")
    print()
    print("6. In Flutter Admin Dashboard:")
    print(f"   - Section: {doc.get('section', 'N/A')}")
    print(f"   - Main Category: {doc.get('main_category', 'N/A')}")
    print(f"   - Subcategory: {doc.get('subcategory', 'N/A')}")
    print(f"   - Product: {doc.get('name', 'N/A')}")
    print("   - Check if product image displays correctly")
    print()
    
    # Test URL accessibility
    import requests
    print("=" * 80)
    print("🌐 URL ACCESSIBILITY TEST")
    print("=" * 80)
    print()
    
    new_url = doc.get('image_url')
    old_url = "https://res.cloudinary.com/vectorai/image/upload/v1762544730/almathina/products/690e4c592ba9e5019c958faf.jpg"
    
    print("Testing NEW URL...")
    try:
        response = requests.head(new_url, timeout=10)
        if response.status_code == 200:
            print(f"   ✅ Status: {response.status_code} - ACCESSIBLE")
            print(f"   ✅ Content-Type: {response.headers.get('Content-Type', 'N/A')}")
            size_kb = int(response.headers.get('Content-Length', 0)) / 1024
            print(f"   ✅ File Size: {size_kb:.2f} KB")
        else:
            print(f"   ❌ Status: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print()
    print("Testing OLD URL...")
    try:
        response = requests.head(old_url, timeout=10)
        if response.status_code == 200:
            print(f"   ⚠️  Status: {response.status_code} - Still accessible (CDN cache)")
        elif response.status_code == 404:
            print(f"   ✅ Status: {response.status_code} - Deleted")
        else:
            print(f"   Status: {response.status_code}")
    except Exception as e:
        print(f"   Error: {e}")
    
    print()
    print("=" * 80)
    print("🎯 QUICK VIEW IN BROWSER")
    print("=" * 80)
    print()
    print("Open this URL to see the migrated image:")
    print(new_url)
    print()

if __name__ == '__main__':
    check_updated_product()
