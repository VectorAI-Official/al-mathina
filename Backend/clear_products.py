"""
Clear all existing products from the database.
Run this script to remove sample/test products.
"""

import sys
import os

# Add parent directory to path to import modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database.mongodb_client import get_mongo_db

def clear_all_products():
    """Delete all products from the database."""
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Count existing products
        count = products_collection.count_documents({})
        print(f"Found {count} products in database")
        
        if count == 0:
            print("✓ No products to delete")
            return
        
        # Ask for confirmation
        response = input(f"\n⚠️  This will delete all {count} products. Continue? (yes/no): ")
        
        if response.lower() not in ['yes', 'y']:
            print("❌ Operation cancelled")
            return
        
        # Delete all products
        result = products_collection.delete_many({})
        print(f"\n✓ Successfully deleted {result.deleted_count} products")
        
        # Verify deletion
        remaining = products_collection.count_documents({})
        print(f"✓ Products remaining in database: {remaining}")
        
        if remaining == 0:
            print("\n✅ All products cleared successfully!")
            print("   You can now add new products from:")
            print("   - Dashboard: Click 'Add New Product' button")
            print("   - Mobile View: Click '➕ Add New' in subcategory")
        
    except Exception as e:
        print(f"❌ Error clearing products: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("=" * 60)
    print("Clear All Products from Database")
    print("=" * 60)
    clear_all_products()
