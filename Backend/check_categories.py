from database.mongodb_client import get_mongo_db
db = get_mongo_db()
print("=== MAIN CATEGORIES ===")
for doc in db.category_metadata.find({"type": "main_category", "section": "Snacks & Drinks"}):
    print(f"  {doc.get('name')}")

print("\n=== SUBCATEGORIES ===")
for doc in db.category_metadata.find({"type": "subcategory", "section": "Snacks & Drinks"}):
    print(f"  {doc.get('name')} (under {doc.get('main_category')})")
