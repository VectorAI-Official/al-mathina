from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['al_mathina']

# Check any products at all
total = db['products'].count_documents({'active': True})
print(f"\n📊 Total active products: {total}")

# Check if is_best_seller field exists
has_field = db['products'].count_documents({'is_best_seller': {'$exists': True}})
print(f"📊 Products with 'is_best_seller' field: {has_field}")

# Check true values
has_true = db['products'].count_documents({'is_best_seller': True})
print(f"✅ Products with is_best_seller=True: {has_true}")

# Sample some products
print(f"\n📦 Sample products:")
samples = list(db['products'].find({'active': True}).limit(3))
for p in samples:
    print(f"\n  Product: {p.get('product_name', 'N/A')}")
    print(f"  is_best_seller: {p.get('is_best_seller', 'FIELD NOT SET')}")
    print(f"  active: {p.get('active', 'FIELD NOT SET')}")

print("\n" + "="*60)
print("To mark products as best sellers:")
print("="*60)
print("\n# Mark first 10 products as best sellers:")
print("db['products'].update_many({}, {'$set': {'is_best_seller': False}})")
print("result = db['products'].update_many({'active': True}, {'$set': {'is_best_seller': True}})")
print("result.limit(10)")
