"""Check category_metadata collection contents"""
from pymongo import MongoClient
import json

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['almadhinadb']
metadata_collection = db['category_metadata']

print("=" * 60)
print("CATEGORY METADATA COLLECTION")
print("=" * 60)

# Count documents
count = metadata_collection.count_documents({})
print(f"\nTotal documents: {count}")

# Get all documents
docs = list(metadata_collection.find())

if docs:
    print("\nAll metadata documents:")
    print("-" * 60)
    for doc in docs:
        print(json.dumps(doc, indent=2, default=str))
        print("-" * 60)
else:
    print("\n⚠️ NO DOCUMENTS FOUND in category_metadata collection!")
    print("This explains why all image_url fields are empty.")
    
# Check if images exist in other collections
print("\n" + "=" * 60)
print("CHECKING OTHER COLLECTIONS FOR IMAGE DATA")
print("=" * 60)

# Check category_hierarchy
hierarchy = list(db['category_hierarchy'].find())
print(f"\ncategory_hierarchy documents: {len(hierarchy)}")
if hierarchy:
    print("Sample document:")
    print(json.dumps(hierarchy[0], indent=2, default=str))

# Check products with images
products_with_images = list(db['products'].find({"image_url": {"$exists": True, "$ne": ""}}))
print(f"\nProducts with images: {len(products_with_images)}")
if products_with_images:
    print("Sample product with image:")
    print(json.dumps(products_with_images[0], indent=2, default=str))
