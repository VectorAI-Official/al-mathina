"""
User Profile Management Routes for Flutter App
Handles user data, preferences, and order history
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from database.mongodb_client import get_mongo_db
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/flutter/user", tags=["User Profile"])

# Pydantic models
class Address(BaseModel):
    street: str
    city: str
    state: str
    pincode: str
    landmark: Optional[str] = None
    is_default: bool = False

class UserProfile(BaseModel):
    phone: str
    name: Optional[str] = None
    email: Optional[str] = None
    addresses: List[Address] = []
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None

class AddAddressRequest(BaseModel):
    street: str
    city: str
    state: str
    pincode: str
    landmark: Optional[str] = None
    is_default: bool = False

class StoreDetails(BaseModel):
    store_name: Optional[str] = None
    street: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    landmark: Optional[str] = None

class OrderItem(BaseModel):
    product_name: str
    weight: str
    quantity: int
    price: float
    image_url: Optional[str] = None

class Order(BaseModel):
    order_id: str
    user_phone: str
    items: List[OrderItem]
    total_amount: float
    status: str  # pending, confirmed, delivered, cancelled
    payment_method: str
    delivery_address: Address
    created_at: datetime
    updated_at: Optional[datetime] = None

# Get or create user profile
@router.get("/profile/{phone}")
async def get_user_profile(phone: str, request: Request):
    """Get user profile by phone number, create if doesn't exist"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Find existing user
        user = users_collection.find_one({"phone": phone})
        
        if not user:
            # Create new user profile
            new_user = {
                "phone": phone,
                "name": None,
                "email": None,
                "addresses": [],
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            result = users_collection.insert_one(new_user)
            user = users_collection.find_one({"_id": result.inserted_id})
        
        # Convert ObjectId to string
        user['_id'] = str(user['_id'])
        
        return {
            "success": True,
            "user": user
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Update user profile
@router.put("/profile/{phone}")
async def update_user_profile(phone: str, profile: UpdateProfileRequest, request: Request):
    """Update user profile information"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        update_data = {
            "updated_at": datetime.utcnow()
        }
        
        if profile.name is not None:
            update_data["name"] = profile.name
        if profile.email is not None:
            update_data["email"] = profile.email
        
        result = users_collection.update_one(
            {"phone": phone},
            {"$set": update_data}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get updated user
        user = users_collection.find_one({"phone": phone})
        user['_id'] = str(user['_id'])
        
        return {
            "success": True,
            "message": "Profile updated successfully",
            "user": user
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Add address
@router.post("/address/{phone}")
async def add_address(phone: str, address: AddAddressRequest, request: Request):
    """Add a new delivery address"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # If this is default address, unset other defaults
        if address.is_default:
            users_collection.update_one(
                {"phone": phone},
                {"$set": {"addresses.$[].is_default": False}}
            )
        
        # Add new address
        new_address = address.dict()
        result = users_collection.update_one(
            {"phone": phone},
            {
                "$push": {"addresses": new_address},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        
        return {
            "success": True,
            "message": "Address added successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Update address
@router.put("/address/{phone}/{address_index}")
async def update_address(phone: str, address_index: int, address: AddAddressRequest, request: Request):
    """Update an existing address"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Get user to check if address exists
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        if address_index >= len(user.get('addresses', [])):
            raise HTTPException(status_code=404, detail="Address not found")
        
        # If this is default address, unset other defaults
        if address.is_default:
            for i in range(len(user['addresses'])):
                if i != address_index:
                    users_collection.update_one(
                        {"phone": phone},
                        {"$set": {f"addresses.{i}.is_default": False}}
                    )
        
        # Update specific address
        update_data = {f"addresses.{address_index}": address.dict(), "updated_at": datetime.utcnow()}
        users_collection.update_one(
            {"phone": phone},
            {"$set": update_data}
        )
        
        return {
            "success": True,
            "message": "Address updated successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Delete address
@router.delete("/address/{phone}/{address_index}")
async def delete_address(phone: str, address_index: int, request: Request):
    """Delete an address"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Get user to check if address exists
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        addresses = user.get('addresses', [])
        if address_index >= len(addresses):
            raise HTTPException(status_code=404, detail="Address not found")
        
        # Remove address
        addresses.pop(address_index)
        
        users_collection.update_one(
            {"phone": phone},
            {
                "$set": {
                    "addresses": addresses,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        return {
            "success": True,
            "message": "Address deleted successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Get user orders
@router.get("/orders/{phone}")
async def get_user_orders(phone: str, request: Request):
    """Get all orders for a user"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        
        # Find all orders for user
        orders = list(orders_collection.find({"user_phone": phone}).sort("created_at", -1))
        
        # Convert ObjectId to string
        for order in orders:
            order['_id'] = str(order['_id'])
        
        return {
            "success": True,
            "orders": orders
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Create order
@router.post("/orders")
async def create_order(request: Request):
    """Create a new order"""
    try:
        from datetime import datetime, timedelta
        import uuid
        
        # Get request body
        order_data = await request.json()
        
        db = get_mongo_db()
        orders_collection = db['orders']
        
        user_phone = order_data.get('user_phone')
        items = order_data.get('items', [])
        delivery_address = order_data.get('delivery_address', {})
        payment_method = order_data.get('payment_method', 'cod')
        total_amount = order_data.get('total_amount', 0)
        
        if not user_phone or not items or not delivery_address:
            raise HTTPException(status_code=400, detail="Missing required fields: user_phone, items, delivery_address")
        
        # Generate a human-readable order ID
        order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
        
        # Prepare order document
        order_doc = {
            'order_id': order_id,  # ✅ Store the generated order_id
            'user_phone': user_phone,
            'items': items,
            'total_amount': float(total_amount),
            'status': 'pending',
            'payment_method': payment_method,
            'delivery_address': delivery_address,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'estimated_delivery': (datetime.utcnow() + timedelta(days=3)).isoformat()
        }
        
        result = orders_collection.insert_one(order_doc)
        
        logger.info(f"Created order {order_id} (MongoDB ID: {result.inserted_id}) for user {user_phone}")
        
        return {
            "success": True,
            "message": "Order created successfully",
            "order_id": order_id,  # ✅ Return the generated order_id
            "status": "pending",
            "created_at": order_doc["created_at"].isoformat()
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating order: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create order: {str(e)}")

# Get single order details by order_id
@router.get("/orders/{phone}/{order_id}")
async def get_order_details(phone: str, order_id: str, request: Request):
    """Get detailed information for a specific order"""
    try:
        db = get_mongo_db()
        orders_collection = db['orders']
        users_collection = db['users']
        products_collection = db['products']
        
        # Find the order for this user
        order = orders_collection.find_one({
            "user_phone": phone,
            "order_id": order_id
        })
        
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Convert ObjectId to string
        order['_id'] = str(order['_id'])
        
        # Enrich order with user's store details for delivery address
        user = users_collection.find_one({"phone": phone})
        if user:
            store_details = user.get('store_details', {})
            # If delivery_address is not in order or is empty, use store_details
            if not order.get('delivery_address') or not order['delivery_address'].get('street'):
                order['delivery_address'] = {
                    'street': store_details.get('street', ''),
                    'city': store_details.get('city', ''),
                    'state': store_details.get('state', ''),
                    'pincode': store_details.get('pincode', ''),
                    'landmark': store_details.get('landmark', '')
                }
        
        # Enrich items with product images if not already present
        enriched_items = []
        for item in order.get('items', []):
            # If image_url is not in item or is empty, fetch from products
            if not item.get('image_url'):
                # Try to find product by item_id first
                product = None
                if item.get('item_id'):
                    product = products_collection.find_one({"item_id": item.get('item_id')})
                
                # If not found by item_id, try by category fields and product name
                if not product and item.get('section'):
                    product = products_collection.find_one({
                        "category_section": item.get('section'),
                        "category_main": item.get('main_category'),
                        "category_sub": item.get('subcategory'),
                        "product_name": item.get('product_name')
                    })
                
                # Add image_url if product found
                if product and product.get('image_url'):
                    item['image_url'] = product.get('image_url')
            
            enriched_items.append(item)
        
        order['items'] = enriched_items
        
        return {
            "success": True,
            "order": order
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Get store details
@router.get("/store-details/{phone}")
async def get_store_details(phone: str, request: Request):
    """Get store details for a user"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Find user
        user = users_collection.find_one({"phone": phone})
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get store details or return empty structure
        store_details = user.get('store_details', {
            'store_name': None,
            'street': None,
            'city': None,
            'state': None,
            'pincode': None,
            'landmark': None
        })
        
        return {
            "success": True,
            "store_details": store_details
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Update store details
@router.put("/store-details/{phone}")
async def update_store_details(phone: str, store_details: StoreDetails, request: Request):
    """Update store details for a user"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Check if user exists
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Update store details
        update_data = {
            "store_details": store_details.dict(),
            "updated_at": datetime.utcnow()
        }
        
        result = users_collection.update_one(
            {"phone": phone},
            {"$set": update_data}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        
        return {
            "success": True,
            "message": "Store details updated successfully",
            "store_details": store_details.dict()
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ================================
# FAVORITES ROUTES
# ================================

class AddFavoriteRequest(BaseModel):
    item_id: str

@router.get("/favorites/{phone}")
async def get_favorites(phone: str, request: Request):
    """Get user's favorite products"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        products_collection = db['products']
        
        # Get user's favorites
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        favorite_ids = user.get('favorites', [])
        
        # Fetch product details for each favorite
        favorite_products = []
        for item_id in favorite_ids:
            product = products_collection.find_one({"item_id": item_id})
            if product:
                # Convert ObjectId to string
                product['_id'] = str(product['_id'])
                
                # Normalize image_url to absolute URL
                if 'image_url' in product and product['image_url']:
                    if not product['image_url'].startswith('http'):
                        base_url = str(request.base_url).rstrip('/')
                        product['image_url'] = f"{base_url}/{product['image_url'].lstrip('/')}"
                
                # Map to Flutter-friendly field names
                favorite_products.append({
                    'item_id': product.get('item_id'),
                    'section': product.get('category_section'),
                    'main_category': product.get('category_main'),
                    'subcategory': product.get('category_sub'),
                    'product_name': product.get('product_name'),
                    'weight': product.get('weight'),
                    'price': product.get('price'),
                    'image_url': product.get('image_url', ''),
                    'stock': product.get('stock', 0),
                    'in_stock': product.get('stock', 0) > 0,
                    'is_best_seller': product.get('is_best_seller', False),
                    'description': product.get('description', ''),
                    'category_section': product.get('category_section'),
                    'category_main': product.get('category_main'),
                    'category_breadcrumb': f"{product.get('category_section', '')} > {product.get('category_main', '')} > {product.get('category_sub', '')}"
                })
        
        return {
            "success": True,
            "favorites": favorite_products
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting favorites: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/favorites/{phone}")
async def add_favorite(phone: str, request_body: AddFavoriteRequest):
    """Add a product to user's favorites"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        products_collection = db['products']
        
        # Verify product exists
        product = products_collection.find_one({"item_id": request_body.item_id})
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Check if user exists, create if not
        user = users_collection.find_one({"phone": phone})
        if not user:
            # Create user with favorites array
            users_collection.insert_one({
                "phone": phone,
                "favorites": [request_body.item_id],
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            })
        else:
            # Add to favorites if not already present
            if 'favorites' not in user:
                user['favorites'] = []
            
            if request_body.item_id not in user['favorites']:
                users_collection.update_one(
                    {"phone": phone},
                    {
                        "$addToSet": {"favorites": request_body.item_id},
                        "$set": {"updated_at": datetime.utcnow()}
                    }
                )
        
        return {
            "success": True,
            "message": "Product added to favorites"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error adding favorite: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/favorites/{phone}/{item_id}")
async def remove_favorite(phone: str, item_id: str):
    """Remove a product from user's favorites"""
    try:
        db = get_mongo_db()
        users_collection = db['users']
        
        # Remove from favorites
        result = users_collection.update_one(
            {"phone": phone},
            {
                "$pull": {"favorites": item_id},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        
        return {
            "success": True,
            "message": "Product removed from favorites"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error removing favorite: {e}")
        raise HTTPException(status_code=500, detail=str(e))
