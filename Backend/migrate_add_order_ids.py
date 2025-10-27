#!/usr/bin/env python3
"""
Migration script to add order_id to existing orders without one
Adds human-readable order IDs (ORD-XXXXXXXX) to all orders in MongoDB
"""

import sys
import uuid
from datetime import datetime
from database.mongodb_client import get_mongo_db

def add_order_ids_to_existing_orders():
    """Add order_id field to orders that don't have one"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        # Find all orders without order_id (field doesn't exist, is empty, or is null)
        orders_without_id = list(orders_collection.find({}))
        
        # Filter to only those without valid order_id
        orders_to_update = [o for o in orders_without_id if not o.get('order_id')]
        
        print(f"Found {len(orders_to_update)} orders without valid order_id (out of {len(orders_without_id)} total)")
        
        if len(orders_to_update) == 0:
            print("✅ All orders already have order_id!")
            return True
        
        # Add order_id to each order
        updated_count = 0
        for order in orders_to_update:
            order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
            
            result = orders_collection.update_one(
                {"_id": order['_id']},
                {"$set": {"order_id": order_id}}
            )
            
            if result.modified_count > 0:
                updated_count += 1
                user_phone = order.get('user_phone', 'unknown')
                print(f"✅ Added order_id '{order_id}' to order {str(order['_id'])[:12]}... (user: {user_phone})")
            else:
                print(f"⚠️  Failed to update order {str(order['_id'])[:12]}...")
        
        print(f"\n✅ Successfully updated {updated_count}/{len(orders_to_update)} orders")
        
        # Verify
        all_orders = list(orders_collection.find({}))
        orders_still_without = [o for o in all_orders if not o.get('order_id')]
        
        if len(orders_still_without) == 0:
            print("✅ MIGRATION COMPLETE: All orders now have valid order_id!")
            return True
        else:
            print(f"⚠️  WARNING: Still {len(orders_still_without)} orders without order_id")
            for order in orders_still_without:
                print(f"  - {str(order['_id'])[:12]}... has order_id='{order.get('order_id')}'")
            return False
            
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Order ID Migration Script")
    print("=" * 60)
    print()
    
    success = add_order_ids_to_existing_orders()
    
    sys.exit(0 if success else 1)

