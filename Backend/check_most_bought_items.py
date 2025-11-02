#!/usr/bin/env python3
"""Check what items are currently in the most_bought collection."""

from database.mongodb_client import get_mongo_db

try:
    db = get_mongo_db()
    most_bought_collection = db["most_bought"]
    
    items = list(most_bought_collection.find().sort("starred_at", -1))
    
    print("\n" + "="*60)
    print("MOST BOUGHT ITEMS IN DATABASE")
    print("="*60 + "\n")
    
    if not items:
        print("❌ No items in most_bought collection!")
    else:
        print(f"✅ Found {len(items)} items:\n")
        for i, item in enumerate(items, 1):
            section = item.get("section", "N/A")
            main_category = item.get("main_category", "N/A")
            starred_at = item.get("starred_at", "N/A")
            print(f"{i}. {section} / {main_category}")
            print(f"   Starred at: {starred_at}\n")
    
    print("="*60 + "\n")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
