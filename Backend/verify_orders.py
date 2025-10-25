"""
Verify order data integrity
"""

from config_local import get_database

def verify_orders():
    db = get_database()
    orders_collection = db['orders']
    
    print("=== ORDER DATA VERIFICATION ===\n")
    
    orders = list(orders_collection.find())
    
    for order in orders:
        order_id = order.get('order_id')
        print(f"Order: {order_id}")
        print(f"  Status: {order.get('status')}")
        print(f"  User Phone: {order.get('user_phone')}")
        print(f"  Total Amount: ₹{order.get('total_amount')}")
        
        # Check delivery address
        delivery_addr = order.get('delivery_address', {})
        if delivery_addr and delivery_addr.get('street'):
            print(f"  Delivery Address: {delivery_addr.get('street')}, {delivery_addr.get('city')}")
        else:
            print(f"  Delivery Address: NOT SET (will use user's store details)")
        
        # Check items
        items = order.get('items', [])
        print(f"  Items ({len(items)}):")
        for i, item in enumerate(items, 1):
            has_image = '✓' if item.get('image_url') else '✗'
            has_item_id = '✓' if item.get('item_id') else '✗'
            print(f"    {i}. {item.get('product_name')} - Qty: {item.get('quantity')}")
            print(f"       Image: {has_image} | Item ID: {has_item_id} {item.get('item_id', 'N/A')}")
            if item.get('section'):
                print(f"       Category: {item.get('section')} > {item.get('main_category')} > {item.get('subcategory')}")
        
        print()

if __name__ == "__main__":
    verify_orders()
