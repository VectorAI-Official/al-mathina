"""
Admin dashboard routes for product catalog management.
Provides CRUD operations for MongoDB products with image upload to Supabase Storage.
"""
from fastapi import APIRouter, HTTPException, Depends, Request, Response, Form, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from typing import Optional, List
from datetime import datetime
import logging
import os

from admin_auth import (
    verify_credentials, create_session, delete_session,
    get_current_session, require_admin
)
from database.mongodb_client import get_mongo_db
from database.supabase_client import supabase_client
from models import ProductResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin Dashboard"])

# Setup Jinja2 templates
templates = Jinja2Templates(directory="templates")

# Supabase Storage bucket name for product images
STORAGE_BUCKET = "product-images"


# ============================================
# Authentication Routes
# ============================================

@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    """Display admin login page."""
    return templates.TemplateResponse("admin_login.html", {"request": request})


@router.post("/login")
async def login(
    response: Response,
    username: str = Form(...),
    password: str = Form(...)
):
    """
    Authenticate admin user and create session.
    Credentials: admin / admin123
    """
    if not verify_credentials(username, password):
        raise HTTPException(
            status_code=401,
            detail="Invalid username or password"
        )
    
    # Create session token
    session_token = create_session(username)
    
    # Set session cookie and redirect to dashboard
    response = RedirectResponse(url="/admin/dashboard", status_code=303)
    response.set_cookie(
        key="admin_session",
        value=session_token,
        httponly=True,
        max_age=28800,  # 8 hours
        samesite="lax"
    )
    
    logger.info(f"Admin logged in: {username}")
    return response


@router.post("/logout")
async def logout(request: Request, response: Response):
    """Logout admin user and delete session."""
    session_token = request.cookies.get("admin_session")
    
    if session_token:
        delete_session(session_token)
    
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie("admin_session")
    
    logger.info("Admin logged out")
    return response


# ============================================
# Dashboard Views
# ============================================

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    """
    Main admin dashboard page.
    Displays product catalog with search and CRUD operations.
    """
    try:
        # Check authentication
        session = require_admin(request)
        
        return templates.TemplateResponse(
            "admin_dashboard.html",
            {
                "request": request,
                "username": session.get("username")
            }
        )
    except HTTPException:
        return RedirectResponse(url="/admin/login")


# ============================================
# Product CRUD API Routes
# ============================================

@router.get("/api/products/all")
async def get_all_products(
    session: dict = Depends(get_current_session),
    search: Optional[str] = None,
    category: Optional[str] = None
):
    """
    Get all products from MongoDB catalog.
    Supports search and category filtering.
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query
        query = {}
        if search:
            query["$or"] = [
                {"name": {"$regex": search, "$options": "i"}},
                {"brand": {"$regex": search, "$options": "i"}},
                {"category": {"$regex": search, "$options": "i"}}
            ]
        if category:
            query["category"] = category
        
        # Fetch products
        products_cursor = products_collection.find(query)
        products = []
        
        for prod in products_cursor:
            products.append({
                "id": str(prod["_id"]),
                "category": prod["category"],
                "brand": prod["brand"],
                "name": prod["name"],
                "image_path": prod.get("image_path"),
                "image_url": prod.get("image_url"),  # Supabase Storage URL
                "weight": prod.get("weight", ""),
                "price": prod.get("price", 0.0),
                "stock": prod.get("stock", 0),
                "active": prod.get("active", True),
                "description": prod.get("description", "")
            })
        
        logger.info(f"Admin fetched {len(products)} products")
        
        return {
            "success": True,
            "products": products,
            "count": len(products)
        }
        
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/products/add")
async def add_product(
    session: dict = Depends(get_current_session),
    category: str = Form(...),
    brand: str = Form(...),
    name: str = Form(...),
    weight: str = Form(...),
    price: float = Form(...),
    buying_price: float = Form(...),
    stock: int = Form(...),
    description: str = Form(""),
    active: bool = Form(True)
):
    """
    Create a new product in MongoDB catalog.
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Check if product already exists
        existing = products_collection.find_one({
            "category": category,
            "brand": brand
        })
        
        if existing:
            raise HTTPException(
                status_code=400,
                detail=f"Product already exists: {category} - {brand}"
            )
        
        # Create new product
        new_product = {
            "category": category,
            "brand": brand,
            "name": name,
            "image_path": f"assets/brands/{brand.lower().replace(' ', '_')}.png",
            "weight": weight,
            "price": price,
            "buying_price": buying_price,
            "stock": stock,
            "active": active,
            "description": description,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        }
        
        result = products_collection.insert_one(new_product)
        
        logger.info(f"Product created: {name} (ID: {result.inserted_id})")
        
        return {
            "success": True,
            "message": "Product created successfully",
            "product_id": str(result.inserted_id)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/api/products/{product_id}")
async def update_product(
    product_id: str,
    session: dict = Depends(get_current_session),
    category: Optional[str] = Form(None),
    brand: Optional[str] = Form(None),
    name: Optional[str] = Form(None),
    weight: Optional[str] = Form(None),
    price: Optional[float] = Form(None),
    buying_price: Optional[float] = Form(None),
    stock: Optional[int] = Form(None),
    description: Optional[str] = Form(None),
    active: Optional[bool] = Form(None)
):
    """
    Update an existing product in MongoDB.
    Only provided fields will be updated.
    """
    try:
        from bson import ObjectId
        
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build update document
        update_fields = {"updated_at": datetime.now()}
        
        if category is not None:
            update_fields["category"] = category
        if brand is not None:
            update_fields["brand"] = brand
        if name is not None:
            update_fields["name"] = name
        if weight is not None:
            update_fields["weight"] = weight
        if price is not None:
            update_fields["price"] = price
        if buying_price is not None:
            update_fields["buying_price"] = buying_price
        if stock is not None:
            update_fields["stock"] = stock
        if description is not None:
            update_fields["description"] = description
        if active is not None:
            update_fields["active"] = active
        
        # Update product
        result = products_collection.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": update_fields}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"Product updated: {product_id}")
        
        return {
            "success": True,
            "message": "Product updated successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/api/products/{product_id}")
async def delete_product(
    product_id: str,
    session: dict = Depends(get_current_session)
):
    """
    Delete a product from MongoDB catalog.
    """
    try:
        from bson import ObjectId
        
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Delete product
        result = products_collection.delete_one({"_id": ObjectId(product_id)})
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"Product deleted: {product_id}")
        
        return {
            "success": True,
            "message": "Product deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# Image Upload to Supabase Storage
# ============================================

@router.post("/api/upload/image/{product_id}")
async def upload_product_image(
    product_id: str,
    session: dict = Depends(get_current_session),
    image: UploadFile = File(...)
):
    """
    Upload product image to Supabase Storage.
    Updates MongoDB product document with public image URL.
    """
    try:
        from bson import ObjectId
        
        # Validate file type
        allowed_extensions = ["jpg", "jpeg", "png", "webp"]
        file_extension = image.filename.split(".")[-1].lower()
        
        if file_extension not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
            )
        
        # Read file content
        file_content = await image.read()
        
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"product_{product_id}_{timestamp}.{file_extension}"
        file_path = f"products/{filename}"
        
        # Upload to Supabase Storage
        try:
            # Create bucket if it doesn't exist
            try:
                supabase_client.storage.create_bucket(STORAGE_BUCKET)
                logger.info(f"Created storage bucket: {STORAGE_BUCKET}")
            except Exception:
                pass  # Bucket already exists
            
            # Upload file
            result = supabase_client.storage.from_(STORAGE_BUCKET).upload(
                file_path,
                file_content,
                {"content-type": image.content_type}
            )
            
            # Get public URL
            public_url = supabase_client.storage.from_(STORAGE_BUCKET).get_public_url(file_path)
            
            logger.info(f"Image uploaded to Supabase Storage: {file_path}")
            
        except Exception as storage_error:
            logger.error(f"Supabase Storage error: {storage_error}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to upload to storage: {str(storage_error)}"
            )
        
        # Update MongoDB product document with image URL
        db = get_mongo_db()
        products_collection = db["products"]
        
        result = products_collection.update_one(
            {"_id": ObjectId(product_id)},
            {
                "$set": {
                    "image_url": public_url,
                    "updated_at": datetime.now()
                }
            }
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"Product image URL updated in MongoDB: {product_id}")
        
        return {
            "success": True,
            "message": "Image uploaded successfully",
            "image_url": public_url
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading image: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# Category Management
# ============================================

@router.get("/api/categories/all")
async def get_all_categories(session: dict = Depends(get_current_session)):
    """Get all categories for dropdown filters."""
    try:
        db = get_mongo_db()
        categories_collection = db["categories"]
        
        categories = list(categories_collection.find({}, {"name": 1, "_id": 0}).sort("order", 1))
        
        return {
            "success": True,
            "categories": [cat["name"] for cat in categories]
        }
        
    except Exception as e:
        logger.error(f"Error fetching categories: {e}")
        raise HTTPException(status_code=500, detail=str(e))
