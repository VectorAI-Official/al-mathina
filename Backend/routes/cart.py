"""
API endpoints for cart management.
Handles cart operations using Supabase PostgreSQL.
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, String, Float, DateTime, func
from datetime import datetime
import logging

from models import CartItemRequest, CartResponse, CartItemResponse, UpdateQuantityRequest
from database.supabase_client import get_db, Base
from database.mongodb_client import get_mongo_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/cart", tags=["Cart"])


# SQLAlchemy model for cart items in Supabase PostgreSQL
class CartItem(Base):
    __tablename__ = "cart_items"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    category = Column(String, nullable=False)
    brand = Column(String, nullable=False)
    quantity = Column(Integer, nullable=False)
    price = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


@router.get("/{user_id}", response_model=CartResponse)
async def get_cart(user_id: str, db: Session = Depends(get_db)):
    """Get user's cart contents."""
    try:
        cart_items = db.query(CartItem).filter(CartItem.user_id == user_id).all()
        
        items_response = []
        total_amount = 0.0
        total_items = 0
        
        for item in cart_items:
            subtotal = item.price * item.quantity
            total_amount += subtotal
            total_items += item.quantity
            
            items_response.append(CartItemResponse(
                id=item.id,
                user_id=item.user_id,
                category=item.category,
                brand=item.brand,
                quantity=item.quantity,
                price=item.price,
                subtotal=subtotal,
                created_at=item.created_at,
                updated_at=item.updated_at
            ))
        
        logger.info(f"Retrieved cart for user {user_id}: {total_items} items, ₹{total_amount:.2f}")
        
        return CartResponse(
            items=items_response,
            total_items=total_items,
            total_amount=total_amount
        )
        
    except Exception as e:
        logger.error(f"Error fetching cart: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch cart: {str(e)}")


@router.post("/add", response_model=CartItemResponse)
async def add_to_cart(request: CartItemRequest, db: Session = Depends(get_db)):
    """Add or update item in cart."""
    try:
        # Get product price from MongoDB
        mongo_db = get_mongo_db()
        product = mongo_db["products"].find_one({
            "category": request.category,
            "brand": request.brand,
            "active": True
        })
        
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        price = product.get("price", 100.0)
        
        # Check if item already exists in cart
        existing_item = db.query(CartItem).filter(
            CartItem.user_id == request.user_id,
            CartItem.category == request.category,
            CartItem.brand == request.brand
        ).first()
        
        if existing_item:
            # Update quantity
            existing_item.quantity += request.quantity
            existing_item.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(existing_item)
            item = existing_item
            logger.info(f"Updated cart item: {request.brand} (new quantity: {item.quantity})")
        else:
            # Create new cart item
            new_item = CartItem(
                user_id=request.user_id,
                category=request.category,
                brand=request.brand,
                quantity=request.quantity,
                price=price
            )
            db.add(new_item)
            db.commit()
            db.refresh(new_item)
            item = new_item
            logger.info(f"Added to cart: {request.brand} (quantity: {request.quantity})")
        
        return CartItemResponse(
            id=item.id,
            user_id=item.user_id,
            category=item.category,
            brand=item.brand,
            quantity=item.quantity,
            price=item.price,
            subtotal=item.price * item.quantity,
            created_at=item.created_at,
            updated_at=item.updated_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding to cart: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to add to cart: {str(e)}")


@router.put("/{cart_item_id}", response_model=CartItemResponse)
async def update_cart_quantity(
    cart_item_id: int,
    request: UpdateQuantityRequest,
    db: Session = Depends(get_db)
):
    """Update cart item quantity or remove if quantity is 0."""
    try:
        item = db.query(CartItem).filter(CartItem.id == cart_item_id).first()
        
        if not item:
            raise HTTPException(status_code=404, detail="Cart item not found")
        
        if request.quantity == 0:
            # Remove item from cart
            db.delete(item)
            db.commit()
            logger.info(f"Removed cart item {cart_item_id}")
            raise HTTPException(status_code=204, detail="Item removed from cart")
        
        # Update quantity
        item.quantity = request.quantity
        item.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(item)
        
        logger.info(f"Updated cart item {cart_item_id}: new quantity = {request.quantity}")
        
        return CartItemResponse(
            id=item.id,
            user_id=item.user_id,
            category=item.category,
            brand=item.brand,
            quantity=item.quantity,
            price=item.price,
            subtotal=item.price * item.quantity,
            created_at=item.created_at,
            updated_at=item.updated_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating cart: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update cart: {str(e)}")


@router.delete("/{user_id}/clear")
async def clear_cart(user_id: str, db: Session = Depends(get_db)):
    """Clear all items from user's cart."""
    try:
        deleted_count = db.query(CartItem).filter(CartItem.user_id == user_id).delete()
        db.commit()
        
        logger.info(f"Cleared cart for user {user_id}: {deleted_count} items removed")
        
        return {"message": f"Cart cleared successfully", "items_removed": deleted_count}
        
    except Exception as e:
        logger.error(f"Error clearing cart: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to clear cart: {str(e)}")
