"""
Debug script to check product image data in MongoDB
"""

from pymongo import MongoClient
from config_local import Settings
import json

def check_product_images():
    try:
        settings = Settings()
        client = MongoClient(settings.mongo_uri)
        db = client[settings.mongo_db_name]
        
        print("\n" + "="*60)
        print("PRODUCT IMAGE DEBUG")
        print("="*60)
        
        # Get all products
        products = list(db.products.find().sort("_id", -1).limit(5))
        
        print(f"\n📊 Found {db.products.count_documents({})} total products")
        print(f"📋 Showing last 5 products:\n")
        
        for i, product in enumerate(products, 1):
            print(f"\n{'='*60}")
            print(f"Product #{i}: {product.get('product_name', 'N/A')}")
            print(f"{'='*60}")
            print(f"ID: {product.get('_id')}")
            print(f"Item ID: {product.get('item_id', 'N/A')}")
            print(f"\n🏷️ CATEGORY INFO:")
            print(f"  Section: {product.get('category_section', 'N/A')}")
            print(f"  Main: {product.get('category_main', 'N/A')}")
            print(f"  Sub: {product.get('category_sub', 'N/A')}")
            print(f"\n🖼️ IMAGE FIELDS:")
            print(f"  image: {product.get('image', 'NOT SET')}")
            print(f"  image_url: {product.get('image_url', 'NOT SET')}")
            
            # Check legacy fields
            if 'category' in product:
                print(f"\n⚠️ LEGACY FIELDS FOUND:")
                print(f"  category: {product.get('category')}")
                print(f"  brand: {product.get('brand', 'N/A')}")
            
            print(f"\n📅 Timestamps:")
            print(f"  Created: {product.get('created_at', 'N/A')}")
            print(f"  Updated: {product.get('updated_at', 'N/A')}")
        
        # Check if image files exist on disk
        print(f"\n{'='*60}")
        print("🔍 CHECKING IMAGE FILES ON DISK")
        print(f"{'='*60}")
        
        import os
        upload_dir = os.path.join(os.path.dirname(__file__), 'static', 'uploads')
        
        if os.path.exists(upload_dir):
            files = os.listdir(upload_dir)
            print(f"\n✓ Upload directory exists: {upload_dir}")
            print(f"📁 Found {len(files)} files:")
            for f in sorted(files)[-10:]:  # Show last 10 files
                file_path = os.path.join(upload_dir, f)
                size = os.path.getsize(file_path)
                print(f"  • {f} ({size} bytes)")
        else:
            print(f"\n✗ Upload directory NOT FOUND: {upload_dir}")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        client.close()

if __name__ == "__main__":
    check_product_images()
