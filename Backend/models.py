"""
Pydantic models for API request/response validation.
Defines data schemas for categories, products, cart, and orders.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ============================================
# Category Models (MongoDB)
# ============================================

class CategoryResponse(BaseModel):
    """Category information returned to the frontend."""
    name: str
    name_ta: str
    icon: str
    image_path: Optional[str] = None
    order: int
    active: bool
    
    class Config:
        from_attributes = True


class CategoryListResponse(BaseModel):
    """Response containing list of categories."""
    categories: List[CategoryResponse]
    count: int


# ============================================
# Product Models (MongoDB)
# ============================================

class ProductResponse(BaseModel):
    """
    Product information returned to the frontend.
    Uses nested categorization: section → main → sub
    """
    item_id: str = Field(..., description="Unique SKU/identifier (e.g., prod_sprite_001)")
    product_name: str = Field(..., description="Full display name (e.g., Sprite 600ml Bottle)")
    category_section: str = Field(..., description="Level 1: App section (e.g., Best Seller)")
    category_main: str = Field(..., description="Level 2: Main category (e.g., Drinks & Juices)")
    category_sub: str = Field(..., description="Level 3: Subcategory (e.g., Soft Drinks)")
    image_url: Optional[str] = Field(None, description="Public URL to product image")
    weight: str = Field(..., description="Product size/weight descriptor")
    price: float = Field(..., description="Wholesale price")
    stock: int = Field(..., description="Current inventory count")
    active: bool = Field(True, description="Product availability status")
    description: Optional[str] = None
    
    class Config:
        from_attributes = True


class ProductListResponse(BaseModel):
    """Response containing list of products."""
    products: List[ProductResponse]
    count: int
    category: Optional[str] = None


# ============================================
# Cart Models (Supabase PostgreSQL)
# ============================================

class CartItemRequest(BaseModel):
    """Request to add/update item in cart."""
    user_id: str
    item_id: str = Field(..., description="Product SKU identifier")
    quantity: int = Field(gt=0, description="Quantity must be greater than 0")


class CartItemResponse(BaseModel):
    """Cart item information."""
    id: Optional[int] = None
    user_id: str
    item_id: str
    product_name: str
    category_section: str
    category_main: str
    category_sub: str
    quantity: int
    price: float
    subtotal: float
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CartResponse(BaseModel):
    """Complete cart information."""
    items: List[CartItemResponse]
    total_items: int
    total_amount: float


class UpdateQuantityRequest(BaseModel):
    """Request to update cart item quantity."""
    quantity: int = Field(ge=0, description="Quantity must be 0 or greater (0 removes item)")


# ============================================
# Order Models (Supabase PostgreSQL)
# ============================================

class OrderItemRequest(BaseModel):
    """Individual item in an order."""
    category: str
    brand: str
    quantity: int
    price: float


class CreateOrderRequest(BaseModel):
    """Request to create a new order."""
    user_id: str
    items: List[OrderItemRequest]
    payment_method: str = Field(..., description="UPI/Apps or COD")
    total_amount: float


class OrderItemResponse(BaseModel):
    """Order item information."""
    category: str
    brand: str
    quantity: int
    price: float
    subtotal: float


class OrderResponse(BaseModel):
    """Order information returned to frontend."""
    id: int
    user_id: str
    order_number: str
    items: List[OrderItemResponse]
    total_amount: float
    payment_method: str
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class OrderListResponse(BaseModel):
    """Response containing list of orders."""
    orders: List[OrderResponse]
    count: int


# ============================================
# Health Check Models
# ============================================

class DatabaseStatus(BaseModel):
    """Database connection status."""
    name: str
    connected: bool
    message: Optional[str] = None


class HealthCheckResponse(BaseModel):
    """Health check response."""
    status: str
    databases: List[DatabaseStatus]
    timestamp: datetime
