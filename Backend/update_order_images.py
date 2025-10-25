"""
Update existing orders to include image_url in items
"""

from config_local import get_database

def update_order_images():
    db = get_database()
    orders_collection = db['orders']
    products_collection = db['products']
    
    # Get all orders
    orders = list(orders_collection.find())
    
    print(f"Found {len(orders)} orders to update")
    
    for order in orders:
        order_id = order.get('order_id')
        items = order.get('items', [])
        updated = False
        
        print(f"\nUpdating order: {order_id}")
        
        for i, item in enumerate(items):
            # Check if item already has image_url
            if item.get('image_url'):
                print(f"  Item {i+1} already has image: {item.get('product_name')}")
                continue
            
            # Try to find product by item_id
            product = None
            if item.get('item_id'):
                product = products_collection.find_one({"item_id": item.get('item_id')})
            
            # If not found, try by product name
            if not product:
                product = products_collection.find_one({"product_name": item.get('product_name')})
            
            if product and product.get('image_url'):
                item['image_url'] = product.get('image_url')
                updated = True
                print(f"  ✓ Added image for: {item.get('product_name')}")
            else:
                print(f"  ✗ No image found for: {item.get('product_name')}")
        
        # Update the order if any items were modified
        if updated:
            orders_collection.update_one(
                {"order_id": order_id},
                {"$set": {"items": items}}
            )
            print(f"  ✓ Order {order_id} updated")
        else:
            print(f"  - No updates needed for order {order_id}")
    
    print("\n✓ Done!")

if __name__ == "__main__":
    update_order_images()
