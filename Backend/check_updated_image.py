"""
Check which document was updated with the new Cloudinary URL
"""
from database.mongodb_client import get_mongo_db
import json

def check_updated_image():
    db = get_mongo_db()
    
    # Find the document with the new URL
    doc = db.category_metadata.find_one({
        'image_url': {'$regex': 'al-mathina.*1000644530_400x400'}
    })
    
    if not doc:
        print("❌ No document found with new URL!")
        return
    
    print("=" * 80)
    print("✅ UPDATED DOCUMENT FOUND")
    print("=" * 80)
    print()
    
    print("📋 DOCUMENT DETAILS:")
    print(f"   Collection:      category_metadata")
    print(f"   Document ID:     {doc['_id']}")
    print(f"   Section:         {doc.get('section', 'N/A')}")
    print(f"   Main Category:   {doc.get('main_category', 'N/A')}")
    print(f"   Name:            {doc.get('name', 'N/A')}")
    print(f"   Type:            {doc.get('type', 'N/A')}")
    print()
    
    print("🔗 URL INFORMATION:")
    print()
    print("   OLD URL:")
    print("   https://res.cloudinary.com/vectorai/image/upload/v1762548713/almathina/1000644530_400x400.jpg")
    print()
    print("   NEW URL (UPDATED):")
    print(f"   {doc.get('image_url', 'N/A')}")
    print()
    
    print("=" * 80)
    print("📄 FULL DOCUMENT (JSON)")
    print("=" * 80)
    print(json.dumps(doc, indent=2, default=str))
    print()
    
    print("=" * 80)
    print("🔍 HOW TO VERIFY MANUALLY")
    print("=" * 80)
    print()
    print("1. Open MongoDB Atlas: https://cloud.mongodb.com")
    print("2. Navigate to Database: almadhinadb")
    print("3. Go to Collection: category_metadata")
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
    print(f"   - Subcategory: {doc.get('name', 'N/A')}")
    print("   - Check if image displays correctly")
    print()

if __name__ == '__main__':
    check_updated_image()
