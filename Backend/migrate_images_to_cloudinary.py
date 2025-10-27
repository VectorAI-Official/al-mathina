#!/usr/bin/env python3
"""Migrate old local image URLs to Cloudinary default images"""
import os
os.environ['ENVIRONMENT'] = 'production'

from database.mongodb_client import get_mongo_db

db = get_mongo_db()
metadata_collection = db['category_metadata']

# Default Cloudinary image for categories without proper images
DEFAULT_CATEGORY_IMAGE = "https://res.cloudinary.com/vectorai/image/upload/v1761581973/almathina/banana%202.png"
DEFAULT_PRODUCT_IMAGE = "https://res.cloudinary.com/vectorai/image/upload/v1761581973/almathina/banana%202.png"

print("=" * 80)
print("MIGRATING OLD IMAGE URLS TO CLOUDINARY")
print("=" * 80)

# Find all documents with old local URLs
old_urls = list(metadata_collection.find({'image_url': {'$regex': '^(http://127\\.0\\.0\\.1|/static/uploads)'}})  )

print(f"\nFound {len(old_urls)} documents with old local URLs")

updated = 0
for doc in old_urls:
    name = doc.get('name', 'Unknown')
    old_url = doc.get('image_url', '')
    doc_type = doc.get('type', 'unknown')
    
    # Choose default image based on type
    if doc_type == 'product':
        new_url = DEFAULT_PRODUCT_IMAGE
    else:
        new_url = DEFAULT_CATEGORY_IMAGE
    
    # Update the document
    result = metadata_collection.update_one(
        {'_id': doc['_id']},
        {'$set': {'image_url': new_url}}
    )
    
    if result.modified_count > 0:
        updated += 1
        print(f"  ✓ Updated {name}")
        print(f"    Old: {old_url[:80]}")
        print(f"    New: {new_url[:80]}\n")

print(f"\nMigration complete!")
print(f"  Total updated: {updated}/{len(old_urls)}")

# Verify
remaining_old = metadata_collection.count_documents({'image_url': {'$regex': '^(http://127\\.0\\.0\\.1|/static/uploads)'}})
print(f"  Remaining old URLs: {remaining_old}")

cloudinary_count = metadata_collection.count_documents({'image_url': {'$regex': 'res.cloudinary.com'}})
print(f"  Total Cloudinary URLs: {cloudinary_count}")
