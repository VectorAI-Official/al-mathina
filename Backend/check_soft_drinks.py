from database.mongodb_client import get_mongo_db
db = get_mongo_db()
soft_drinks_docs = list(db.category_metadata.find({'name': 'Soft Drinks'}))
for doc in soft_drinks_docs:
    print(f"Type: {doc.get('type')}, Section: {doc.get('section')}, Main: {doc.get('main_category')}")
