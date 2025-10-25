from database.mongodb_client import get_mongo_db

DB = get_mongo_db()
metadata_col = DB['category_metadata']

section = 'Grocery & Kitchen'
main = 'Vegetables & Fruits'
sub = 'Vegetables'

query = {
    'section': section,
    'main_category': main,
    'subcategory': sub,
    'type': 'subcategory'
}

res = metadata_col.find_one(query)
print('Query:', query)
print('Result:', res)
