"""
Admin Order Management Routes
Handles order listing, status updates, and stock management
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from database.mongodb_client import get_mongo_db
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/orders", tags=["Admin Orders"])

class UpdateOrderStatusRequest(BaseModel):
    status: str  # 'delivered', 'cancelled', 'pending'

# Get all orders for admin dashboard
@router.get("")
async def get_all_orders(request: Request):
    """Get all orders with user details and product information"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        users_collection = db['users']
        products_collection = db['products']
        
        # Get all orders sorted by created_at (newest first)
        orders = list(orders_collection.find().sort("created_at", -1))
        
        # Enrich orders with user and product details
        enriched_orders = []
        for order in orders:
            order['_id'] = str(order['_id'])
            
            # Ensure order_id exists (use _id as fallback for old orders)
            if 'order_id' not in order:
                order['order_id'] = str(order['_id'])
            
            # Get user details - support both user_phone and user_id fields
            user_phone = order.get('user_phone')
            user_id = order.get('user_id')
            
            user = None
            if user_phone:
                user = users_collection.find_one({"phone": user_phone})
            elif user_id:
                # Try to find by user_id or phone (user_id might be phone)
                user = users_collection.find_one({"user_id": user_id}) or users_collection.find_one({"phone": user_id})
            
            if user:
                order['user_name'] = user.get('name', 'Unknown')
                order['user_store_name'] = user.get('store_name', '')
                # Ensure user_phone is set for display
                if not user_phone:
                    order['user_phone'] = user.get('phone', user_id)
            else:
                order['user_name'] = 'Unknown'
                order['user_store_name'] = ''
                order['user_phone'] = user_phone or user_id or 'N/A'
            
            # Enrich items with product details and images
            enriched_items = []
            for item in order.get('items', []):
                # Find the product to get current stock and image
                product = products_collection.find_one({
                    "section": item.get('section'),
                    "main_category": item.get('main_category'),
                    "subcategory": item.get('subcategory'),
                    "item_id": item.get('item_id')
                })
                
                if product:
                    item['current_stock'] = product.get('stock', 0)
                    item['image_url'] = product.get('image_url', '')
                else:
                    item['current_stock'] = 0
                    item['image_url'] = ''
                
                enriched_items.append(item)
            
            order['items'] = enriched_items
            enriched_orders.append(order)
        
        logger.info(f"Retrieved {len(enriched_orders)} orders for admin dashboard")
        
        return {
            "success": True,
            "orders": enriched_orders
        }
    except Exception as e:
        logger.error(f"Error fetching all orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Get single order details
@router.get("/{order_id}")
async def get_order_by_id(order_id: str, request: Request):
    """Get detailed information for a specific order"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        users_collection = db['users']
        products_collection = db['products']
        
        # Find the order by ObjectId (MongoDB _id)
        try:
            order_obj_id = ObjectId(order_id)
            order = orders_collection.find_one({"_id": order_obj_id})
        except:
            # If not a valid ObjectId, try finding by order_id string field
            order = orders_collection.find_one({"order_id": order_id})
        
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        order['_id'] = str(order['_id'])
        
        # Ensure order_id exists
        if 'order_id' not in order:
            order['order_id'] = str(order['_id'])
        
        # Get user details - support both user_phone and user_id
        user_phone = order.get('user_phone')
        user_id = order.get('user_id')
        
        user = None
        if user_phone:
            user = users_collection.find_one({"phone": user_phone})
        elif user_id:
            user = users_collection.find_one({"user_id": user_id}) or users_collection.find_one({"phone": user_id})
        
        if user:
            order['user_name'] = user.get('name', 'Unknown')
            # Ensure user_phone is set
            if not user_phone:
                order['user_phone'] = user.get('phone', user_id)
            # Get store details
            store_details = user.get('store_details', {})
            order['user_store_name'] = store_details.get('store_name', '')
            order['user_store_address'] = {
                'street': store_details.get('street', ''),
                'city': store_details.get('city', ''),
                'state': store_details.get('state', ''),
                'pincode': store_details.get('pincode', ''),
                'landmark': store_details.get('landmark', '')
            }
        else:
            order['user_name'] = 'Unknown'
            order['user_store_name'] = ''
            order['user_store_address'] = {}
            order['user_phone'] = user_phone or user_id or 'N/A'
        
        # Enrich items with product details
        enriched_items = []
        for item in order.get('items', []):
            product = products_collection.find_one({
                "section": item.get('section'),
                "main_category": item.get('main_category'),
                "subcategory": item.get('subcategory'),
                "item_id": item.get('item_id')
            })
            
            if product:
                item['current_stock'] = product.get('stock', 0)
                item['image_url'] = product.get('image_url', '')
            else:
                item['current_stock'] = 0
                item['image_url'] = ''
            
            enriched_items.append(item)
        
        order['items'] = enriched_items
        
        logger.info(f"Retrieved order details: {order_id}")
        
        return {
            "success": True,
            "order": order
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching order {order_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Update order status
@router.put("/{order_id}/status")
async def update_order_status(order_id: str, status_update: UpdateOrderStatusRequest, request: Request):
    """Update order status and manage stock accordingly"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        products_collection = db['products']
        
        # Find the order
        try:
            order_obj_id = ObjectId(order_id)
            order = orders_collection.find_one({"_id": order_obj_id})
        except:
            order = orders_collection.find_one({"order_id": order_id})
        
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        old_status = order.get('status', 'pending')
        new_status = status_update.status
        
        # If marking as delivered, reduce stock
        if new_status == 'delivered' and old_status != 'delivered':
            for item in order.get('items', []):
                # Log the item details for debugging
                logger.info(f"Processing item for stock reduction: {item}")
                
                # Try to find product by item_id first (most reliable)
                item_id = item.get('item_id')
                if item_id:
                    result = products_collection.update_one(
                        {"item_id": item_id},
                        {"$inc": {"stock": -item.get('quantity', 0)}}
                    )
                    logger.info(f"Stock reduction by item_id - matched: {result.matched_count}, modified: {result.modified_count}")
                    
                    if result.matched_count > 0:
                        continue
                
                # Fallback: try using section/main_category/subcategory with correct field names
                section = item.get('section')
                main_category = item.get('main_category')
                subcategory = item.get('subcategory')
                
                if section and main_category and subcategory:
                    result = products_collection.update_one(
                        {
                            "category_section": section,
                            "category_main": main_category,
                            "category_sub": subcategory,
                            "product_name": item.get('product_name')
                        },
                        {"$inc": {"stock": -item.get('quantity', 0)}}
                    )
                    logger.info(f"Stock reduction by category fields - matched: {result.matched_count}, modified: {result.modified_count}")
                else:
                    logger.warning(f"Cannot update stock - insufficient product identification info: {item}")
        
        # If cancelling an order that was previously delivered, restore stock
        elif new_status == 'cancelled' and old_status == 'delivered':
            for item in order.get('items', []):
                # Try to find product by item_id first
                item_id = item.get('item_id')
                if item_id:
                    result = products_collection.update_one(
                        {"item_id": item_id},
                        {"$inc": {"stock": item.get('quantity', 0)}}
                    )
                    logger.info(f"Stock restored by item_id for: {item.get('product_name')}")
                    
                    if result.matched_count > 0:
                        continue
                
                # Fallback: try using section/main_category/subcategory
                section = item.get('section')
                main_category = item.get('main_category')
                subcategory = item.get('subcategory')
                
                if section and main_category and subcategory:
                    products_collection.update_one(
                        {
                            "category_section": section,
                            "category_main": main_category,
                            "category_sub": subcategory,
                            "product_name": item.get('product_name')
                        },
                        {"$inc": {"stock": item.get('quantity', 0)}}
                    )
                    logger.info(f"Stock restored by category fields for: {item.get('product_name')}")
                else:
                    logger.warning(f"Cannot restore stock - insufficient product identification info: {item}")
        
        # Update order status
        orders_collection.update_one(
            {"_id": ObjectId(order['_id']) if isinstance(order['_id'], str) else order['_id']},
            {
                "$set": {
                    "status": new_status,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        logger.info(f"Order {order_id} status updated from {old_status} to {new_status}")
        
        return {
            "success": True,
            "message": f"Order status updated to {new_status}",
            "order_id": order_id,
            "new_status": new_status
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating order status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class UpdateOrderItemsRequest(BaseModel):
    items: List[dict]
    total_amount: float

@router.put("/{order_id}/update-items")
async def update_order_items(order_id: str, update_data: UpdateOrderItemsRequest, request: Request):
    """Update order items and total amount"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        # Find the order
        try:
            order_obj_id = ObjectId(order_id)
            order = orders_collection.find_one({"_id": order_obj_id})
        except:
            order = orders_collection.find_one({"order_id": order_id})
        
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Update order items and total
        orders_collection.update_one(
            {"_id": ObjectId(order['_id']) if isinstance(order['_id'], str) else order['_id']},
            {
                "$set": {
                    "items": update_data.items,
                    "total_amount": update_data.total_amount,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        logger.info(f"Order {order_id} items updated - New total: ₹{update_data.total_amount}")
        
        return {
            "success": True,
            "message": "Order items updated successfully",
            "order_id": order_id,
            "new_total": update_data.total_amount
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating order items: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Delete order
@router.delete("/{order_id}")
async def delete_order(order_id: str, request: Request):
    """Delete an order by order_id"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        logger.info(f"🗑️ DELETING ORDER:")
        logger.info(f"   Order ID: {order_id}")
        
        # Find the order first to get details for logging
        order = orders_collection.find_one({"order_id": order_id})
        
        if not order:
            # Try finding by _id as fallback
            try:
                order = orders_collection.find_one({"_id": ObjectId(order_id)})
            except:
                pass
        
        if not order:
            logger.warning(f"   ⚠ Order not found: {order_id}")
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Log order details
        logger.info(f"   Customer: {order.get('user_name', 'Unknown')}")
        logger.info(f"   Phone: {order.get('user_phone', 'N/A')}")
        logger.info(f"   Total Amount: ₹{order.get('total_amount', 0)}")
        logger.info(f"   Status: {order.get('status', 'unknown')}")
        logger.info(f"   Items Count: {len(order.get('items', []))}")
        
        # Delete the order
        result = orders_collection.delete_one({"order_id": order_id})
        
        if result.deleted_count == 0:
            # Try deleting by _id as fallback
            try:
                result = orders_collection.delete_one({"_id": ObjectId(order_id)})
            except:
                pass
        
        if result.deleted_count > 0:
            logger.info(f"   ✓ Order document deleted from database")
            logger.info(f"✅ ORDER DELETION COMPLETE: {order_id}")
            return {
                "success": True,
                "message": f"Order {order_id} deleted successfully"
            }
        else:
            logger.error(f"   ✗ Failed to delete order: {order_id}")
            raise HTTPException(status_code=500, detail="Failed to delete order")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Error deleting order {order_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Get order statistics
@router.get("/stats/summary")
async def get_order_statistics(request: Request):
    """Get order statistics for dashboard"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        # Count orders by status
        total_orders = orders_collection.count_documents({})
        pending_orders = orders_collection.count_documents({"status": "pending"})
        delivered_orders = orders_collection.count_documents({"status": "delivered"})
        cancelled_orders = orders_collection.count_documents({"status": "cancelled"})
        
        # Calculate total revenue from delivered orders
        delivered_orders_list = list(orders_collection.find({"status": "delivered"}))
        total_revenue = sum(order.get('total_amount', 0) for order in delivered_orders_list)
        
        logger.info(f"Order statistics: Total={total_orders}, Pending={pending_orders}, Delivered={delivered_orders}, Cancelled={cancelled_orders}")
        
        return {
            "success": True,
            "stats": {
                "total_orders": total_orders,
                "pending_orders": pending_orders,
                "delivered_orders": delivered_orders,
                "cancelled_orders": cancelled_orders,
                "total_revenue": total_revenue
            }
        }
    except Exception as e:
        logger.error(f"Error fetching order statistics: {e}")
        raise HTTPException(status_code=500, detail=str(e))
