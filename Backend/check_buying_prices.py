"""
Check how many products have buying_price field populated
"""
from pymongo import MongoClient
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv('.env.production')
load_dotenv()

# Connect to MongoDB
mongodb_uri = os.getenv('MONGO_URI')
db_name = os.getenv('MONGO_DB_NAME', 'almadhinadb')
if not mongodb_uri:
    print("❌ MONGO_URI not found in environment")
    exit(1)

client = MongoClient(mongodb_uri)
db = client[db_name]

print("\n" + "="*60)
print("📊 BUYING PRICE DATABASE ANALYSIS")
print("="*60 + "\n")

# Count total products
total = db.products.count_documents({})
print(f"📦 Total products: {total}")

# Count products with buying_price
with_price = db.products.count_documents({
    'buying_price': {'$exists': True, '$ne': None}
})
without_price = total - with_price

print(f"✅ Products WITH buying_price: {with_price}")
print(f"❌ Products WITHOUT buying_price: {without_price}")
print(f"📈 Percentage complete: {(with_price/total)*100:.1f}%")

print("\n" + "-"*60 + "\n")

# Sample products without buying_price
print("🔍 Sample products WITHOUT buying_price (first 10):\n")
missing = db.products.find(
    {'buying_price': {'$exists': False}},
    {'product_name': 1, 'section': 1, 'main_category': 1, 'subcategory': 1, 'price': 1}
).limit(10)

for i, product in enumerate(missing, 1):
    print(f"{i}. {product.get('product_name', 'Unknown')}")
    print(f"   Section: {product.get('section', 'N/A')}")
    print(f"   Category: {product.get('main_category', 'N/A')} > {product.get('subcategory', 'N/A')}")
    print(f"   Selling Price: ₹{product.get('price', 0):.2f}")
    print()

print("-"*60 + "\n")

# Sample products with buying_price
print("✅ Sample products WITH buying_price (first 10):\n")
with_prices = db.products.find(
    {'buying_price': {'$exists': True, '$ne': None}},
    {'product_name': 1, 'section': 1, 'price': 1, 'buying_price': 1}
).limit(10)

for i, product in enumerate(with_prices, 1):
    selling = product.get('price', 0)
    buying = product.get('buying_price', 0)
    margin = selling - buying
    margin_pct = (margin / selling * 100) if selling > 0 else 0
    
    print(f"{i}. {product.get('product_name', 'Unknown')}")
    print(f"   Section: {product.get('section', 'N/A')}")
    print(f"   Selling: ₹{selling:.2f} | Buying: ₹{buying:.2f}")
    print(f"   Margin: ₹{margin:.2f} ({margin_pct:.1f}%)")
    print()

print("="*60)
print("\n💡 To add buying prices for products, update MongoDB:")
print("   db.products.updateMany({buying_price: {$exists: false}}, {$set: {buying_price: 0}})")
print("\n   Or set specific values:")
print("   db.products.updateOne({product_name: 'XXX'}, {$set: {buying_price: YYY}})")
print("\n" + "="*60 + "\n")

client.close()
