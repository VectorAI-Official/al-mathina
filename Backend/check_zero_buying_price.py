from pymongo import MongoClient
import os
from dotenv import load_dotenv

load_dotenv('.env.production')

client = MongoClient(os.getenv('MONGO_URI'))
db = client[os.getenv('MONGO_DB_NAME', 'almadhinadb')]

products_with_zero = db.products.count_documents({'buying_price': 0})
products_with_value = db.products.count_documents({'buying_price': {'$gt': 0}})
products_exists = db.products.count_documents({'buying_price': {'$exists': True}})
products_not_exists = db.products.count_documents({'buying_price': {'$exists': False}})

print(f'\nBuying Price Statistics:')
print(f'========================')
print(f'Products with buying_price = 0: {products_with_zero}')
print(f'Products with buying_price > 0: {products_with_value}')
print(f'Products with buying_price field exists: {products_exists}')
print(f'Products without buying_price field: {products_not_exists}')
print()

# Sample products with buying_price
print('Sample products WITH buying_price > 0:')
print('-' * 60)
sample = db.products.find({'buying_price': {'$gt': 0}}, {'product_name': 1, 'price': 1, 'buying_price': 1}).limit(5)
for p in sample:
    print(f"  {p['product_name']}: selling=₹{p.get('price', 0):.2f}, buying=₹{p.get('buying_price', 0):.2f}")

print()
print('Sample products with buying_price = 0:')
print('-' * 60)
sample = db.products.find({'buying_price': 0}, {'product_name': 1, 'price': 1, 'buying_price': 1}).limit(5)
for p in sample:
    print(f"  {p['product_name']}: selling=₹{p.get('price', 0):.2f}, buying=₹{p.get('buying_price', 0):.2f}")

client.close()
