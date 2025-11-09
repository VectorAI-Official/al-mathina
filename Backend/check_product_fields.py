"""
Check actual product structure in database
"""
import os
from pymongo import MongoClient
from dotenv import load_dotenv
import json

load_dotenv()

MONGODB_URI = os.getenv("MONGO_URI")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "almadhinadb")

def check_product_structure():
    client = MongoClient(MONGODB_URI)
    db = client[DATABASE_NAME]
    
    print("🔍 Checking product structure...\n")
    
    # Get a sample product
    product = db.products.find_one()
    
    if product:
        print("📋 Sample product fields:")
        for key in product.keys():
            value = product[key]
            if key == "_id":
                value = str(value)
            elif len(str(value)) > 100:
                value = str(value)[:100] + "..."
            print(f"   {key}: {value}")
        
        print("\n📊 All products:")
        for i, prod in enumerate(db.products.find().limit(10), 1):
            print(f"\n{i}. {prod.get('product_name', 'Unknown')}")
            print(f"   Section: {prod.get('section', 'MISSING')}")
            print(f"   Main Category: {prod.get('main_category', 'MISSING')}")
            print(f"   Subcategory: {prod.get('subcategory', 'MISSING')}")
            print(f"   Item ID: {prod.get('item_id', 'MISSING')}")
    else:
        print("❌ No products found in database")
    
    client.close()

if __name__ == "__main__":
    check_product_structure()
