#!/usr/bin/env python3
"""
Clean up Most Bought collection by removing invalid/test categories.
"""
import sys
import os

# Add Backend to path
sys.path.insert(0, '/app')

from database.mongodb_client import get_mongo_db
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def cleanup_most_bought():
    """Remove test/invalid categories from Most Bought."""
    try:
        db = get_mongo_db()
        most_bought_collection = db["most_bought"]
        products_collection = db["products"]
        
        print("\n" + "="*70)
        print("CLEANING UP MOST BOUGHT COLLECTION")
        print("="*70 + "\n")
        
        # Get all items in most_bought
        items = list(most_bought_collection.find().sort("starred_at", -1))
        
        print(f"📊 Total items in most_bought: {len(items)}\n")
        
        if not items:
            print("✅ Most Bought collection is empty!\n")
            return
        
        print("Current Most Bought items:")
        for i, item in enumerate(items, 1):
            section = item.get("section")
            main_category = item.get("main_category")
            
            # Count products in this category
            product_count = products_collection.count_documents({
                "category_section": section,
                "category_main": main_category,
                "active": True
            })
            
            print(f"{i}. {section} / {main_category} ({product_count} active products)")
        
        print("\n" + "-"*70)
        print("\n⚠️  Which items would you like to REMOVE from Most Bought?")
        print("Enter item numbers separated by commas (e.g., 1,3,5)")
        print("Or type 'all' to remove all, 'none' to skip: ", end="")
        
        user_input = input().strip().lower()
        
        if user_input == "none":
            print("\n✅ No changes made.\n")
            return
        
        items_to_remove = []
        
        if user_input == "all":
            items_to_remove = list(range(len(items)))
        else:
            try:
                indices = [int(x.strip()) - 1 for x in user_input.split(",")]
                items_to_remove = [i for i in indices if 0 <= i < len(items)]
            except ValueError:
                print("\n❌ Invalid input!\n")
                return
        
        if not items_to_remove:
            print("\n❌ No valid items selected.\n")
            return
        
        print(f"\n🗑️  Removing {len(items_to_remove)} items...\n")
        
        removed_count = 0
        for idx in items_to_remove:
            item = items[idx]
            section = item.get("section")
            main_category = item.get("main_category")
            
            result = most_bought_collection.delete_one({
                "section": section,
                "main_category": main_category
            })
            
            if result.deleted_count > 0:
                print(f"✅ Removed: {section} / {main_category}")
                removed_count += 1
            else:
                print(f"❌ Failed to remove: {section} / {main_category}")
        
        print(f"\n" + "="*70)
        print(f"✅ Successfully removed {removed_count} items from Most Bought")
        print("="*70 + "\n")
        
        # Show remaining items
        remaining = list(most_bought_collection.find().sort("starred_at", -1))
        print(f"📊 Remaining items in most_bought: {len(remaining)}\n")
        
        if remaining:
            print("Remaining Most Bought categories:")
            for i, item in enumerate(remaining, 1):
                section = item.get("section")
                main_category = item.get("main_category")
                product_count = products_collection.count_documents({
                    "category_section": section,
                    "category_main": main_category,
                    "active": True
                })
                print(f"{i}. {section} / {main_category} ({product_count} active products)")
        
        print()
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        print()

if __name__ == "__main__":
    cleanup_most_bought()
