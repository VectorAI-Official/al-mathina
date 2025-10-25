from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['al_mathina']

# Check all products
total = db['products'].count_documents({})
print(f'\n📊 Total products in database: {total}')

if total > 0:
    print('\n📦 First 5 products:')
    for p in db['products'].find().limit(5):
        print(f"  - {p.get('product_name', 'NO NAME')} | active: {p.get('active', 'NOT SET')} | is_best_seller: {p.get('is_best_seller', 'NOT SET')}")
else:
    print('\n⚠️  Database is empty! You need to populate products first.')
    print('   Check the Backend documentation or run populate_new_data.py')
