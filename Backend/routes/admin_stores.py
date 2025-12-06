"""
Admin Store Management Routes
Handles store/user viewing, filtering, and revenue calculations
"""

from fastapi import APIRouter, HTTPException, Request, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from database.mongodb_client import get_mongo_db
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/api/stores", tags=["Admin Stores"])


# Pydantic models
class StoreListResponse(BaseModel):
    success: bool
    stores: List[dict]
    total: int


class StoreDetailResponse(BaseModel):
    success: bool
    store: dict
    orders: List[dict]
    revenue: dict


# Helper to serialize MongoDB documents
def serialize_doc(doc):
    """Convert MongoDB document to JSON-serializable dict"""
    if doc is None:
        return None
    if isinstance(doc, list):
        return [serialize_doc(item) for item in doc]
    if isinstance(doc, dict):
        result = {}
        for key, value in doc.items():
            if isinstance(value, ObjectId):
                result[key] = str(value)
            elif isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, (dict, list)):
                result[key] = serialize_doc(value)
            else:
                result[key] = value
        return result
    return doc


@router.get("/list")
async def get_stores_list(
    request: Request,
    search: Optional[str] = Query(None, description="Search by store name or phone"),
    start_date: Optional[str] = Query(None, description="Filter by order date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="Filter by order date (YYYY-MM-DD)"),
    limit: Optional[int] = Query(50, description="Number of stores per page"),
    skip: Optional[int] = Query(0, description="Number of stores to skip")
):
    """
    Get stores with pagination for lazy loading
    Returns limited results with has_more flag
    """
    try:
        db = get_mongo_db()
        users_collection = db['users']
        orders_collection = db['orders']
        
        # Build query filter for users
        user_query = {}
        
        # Search filter
        if search:
            user_query["$or"] = [
                {"store_details.store_name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
                {"name": {"$regex": search, "$options": "i"}}
            ]
        
        # Date filter - filter by order date, not user registration date
        user_phones_with_orders = None
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            
            # Find all users who placed orders in the date range
            orders_in_range = orders_collection.find(
                {"created_at": date_query},
                {"user_phone": 1}
            ).distinct("user_phone")
            
            user_phones_with_orders = set(orders_in_range)
            
            # Add to user query to filter only users with orders in date range
            if user_phones_with_orders:
                user_query["phone"] = {"$in": list(user_phones_with_orders)}
            else:
                # No orders in date range, return empty
                return {
                    "success": True,
                    "stores": [],
                    "total": 0,
                    "has_more": False
                }
        
        # Fetch all matching users
        total_count = users_collection.count_documents(user_query)
        users = list(users_collection.find(user_query).sort("created_at", -1).skip(skip).limit(limit))
        
        # Use aggregation pipeline for efficient order stats
        user_phones = [user['phone'] for user in users]
        
        # Build order stats pipeline with date filter if applicable
        order_match = {"user_phone": {"$in": user_phones}}
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            order_match["created_at"] = date_query
        
        # Batch fetch order stats for all users at once
        pipeline = [
            {"$match": order_match},
            {"$group": {
                "_id": "$user_phone",
                "order_count": {"$sum": 1},
                "total_revenue": {"$sum": "$total_amount"},
                "latest_order": {"$max": "$created_at"}
            }}
        ]
        order_stats = {doc['_id']: doc for doc in orders_collection.aggregate(pipeline)}
        
        # Build response with pre-fetched stats
        stores = []
        for user in users:
            phone = user['phone']
            stats = order_stats.get(phone, {})
            
            store_info = {
                "_id": str(user['_id']),
                "phone": phone,
                "name": user.get('name'),
                "email": user.get('email'),
                "store_name": user.get('store_details', {}).get('store_name'),
                "city": user.get('store_details', {}).get('city'),
                "state": user.get('store_details', {}).get('state'),
                "created_at": user.get('created_at').isoformat() if user.get('created_at') else None,
                "order_count": stats.get('order_count', 0),
                "total_revenue": round(float(stats.get('total_revenue', 0)), 2),
                "latest_order": stats.get('latest_order').isoformat() if stats.get('latest_order') else None
            }
            stores.append(store_info)
        
        return {
            "success": True,
            "stores": stores,
            "total": len(stores),
            "has_more": (skip + limit) < total_count
        }
    except Exception as e:
        logger.error(f"Error fetching stores: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/statistics")
async def get_stores_statistics(
    request: Request,
    search: Optional[str] = Query(None, description="Search by store name or phone"),
    start_date: Optional[str] = Query(None, description="Filter by order date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="Filter by order date (YYYY-MM-DD)")
):
    """
    Get statistics for ALL stores matching the filters
    Used independently from pagination to show accurate totals
    """
    try:
        db = get_mongo_db()
        users_collection = db['users']
        orders_collection = db['orders']
        
        # Build same query filter as /list endpoint
        user_query = {}
        
        # Search filter
        if search:
            user_query["$or"] = [
                {"store_details.store_name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
                {"name": {"$regex": search, "$options": "i"}}
            ]
        
        # Date filter - filter by order date, not user registration date
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            
            # Find all users who placed orders in the date range
            orders_in_range = orders_collection.find(
                {"created_at": date_query},
                {"user_phone": 1}
            ).distinct("user_phone")
            
            user_phones_with_orders = set(orders_in_range)
            
            # Add to user query to filter only users with orders in date range
            if user_phones_with_orders:
                user_query["phone"] = {"$in": list(user_phones_with_orders)}
            else:
                # No orders in date range, return zero stats
                return {
                    "success": True,
                    "total_stores": 0,
                    "total_orders": 0,
                    "total_revenue": 0.0,
                    "avg_per_store": 0.0
                }
        
        # Get total count and all matching phone numbers
        total_stores = users_collection.count_documents(user_query)
        user_phones = [user['phone'] for user in users_collection.find(user_query, {"phone": 1})]
        
        # Build order match query with date filter if applicable
        order_match = {"user_phone": {"$in": user_phones}} if user_phones else {}
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            order_match["created_at"] = date_query
        
        # Calculate aggregated statistics across all orders for these stores with date filter
        pipeline = [
            {"$match": order_match},
            {"$group": {
                "_id": None,
                "total_orders": {"$sum": 1},
                "total_revenue": {"$sum": "$total_amount"},
                "delivered_orders": {
                    "$sum": {"$cond": [{"$eq": ["$status", "delivered"]}, 1, 0]}
                },
                "delivered_revenue": {
                    "$sum": {"$cond": [{"$eq": ["$status", "delivered"]}, "$total_amount", 0]}
                }
            }}
        ]
        
        stats_result = list(orders_collection.aggregate(pipeline))
        stats = stats_result[0] if stats_result else {}
        
        total_orders = stats.get('total_orders', 0)
        total_revenue = round(float(stats.get('total_revenue', 0)), 2)
        delivered_orders = stats.get('delivered_orders', 0)
        delivered_revenue = round(float(stats.get('delivered_revenue', 0)), 2)
        avg_order_value = round(total_revenue / total_orders, 2) if total_orders > 0 else 0
        
        return {
            "success": True,
            "statistics": {
                "total_stores": total_stores,
                "total_orders": total_orders,
                "total_revenue": total_revenue,
                "delivered_orders": delivered_orders,
                "delivered_revenue": delivered_revenue,
                "avg_order_value": avg_order_value
            }
        }
    except Exception as e:
        logger.error(f"Error calculating statistics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detail/{phone}")
async def get_store_detail(
    phone: str,
    request: Request,
    start_date: Optional[str] = Query(None, description="Filter orders by date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="Filter orders by date (YYYY-MM-DD)")
):
    """
    Get detailed store information including:
    - Personal details
    - All orders (with date filtering)
    - Revenue calculations based on date filter
    """
    try:
        db = get_mongo_db()
        users_collection = db['users']
        orders_collection = db['orders']
        products_collection = db['products']
        
        # Find user
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="Store not found")
        
        # Build orders query
        orders_query = {"user_phone": phone}
        
        # Date filter for orders
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            orders_query["created_at"] = date_query
        
        # Fetch orders
        orders = list(orders_collection.find(orders_query).sort("created_at", -1))
        
        # Enrich orders with product images
        enriched_orders = []
        for order in orders:
            # Enrich items with images
            for item in order.get('items', []):
                product = products_collection.find_one({"item_id": item.get('item_id')})
                if product and product.get('image_url'):
                    item['image_url'] = product.get('image_url')
            
            order_data = serialize_doc(order)
            enriched_orders.append(order_data)
        
        # Calculate revenue statistics
        total_orders = len(enriched_orders)
        total_revenue = sum(float(order.get('total_amount', 0)) for order in enriched_orders)
        
        # Status breakdown
        pending_orders = sum(1 for o in enriched_orders if o.get('status') == 'pending')
        confirmed_orders = sum(1 for o in enriched_orders if o.get('status') == 'confirmed')
        delivered_orders = sum(1 for o in enriched_orders if o.get('status') == 'delivered')
        cancelled_orders = sum(1 for o in enriched_orders if o.get('status') == 'cancelled')
        
        # Calculate delivered revenue only
        delivered_revenue = sum(
            float(order.get('total_amount', 0)) 
            for order in enriched_orders 
            if order.get('status') == 'delivered'
        )
        
        # Store details
        store_data = {
            "_id": str(user['_id']),
            "phone": user['phone'],
            "name": user.get('name'),
            "email": user.get('email'),
            "created_at": user.get('created_at').isoformat() if user.get('created_at') else None,
            "updated_at": user.get('updated_at').isoformat() if user.get('updated_at') else None,
            "store_details": user.get('store_details', {}),
            "addresses": user.get('addresses', [])
        }
        
        revenue_stats = {
            "total_orders": total_orders,
            "total_revenue": round(total_revenue, 2),
            "delivered_revenue": round(delivered_revenue, 2),
            "pending_orders": pending_orders,
            "confirmed_orders": confirmed_orders,
            "delivered_orders": delivered_orders,
            "cancelled_orders": cancelled_orders,
            "average_order_value": round(total_revenue / total_orders, 2) if total_orders > 0 else 0
        }
        
        return {
            "success": True,
            "store": store_data,
            "orders": enriched_orders,
            "revenue": revenue_stats
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching store detail: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/revenue-summary")
async def get_revenue_summary(
    request: Request,
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None)
):
    """
    Get overall revenue summary for all stores
    """
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        # Build query
        query = {}
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query["$gte"] = datetime.fromisoformat(start_date)
            if end_date:
                from datetime import timedelta
                end_dt = datetime.fromisoformat(end_date)
                date_query["$lte"] = end_dt + timedelta(days=1)
            query["created_at"] = date_query
        
        # Fetch all orders
        orders = list(orders_collection.find(query))
        
        total_orders = len(orders)
        total_revenue = sum(float(order.get('total_amount', 0)) for order in orders)
        delivered_revenue = sum(
            float(order.get('total_amount', 0)) 
            for order in orders 
            if order.get('status') == 'delivered'
        )
        
        # Count unique stores
        unique_stores = len(set(order.get('user_phone') for order in orders if order.get('user_phone')))
        
        return {
            "success": True,
            "summary": {
                "total_orders": total_orders,
                "total_revenue": round(total_revenue, 2),
                "delivered_revenue": round(delivered_revenue, 2),
                "active_stores": unique_stores,
                "average_per_store": round(total_revenue / unique_stores, 2) if unique_stores > 0 else 0
            }
        }
    except Exception as e:
        logger.error(f"Error fetching revenue summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))
