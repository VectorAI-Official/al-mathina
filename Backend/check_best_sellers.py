from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['al_mathina']

# Find all best seller products
products = list(db['products'].find({'is_best_seller': True, 'active': True}).limit(10))

print(f'\n✅ Found {len(products)} best seller products:\n')

if products:
    for i, p in enumerate(products, 1):
        print(f"{i}. {p.get('product_name', 'N/A')} ({p.get('weight', 'N/A')}) - ₹{p.get('price', 0)}")
        print(f"   Section: {p.get('category_section', 'N/A')}, Main: {p.get('category_main', 'N/A')}")
        print(f"   Image: {p.get('image_url', 'N/A')[:50]}...")
        print()
else:
    print("⚠️ No best seller products found in database!")
    print("\nTo mark products as best sellers, you can:")
    print("1. Use the admin dashboard")
    print("2. Or run: db.products.update_many({'product_name': {'$regex': 'Rice'}}, {'$set': {'is_best_seller': True}})")
