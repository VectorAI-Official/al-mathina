"""
API endpoints for order management.
Handles order creation and history using Supabase PostgreSQL.
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from datetime import datetime
from typing import List
import json
import logging

from models import CreateOrderRequest, OrderResponse, OrderListResponse, OrderItemResponse
from database.supabase_client import get_db, Base
from routes.cart import CartItem

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/orders", tags=["Orders"])


# SQLAlchemy model for orders in Supabase PostgreSQL
class Order(Base):
    __tablename__ = "orders"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    order_number = Column(String, unique=True, nullable=False, index=True)
    items_json = Column(Text, nullable=False)  # JSON string of order items
    total_amount = Column(Float, nullable=False)
    payment_method = Column(String, nullable=False)
    status = Column(String, default="pending", nullable=False)  # pending, confirmed, delivered, cancelled
    created_at = Column(DateTime, default=datetime.utcnow)


@router.post("/create", response_model=OrderResponse)
async def create_order(request: CreateOrderRequest, db: Session = Depends(get_db)):
    """
    Create a new order and clear the cart.
    """
    try:
        # Generate order number
        order_count = db.query(Order).count() + 1
        order_number = f"ORD{datetime.now().strftime('%Y%m%d')}{order_count:04d}"
        
        # Prepare order items
        order_items = []
        for item in request.items:
            order_items.append({
                "category": item.category,
                "brand": item.brand,
                "quantity": item.quantity,
                "price": item.price,
                "subtotal": item.price * item.quantity
            })
        
        # Create order
        new_order = Order(
            user_id=request.user_id,
            order_number=order_number,
            items_json=json.dumps(order_items),
            total_amount=request.total_amount,
            payment_method=request.payment_method,
            status="confirmed" if request.payment_method == "COD" else "pending"
        )
        
        db.add(new_order)
        
        # Clear user's cart
        db.query(CartItem).filter(CartItem.user_id == request.user_id).delete()
        
        db.commit()
        db.refresh(new_order)
        
        logger.info(f"Order created: {order_number} for user {request.user_id}, ₹{request.total_amount:.2f}")
        
        # Parse items for response
        items_response = []
        for item_data in json.loads(new_order.items_json):
            items_response.append(OrderItemResponse(**item_data))
        
        return OrderResponse(
            id=new_order.id,
            user_id=new_order.user_id,
            order_number=new_order.order_number,
            items=items_response,
            total_amount=new_order.total_amount,
            payment_method=new_order.payment_method,
            status=new_order.status,
            created_at=new_order.created_at
        )
        
    except Exception as e:
        logger.error(f"Error creating order: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create order: {str(e)}")


@router.get("/user/{user_id}", response_model=OrderListResponse)
async def get_user_orders(user_id: str, db: Session = Depends(get_db)):
    """
    Get all orders for a specific user.
    """
    try:
        orders = db.query(Order).filter(Order.user_id == user_id).order_by(Order.created_at.desc()).all()
        
        orders_response = []
        for order in orders:
            items_response = []
            for item_data in json.loads(order.items_json):
                items_response.append(OrderItemResponse(**item_data))
            
            orders_response.append(OrderResponse(
                id=order.id,
                user_id=order.user_id,
                order_number=order.order_number,
                items=items_response,
                total_amount=order.total_amount,
                payment_method=order.payment_method,
                status=order.status,
                created_at=order.created_at
            ))
        
        logger.info(f"Retrieved {len(orders_response)} orders for user {user_id}")
        
        return OrderListResponse(
            orders=orders_response,
            count=len(orders_response)
        )
        
    except Exception as e:
        logger.error(f"Error fetching orders: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch orders: {str(e)}")


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: int, db: Session = Depends(get_db)):
    """
    Get a specific order by ID.
    """
    try:
        order = db.query(Order).filter(Order.id == order_id).first()
        
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        items_response = []
        for item_data in json.loads(order.items_json):
            items_response.append(OrderItemResponse(**item_data))
        
        return OrderResponse(
            id=order.id,
            user_id=order.user_id,
            order_number=order.order_number,
            items=items_response,
            total_amount=order.total_amount,
            payment_method=order.payment_method,
            status=order.status,
            created_at=order.created_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching order: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch order: {str(e)}")
