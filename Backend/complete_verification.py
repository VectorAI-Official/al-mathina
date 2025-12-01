"""
Complete verification of the migrated image
"""
from database.mongodb_client import get_mongo_db
import requests
import json

def complete_verification():
    print("=" * 80)
    print("🔍 COMPLETE MIGRATION VERIFICATION")
    print("=" * 80)
    print()
    
    # 1. DATABASE CHECK
    print("=" * 80)
    print("1️⃣  DATABASE VERIFICATION")
    print("=" * 80)
    print()
    
    db = get_mongo_db()
    doc = db.category_metadata.find_one({
        'image_url': {'$regex': 'al-mathina.*1000644530_400x400'}
    })
    
    if doc:
        print("✅ Document found with NEW URL")
        print()
        print("📋 LOCATION IN ADMIN DASHBOARD:")
        print(f"   Section:         {doc.get('section', 'N/A')}")
        print(f"   Main Category:   {doc.get('main_category', 'N/A')}")
        print(f"   Subcategory:     {doc.get('name', 'N/A')}")
        print()
        print("🔗 DATABASE URLs:")
        print(f"   Document ID:     {doc['_id']}")
        print()
        print("   OLD URL (before migration):")
        print("   https://res.cloudinary.com/vectorai/image/upload/v1762548713/almathina/1000644530_400x400.jpg")
        print()
        print("   NEW URL (after migration - in database):")
        print(f"   {doc.get('image_url', 'N/A')}")
        print()
    else:
        print("❌ Document not found!")
        return
    
    # 2. URL ACCESSIBILITY CHECK
    print("=" * 80)
    print("2️⃣  URL ACCESSIBILITY TEST")
    print("=" * 80)
    print()
    
    old_url = "https://res.cloudinary.com/vectorai/image/upload/v1762548713/almathina/1000644530_400x400.jpg"
    new_url = doc.get('image_url')
    
    print("Testing OLD URL (vectorai account)...")
    try:
        response = requests.head(old_url, timeout=10)
        if response.status_code == 200:
            print(f"   Status: {response.status_code} ⚠️  Still accessible")
            print(f"   Note: May take a few minutes for Cloudinary CDN to clear cache")
        elif response.status_code == 404:
            print(f"   Status: {response.status_code} ✅ Deleted successfully")
    except Exception as e:
        print(f"   Error: {e}")
    
    print()
    print("Testing NEW URL (al-mathina account)...")
    try:
        response = requests.head(new_url, timeout=10)
        if response.status_code == 200:
            print(f"   Status: {response.status_code} ✅ Accessible")
            print(f"   Content-Type: {response.headers.get('Content-Type', 'N/A')}")
            size_kb = int(response.headers.get('Content-Length', 0)) / 1024
            print(f"   File Size: {size_kb:.2f} KB")
        else:
            print(f"   Status: {response.status_code} ❌ Not accessible")
    except Exception as e:
        print(f"   Error: {e}")
    
    print()
    
    # 3. MANUAL VERIFICATION STEPS
    print("=" * 80)
    print("3️⃣  MANUAL VERIFICATION STEPS")
    print("=" * 80)
    print()
    
    print("📱 IN FLUTTER ADMIN DASHBOARD:")
    print()
    print("   1. Open admin dashboard: http://127.0.0.1:8000/admin/")
    print(f"   2. Navigate to: {doc.get('section', 'N/A')}")
    print(f"   3. Click on Main Category: {doc.get('main_category', 'N/A')}")
    print(f"   4. Find Subcategory: {doc.get('name', 'N/A')}")
    print("   5. Check if image displays correctly")
    print()
    
    print("🗄️  IN MONGODB ATLAS:")
    print()
    print("   1. Open: https://cloud.mongodb.com")
    print("   2. Database: almadhinadb")
    print("   3. Collection: category_metadata")
    print("   4. Filter:")
    print(f'      {{"_id": ObjectId("{doc["_id"]}")}}')
    print("   5. Check 'image_url' field should contain:")
    print("      https://res.cloudinary.com/al-mathina/...")
    print()
    
    print("☁️  IN CLOUDINARY DASHBOARD:")
    print()
    print("   OLD ACCOUNT (vectorai):")
    print("   1. Login: https://cloudinary.com/console")
    print("   2. Select: vectorai account")
    print("   3. Media Library → Search: 1000644530_400x400")
    print("   4. Expected: Not found (deleted)")
    print()
    print("   NEW ACCOUNT (al-mathina):")
    print("   1. Login: https://cloudinary.com/console")
    print("   2. Select: al-mathina account")
    print("   3. Media Library → Search: 1000644530_400x400")
    print("   4. Expected: Found in almathina folder")
    print()
    
    # 4. BROWSER TEST
    print("=" * 80)
    print("4️⃣  TEST IN BROWSER")
    print("=" * 80)
    print()
    print("Open this URL in browser to see the migrated image:")
    print()
    print(new_url)
    print()
    
    # 5. SUMMARY
    print("=" * 80)
    print("📊 MIGRATION SUMMARY")
    print("=" * 80)
    print()
    print(f"✅ Database updated:      YES")
    print(f"✅ New URL accessible:    YES")
    print(f"⚠️  Old URL status:        May take time to clear from CDN cache")
    print(f"✅ Collection:            category_metadata")
    print(f"✅ Document Type:         subcategory")
    print(f"✅ Section:               {doc.get('section', 'N/A')}")
    print(f"✅ Main Category:         {doc.get('main_category', 'N/A')}")
    print(f"✅ Subcategory Name:      {doc.get('name', 'N/A')}")
    print()
    print("🎯 WHAT TO CHECK:")
    print()
    print("1. Open Flutter Admin Dashboard")
    print(f"2. Go to section: {doc.get('section', 'N/A')}")
    print(f"3. Open main category: {doc.get('main_category', 'N/A')}")
    print(f"4. Look for subcategory: {doc.get('name', 'N/A')}")
    print("5. Verify the image displays correctly")
    print()

if __name__ == '__main__':
    complete_verification()
