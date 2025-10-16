"""
Admin dashboard routes for product catalog management (Local MongoDB Only).
Provides CRUD operations for MongoDB products with local file storage.
"""
from fastapi import APIRouter, HTTPException, Depends, Request, Response, Form, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from typing import Optional, List
from datetime import datetime
import logging
import os
import uuid
from bson import ObjectId

from admin_auth import (
    verify_credentials, create_session, delete_session,
    get_current_session, require_admin
)
from database.mongodb_client import get_mongo_db
from database.category_hierarchy import (
    get_all_sections, get_main_categories_for_section,
    get_subcategories_for_main, add_new_section,
    add_main_category_to_section, add_subcategory,
    get_full_hierarchy
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin Dashboard"])

# Setup Jinja2 templates
templates_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates")
templates = Jinja2Templates(directory=templates_dir)

# Local image storage directory
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


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
    if verify_credentials(username, password):
        session_id = create_session(username)
        redirect_response = RedirectResponse(url="/admin/dashboard", status_code=302)
        redirect_response.set_cookie(
            key="admin_session",
            value=session_id,
            httponly=True,
            max_age=86400,  # 24 hours
            samesite="lax"
        )
        return redirect_response
    else:
        # Return to login with error
        return templates.TemplateResponse(
            "admin_login.html",
            {"request": Request, "error": "Invalid username or password"}
        )


@router.post("/logout")
async def logout(session_id: str = Depends(get_current_session)):
    """Logout admin user and destroy session."""
    delete_session(session_id)
    redirect_response = RedirectResponse(url="/admin/login", status_code=302)
    redirect_response.delete_cookie("admin_session")
    return redirect_response


# ============================================
# Dashboard View
# ============================================

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request, session: dict = Depends(require_admin)):
    """Display admin dashboard with products table."""
    return templates.TemplateResponse(
        "admin_dashboard.html",
        {"request": request, "username": session.get("username", "Admin")}
    )


# ============================================
# Product Management API
# ============================================

@router.get("/api/products/all")
async def get_all_products(session: dict = Depends(require_admin)):
    """Get all products from MongoDB."""
    try:
        db = get_mongo_db()
        products = list(db.products.find())
        
        # Convert ObjectId to string
        for product in products:
            product["_id"] = str(product["_id"])
        
        return {"products": products}
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch products")


@router.get("/api/categories/all")
async def get_all_categories(session: dict = Depends(require_admin)):
    """Get hierarchical category structure from MongoDB."""
    try:
        # Get full hierarchy from category_hierarchy collection
        hierarchy = get_full_hierarchy()
        
        return {
            "hierarchy": hierarchy
        }
    except Exception as e:
        logger.error(f"Error fetching categories: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch categories")


@router.get("/api/categories/sections")
async def get_sections(session: dict = Depends(require_admin)):
    """Get all sections."""
    try:
        sections = get_all_sections()
        return {"sections": sections}
    except Exception as e:
        logger.error(f"Error fetching sections: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch sections")


@router.get("/api/categories/main/{section}")
async def get_main_for_section(section: str, session: dict = Depends(require_admin)):
    """Get main categories for a specific section."""
    try:
        main_categories = get_main_categories_for_section(section)
        return {"main_categories": main_categories}
    except Exception as e:
        logger.error(f"Error fetching main categories: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch main categories")


@router.get("/api/categories/sub/{section}/{main_category}")
async def get_sub_for_main(section: str, main_category: str, session: dict = Depends(require_admin)):
    """Get subcategories for a specific section and main category."""
    try:
        subcategories = get_subcategories_for_main(section, main_category)
        return {"subcategories": subcategories}
    except Exception as e:
        logger.error(f"Error fetching subcategories: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch subcategories")


@router.post("/api/categories/section")
async def create_section(request: Request, session: dict = Depends(require_admin)):
    """Create a new section."""
    try:
        data = await request.json()
        section = data.get("section")
        
        if not section:
            raise HTTPException(status_code=400, detail="Section name is required")
        
        success = add_new_section(section)
        if success:
            return {"message": f"Section '{section}' created successfully"}
        else:
            raise HTTPException(status_code=400, detail="Failed to create section")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating section: {e}")
        raise HTTPException(status_code=500, detail="Failed to create section")


@router.post("/api/categories/main")
async def create_main_category(request: Request, session: dict = Depends(require_admin)):
    """Create a new main category under a section."""
    try:
        data = await request.json()
        section = data.get("section")
        main_category = data.get("main_category")
        image_url = data.get("image_url")
        
        if not section or not main_category:
            raise HTTPException(status_code=400, detail="Section and main category are required")
        
        db = get_mongo_db()
        
        # Add main category to hierarchy
        success = add_main_category_to_section(section, main_category)
        if not success:
            raise HTTPException(status_code=400, detail="Failed to create main category")
        
        # Save image metadata if provided
        if image_url:
            db.category_metadata.update_one(
                {"name": main_category, "type": "main_category"},
                {
                    "$set": {
                        "name": main_category,
                        "type": "main_category",
                        "section": section,
                        "image_url": image_url
                    }
                },
                upsert=True
            )
        
        return {"message": f"Main category '{main_category}' created successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating main category: {e}")
        raise HTTPException(status_code=500, detail="Failed to create main category")


@router.post("/api/categories/sub")
async def create_subcategory(request: Request, session: dict = Depends(require_admin)):
    """Create a new subcategory under a main category with optional image."""
    try:
        data = await request.json()
        section = data.get("section")
        main_category = data.get("main_category")
        subcategory = data.get("subcategory")
        image_url = data.get("image_url")  # NEW: Get image URL
        
        if not section or not main_category or not subcategory:
            raise HTTPException(status_code=400, detail="Section, main category, and subcategory are required")
        
        # Add subcategory to hierarchy
        success = add_subcategory(section, main_category, subcategory)
        if success:
            # Save image metadata if provided (NEW)
            if image_url:
                db = get_mongo_db()
                db.category_metadata.update_one(
                    {"name": subcategory, "type": "subcategory"},
                    {"$set": {
                        "name": subcategory,
                        "type": "subcategory",
                        "section": section,
                        "main_category": main_category,
                        "image_url": image_url
                    }},
                    upsert=True
                )
            return {"message": f"Subcategory '{subcategory}' created successfully"}
        else:
            raise HTTPException(status_code=400, detail="Failed to create subcategory")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating subcategory: {e}")
        raise HTTPException(status_code=500, detail="Failed to create subcategory")


@router.put("/api/categories/section/{section_name}")
async def update_section_name(
    section_name: str,
    request: Request,
    session: dict = Depends(require_admin)
):
    """Update a section's name and/or image."""
    try:
        data = await request.json()
        new_name = data.get("new_name")
        image_url = data.get("image_url")
        
        # At least one field should be provided (even if empty string, we check later)
        if new_name is None and image_url is None:
            raise HTTPException(status_code=400, detail="No update data provided")
        
        db = get_mongo_db()
        
        # Update section name in category_hierarchy
        if new_name and new_name != section_name:
            result = db.category_hierarchy.update_one(
                {"section": section_name},
                {"$set": {"section": new_name}}
            )
            if result.modified_count == 0:
                raise HTTPException(status_code=404, detail="Section not found")
            
            # Update all products with this section
            db.products.update_many(
                {"category_section": section_name},
                {"$set": {"category_section": new_name}}
            )
        
        # Store image URL in a separate metadata collection
        if image_url:
            db.category_metadata.update_one(
                {"section": new_name if new_name else section_name, "type": "section"},
                {"$set": {"image_url": image_url, "section": new_name if new_name else section_name, "type": "section"}},
                upsert=True
            )
        
        return {"message": "Section updated successfully", "new_name": new_name if new_name else section_name}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating section: {e}")
        raise HTTPException(status_code=500, detail="Failed to update section")


@router.put("/api/categories/main/{main_category_name}")
async def update_main_category(
    main_category_name: str,
    request: Request,
    session: dict = Depends(require_admin)
):
    """Update a main category's name and/or image."""
    try:
        data = await request.json()
        new_name = data.get("new_name")
        image_url = data.get("image_url")
        section = data.get("section")  # Required to locate the category
        
        if not section:
            raise HTTPException(status_code=400, detail="Section name is required")
        
        # At least one update field should be provided
        if new_name is None and image_url is None:
            raise HTTPException(status_code=400, detail="No update data provided")
        
        db = get_mongo_db()
        
        # Update main category name in category_hierarchy
        if new_name and new_name != main_category_name:
            # Find the section document
            section_doc = db.category_hierarchy.find_one({"section": section})
            if not section_doc:
                raise HTTPException(status_code=404, detail="Section not found")
            
            # Check if main category exists
            main_categories = section_doc.get("main_categories", {})
            if main_category_name not in main_categories:
                raise HTTPException(status_code=404, detail="Main category not found")
            
            # Rename the main category key
            subcategories = main_categories[main_category_name]
            db.category_hierarchy.update_one(
                {"section": section},
                {
                    "$unset": {f"main_categories.{main_category_name}": ""},
                    "$set": {f"main_categories.{new_name}": subcategories}
                }
            )
            
            # Update all products with this main category
            db.products.update_many(
                {"category_section": section, "category_main": main_category_name},
                {"$set": {"category_main": new_name}}
            )
            
            # Update metadata if exists
            db.category_metadata.update_one(
                {"name": main_category_name, "type": "main_category"},
                {"$set": {"name": new_name}}
            )
        
        # Store/update image URL in category_metadata
        if image_url is not None:  # Allow empty string to remove image
            category_name = new_name if new_name else main_category_name
            db.category_metadata.update_one(
                {"name": category_name, "type": "main_category"},
                {
                    "$set": {
                        "name": category_name,
                        "type": "main_category",
                        "section": section,
                        "image_url": image_url if image_url else None
                    }
                },
                upsert=True
            )
        
        return {
            "message": "Main category updated successfully",
            "new_name": new_name if new_name else main_category_name
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating main category: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update main category: {str(e)}")


@router.put("/api/categories/sub/{subcategory_name}")
async def update_subcategory(
    subcategory_name: str,
    request: Request,
    session: dict = Depends(require_admin)
):
    """Update subcategory name and/or image."""
    try:
        data = await request.json()
        new_name = data.get("new_name")
        image_url = data.get("image_url")
        section = data.get("section")  # Required to locate the subcategory
        main_category = data.get("main_category")  # Required to locate the subcategory
        
        if not section or not main_category:
            raise HTTPException(status_code=400, detail="Section and main_category are required")
        
        db = get_mongo_db()
        
        # Rename subcategory in hierarchy if new name provided
        if new_name and new_name != subcategory_name:
            # Get current subcategories array
            section_doc = db.category_hierarchy.find_one({"section": section})
            if not section_doc or main_category not in section_doc.get("main_categories", {}):
                raise HTTPException(status_code=404, detail="Section or main category not found")
            
            subcategories = section_doc["main_categories"][main_category]
            
            # Check if old subcategory exists
            if subcategory_name not in subcategories:
                raise HTTPException(status_code=404, detail="Subcategory not found")
            
            # Replace old name with new name in array
            updated_subcategories = [new_name if sub == subcategory_name else sub for sub in subcategories]
            
            # Update the array in database
            db.category_hierarchy.update_one(
                {"section": section},
                {"$set": {f"main_categories.{main_category}": updated_subcategories}}
            )
            
            # Update all products with this subcategory
            db.products.update_many(
                {
                    "category_section": section,
                    "category_main": main_category,
                    "category_sub": subcategory_name
                },
                {"$set": {"category_sub": new_name}}
            )
            
            # Update metadata if exists
            db.category_metadata.update_one(
                {"name": subcategory_name, "type": "subcategory"},
                {"$set": {"name": new_name}}
            )
        
        # Store/update image URL in category_metadata
        if image_url is not None:  # Allow empty string to remove image
            category_name = new_name if new_name else subcategory_name
            db.category_metadata.update_one(
                {"name": category_name, "type": "subcategory"},
                {
                    "$set": {
                        "name": category_name,
                        "type": "subcategory",
                        "section": section,
                        "main_category": main_category,
                        "image_url": image_url if image_url else None
                    }
                },
                upsert=True
            )
        
        return {
            "message": "Subcategory updated successfully",
            "new_name": new_name if new_name else subcategory_name
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating subcategory: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update subcategory: {str(e)}")


@router.delete("/api/categories/section/{section_name}")
async def delete_section(
    section_name: str,
    session: dict = Depends(require_admin)
):
    """Delete a section and all its categories."""
    try:
        db = get_mongo_db()
        
        # Delete from category_hierarchy
        result = db.category_hierarchy.delete_one({"section": section_name})
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Section not found")
        
        # Delete from category_metadata
        db.category_metadata.delete_many({"section": section_name})
        
        # Note: Products with this section will remain but won't show in categories
        # Optionally, you could also delete or reassign products here
        
        return {"message": f"Section '{section_name}' deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting section: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete section")


@router.delete("/api/categories/main/{section_name}/{main_category}")
async def delete_main_category(
    section_name: str,
    main_category: str,
    session: dict = Depends(require_admin)
):
    """Delete a main category and all its subcategories."""
    try:
        db = get_mongo_db()
        
        # Remove main category from category_hierarchy
        result = db.category_hierarchy.update_one(
            {"section": section_name},
            {"$unset": {f"main_categories.{main_category}": ""}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Section or main category not found")
        
        # Delete from category_metadata
        db.category_metadata.delete_many({"category": main_category})
        
        return {"message": f"Main category '{main_category}' deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting main category: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete main category")


@router.delete("/api/categories/sub/{section_name}/{main_category}/{subcategory}")
async def delete_subcategory(
    section_name: str,
    main_category: str,
    subcategory: str,
    session: dict = Depends(require_admin)
):
    """Delete a subcategory."""
    try:
        db = get_mongo_db()
        
        # Remove subcategory from the main category's array
        result = db.category_hierarchy.update_one(
            {"section": section_name},
            {"$pull": {f"main_categories.{main_category}": subcategory}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Section, main category, or subcategory not found")
        
        # Delete from category_metadata
        db.category_metadata.delete_many({"category": subcategory})
        
        return {"message": f"Subcategory '{subcategory}' deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting subcategory: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete subcategory")


@router.get("/api/categories/metadata")
async def get_category_metadata(session: dict = Depends(require_admin)):
    """Get all category metadata including images."""
    try:
        db = get_mongo_db()
        metadata = list(db.category_metadata.find({}, {"_id": 0}))
        return {"metadata": metadata}
    except Exception as e:
        logger.error(f"Error fetching category metadata: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch category metadata")


@router.post("/api/upload-image")
async def upload_category_image(
    file: UploadFile = File(...),
    session: dict = Depends(require_admin)
):
    """
    Upload category image to local storage.
    Saves to static/uploads directory.
    """
    try:
        # Validate file type
        allowed_types = ["image/jpeg", "image/jpg", "image/png", "image/webp"]
        if file.content_type not in allowed_types:
            raise HTTPException(status_code=400, detail="Invalid file type. Only JPG, PNG, WebP allowed.")
        
        # Validate file size (max 2MB)
        content = await file.read()
        if len(content) > 2 * 1024 * 1024:  # 2MB
            raise HTTPException(status_code=400, detail="File size exceeds 2MB limit.")
        
        # Generate unique filename
        file_extension = file.filename.split(".")[-1]
        unique_filename = f"category_{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join(UPLOAD_DIR, unique_filename)
        
        # Save file locally
        with open(file_path, "wb") as f:
            f.write(content)
        
        # Generate public URL (relative to static directory)
        image_url = f"/static/uploads/{unique_filename}"
        
        logger.info(f"Category image uploaded: {unique_filename}")
        
        return {
            "message": "Image uploaded successfully",
            "url": image_url
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading category image: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload image")


@router.get("/api/generate-item-id")
async def generate_item_id(session: dict = Depends(require_admin)):
    """Generate a unique item ID for a new product."""
    try:
        db = get_mongo_db()
        
        # Count existing products to generate sequential ID
        count = db.products.count_documents({})
        item_id = f"prod_{count + 1:05d}"
        
        # Ensure uniqueness
        while db.products.find_one({"item_id": item_id}):
            count += 1
            item_id = f"prod_{count + 1:05d}"
        
        return {"item_id": item_id}
    except Exception as e:
        logger.error(f"Error generating item ID: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate item ID")


@router.post("/api/products/add")
async def add_product(request: Request, session: dict = Depends(require_admin)):
    """Add a new product to MongoDB."""
    try:
        db = get_mongo_db()
        data = await request.json()
        
        # Log received data for debugging
        logger.info(f"=== ADDING NEW PRODUCT ===")
        logger.info(f"Received data: {data}")
        logger.info(f"User: {session.get('username', 'admin')}")
        
        # ⚠️ VALIDATION: Product image is mandatory for new products
        # Note: Image will be uploaded after product creation, so we just need to ensure
        # the frontend sends the request. The actual image validation happens on frontend.
        # This is a backup validation in case frontend validation is bypassed.
        
        # Add metadata
        data["created_at"] = datetime.utcnow()
        data["updated_at"] = datetime.utcnow()
        data["created_by"] = session.get("username", "admin")
        
        # Set default image if not provided (use empty string instead of external placeholder)
        if "image_url" not in data or not data["image_url"]:
            data["image_url"] = ""
        
        # Remove legacy fields to avoid duplicate key errors from old index
        # These fields are deprecated in favor of category_section, category_main, category_sub
        data.pop("category", None)
        data.pop("brand", None)
        
        logger.info(f"Inserting product into MongoDB...")
        logger.info(f"Section: {data.get('category_section')}, Main: {data.get('category_main')}, Sub: {data.get('category_sub')}")
        
        # Insert into MongoDB
        result = db.products.insert_one(data)
        
        logger.info(f"Product inserted with ID: {result.inserted_id}")
        
        # Get the inserted product
        product = db.products.find_one({"_id": result.inserted_id})
        product["_id"] = str(product["_id"])
        
        logger.info(f"Product created successfully: {product.get('item_id')} by {session.get('username')}")
        return {"message": "Product added successfully", "product": product}
    except Exception as e:
        logger.error(f"=== ERROR ADDING PRODUCT ===")
        logger.error(f"Exception Type: {type(e).__name__}")
        logger.error(f"Exception Message: {str(e)}")
        logger.error(f"Traceback:", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to add product: {str(e)}")


@router.put("/api/products/{product_id}")
async def update_product(
    product_id: str,
    request: Request,
    session: dict = Depends(require_admin)
):
    """Update an existing product in MongoDB."""
    try:
        db = get_mongo_db()
        data = await request.json()
        
        # Add update metadata
        data["updated_at"] = datetime.utcnow()
        data["updated_by"] = session.get("username", "admin")
        
        # Remove item_id if it's in the data (prevent modification)
        if "item_id" in data:
            logger.warning(f"Attempt to modify item_id blocked for product {product_id}")
            del data["item_id"]
        
        # Update in MongoDB
        result = db.products.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": data}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Get updated product
        product = db.products.find_one({"_id": ObjectId(product_id)})
        product["_id"] = str(product["_id"])
        
        logger.info(f"Product updated: {product.get('item_id')} by {session.get('username')}")
        return {"message": "Product updated successfully", "product": product}
    except Exception as e:
        logger.error(f"Error updating product: {e}")
        raise HTTPException(status_code=500, detail="Failed to update product")


@router.put("/api/products/{product_id}/best-seller")
async def toggle_best_seller(
    product_id: str,
    request: Request,
    session: dict = Depends(require_admin)
):
    """Toggle Best Seller status for a product."""
    try:
        db = get_mongo_db()
        data = await request.json()
        is_best_seller = data.get("is_best_seller", False)
        
        logger.info(f"=== TOGGLING BEST SELLER ===")
        logger.info(f"Product ID: {product_id}")
        logger.info(f"New Status: {is_best_seller}")
        logger.info(f"Updated by: {session.get('username')}")
        
        # Update best seller status
        result = db.products.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": {
                "is_best_seller": is_best_seller,
                "updated_at": datetime.utcnow(),
                "updated_by": session.get("username", "admin")
            }}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Get updated product
        product = db.products.find_one({"_id": ObjectId(product_id)})
        product["_id"] = str(product["_id"])
        
        logger.info(f"Best Seller status updated: {product.get('product_name')} - {is_best_seller}")
        return {
            "message": "Best Seller status updated successfully",
            "product": product,
            "is_best_seller": is_best_seller
        }
    except Exception as e:
        logger.error(f"Error toggling best seller: {e}")
        raise HTTPException(status_code=500, detail="Failed to update Best Seller status")


@router.delete("/api/products/{product_id}")
async def delete_product(product_id: str, session: dict = Depends(require_admin)):
    """Delete a product from MongoDB."""
    try:
        db = get_mongo_db()
        
        # Delete from MongoDB
        result = db.products.delete_one({"_id": ObjectId(product_id)})
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        return {"message": "Product deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting product: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete product")


@router.post("/api/upload/image/{product_id}")
async def upload_product_image(
    product_id: str,
    file: UploadFile = File(...),
    session: dict = Depends(require_admin)
):
    """
    Upload product image to local storage.
    Saves to static/uploads directory.
    """
    try:
        # Validate file type
        allowed_types = ["image/jpeg", "image/jpg", "image/png", "image/webp"]
        if file.content_type not in allowed_types:
            raise HTTPException(status_code=400, detail="Invalid file type. Only JPG, PNG, WebP allowed.")
        
        # Generate unique filename
        file_extension = file.filename.split(".")[-1]
        unique_filename = f"{product_id}_{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join(UPLOAD_DIR, unique_filename)
        
        # Save file locally
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        # Generate public URL (relative to static directory)
        image_url = f"/static/uploads/{unique_filename}"
        
        # Update product in MongoDB (update both image and image_url for compatibility)
        db = get_mongo_db()
        result = db.products.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": {
                "image": image_url,
                "image_url": image_url,  # Also update image_url field
                "updated_at": datetime.utcnow()
            }}
        )
        
        logger.info(f"Image uploaded for product {product_id}: {image_url}")
        
        if result.matched_count == 0:
            logger.warning(f"Product {product_id} not found when updating image")
        
        return {
            "message": "Image uploaded successfully",
            "image_url": image_url
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading image: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload image")
