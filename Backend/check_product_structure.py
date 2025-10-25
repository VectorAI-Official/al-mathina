from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['al_mathina']

# Get any products to see their structure
products = list(db['products'].find().limit(3))

print(f'\n📊 Total products: {db["products"].count_documents({})}')
print(f'\n Sample product structure:\n')

if products:
    for p in products:
        print(f"Product: {p.get('product_name', 'N/A')}")
        print(f"  _id: {p.get('_id')}")
        print(f"  item_id: {p.get('item_id')}")
        print(f"  active: {p.get('active', 'NOT SET')}")
        print(f"  is_best_seller: {p.get('is_best_seller', 'NOT SET')}")
        print(f"  Keys: {list(p.keys())}")
        print()
else:
    print("No products found!")
