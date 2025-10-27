"""
Migrate from Best Seller to Most Bought
- Remove old is_best_seller field from products
- Create new most_bought collection to store starred main categories
"""
from pymongo import MongoClient
from config_local import settings

# Connect to MongoDB
client = MongoClient(settings.mongo_uri)
db = client[settings.mongo_db_name]

print("=== MIGRATING TO MOST BOUGHT SYSTEM ===\n")

# 1. Remove is_best_seller field from all products
print("1. Removing is_best_seller field from products...")
result = db.products.update_many(
    {},
    {"$unset": {"is_best_seller": ""}}
)
print(f"   ✅ Updated {result.modified_count} products\n")

# 2. Create most_bought collection (will be auto-created on first insert)
print("2. Setting up most_bought collection...")
# Check if collection exists
if "most_bought" in db.list_collection_names():
    # Clear existing data
    db.most_bought.delete_many({})
    print("   ✅ Cleared existing most_bought collection\n")
else:
    print("   ✅ most_bought collection will be created on first insert\n")

# 3. Create unique index on section + main_category
print("3. Creating unique index on most_bought...")
db.most_bought.create_index(
    [("section", 1), ("main_category", 1)],
    unique=True
)
print("   ✅ Created unique index\n")

print("=== MIGRATION COMPLETE ===\n")
print("Most Bought collection structure:")
print("  - section: string (e.g., 'Beverages')")
print("  - main_category: string (e.g., 'Soft Drinks')")
print("  - starred_at: datetime (when it was starred)")
print("  - order: int (display order, optional)")
