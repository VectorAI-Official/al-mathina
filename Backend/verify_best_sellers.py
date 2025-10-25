from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['al_mathina']

# Check for best seller products
products = list(db['products'].find({'is_best_seller': True}).limit(10))

print(f'\n✅ Found {len(products)} products with is_best_seller=True:\n')

for i, p in enumerate(products, 1):
    print(f"{i}. {p.get('product_name', 'N/A')}")
    print(f"   Price: ₹{p.get('price', 0)}")
    print(f"   Stock: {p.get('stock', 0)}")
    print(f"   Active: {p.get('active', False)}")
    print(f"   is_best_seller: {p.get('is_best_seller', False)}")
    print()
