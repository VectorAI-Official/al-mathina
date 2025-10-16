"""Fix duplicate metadata - remove new duplicates and update old ones"""
from pymongo import MongoClient
import json

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['almadhinadb']
metadata_collection = db['category_metadata']

print("=" * 60)
print("FIXING DUPLICATE METADATA")
print("=" * 60)

# Find all main_category type documents
main_cat_docs = list(metadata_collection.find({"type": "main_category"}))

# Group by name and section
from collections import defaultdict
groups = defaultdict(list)

for doc in main_cat_docs:
    key = (doc.get('section'), doc.get('name'))
    groups[key].append(doc)

duplicates_fixed = 0
documents_updated = 0

for (section, name), docs in groups.items():
    if len(docs) > 1:
        print(f"\n🔄 Found {len(docs)} documents for: {section} / {name}")
        
        # Find the one with image_url
        has_image = [d for d in docs if d.get('image_url') and d.get('image_url') != '']
        no_image = [d for d in docs if not d.get('image_url') or d.get('image_url') == '']
        
        if has_image and no_image:
            # Keep the one with image, delete others, but first update it with main_category field
            keep_doc = has_image[0]
            delete_docs = no_image
            
            # Update the document to have main_category field
            if 'main_category' not in keep_doc:
                metadata_collection.update_one(
                    {"_id": keep_doc["_id"]},
                    {"$set": {"main_category": name}}
                )
                print(f"  ✅ Updated document {keep_doc['_id']} to add main_category field")
                documents_updated += 1
            
            # Delete duplicates
            for doc in delete_docs:
                metadata_collection.delete_one({"_id": doc["_id"]})
                print(f"  🗑️  Deleted duplicate: {doc['_id']}")
                duplicates_fixed += 1
        elif len(no_image) > 1:
            # All have no image, keep the first one
            keep_doc = no_image[0]
            delete_docs = no_image[1:]
            
            # Delete duplicates
            for doc in delete_docs:
                metadata_collection.delete_one({"_id": doc["_id"]})
                print(f"  🗑️  Deleted duplicate (no image): {doc['_id']}")
                duplicates_fixed += 1

print("\n" + "=" * 60)
print("UPDATING OLD DOCUMENTS TO HAVE MAIN_CATEGORY FIELD")
print("=" * 60)

# Now find all main_category type documents that don't have the main_category field
old_format_docs = list(metadata_collection.find({
    "type": "main_category",
    "main_category": {"$exists": False}
}))

for doc in old_format_docs:
    name = doc.get('name')
    metadata_collection.update_one(
        {"_id": doc["_id"]},
        {"$set": {"main_category": name}}
    )
    print(f"  ✅ Added main_category field to: {doc.get('section')} / {name}")
    documents_updated += 1

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"🗑️  Deleted duplicates: {duplicates_fixed}")
print(f"✅ Updated documents: {documents_updated}")
print(f"📊 Total metadata documents now: {metadata_collection.count_documents({})}")

# Show final state for summa main
print("\n" + "=" * 60)
print("FINAL STATE FOR 'summa main'")
print("=" * 60)
summa_docs = list(metadata_collection.find({"name": "summa main"}))
for doc in summa_docs:
    print(json.dumps(doc, indent=2, default=str))
