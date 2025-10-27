#!/usr/bin/env python3
"""Check Most Bought categories and their images"""

from config_local import settings
from pymongo import MongoClient

def check_most_bought_images():
    client = MongoClient(settings.mongo_uri)
    db = client[settings.mongo_db_name]
    
    most_bought_collection = db["most_bought"]
    metadata_collection = db["category_metadata"]
    
    print("=== MOST BOUGHT CATEGORIES AND IMAGES ===\n")
    
    most_bought_items = list(most_bought_collection.find())
    
    if not most_bought_items:
        print("No items in most_bought collection")
        return
    
    for item in most_bought_items:
        section = item.get("section")
        main_category = item.get("main_category")
        
        print(f"Category: {section} → {main_category}")
        
        # Try exact match with name field (current format)
        metadata = metadata_collection.find_one({
            "type": "main_category",
            "section": section,
            "name": main_category
        })
        
        if metadata:
            print(f"  ✅ Metadata found (exact match with name)")
            print(f"  Image URL: {metadata.get('image_url', 'NO IMAGE')}")
        else:
            # Try fallback with name only
            metadata = metadata_collection.find_one({
                "type": "main_category",
                "name": main_category
            })
            if metadata:
                print(f"  ⚠️  Metadata found (fallback - name only)")
                print(f"  Image URL: {metadata.get('image_url', 'NO IMAGE')}")
            else:
                # Try legacy main_category field
                metadata = metadata_collection.find_one({
                    "type": "main_category",
                    "main_category": main_category
                })
                if metadata:
                    print(f"  ⚠️  Metadata found (legacy main_category field)")
                    print(f"  Image URL: {metadata.get('image_url', 'NO IMAGE')}")
                else:
                    print(f"  ❌ No metadata found")
        
        print()

if __name__ == "__main__":
    check_most_bought_images()
