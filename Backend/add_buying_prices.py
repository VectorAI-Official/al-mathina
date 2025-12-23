"""
Interactive tool to add buying prices to products in the database
"""
from pymongo import MongoClient
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv('.env.production')

mongodb_uri = os.getenv('MONGO_URI')
db_name = os.getenv('MONGO_DB_NAME', 'almadhinadb')

if not mongodb_uri:
    print("❌ MONGO_URI not found in environment")
    exit(1)

client = MongoClient(mongodb_uri)
db = client[db_name]

print("\n" + "="*70)
print("💰 ADD BUYING PRICES TO PRODUCTS")
print("="*70 + "\n")

# Show options
print("Choose an option:")
print("1. Set default buying price (80% of selling price) for all missing products")
print("2. Set default buying price (90% of selling price) for all missing products")
print("3. Set default buying price (95% of selling price) for all missing products")
print("4. Set custom percentage for all missing products")
print("5. Add buying prices by category")
print("6. Export products to CSV for manual entry")
print("7. View products without buying prices")
print("8. Exit")
print()

choice = input("Enter your choice (1-8): ").strip()

if choice == "1":
    percentage = 80
elif choice == "2":
    percentage = 90
elif choice == "3":
    percentage = 95
elif choice == "4":
    try:
        percentage = float(input("Enter percentage of selling price (e.g., 85 for 85%): ").strip())
        if percentage <= 0 or percentage >= 100:
            print("❌ Invalid percentage. Must be between 0 and 100.")
            exit(1)
    except ValueError:
        print("❌ Invalid input. Please enter a number.")
        exit(1)
elif choice == "5":
    # Show categories
    print("\n📦 Sections with missing buying prices:\n")
    pipeline = [
        {'$match': {'buying_price': {'$exists': False}}},
        {'$group': {
            '_id': '$section',
            'count': {'$sum': 1}
        }},
        {'$sort': {'count': -1}}
    ]
    sections = list(db.products.aggregate(pipeline))
    
    for i, section in enumerate(sections, 1):
        section_name = section['_id'] if section['_id'] else 'Unknown'
        print(f"{i}. {section_name}: {section['count']} products")
    
    print()
    section_choice = input("Enter section name (or 'all' for all sections): ").strip()
    
    if section_choice.lower() == 'all':
        filter_query = {'buying_price': {'$exists': False}}
    else:
        filter_query = {'section': section_choice, 'buying_price': {'$exists': False}}
    
    try:
        percentage = float(input("Enter percentage of selling price (e.g., 85 for 85%): ").strip())
        if percentage <= 0 or percentage >= 100:
            print("❌ Invalid percentage. Must be between 0 and 100.")
            exit(1)
    except ValueError:
        print("❌ Invalid input. Please enter a number.")
        exit(1)
    
    # Update products
    print(f"\n🔄 Updating products with {percentage}% of selling price...\n")
    
    products = db.products.find(filter_query)
    updated_count = 0
    
    for product in products:
        selling_price = product.get('price', 0)
        buying_price = round(selling_price * (percentage / 100), 2)
        
        db.products.update_one(
            {'_id': product['_id']},
            {'$set': {'buying_price': buying_price}}
        )
        updated_count += 1
        
        print(f"✅ {product.get('product_name', 'Unknown')}")
        print(f"   Selling: ₹{selling_price:.2f} → Buying: ₹{buying_price:.2f}")
    
    print(f"\n✅ Updated {updated_count} products!")
    client.close()
    exit(0)

elif choice == "6":
    import csv
    from datetime import datetime
    
    filename = f"products_without_buying_price_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    products = db.products.find(
        {'buying_price': {'$exists': False}},
        {'product_name': 1, 'section': 1, 'main_category': 1, 'subcategory': 1, 'price': 1, 'weight': 1}
    ).sort('section', 1)
    
    with open(filename, 'w', newline='', encoding='utf-8-sig') as csvfile:
        fieldnames = ['product_name', 'weight', 'section', 'main_category', 'subcategory', 'selling_price', 'buying_price']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for product in products:
            writer.writerow({
                'product_name': product.get('product_name', ''),
                'weight': product.get('weight', ''),
                'section': product.get('section', ''),
                'main_category': product.get('main_category', ''),
                'subcategory': product.get('subcategory', ''),
                'selling_price': product.get('price', 0),
                'buying_price': ''  # Empty for manual entry
            })
    
    print(f"\n✅ Exported to {filename}")
    print(f"   Fill in the 'buying_price' column and use import script to update.")
    client.close()
    exit(0)

elif choice == "7":
    products = db.products.find(
        {'buying_price': {'$exists': False}},
        {'product_name': 1, 'section': 1, 'main_category': 1, 'price': 1}
    ).limit(50)
    
    print("\n📋 First 50 products without buying prices:\n")
    for i, product in enumerate(products, 1):
        print(f"{i}. {product.get('product_name', 'Unknown')}")
        print(f"   Section: {product.get('section', 'N/A')}")
        print(f"   Category: {product.get('main_category', 'N/A')}")
        print(f"   Selling: ₹{product.get('price', 0):.2f}")
        print()
    
    client.close()
    exit(0)

elif choice == "8":
    print("\n👋 Goodbye!")
    client.close()
    exit(0)

else:
    print("❌ Invalid choice")
    client.close()
    exit(1)

# Update all products without buying_price
print(f"\n🔄 Setting buying price to {percentage}% of selling price for all missing products...\n")

products = db.products.find({'buying_price': {'$exists': False}})
updated_count = 0
total_margin = 0

for product in products:
    selling_price = product.get('price', 0)
    buying_price = round(selling_price * (percentage / 100), 2)
    margin = selling_price - buying_price
    
    db.products.update_one(
        {'_id': product['_id']},
        {'$set': {'buying_price': buying_price}}
    )
    
    updated_count += 1
    total_margin += margin
    
    if updated_count <= 10:  # Show first 10
        print(f"✅ {product.get('product_name', 'Unknown')}")
        print(f"   Selling: ₹{selling_price:.2f} → Buying: ₹{buying_price:.2f} (Margin: ₹{margin:.2f})")
        print()

if updated_count > 10:
    print(f"... and {updated_count - 10} more products")

print(f"\n" + "="*70)
print(f"✅ Successfully updated {updated_count} products!")
print(f"💰 Total margin added: ₹{total_margin:.2f}")
print(f"📊 Average margin per product: ₹{total_margin/updated_count:.2f}")
print("="*70 + "\n")

# Verify
total = db.products.count_documents({})
with_price = db.products.count_documents({'buying_price': {'$exists': True, '$ne': None}})
print(f"📊 New statistics:")
print(f"   Total products: {total}")
print(f"   With buying_price: {with_price}")
print(f"   Percentage complete: {(with_price/total)*100:.1f}%")
print()

client.close()
