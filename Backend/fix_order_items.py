"""
Fix existing orders to include section, main_category, subcategory in items
"""

from config_local import get_database

def fix_order_items():
    db = get_database()
    orders_collection = db['orders']
    products_collection = db['products']
    
    # Get all orders
    orders = list(orders_collection.find())
    
    print(f"Found {len(orders)} orders to check")
    
    for order in orders:
        order_id = order.get('order_id')
        items = order.get('items', [])
        updated = False
        
        print(f"\nChecking order: {order_id}")
        
        for i, item in enumerate(items):
            # Check if item has the required fields
            has_fields = all(key in item for key in ['section', 'main_category', 'subcategory', 'item_id'])
            
            if not has_fields:
                print(f"  Item {i+1} missing fields: {item.get('product_name')}")
                
                # Try to find the product by item_id
                item_id = item.get('item_id')
                if item_id:
                    product = products_collection.find_one({"item_id": item_id})
                    if product:
                        # Update item with section, main_category, subcategory
                        item['section'] = product.get('section', '')
                        item['main_category'] = product.get('main_category', '')
                        item['subcategory'] = product.get('subcategory', '')
                        updated = True
                        print(f"    ✓ Updated with: section={product.get('section')}, main_category={product.get('main_category')}, subcategory={product.get('subcategory')}")
                    else:
                        print(f"    ✗ Product not found for item_id: {item_id}")
                else:
                    # Try to find by product name
                    product_name = item.get('product_name')
                    product = products_collection.find_one({"product_name": product_name})
                    if product:
                        item['item_id'] = product.get('item_id', '')
                        item['section'] = product.get('section', '')
                        item['main_category'] = product.get('main_category', '')
                        item['subcategory'] = product.get('subcategory', '')
                        updated = True
                        print(f"    ✓ Found and updated: item_id={product.get('item_id')}, section={product.get('section')}")
                    else:
                        print(f"    ✗ Product not found for name: {product_name}")
            else:
                print(f"  Item {i+1} already has all fields: {item.get('product_name')}")
        
        # Update the order if any items were modified
        if updated:
            orders_collection.update_one(
                {"order_id": order_id},
                {"$set": {"items": items}}
            )
            print(f"  ✓ Order {order_id} updated in database")
        else:
            print(f"  - No updates needed for order {order_id}")
    
    print("\n✓ Done!")

if __name__ == "__main__":
    fix_order_items()
