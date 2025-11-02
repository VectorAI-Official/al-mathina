#!/usr/bin/env python3
"""
Direct MongoDB cleanup script - uses Backend config.
"""

import sys
sys.path.insert(0, '/d/al-mathina/Backend')

from database.mongodb_client import get_mongo_db

def cleanup_most_bought():
    """Remove test/invalid categories from Most Bought collection."""
    try:
        db = get_mongo_db()
        most_bought = db["most_bought"]
        products = db["products"]
        
        print("\n" + "="*70)
        print("MOST BOUGHT CLEANUP TOOL")
        print("="*70 + "\n")
        
        # Get all items
        items = list(most_bought.find().sort("starred_at", -1))
        
        print(f"📊 Total items in most_bought: {len(items)}\n")
        
        if not items:
            print("✅ Most Bought collection is already empty!\n")
            return
        
        # Display all items with product counts
        print("Current Most Bought items:")
        for i, item in enumerate(items, 1):
            section = item.get("section", "N/A")
            main_category = item.get("main_category", "N/A")
            
            # Count active products
            product_count = products.count_documents({
                "category_section": section,
                "category_main": main_category,
                "active": True
            })
            
            print(f"  {i}. {section} / {main_category}")
            print(f"     └─ Active products: {product_count}")
        
        print("\n" + "-"*70)
        print("\n⚠️  Which items would you like to REMOVE from Most Bought?")
        print("    (Enter item numbers separated by commas)")
        print("    Examples: 1,3,5  or  all  or  none\n")
        
        user_input = input("Enter your choice: ").strip().lower()
        
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
            except (ValueError, IndexError):
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
            
            result = most_bought.delete_one({
                "section": section,
                "main_category": main_category
            })
            
            if result.deleted_count > 0:
                print(f"  ✅ Removed: {section} / {main_category}")
                removed_count += 1
            else:
                print(f"  ❌ Failed: {section} / {main_category}")
        
        print(f"\n" + "="*70)
        print(f"✅ Successfully removed {removed_count} items!")
        print("="*70 + "\n")
        
        # Show remaining
        remaining = list(most_bought.find().sort("starred_at", -1))
        print(f"📊 Remaining items in most_bought: {len(remaining)}\n")
        
        if remaining:
            print("Still in Most Bought:")
            for i, item in enumerate(remaining, 1):
                section = item.get("section")
                main_category = item.get("main_category")
                product_count = products.count_documents({
                    "category_section": section,
                    "category_main": main_category,
                    "active": True
                })
                print(f"  {i}. {section} / {main_category} ({product_count} active products)")
        else:
            print("✅ Most Bought collection is now empty!")
        
        print()
        
    except Exception as e:
        print(f"\n❌ Error: {type(e).__name__}: {e}\n")
        import traceback
        traceback.print_exc()
        print()

if __name__ == "__main__":
    cleanup_most_bought()
