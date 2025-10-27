#!/usr/bin/env python3
"""
Add Tamil name support to AL-Madhina database

This script adds Tamil name fields to category_metadata and category_hierarchy collections.
"""

from config_local import settings
from pymongo import MongoClient

def add_tamil_support():
    client = MongoClient(settings.mongo_uri)
    db = client[settings.mongo_db_name]
    
    print("=== Adding Tamil Name Support ===\n")
    
    # 1. Update category_metadata collection
    print("1. Updating category_metadata collection...")
    metadata_collection = db["category_metadata"]
    
    # Add name_ta field to all documents (default to empty string)
    result = metadata_collection.update_many(
        {},
        {"$set": {"name_ta": ""}}
    )
    print(f"   Updated {result.modified_count} metadata documents with name_ta field\n")
    
    # 2. Update category_hierarchy collection
    print("2. Updating category_hierarchy collection...")
    hierarchy_collection = db["category_hierarchy"]
    
    # Add section_ta field to all documents (default to empty string)
    result = hierarchy_collection.update_many(
        {},
        {"$set": {"section_ta": ""}}
    )
    print(f"   Updated {result.modified_count} hierarchy documents with section_ta field\n")
    
    # 3. Create indexes for better performance
    print("3. Creating indexes...")
    try:
        metadata_collection.create_index([("name_ta", 1)])
        print("   Created index on category_metadata.name_ta")
    except Exception as e:
        print(f"   Index may already exist: {e}")
    
    print("\n✅ Tamil name support added successfully!")
    print("\nNext steps:")
    print("1. Update admin dashboard to accept Tamil names")
    print("2. Update Flutter API to return appropriate names based on language")
    print("3. Update Flutter app to display Tamil names when language is Tamil")

if __name__ == "__main__":
    add_tamil_support()
