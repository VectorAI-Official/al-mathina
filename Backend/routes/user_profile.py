"""
User Profile Management Routes for Flutter App
Handles user data, preferences, and order history
"""

from fastapi import APIRouter, HTTPException, Request, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from database.mongodb_client import get_mongo_db
from database.supabase_client import get_supabase_client
from utils.fcm_service import fcm_service
from utils.email_service import email_service
import logging

logger = logging.getLogger(__name__)

# MODULE LOAD INDICATOR - Will print when file is imported
print("=" * 80, flush=True)
print("🔥🔥🔥 USER_PROFILE.PY MODULE LOADED - BACKGROUND TASKS VERSION", flush=True)
print("=" * 80, flush=True)
logger.error("🔥🔥🔥 USER_PROFILE.PY MODULE LOADED - BACKGROUND TASKS VERSION")

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

class UpdatePhoneRequest(BaseModel):
    new_phone: str

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

# Version check endpoint to verify deployment
@router.get("/version")
async def get_version():
    """Check backend version and deployment timestamp"""
    from datetime import datetime
    return {
        "version": "2.0.0-FIXED-LOGGING",
        "deployed_at": "2025-12-07T18:30:00Z",
        "timestamp": datetime.now().isoformat(),
        "logging": "ENHANCED",
        "status": "✅ Backend is alive with enhanced logging"
    }

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

# Update phone number
@router.put("/phone/{old_phone}")
async def update_phone_number(old_phone: str, update_request: UpdatePhoneRequest, request: Request):
    """
    Update user's phone number
    First checks if new phone already exists, then updates across all collections
    """
    try:
        new_phone = update_request.new_phone
        
        # Validate phone format
        if not new_phone.startswith('+91') or len(new_phone) != 13:
            raise HTTPException(
                status_code=400, 
                detail="Invalid phone format. Must be +91XXXXXXXXXX"
            )
        
        # Check if it's the same number
        if old_phone == new_phone:
            raise HTTPException(
                status_code=400,
                detail="New phone number is the same as current"
            )
        
        db = get_mongo_db()
        users_collection = db['users']
        orders_collection = db['orders']
        
        # Check if new phone already exists
        existing_user = users_collection.find_one({"phone": new_phone})
        if existing_user:
            raise HTTPException(
                status_code=409,
                detail="Phone number already registered to another user"
            )
        
        # Get old user data
        old_user = users_collection.find_one({"phone": old_phone})
        if not old_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        logger.info(f"📱 Updating phone number: {old_phone} -> {new_phone}")
        
        # Update phone in users collection
        result = users_collection.update_one(
            {"phone": old_phone},
            {
                "$set": {
                    "phone": new_phone,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        if result.modified_count > 0:
            logger.info(f"✅ Updated phone in users collection")
        
        # Update phone in all orders
        orders_result = orders_collection.update_many(
            {"phone": old_phone},
            {"$set": {"phone": new_phone}}
        )
        
        if orders_result.modified_count > 0:
            logger.info(f"✅ Updated {orders_result.modified_count} orders")
        
        # Update in Supabase users table
        try:
            supabase = get_supabase_client()
            supabase_result = supabase.table('users').update({
                'phone': new_phone,
                'updated_at': datetime.utcnow().isoformat()
            }).eq('phone', old_phone).execute()
            
            if supabase_result.data:
                logger.info(f"✅ Updated phone in Supabase")
        except Exception as supabase_error:
            logger.warning(f"⚠️ Supabase update failed (non-critical): {supabase_error}")
        
        # Get updated user
        updated_user = users_collection.find_one({"phone": new_phone})
        updated_user['_id'] = str(updated_user['_id'])
        
        logger.info(f"🎉 Phone number update completed successfully")
        
        return {
            "success": True,
            "message": "Phone number updated successfully",
            "old_phone": old_phone,
            "new_phone": new_phone,
            "user": updated_user
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error updating phone number: {str(e)}")
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

# Background task function for sending order email
async def send_order_email_background(
    order_id: str,
    user_phone: str,
    store_name: Optional[str],
    items: list,
    total_amount: float,
    delivery_address: dict,
    payment_method: str
):
    """Send order notification email in background (non-blocking)"""
    print("\n" + "*"*60, flush=True)
    print("📧 BACKGROUND: Starting email notification...", flush=True)
    print(f"📧 BACKGROUND: Order ID: {order_id}", flush=True)
    print("*"*60, flush=True)
    
    try:
        logger.info("\n" + "*"*60)
        logger.info("📧 BACKGROUND: Sending admin email notification...")
        logger.info(f"📧 BACKGROUND: Order: {order_id}")
        
        # Send email to admin with all order details
        email_sent = await email_service.send_order_notification_to_admin(
            order_id=order_id,
            user_phone=user_phone,
            store_name=store_name,
            items=items,
            total_amount=total_amount,
            delivery_address=delivery_address,
            payment_method=payment_method
        )
        
        if email_sent:
            logger.info("✅ BACKGROUND: Email sent successfully!")
            print("✅ BACKGROUND: Email delivered!", flush=True)
        else:
            logger.warning("⚠️ BACKGROUND: Email not sent (service may be disabled)")
            print("⚠️ BACKGROUND: Email service disabled", flush=True)
        
        logger.info("*"*60 + "\n")
        print("*"*60 + "\n", flush=True)
        
    except Exception as email_error:
        # Log error but don't fail (user already got their response)
        print(f"❌ BACKGROUND: Email failed: {email_error}", flush=True)
        print(f"❌ BACKGROUND: Type: {type(email_error).__name__}", flush=True)
        import traceback
        print(f"❌ BACKGROUND: Traceback: {traceback.format_exc()}", flush=True)
        print("*"*60 + "\n", flush=True)
        
        logger.error(f"❌ BACKGROUND: Email notification failed: {email_error}")
        logger.error(f"❌ BACKGROUND: Exception type: {type(email_error).__name__}")
        logger.error(f"❌ BACKGROUND: Traceback: {traceback.format_exc()}")
        logger.error("*"*60 + "\n")

# Create order
@router.post("/orders")
async def create_order(request: Request, background_tasks: BackgroundTasks):
    """Create a new order - automatically splits by section"""
    from datetime import datetime, timedelta, timezone
    from collections import defaultdict
    import uuid
    import sys
    import traceback
    import logging
    
    # Force immediate log output for Render
    sys.stdout.flush()
    sys.stderr.flush()
    logging.basicConfig(level=logging.INFO, force=True)
    
    print("\n" + "="*80, flush=True)
    print("🚀🚀🚀 ORDER ENDPOINT HIT - START OF FUNCTION", flush=True)
    print(f"🚀 RENDER LOG TEST: {datetime.now()}", flush=True)
    print(f"🚀 Timestamp: {datetime.now().isoformat()}", flush=True)
    print(f"🚀 Request method: {request.method}", flush=True)
    print(f"🚀 Request URL: {request.url}", flush=True)
    print("="*80 + "\n", flush=True)
    
    logger.error("🚀🚀🚀 ORDER ENDPOINT HIT - LOGGER TEST")
    logger.warning("🚀🚀🚀 ORDER ENDPOINT HIT - LOGGER WARNING")
    logger.info("🚀🚀🚀 ORDER ENDPOINT HIT - LOGGER INFO")
    try:
        
        print("📥 Step 1: Reading request body...", flush=True)
        # Get request body
        order_data = await request.json()
        print(f"✅ Step 1: Request body received, keys: {list(order_data.keys())}", flush=True)
        
        print("📊 Step 2: Connecting to MongoDB...", flush=True)
        db = get_mongo_db()
        orders_collection = db['orders']
        print("✅ Step 2: MongoDB connected", flush=True)
        
        print("🔍 Step 3: Extracting order data...", flush=True)
        user_phone = order_data.get('user_phone')
        items = order_data.get('items', [])
        delivery_address = order_data.get('delivery_address', {})
        payment_method = order_data.get('payment_method', 'cod')
        total_amount = order_data.get('total_amount', 0)
        print(f"✅ Step 3: user_phone={user_phone}, items_count={len(items)}, total={total_amount}", flush=True)
        
        if not user_phone or not items or not delivery_address:
            raise HTTPException(status_code=400, detail="Missing required fields: user_phone, items, delivery_address")
        
        # Group items by section
        items_by_section = defaultdict(list)
        for item in items:
            section = item.get('section', 'Unknown')
            items_by_section[section].append(item)
        
        # Use local timezone (India Standard Time - UTC+5:30)
        ist_offset = timezone(timedelta(hours=5, minutes=30))
        current_time = datetime.now(ist_offset)
        
        created_orders = []
        
        # Create separate order for each section
        for section, section_items in items_by_section.items():
            # Calculate section total
            section_total = sum(item.get('price', 0) * item.get('quantity', 1) for item in section_items)
            
            # Generate a human-readable order ID
            order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
            
            # Prepare order document
            order_doc = {
                'order_id': order_id,
                'user_phone': user_phone,
                'section': section,  # Store which section this order belongs to
                'items': section_items,
                'total_amount': float(section_total),
                'status': 'pending',
                'payment_method': payment_method,
                'delivery_address': delivery_address,
                'created_at': current_time,
                'updated_at': current_time,
                'estimated_delivery': (current_time + timedelta(days=3)).isoformat()
            }
            
            result = orders_collection.insert_one(order_doc)
            
            created_orders.append({
                'order_id': order_id,
                'section': section,
                'items_count': len(section_items),
                'total_amount': section_total,
                'status': 'pending'
            })
            
            logger.info(f"Created order {order_id} for section '{section}' (MongoDB ID: {result.inserted_id}) for user {user_phone}")
        
        print("="*80, flush=True)
        print("🎯 ALL ORDERS CREATED SUCCESSFULLY", flush=True)
        print(f"🎯 Total orders: {len(created_orders)}", flush=True)
        print("🎯 NOW ATTEMPTING FCM NOTIFICATION...", flush=True)
        print("="*80, flush=True)
        
        # 🏪 GET USER DETAILS (for both FCM and email)
        logger.info("🗄️ ORDER: Getting Supabase client for user details...")
        supabase = get_supabase_client()
        logger.info("✅ ORDER: Supabase client obtained")
        
        # Get store_name from users table (needed for both FCM and email)
        user_result = supabase.table("users").select("store_name").eq("phone", user_phone).execute()
        store_name = user_result.data[0].get("store_name") if user_result.data else None
        logger.info(f"✅ ORDER: Store name: {store_name or 'N/A'}")
        
        # 🔔 SEND PUSH NOTIFICATION TO USER (for all split orders combined)
        print("\n" + "*"*60, flush=True)
        print("🔔 ORDER: Starting FCM notification process...", flush=True)
        print(f"🔔 ORDER: User phone: {user_phone}", flush=True)
        print(f"🔔 ORDER: Store name: {store_name or 'N/A'}", flush=True)
        print(f"🔔 ORDER: Total amount: ₹{total_amount}", flush=True)
        print(f"🔔 ORDER: Number of split orders: {len(created_orders)}", flush=True)
        print("*"*60, flush=True)
        try:
            logger.info("\n" + "*"*60)
            logger.info("🔔 ORDER: Starting FCM notification process...")
            logger.info(f"🔔 ORDER: User phone: {user_phone}")
            logger.info(f"🔔 ORDER: Store name: {store_name or 'N/A'}")
            logger.info(f"🔔 ORDER: Total amount: ₹{total_amount}")
            logger.info(f"🔔 ORDER: Number of split orders: {len(created_orders)}")
            logger.info("*"*60)
            
            logger.info(f"🔍 ORDER: Querying ALL FCM tokens for phone: {user_phone}")
            # Query user_devices table for multi-device support (column is 'phone', not 'user_phone')
            devices_result = supabase.table("user_devices").select("fcm_token").eq("phone", user_phone).execute()
            logger.info(f"✅ ORDER: Query completed, found {len(devices_result.data) if devices_result.data else 0} device(s)")
            
            if devices_result.data:
                device_count = len(devices_result.data)
                logger.info(f"📱 ORDER: Found {device_count} device(s) for user {user_phone}")
                
                # Send notification to ALL devices
                # created_orders only has items_count, not the full items array
                total_items = sum(order['items_count'] for order in created_orders)
                logger.info(f"📊 ORDER: Total items across all orders: {total_items}")
                logger.info(f"📦 ORDER: First order ID: {created_orders[0]['order_id']}")
                
                successful_sends = 0
                failed_sends = 0
                
                for idx, device in enumerate(devices_result.data, 1):
                    fcm_token = device["fcm_token"]
                    logger.info(f"📤 ORDER: [{idx}/{device_count}] Sending to device: {fcm_token[:30]}...")
                    
                    notification_sent = await fcm_service.send_order_notification(
                        fcm_token=fcm_token,
                        order_id=created_orders[0]['order_id'],  # Use first order ID
                        total_amount=float(total_amount),  # Total across all orders
                        items_count=total_items,
                        store_name=store_name,
                        user_phone=user_phone
                    )
                    
                    if notification_sent:
                        successful_sends += 1
                        logger.info(f"✅ ORDER: [{idx}/{device_count}] Notification sent successfully!")
                    else:
                        failed_sends += 1
                        logger.error(f"❌ ORDER: [{idx}/{device_count}] Failed to send notification")
                
                logger.info(f"🎉 ORDER: Notification summary: {successful_sends} sent, {failed_sends} failed out of {device_count} device(s)")
                if successful_sends > 0:
                    logger.info(f"🎉 ORDER: At least one device received notification!")
            else:
                logger.warning(f"⚠️ ORDER: No devices found for user {user_phone}")
                logger.warning(f"⚠️ ORDER: User needs to login again to save FCM token")
            
            logger.info("*"*60 + "\n")
                
        except Exception as fcm_error:
            # Don't fail order creation if notification fails
            print(f"❌ ORDER: EXCEPTION during FCM: {fcm_error}", flush=True)
            print(f"❌ ORDER: Exception type: {type(fcm_error).__name__}", flush=True)
            import traceback
            print(f"❌ ORDER: Traceback: {traceback.format_exc()}", flush=True)
            print("*"*60 + "\n", flush=True)
            logger.error(f"❌ ORDER: Exception during FCM notification: {fcm_error}")
            logger.error(f"❌ ORDER: Exception type: {type(fcm_error).__name__}")
            logger.error(f"❌ ORDER: Traceback: {traceback.format_exc()}")
            logger.error("*"*60 + "\n")
        
        # 📧 SEND EMAIL NOTIFICATION TO ADMIN (IN BACKGROUND)
        # This runs after the response is sent to the user
        print("📧 EMAIL: Scheduling background task...", flush=True)
        logger.info("📧 EMAIL: Adding email notification to background tasks")
        
        background_tasks.add_task(
            send_order_email_background,
            order_id=created_orders[0]['order_id'],
            user_phone=user_phone,
            store_name=store_name,
            items=items,
            total_amount=total_amount,
            delivery_address=delivery_address,
            payment_method=payment_method
        )
        
        print("✅ EMAIL: Background task scheduled (will run after response)", flush=True)
        logger.info("✅ EMAIL: Background task scheduled")
        
        # Return response immediately (email will be sent in background)
        return {
            "success": True,
            "message": f"Created {len(created_orders)} order(s) - split by section",
            "orders": created_orders,
            "created_at": current_time.isoformat(),
            "total_orders": len(created_orders)
        }
    except HTTPException:
        raise
    except Exception as e:
        print("\n" + "❌"*40, flush=True)
        print(f"❌ CRITICAL ERROR IN ORDER CREATION", flush=True)
        print(f"❌ Error type: {type(e).__name__}", flush=True)
        print(f"❌ Error message: {str(e)}", flush=True)
        print("❌ Full traceback:", flush=True)
        print(traceback.format_exc(), flush=True)
        print("❌"*40 + "\n", flush=True)
        
        logger.error(f"❌ CRITICAL ERROR IN ORDER CREATION")
        logger.error(f"Error type: {type(e).__name__}")
        logger.error(f"Error message: {str(e)}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        
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

# Delete user profile (Admin only)
@router.delete("/profile/{phone}")
async def delete_user_profile(phone: str, request: Request):
    """
    Delete user profile and all associated data
    WARNING: This permanently deletes user data from MongoDB and Supabase
    """
    try:
        db = get_mongo_db()
        users_collection = db['users']
        orders_collection = db['orders']
        
        logger.info(f"🗑️ ADMIN: Attempting to delete user profile: {phone}")
        
        # Check if user exists
        user = users_collection.find_one({"phone": phone})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_name = user.get('name', 'Unknown')
        store_name = user.get('store_details', {}).get('store_name', 'Unknown')
        
        # Count orders to be deleted
        order_count = orders_collection.count_documents({"phone": phone})
        
        logger.info(f"📊 ADMIN: User {phone} has {order_count} orders")
        
        # Delete from MongoDB
        # 1. Delete all user's orders
        if order_count > 0:
            delete_orders_result = orders_collection.delete_many({"phone": phone})
            logger.info(f"✅ ADMIN: Deleted {delete_orders_result.deleted_count} orders")
        
        # 2. Delete user profile
        delete_user_result = users_collection.delete_one({"phone": phone})
        if delete_user_result.deleted_count > 0:
            logger.info(f"✅ ADMIN: Deleted user from MongoDB")
        
        # Delete from Supabase
        try:
            supabase = get_supabase_client()
            
            # Delete FCM tokens from user_devices
            try:
                devices_result = supabase.table("user_devices").delete().eq("user_phone", phone).execute()
                logger.info(f"✅ ADMIN: Deleted FCM tokens from Supabase")
            except Exception as e:
                logger.warning(f"⚠️ ADMIN: Failed to delete FCM tokens: {e}")
            
            # Delete from users table
            try:
                users_result = supabase.table("users").delete().eq("phone", phone).execute()
                logger.info(f"✅ ADMIN: Deleted user from Supabase")
            except Exception as e:
                logger.warning(f"⚠️ ADMIN: Failed to delete from Supabase users: {e}")
        except Exception as supabase_error:
            logger.warning(f"⚠️ ADMIN: Supabase deletion failed (non-critical): {supabase_error}")
        
        logger.info(f"🎉 ADMIN: Successfully deleted user {phone}")
        
        return {
            "success": True,
            "message": "User profile deleted successfully",
            "deleted": {
                "phone": phone,
                "name": user_name,
                "store_name": store_name,
                "orders_deleted": order_count
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ ADMIN: Error deleting user profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))
