"""
Admin Routes with Cloudinary Integration (Production)
Handles category management, product CRUD, and image uploads via Cloudinary
"""
import logging
import os
import json
import uuid
from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends, Request, Response, Form, UploadFile, File
from pydantic import BaseModel, Field
from bson import ObjectId

from database.mongodb_client import get_mongo_db
from utils.cloudinary_helper import upload_image_to_cloudinary, delete_image_from_cloudinary, get_cloudinary_manager

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin/api", tags=["admin"])


# ============ UUID Generation Helper ============
def generate_category_id(section: str, main_category: str = None, subcategory: str = None) -> str:
    """Generate consistent UUID for a category based on its path"""
    key = f"{section}|{main_category or ''}|{subcategory or ''}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, key))


# ============ Pydantic Models ============

class SectionCreate(BaseModel):
    name: str
    name_ta: Optional[str] = None


class MainCategoryCreate(BaseModel):
    section: str
    name: str
    name_ta: Optional[str] = None


class SubcategoryCreate(BaseModel):
    section: str
    main_category: str
    name: str
    name_ta: Optional[str] = None


class ProductCreate(BaseModel):
    section: str
    main_category: str
    subcategory: str
    product_name: str
    product_name_ta: Optional[str] = None
    item_id: str
    unit: str
    price: float
    stock: int = 0


class ProductUpdate(BaseModel):
    product_name: Optional[str] = None
    product_name_ta: Optional[str] = None
    item_id: Optional[str] = None
    unit: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    image_url: Optional[str] = None


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    name_ta: Optional[str] = None
    image_url: Optional[str] = None


class MostBoughtCreate(BaseModel):
    section: str
    main_category: str


# ============ Image Upload Endpoints ============

@router.post("/upload/image")
async def upload_image(
    file: UploadFile = File(...),
    category_type: Optional[str] = Form(None),  # section, main_category, subcategory, product
    category_name: Optional[str] = Form(None),
    product_id: Optional[str] = Form(None)
):
    """
    Upload an image to Cloudinary
    
    Args:
        file: Image file to upload
        category_type: Type of category (section, main_category, subcategory, product)
        category_name: Name of the category
        product_id: Product ID (for product images)
    
    Returns:
        Cloudinary URL of the uploaded image
    """
    try:
        # Validate file type
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Validate file size (max 5MB)
        file_content = await file.read()
        if len(file_content) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File size must be less than 5MB")
        
        # Check Cloudinary is configured
        manager = get_cloudinary_manager()
        if not manager.is_ready():
            raise HTTPException(
                status_code=503,
                detail="Cloudinary not configured. Please set CLOUDINARY_* environment variables."
            )
        
        # Upload to Cloudinary
        image_url = upload_image_to_cloudinary(
            file_content=file_content,
            filename=file.filename,
            category_type=category_type,
            category_name=category_name,
            product_id=product_id
        )
        
        if not image_url:
            raise HTTPException(status_code=500, detail="Failed to upload image to Cloudinary")
        
        logger.info(f"✓ Image uploaded: {image_url}")
        
        return {
            "success": True,
            "image_url": image_url,
            "message": "Image uploaded successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Image upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@router.delete("/image")
async def delete_image(image_url: str):
    """Delete an image from Cloudinary"""
    try:
        success = delete_image_from_cloudinary(image_url)
        
        if success:
            return {"success": True, "message": "Image deleted successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to delete image")
    
    except Exception as e:
        logger.error(f"✗ Image deletion failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Section Management ============

@router.get("/sections")
async def get_sections():
    """Get all sections"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one({}, {"_id": 0, "sections": 1})
        
        if not hierarchy or "sections" not in hierarchy:
            return {"sections": []}
        
        sections = hierarchy["sections"]
        
        # Get metadata for each section
        metadata_collection = db.category_metadata
        section_list = []
        
        for section_name in sections:
            metadata = metadata_collection.find_one({
                "section": section_name,
                "type": "section"
            })
            
            section_data = {
                "name": section_name,
                "name_ta": metadata.get("name_ta") if metadata else None,
                "image_url": metadata.get("image_url") if metadata else None
            }
            section_list.append(section_data)
        
        return {"sections": section_list}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch sections: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/section")
async def create_section(section: SectionCreate):
    """Create a new section with UUID"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
        # Check if section exists
        hierarchy = hierarchy_collection.find_one({})
        if hierarchy and section.name in hierarchy.get("sections", []):
            raise HTTPException(status_code=400, detail="Section already exists")
        
        # Generate section UUID
        section_id = generate_category_id(section.name)
        
        # Add section to hierarchy
        hierarchy_collection.update_one(
            {},
            {"$addToSet": {"sections": section.name}},
            upsert=True
        )
        
        # Save metadata with UUID
        db.category_metadata.update_one(
            {"section": section.name, "type": "section"},
            {
                "$set": {
                    "section": section.name,
                    "type": "section",
                    "category_id": section_id,
                    "name_ta": section.name_ta if section.name_ta else None,
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
        
        logger.info(f"✓ Section created with UUID: {section.name} (ID: {section_id})")
        return {"success": True, "message": "Section created successfully", "section_id": section_id}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to create section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/section/{section_name}")
async def update_section(section_name: str, update: CategoryUpdate):
    """Update a section's name, Tamil name, and/or image with UUID-based CASCADE"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
        # Get old section ID
        old_section_id = generate_category_id(section_name)
        
        # Prepare update data
        update_data = {"updated_at": datetime.utcnow()}
        
        if update.name_ta:
            update_data["name_ta"] = update.name_ta
        
        if update.image_url:
            update_data["image_url"] = update.image_url
        
        # Check if name is being changed
        new_name = update.name if hasattr(update, 'name') and update.name else section_name
        if new_name != section_name:
            update_data["name"] = new_name
            # Generate new section ID
            new_section_id = generate_category_id(new_name)
            update_data["category_id"] = new_section_id
        
        # Update or create metadata
        result = metadata_collection.update_one(
            {"section": section_name, "type": "section"},
            {"$set": update_data},
            upsert=True
        )
        
        logger.info(f"✓ Section updated: {section_name}")
        
        # If name changed, CASCADE UPDATE using UUID references
        if new_name != section_name:
            logger.info(f"🔄 CASCADE: Renaming section '{section_name}' → '{new_name}' (ID: {old_section_id} → {new_section_id})")
            
            # 1. CASCADE UPDATE: Update all products by section_id (using CORRECT field names)
            products_result = db.products.update_many(
                {"category_section_id": old_section_id},
                {
                    "$set": {
                        "category_section": new_name,  # CORRECT field name
                        "category_section_id": new_section_id,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            logger.info(f"✓ CASCADE: Updated {products_result.modified_count} products (by UUID)")
            
            # 2. CASCADE UPDATE: Update all main category metadata
            main_cat_result = db.category_metadata.update_many(
                {"section_id": old_section_id, "type": "main_category"},
                {
                    "$set": {
                        "section": new_name,
                        "section_id": new_section_id,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            logger.info(f"✓ CASCADE: Updated {main_cat_result.modified_count} main category metadata")
            
            # 3. CASCADE UPDATE: Update all subcategory metadata
            subcat_result = db.category_metadata.update_many(
                {"section_id": old_section_id, "type": "subcategory"},
                {
                    "$set": {
                        "section": new_name,
                        "section_id": new_section_id,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            logger.info(f"✓ CASCADE: Updated {subcat_result.modified_count} subcategory metadata")
            
            # 4. CASCADE UPDATE: Update category_hierarchy
            db.category_hierarchy.update_many(
                {"sections": section_name},
                {"$pull": {"sections": section_name}}
            )
            db.category_hierarchy.update_many(
                {},
                {"$addToSet": {"sections": new_name}}
            )
            hierarchy_docs = db.category_hierarchy.find({"sections": new_name})
            for doc in hierarchy_docs:
                if section_name in doc.get("main_categories", {}):
                    main_cats = doc["main_categories"].pop(section_name, [])
                    doc["main_categories"][new_name] = main_cats
                    db.category_hierarchy.update_one(
                        {"_id": doc["_id"]},
                        {"$set": {"main_categories": doc["main_categories"]}}
                    )
            logger.info(f"✓ CASCADE: Updated category_hierarchy")
        
        return {
            "success": True, 
            "message": "Section updated successfully",
            "reload_required": new_name != section_name
        }
    
    except Exception as e:
        logger.error(f"✗ Failed to update section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Main Category Management ============

@router.get("/main-categories")
async def get_main_categories(section: str):
    """Get all main categories in a section"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one(
            {"sections": section},
            {"_id": 0, f"main_categories.{section}": 1}
        )
        
        if not hierarchy:
            return {"main_categories": []}
        
        main_cats = hierarchy.get("main_categories", {}).get(section, [])
        
        # Get metadata for each main category
        metadata_collection = db.category_metadata
        main_cat_list = []
        
        for cat_name in main_cats:
            metadata = metadata_collection.find_one({
                "section": section,
                "name": cat_name,
                "type": "main_category"
            })
            
            cat_data = {
                "name": cat_name,
                "name_ta": metadata.get("name_ta") if metadata else None,
                "image_url": metadata.get("image_url") if metadata else None
            }
            main_cat_list.append(cat_data)
        
        return {"main_categories": main_cat_list}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch main categories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/main-category")
async def create_main_category(category: MainCategoryCreate):
    """Create a new main category with UUID"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
        # Generate UUIDs
        section_id = generate_category_id(category.section)
        main_cat_id = generate_category_id(category.section, category.name)
        
        # Add to hierarchy
        hierarchy_collection.update_one(
            {},
            {"$addToSet": {f"main_categories.{category.section}": category.name}},
            upsert=True
        )
        
        # Save metadata with UUID
        db.category_metadata.update_one(
            {
                "section": category.section,
                "name": category.name,
                "type": "main_category"
            },
            {
                "$set": {
                    "section": category.section,
                    "name": category.name,
                    "type": "main_category",
                    "category_id": main_cat_id,
                    "section_id": section_id,
                    "name_ta": category.name_ta if category.name_ta else None,
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
        
        logger.info(f"✓ Main category created with UUID: {category.section}/{category.name} (ID: {main_cat_id})")
        return {"success": True, "message": "Main category created successfully", "main_category_id": main_cat_id}
    
    except Exception as e:
        logger.error(f"✗ Failed to create main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/main-category/{section}/{main_category}")
async def update_main_category(section: str, main_category: str, update: CategoryUpdate):
    """Update a main category's name with UUID-based CASCADE"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
        # Get old IDs
        old_section_id = generate_category_id(section)
        old_main_cat_id = generate_category_id(section, main_category)
        
        # Prepare update data
        update_data = {"updated_at": datetime.utcnow()}
        
        if update.name_ta:
            update_data["name_ta"] = update.name_ta
        
        if update.image_url:
            update_data["image_url"] = update.image_url
        
        # Check if name is being changed
        new_name = update.name if hasattr(update, 'name') and update.name else main_category
        if new_name != main_category:
            update_data["name"] = new_name
            # Generate new main category ID
            new_main_cat_id = generate_category_id(section, new_name)
            update_data["category_id"] = new_main_cat_id
        
        # Update or create metadata (use OLD name to find, then update to new name)
        result = metadata_collection.update_one(
            {
                "section": section,
                "name": main_category,  # Find by OLD name
                "type": "main_category"
            },
            {"$set": update_data},  # Update to new name (if changed)
            upsert=True
        )
        
        logger.info(f"✓ Main category metadata updated: {section}/{main_category}" + (f" → {new_name}" if new_name != main_category else ""))
        
        # If name changed, CASCADE UPDATE using UUID references
        if new_name != main_category:
            new_main_cat_id = generate_category_id(section, new_name)
            logger.info(f"🔄 CASCADE: Renaming main category '{main_category}' → '{new_name}' (ID: {old_main_cat_id} → {new_main_cat_id})")
            
            # 1. Update category_hierarchy collection (CRITICAL for dashboard display)
            hierarchy_doc = db.category_hierarchy.find_one({"sections": section})
            
            if hierarchy_doc:
                main_cats = hierarchy_doc.get("main_categories", {}).get(section, [])
                logger.info(f"   Current hierarchy main_categories for '{section}': {main_cats}")
                
                if main_category in main_cats:
                    # Find index and replace in-place to preserve order
                    idx = main_cats.index(main_category)
                    main_cats[idx] = new_name
                    
                    db.category_hierarchy.update_one(
                        {"_id": hierarchy_doc["_id"]},
                        {"$set": {f"main_categories.{section}": main_cats}}
                    )
                    logger.info(f"✓ CASCADE: Hierarchy updated - '{main_category}' → '{new_name}'")
                    logger.info(f"   New hierarchy main_categories: {main_cats}")
                else:
                    logger.warning(f"⚠️  Old name '{main_category}' not found in hierarchy!")
            else:
                logger.warning(f"⚠️  Hierarchy document not found for section '{section}'")
            
            # 2. CASCADE UPDATE: Update all products by main_category_id (using CORRECT field names)
            products_result = db.products.update_many(
                {"category_main_id": old_main_cat_id},
                {
                    "$set": {
                        "category_main": new_name,  # CORRECT field name
                        "category_main_id": new_main_cat_id,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            logger.info(f"✓ CASCADE: Updated {products_result.modified_count} products (by UUID)")
            
            # 3. CASCADE UPDATE: Update all subcategory metadata and regenerate their IDs
            # First, get all subcategories under this main category
            subcats_cursor = db.category_metadata.find({
                "main_category_id": old_main_cat_id,
                "type": "subcategory"
            })
            
            subcategories_list = []  # Track subcategory names for hierarchy update
            
            for subcat_doc in subcats_cursor:
                subcat_name = subcat_doc.get("name")
                subcategories_list.append(subcat_name)
                old_subcat_id = subcat_doc.get("category_id")
                # Generate new subcategory ID with new main category name
                new_subcat_id = generate_category_id(section, new_name, subcat_name)
                
                # Update subcategory metadata
                db.category_metadata.update_one(
                    {"_id": subcat_doc["_id"]},
                    {
                        "$set": {
                            "main_category": new_name,
                            "main_category_id": new_main_cat_id,
                            "category_id": new_subcat_id,
                            "updated_at": datetime.utcnow()
                        }
                    }
                )
                
                # Update products referencing this subcategory (using CORRECT field names)
                db.products.update_many(
                    {"category_sub_id": old_subcat_id},
                    {
                        "$set": {
                            "category_main": new_name,  # CORRECT field name
                            "category_main_id": new_main_cat_id,
                            "category_sub_id": new_subcat_id,
                            "updated_at": datetime.utcnow()
                        }
                    }
                )
            
            # 4. CASCADE UPDATE: Update subcategories in hierarchy (for dashboard display)
            if subcategories_list and hierarchy_doc:
                # Update subcategories.{section}.{old_main_cat} → subcategories.{section}.{new_main_cat}
                subcats_in_hierarchy = hierarchy_doc.get("subcategories", {}).get(section, {})
                if main_category in subcats_in_hierarchy:
                    # Move subcategories from old main cat name to new main cat name
                    subcats_in_hierarchy[new_name] = subcats_in_hierarchy.pop(main_category)
                    
                    db.category_hierarchy.update_one(
                        {"_id": hierarchy_doc["_id"]},
                        {"$set": {f"subcategories.{section}": subcats_in_hierarchy}}
                    )
                    logger.info(f"✓ CASCADE: Moved {len(subcategories_list)} subcategories in hierarchy")
            
            logger.info(f"✓ CASCADE: Updated all subcategory metadata and regenerated UUIDs")
        
        # Return with reload flag if name changed
        return {
            "success": True, 
            "message": "Main category updated successfully",
            "reload_required": new_name != main_category,  # Signal dashboard to reload
            "old_name": main_category if new_name != main_category else None,
            "new_name": new_name if new_name != main_category else None
        }
    
    except Exception as e:
        logger.error(f"✗ Failed to update main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Subcategory Management ============

@router.get("/subcategories")
async def get_subcategories(section: str, main_category: str):
    """Get all subcategories in a main category"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one(
            {"sections": section},
            {"_id": 0, f"subcategories.{section}.{main_category}": 1}
        )
        
        if not hierarchy:
            return {"subcategories": []}
        
        subcats = (
            hierarchy.get("subcategories", {})
            .get(section, {})
            .get(main_category, [])
        )
        
        # Get metadata for each subcategory
        metadata_collection = db.category_metadata
        subcat_list = []
        
        for subcat_name in subcats:
            metadata = metadata_collection.find_one({
                "section": section,
                "main_category": main_category,
                "name": subcat_name,
                "type": "subcategory"
            })
            
            subcat_data = {
                "name": subcat_name,
                "name_ta": metadata.get("name_ta") if metadata else None,
                "image_url": metadata.get("image_url") if metadata else None
            }
            subcat_list.append(subcat_data)
        
        return {"subcategories": subcat_list}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch subcategories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/subcategory")
async def create_subcategory(subcategory: SubcategoryCreate):
    """Create a new subcategory with UUID"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
        # Generate UUIDs
        section_id = generate_category_id(subcategory.section)
        main_cat_id = generate_category_id(subcategory.section, subcategory.main_category)
        subcat_id = generate_category_id(subcategory.section, subcategory.main_category, subcategory.name)
        
        # Add to hierarchy
        hierarchy_collection.update_one(
            {},
            {
                "$addToSet": {
                    f"subcategories.{subcategory.section}.{subcategory.main_category}": subcategory.name
                }
            },
            upsert=True
        )
        
        # Save metadata with UUID
        db.category_metadata.update_one(
            {
                "section": subcategory.section,
                "main_category": subcategory.main_category,
                "name": subcategory.name,
                "type": "subcategory"
            },
            {
                "$set": {
                    "section": subcategory.section,
                    "main_category": subcategory.main_category,
                    "name": subcategory.name,
                    "type": "subcategory",
                    "category_id": subcat_id,
                    "section_id": section_id,
                    "main_category_id": main_cat_id,
                    "name_ta": subcategory.name_ta if subcategory.name_ta else None,
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
        
        logger.info(f"✓ Subcategory created with UUID: {subcategory.section}/{subcategory.main_category}/{subcategory.name} (ID: {subcat_id})")
        return {"success": True, "message": "Subcategory created successfully", "subcategory_id": subcat_id}
    
    except Exception as e:
        logger.error(f"✗ Failed to create subcategory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/subcategory/{section}/{main_category}/{subcategory}")
async def update_subcategory(
    section: str,
    main_category: str,
    subcategory: str,
    update: CategoryUpdate
):
    """Update a subcategory's name with UUID-based CASCADE"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
        # Get old IDs
        old_section_id = generate_category_id(section)
        old_main_cat_id = generate_category_id(section, main_category)
        old_subcat_id = generate_category_id(section, main_category, subcategory)
        
        # Prepare update data
        update_data = {"updated_at": datetime.utcnow()}
        
        if update.name_ta:
            update_data["name_ta"] = update.name_ta
        
        if update.image_url:
            update_data["image_url"] = update.image_url
        
        # Check if name is being changed
        new_name = update.name if hasattr(update, 'name') and update.name else subcategory
        if new_name != subcategory:
            update_data["name"] = new_name
            # Generate new subcategory ID
            new_subcat_id = generate_category_id(section, main_category, new_name)
            update_data["category_id"] = new_subcat_id
        
        # Update or create metadata
        result = metadata_collection.update_one(
            {
                "section": section,
                "main_category": main_category,
                "name": subcategory,
                "type": "subcategory"
            },
            {"$set": update_data},
            upsert=True
        )
        
        logger.info(f"✓ Subcategory updated: {section}/{main_category}/{subcategory}")
        
        # If name changed, CASCADE UPDATE using UUID references
        if new_name != subcategory:
            new_subcat_id = generate_category_id(section, main_category, new_name)
            logger.info(f"🔄 CASCADE: Renaming subcategory '{subcategory}' → '{new_name}' (ID: {old_subcat_id} → {new_subcat_id})")
            
            # CASCADE UPDATE: Update all products by subcategory_id (using CORRECT field names)
            products_result = db.products.update_many(
                {"category_sub_id": old_subcat_id},
                {
                    "$set": {
                        "category_sub": new_name,  # CORRECT field name
                        "category_sub_id": new_subcat_id,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            logger.info(f"✓ CASCADE: Updated {products_result.modified_count} products (by UUID)")
        
        return {
            "success": True, 
            "message": "Subcategory updated successfully",
            "reload_required": new_name != subcategory
        }
    
    except Exception as e:
        logger.error(f"✗ Failed to update subcategory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Product Management ============

@router.get("/products")
async def get_products(
    section: Optional[str] = None,
    main_category: Optional[str] = None,
    subcategory: Optional[str] = None,
    limit: int = 100
):
    """Get products with optional filtering"""
    try:
        db = get_mongo_db()
        products_collection = db.products
        
        # Build filter
        filter_dict = {}
        if section:
            filter_dict["section"] = section
        if main_category:
            filter_dict["main_category"] = main_category
        if subcategory:
            filter_dict["subcategory"] = subcategory
        
        # Fetch products
        products = list(products_collection.find(filter_dict).limit(limit))
        
        # Convert ObjectId and datetime to string for JSON serialization
        for product in products:
            product["_id"] = str(product["_id"])
            # Convert datetime objects to ISO format strings
            if "created_at" in product and isinstance(product["created_at"], datetime):
                product["created_at"] = product["created_at"].isoformat()
            if "updated_at" in product and isinstance(product["updated_at"], datetime):
                product["updated_at"] = product["updated_at"].isoformat()
        
        return {"products": products, "count": len(products)}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch products: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/product")
async def create_product(product: ProductCreate):
    """Create a new product"""
    try:
        db = get_mongo_db()
        products_collection = db.products
        
        # Check if item_id already exists
        existing = products_collection.find_one({"item_id": product.item_id})
        if existing:
            raise HTTPException(status_code=400, detail="Product with this item_id already exists")
        
        # Generate category UUIDs
        section_id = generate_category_id(product.section)
        main_cat_id = generate_category_id(product.section, product.main_category)
        subcat_id = generate_category_id(product.section, product.main_category, product.subcategory)
        
        # Create product document with CORRECT field names and UUID fields
        product_doc = {
            # CORRECT field names (as used in existing DB)
            "category_section": product.section,
            "category_main": product.main_category,
            "category_sub": product.subcategory,
            # UUID references for CASCADE updates
            "category_section_id": section_id,
            "category_main_id": main_cat_id,
            "category_sub_id": subcat_id,
            # Product data
            "product_name": product.product_name,
            "product_name_ta": product.product_name_ta,
            "item_id": product.item_id,
            "unit": product.unit,
            "price": product.price,
            "stock": product.stock,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        result = products_collection.insert_one(product_doc)
        
        logger.info(f"✓ Product created with UUID: {product.product_name} (section_id={section_id}, main_id={main_cat_id}, sub_id={subcat_id})")
        
        return {
            "success": True,
            "message": "Product created successfully",
            "product_id": str(result.inserted_id)
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to create product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/product/{product_id}")
async def update_product(product_id: str, update: ProductUpdate):
    """Update a product"""
    try:
        db = get_mongo_db()
        products_collection = db.products
        
        # Prepare update data
        update_data = {}
        if update.product_name is not None:
            update_data["product_name"] = update.product_name
        if update.product_name_ta is not None:
            update_data["product_name_ta"] = update.product_name_ta
        if update.item_id is not None:
            # Check if new item_id already exists
            existing = products_collection.find_one({
                "item_id": update.item_id,
                "_id": {"$ne": ObjectId(product_id)}
            })
            if existing:
                raise HTTPException(status_code=400, detail="Product with this item_id already exists")
            update_data["item_id"] = update.item_id
        if update.unit is not None:
            update_data["unit"] = update.unit
        if update.price is not None:
            update_data["price"] = update.price
        if update.stock is not None:
            update_data["stock"] = update.stock
        if update.image_url is not None:
            update_data["image_url"] = update.image_url
        
        update_data["updated_at"] = datetime.utcnow()
        
        # Update product
        result = products_collection.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": update_data}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"✓ Product updated: {product_id}")
        return {"success": True, "message": "Product updated successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to update product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/product/{product_id}")
async def delete_product(product_id: str):
    """Delete a product"""
    try:
        db = get_mongo_db()
        products_collection = db.products
        
        # Get product to check for image
        product = products_collection.find_one({"_id": ObjectId(product_id)})
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"🗑️ DELETING PRODUCT:")
        logger.info(f"   Product ID: {product_id}")
        logger.info(f"   Product Name: {product.get('name', 'Unknown')}")
        logger.info(f"   Section: {product.get('category_section', 'N/A')}")
        logger.info(f"   Main Category: {product.get('category_main', 'N/A')}")
        logger.info(f"   Subcategory: {product.get('category_sub', 'N/A')}")
        
        # Delete image from Cloudinary if exists
        if "image_url" in product and product["image_url"]:
            logger.info(f"   Image URL: {product['image_url']}")
            if delete_image_from_cloudinary(product["image_url"]):
                logger.info(f"   ✓ Image deleted from Cloudinary")
            else:
                logger.warning(f"   ⚠ Failed to delete image from Cloudinary")
        else:
            logger.info(f"   No image to delete")
        
        # Delete product
        result = products_collection.delete_one({"_id": ObjectId(product_id)})
        
        logger.info(f"   ✓ Product document deleted from database")
        logger.info(f"✅ PRODUCT DELETION COMPLETE: {product.get('name', 'Unknown')}")
        return {"success": True, "message": "Product deleted successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to delete product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Most Bought Management ============

@router.get("/most-bought")
async def get_most_bought():
    """Get all Most Bought categories"""
    try:
        logger.info("=" * 80)
        logger.info("🔍 GET MOST BOUGHT REQUEST RECEIVED")
        
        db = get_mongo_db()
        most_bought = list(db.most_bought.find({}, {"_id": 0}))
        
        logger.info(f"📊 Found {len(most_bought)} starred categories in database")
        for idx, item in enumerate(most_bought, 1):
            logger.info(f"   {idx}. {item.get('section')} / {item.get('main_category')}")
        
        # Return as "items" array to match frontend expectation
        logger.info(f"✅ Returning {len(most_bought)} items")
        logger.info("=" * 80)
        
        return {"items": most_bought}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch most bought: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/most-bought")
async def add_most_bought(data: MostBoughtCreate):
    """Add a main category to Most Bought"""
    try:
        logger.info("=" * 80)
        logger.info("⭐ ADD TO MOST BOUGHT REQUEST RECEIVED")
        logger.info(f"📦 Request Data: section='{data.section}', main_category='{data.main_category}'")
        logger.info(f"   Section type: {type(data.section)}, length: {len(data.section) if data.section else 0}")
        logger.info(f"   Main category type: {type(data.main_category)}, length: {len(data.main_category) if data.main_category else 0}")
        
        db = get_mongo_db()
        most_bought_collection = db.most_bought
        
        # Check if already exists
        logger.info(f"🔍 Checking if already exists in database...")
        existing = most_bought_collection.find_one({
            "section": data.section,
            "main_category": data.main_category
        })
        
        if existing:
            logger.warning(f"⚠️  Category already exists in Most Bought!")
            logger.info(f"   Existing document: {existing}")
            raise HTTPException(status_code=409, detail="Category already in Most Bought")
        
        logger.info(f"✅ No duplicate found - proceeding with insert")
        
        # Add to most_bought
        document = {
            "section": data.section,
            "main_category": data.main_category,
            "starred_at": datetime.utcnow()
        }
        logger.info(f"📝 Document to insert: {document}")
        
        result = most_bought_collection.insert_one(document)
        logger.info(f"✅ Insert successful - ID: {result.inserted_id}")
        logger.info(f"✓ Added to Most Bought: {data.section}/{data.main_category}")
        logger.info("=" * 80)
        
        return {"success": True, "message": "Added to Most Bought"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to add most bought: {e}")
        logger.error(f"   Exception type: {type(e)}")
        logger.error(f"   Exception details: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/most-bought")
async def remove_most_bought(section: str, main_category: str):
    """Remove a main category from Most Bought"""
    try:
        logger.info("=" * 80)
        logger.info("🗑️ REMOVE FROM MOST BOUGHT REQUEST RECEIVED")
        logger.info(f"📦 Request Params: section='{section}', main_category='{main_category}'")
        logger.info(f"   Section type: {type(section)}, length: {len(section) if section else 0}")
        logger.info(f"   Main category type: {type(main_category)}, length: {len(main_category) if main_category else 0}")
        
        db = get_mongo_db()
        most_bought_collection = db.most_bought
        
        logger.info(f"🔍 Attempting to delete from database...")
        result = most_bought_collection.delete_one({
            "section": section,
            "main_category": main_category
        })
        
        logger.info(f"📊 Delete result: deleted_count={result.deleted_count}")
        
        if result.deleted_count == 0:
            logger.warning(f"⚠️  Category not found in Most Bought!")
            raise HTTPException(status_code=404, detail="Category not in Most Bought")
        
        logger.info(f"✅ Delete successful")
        logger.info(f"✓ Removed from Most Bought: {section}/{main_category}")
        logger.info("=" * 80)
        
        return {"success": True, "message": "Removed from Most Bought"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to remove most bought: {e}")
        logger.error(f"   Exception type: {type(e)}")
        logger.error(f"   Exception details: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ============ Dashboard Compatibility Endpoints ============
# These endpoints match the local admin dashboard URL structure

@router.get("/categories/all")
async def get_all_categories_hierarchy():
    """Get complete category hierarchy for dashboard - matches local admin format"""
    try:
        db = get_mongo_db()
        
        # Get ALL documents from category_hierarchy (each document is a section)
        hierarchy_docs = list(db.category_hierarchy.find({}, {"_id": 0}))
        
        if not hierarchy_docs:
            logger.warning("⚠️ No hierarchy documents found in database")
            return {"hierarchy": []}
        
        logger.info(f"✓ Returning hierarchy: {len(hierarchy_docs)} section documents")
        
        # Log each section being returned
        for idx, doc in enumerate(hierarchy_docs, 1):
            logger.info(f"   Section {idx}: '{doc.get('section', 'UNKNOWN')}'")
        
        # Return in the format dashboard expects: {"hierarchy": [array of section documents]}
        return {
            "hierarchy": hierarchy_docs
        }
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch all categories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories/sections")
async def get_sections_list():
    """Get list of all sections"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one({})
        
        if not hierarchy:
            return {"sections": []}
        
        # Get sections from DB, filter out None/null
        sections_from_db = hierarchy.get("sections", [])
        sections = [s for s in sections_from_db if s is not None]
        
        # If sections is empty, extract from main_categories keys
        if not sections:
            main_categories = hierarchy.get("main_categories", {})
            sections = list(main_categories.keys())
        
        return {"sections": sections}
    except Exception as e:
        logger.error(f"✗ Failed to fetch sections: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories/main/{section}")
async def get_main_categories_for_section_compat(section: str):
    """Get main categories for a section (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one({})
        if not hierarchy:
            return {"main_categories": []}
        main_cats = hierarchy.get("main_categories", {}).get(section, [])
        return {"main_categories": main_cats}
    except Exception as e:
        logger.error(f"✗ Failed to fetch main categories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories/sub/{section}/{main_category}")
async def get_subcategories_compat(section: str, main_category: str):
    """Get subcategories (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        hierarchy = db.category_hierarchy.find_one({})
        if not hierarchy:
            return {"subcategories": []}
        subcats = hierarchy.get("subcategories", {}).get(section, {}).get(main_category, [])
        return {"subcategories": subcats}
    except Exception as e:
        logger.error(f"✗ Failed to fetch subcategories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/categories/section")
async def create_section_compat(data: dict):
    """Create section (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        # Frontend sends 'section', so get it from there
        section_name = data.get("section") or data.get("name")
        section_name_ta = data.get("name_ta", "")
        image_url = data.get("image_url")
        
        if not section_name:
            raise ValueError("Section name is required")
        
        # Add to hierarchy
        db.category_hierarchy.update_one(
            {},
            {"$addToSet": {"sections": section_name}},
            upsert=True
        )
        
        # Save metadata
        metadata_doc = {
            "section": section_name,
            "type": "section",
            "name_ta": section_name_ta,
            "updated_at": datetime.utcnow()
        }
        if image_url:
            metadata_doc["image_url"] = image_url
        
        db.category_metadata.update_one(
            {"section": section_name, "type": "section"},
            {"$set": metadata_doc},
            upsert=True
        )
        
        logger.info(f"✓ Section created: {section_name}")
        return {"success": True, "message": "Section created"}
    except Exception as e:
        logger.error(f"✗ Failed to create section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/categories/main")
async def create_main_category_compat(data: dict):
    """Create main category (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        section = data.get("section")
        # Frontend sends 'main_category', so get it from there
        name = data.get("main_category") or data.get("name")
        name_ta = data.get("name_ta", "")
        image_url = data.get("image_url")
        
        if not section or not name:
            raise ValueError("Section and main category name are required")
        
        # Add to hierarchy - find the document by SECTION first
        db.category_hierarchy.update_one(
            {"section": section},  # FIX: Filter by section
            {"$set": {f"main_categories.{name}": []}},  # FIX: Use $set not $addToSet, and add empty array
            upsert=True
        )
        
        # Save metadata
        metadata_doc = {
            "section": section,
            "name": name,
            "type": "main_category",
            "name_ta": name_ta,
            "updated_at": datetime.utcnow()
        }
        if image_url:
            metadata_doc["image_url"] = image_url
        
        db.category_metadata.update_one(
            {"section": section, "name": name, "type": "main_category"},
            {"$set": metadata_doc},
            upsert=True
        )
        
        logger.info(f"✓ Main category created: {section} → {name}")
        return {"success": True, "message": "Main category created"}
    except Exception as e:
        logger.error(f"✗ Failed to create main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/categories/sub")
async def create_subcategory_compat(data: dict):
    """Create subcategory (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        section = data.get("section")
        main_category = data.get("main_category")
        # Frontend sends 'subcategory', so get it from there
        name = data.get("subcategory") or data.get("name")
        name_ta = data.get("subcategory_ta") or data.get("name_ta", "")
        image_url = data.get("image_url")
        
        if not section or not main_category or not name:
            raise ValueError("Section, main category, and subcategory name are required")
        
        # Add to hierarchy - find by section first
        db.category_hierarchy.update_one(
            {"section": section},  # FIX: Filter by section
            {"$addToSet": {f"main_categories.{main_category}": name}},  # FIX: Add to correct path
            upsert=True
        )
        
        # Save metadata
        metadata_doc = {
            "section": section,
            "main_category": main_category,
            "name": name,
            "type": "subcategory",
            "name_ta": name_ta,
            "updated_at": datetime.utcnow()
        }
        if image_url:
            metadata_doc["image_url"] = image_url
        
        db.category_metadata.update_one(
            {"section": section, "main_category": main_category, "name": name, "type": "subcategory"},
            {"$set": metadata_doc},
            upsert=True
        )
        
        logger.info(f"✓ Subcategory created: {section} → {main_category} → {name}")
        return {"success": True, "message": "Subcategory created"}
    except Exception as e:
        logger.error(f"✗ Failed to create subcategory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload-image")
async def upload_image_compat(file: UploadFile = File(...), category_type: str = Form(None), category_name: str = Form(None)):
    """Image upload (compatibility endpoint)"""
    return await upload_image(file, category_type, category_name, None)


@router.post("/products/add")
async def add_product_compat(request: Request):
    """Add product (compatibility endpoint) - matches local admin format"""
    try:
        logger.info("=" * 100)
        logger.info("🚀🚀🚀 PRODUCT CREATION REQUEST RECEIVED 🚀🚀🚀")
        logger.info("=" * 100)
        
        db = get_mongo_db()
        data = await request.json()
        
        logger.info("📦 STEP 1: REQUEST DATA PARSING")
        logger.info(f"   📊 Raw request data: {json.dumps(data, indent=2, default=str)}")
        logger.info(f"   ✅ JSON parsing successful")
        
        logger.info("📦 STEP 2: EXTRACTING PRODUCT FIELDS")
        logger.info(f"   📝 product_name: {data.get('product_name')}")
        logger.info(f"   📝 product_name_ta: {data.get('product_name_ta')}")
        logger.info(f"   📝 item_id: {data.get('item_id')}")
        logger.info(f"   📝 category_section: {data.get('category_section')}")
        logger.info(f"   📝 category_main: {data.get('category_main')}")
        logger.info(f"   📝 category_sub: {data.get('category_sub')}")
        logger.info(f"   📝 weight: {data.get('weight')}")
        logger.info(f"   📝 price: {data.get('price')}")
        logger.info(f"   📝 stock: {data.get('stock')}")
        logger.info(f"   📝 description: {data.get('description')}")
        logger.info(f"   📝 active: {data.get('active')}")
        logger.info(f"   📝 image_url: {data.get('image_url')}")
        
        logger.info("📦 STEP 3: ADDING METADATA")
        # Add metadata
        data["created_at"] = datetime.utcnow()
        data["updated_at"] = datetime.utcnow()
        data["created_by"] = "admin"
        logger.info(f"   ✅ created_at: {data['created_at']}")
        logger.info(f"   ✅ updated_at: {data['updated_at']}")
        logger.info(f"   ✅ created_by: {data['created_by']}")
        
        logger.info("📦 STEP 4: IMAGE VALIDATION")
        # Set default image if not provided
        if "image_url" not in data or not data["image_url"]:
            data["image_url"] = ""
            logger.info(f"   ⚠️  No image URL provided, setting to empty string")
        else:
            logger.info(f"   ✅ Image URL present: {data['image_url'][:100]}...")
        
        logger.info("📦 STEP 5: CLEANING LEGACY FIELDS")
        # Remove legacy fields to avoid duplicate key errors
        removed_category = data.pop("category", None)
        removed_brand = data.pop("brand", None)
        logger.info(f"   ✅ Removed 'category': {removed_category}")
        logger.info(f"   ✅ Removed 'brand': {removed_brand}")

        logger.info("📦 STEP 5B: ASSIGNING DETERMINISTIC CATEGORY UUIDs (compat mode)")
        try:
            section_val = data.get("category_section")
            main_val = data.get("category_main")
            sub_val = data.get("category_sub")

            # Only set if not already present (avoid overwriting if caller supplied)
            if section_val and "category_section_id" not in data:
                data["category_section_id"] = generate_category_id(section_val)
                logger.info(f"   ✓ category_section_id = {data['category_section_id']}")
            if section_val and main_val and "category_main_id" not in data:
                data["category_main_id"] = generate_category_id(section_val, main_val)
                logger.info(f"   ✓ category_main_id = {data['category_main_id']}")
            if section_val and main_val and sub_val and "category_sub_id" not in data:
                data["category_sub_id"] = generate_category_id(section_val, main_val, sub_val)
                logger.info(f"   ✓ category_sub_id = {data['category_sub_id']}")
        except Exception as uuid_err:
            logger.error(f"   ⚠️ Failed to assign deterministic UUIDs: {uuid_err}")
            # Don't fail product creation; continue
        
        logger.info("📦 STEP 6: MONGODB CONNECTION CHECK")
        logger.info(f"   📊 Database: {db.name}")
        logger.info(f"   📊 Collection: products")
        
        # Check if collection exists and count
        try:
            existing_count = db.products.count_documents({})
            logger.info(f"   ✅ Connection successful - Existing products: {existing_count}")
        except Exception as count_error:
            logger.error(f"   ❌ Failed to count existing products: {count_error}")
        
        logger.info("📦 STEP 7: PREPARING TO INSERT INTO MONGODB")
        logger.info(f"   📊 Final product data structure:")
        logger.info(f"   {json.dumps(data, indent=6, default=str)}")
        
        logger.info("📦 STEP 8: INSERTING INTO MONGODB ATLAS")
        logger.info(f"   🎯 Target: MongoDB Atlas -> {db.name} -> products collection")
        logger.info(f"   📤 Executing insert_one()...")
        
        # Insert into MongoDB
        result = db.products.insert_one(data)
        
        logger.info("📦 STEP 9: INSERT RESULT")
        logger.info(f"   ✅✅✅ Product inserted successfully!")
        logger.info(f"   📝 MongoDB ObjectId: {result.inserted_id}")
        logger.info(f"   📝 Acknowledged: {result.acknowledged}")
        
        logger.info("📦 STEP 10: FETCHING INSERTED PRODUCT")
        # Get the inserted product
        product = db.products.find_one({"_id": result.inserted_id})
        logger.info(f"   ✅ Product retrieved from database")
        
        logger.info("📦 STEP 11: CONVERTING OBJECTID AND DATETIME TO STRING")
        # Convert ObjectId to string
        product["_id"] = str(product["_id"])
        logger.info(f"   ✅ _id converted: {product['_id']}")
        
        # Convert datetime objects to ISO format strings for JSON serialization
        if "created_at" in product and isinstance(product["created_at"], datetime):
            product["created_at"] = product["created_at"].isoformat()
            logger.info(f"   ✅ created_at converted to ISO string: {product['created_at']}")
        
        if "updated_at" in product and isinstance(product["updated_at"], datetime):
            product["updated_at"] = product["updated_at"].isoformat()
            logger.info(f"   ✅ updated_at converted to ISO string: {product['updated_at']}")
        
        logger.info(f"   📊 Final product data: {json.dumps(product, indent=6, default=str)}")
        
        logger.info("📦 STEP 12: PREPARING RESPONSE")
        response_data = {
            "message": "Product added successfully",
            "product": product
        }
        logger.info(f"   📊 Response: {json.dumps(response_data, indent=6, default=str)}")
        
        logger.info("=" * 100)
        logger.info(f"✅✅✅ PRODUCT CREATION COMPLETED SUCCESSFULLY: {product.get('item_id')} ✅✅✅")
        logger.info("=" * 100)
        
        return response_data
        
    except Exception as e:
        logger.error("=" * 100)
        logger.error("❌❌❌ PRODUCT CREATION FAILED ❌❌❌")
        logger.error("=" * 100)
        logger.error(f"💥 Exception Type: {type(e).__name__}")
        logger.error(f"💥 Exception Message: {str(e)}")
        logger.error(f"💥 Full Traceback:")
        logger.error("", exc_info=True)
        logger.error("=" * 100)
        raise HTTPException(status_code=500, detail=f"Failed to add product: {str(e)}")


@router.get("/generate-item-id")
async def generate_item_id():
    """Generate a unique item ID"""
    try:
        db = get_mongo_db()
        # Find the highest existing item_id
        products = list(db.products.find({}, {"item_id": 1}).sort("item_id", -1).limit(1))
        
        if products and products[0].get("item_id"):
            last_id = products[0]["item_id"]
            # Extract number from ID (e.g., "ITEM001" -> 1)
            try:
                num = int(''.join(filter(str.isdigit, last_id)))
                new_num = num + 1
                new_id = f"ITEM{new_num:03d}"
            except:
                # If parsing fails, start from 001
                new_id = "ITEM001"
        else:
            new_id = "ITEM001"
        
        return {"item_id": new_id}
    except Exception as e:
        logger.error(f"✗ Failed to generate item ID: {e}")
        return {"item_id": f"ITEM{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"}


@router.put("/categories/section/{section_name}")
async def update_section_compat(section_name: str, data: dict):
    """Update section (compatibility endpoint)"""
    try:
        logger.info(f"=" * 80)
        logger.info(f"🔧 BACKEND STEP 1: Section edit endpoint called")
        logger.info(f"   Section name from URL: '{section_name}'")
        logger.info(f"   Request data: {data}")
        
        db = get_mongo_db()
        new_name = data.get("new_name", section_name)
        # Frontend sends 'section_ta', accept both for compatibility
        section_ta = data.get("section_ta") or data.get("name_ta")
        image_url = data.get("image_url")
        
        logger.info(f"� BACKEND STEP 2: Parsed request data:")
        logger.info(f"   - new_name: '{new_name}'")
        logger.info(f"   - section_ta: '{section_ta}'")
        logger.info(f"   - image_url: {image_url if not image_url else image_url[:80]}")
        logger.info(f"   - Name changed: {new_name != section_name}")
        
        # Update hierarchy if name changed
        if new_name != section_name:
            logger.info(f"🔧 BACKEND STEP 3a: Section name changed, updating hierarchy...")
            
            # Try to find section document (new structure: each doc has 'section' field)
            hierarchy_doc = db.category_hierarchy.find_one({"section": section_name})
            logger.info(f"   - Found hierarchy doc with section field: {hierarchy_doc is not None}")
            
            if hierarchy_doc:
                # NEW STRUCTURE: Document has 'section' field
                logger.info(f"   - Using NEW structure (section field)")
                logger.info(f"   - Hierarchy doc ID: {hierarchy_doc.get('_id')}")
                # Update the section field in this document
                result = db.category_hierarchy.update_one(
                    {"section": section_name},
                    {"$set": {"section": new_name}}
                )
                logger.info(f"   ✓ Hierarchy section field updated: Matched {result.matched_count}, Modified {result.modified_count}")
                
                # Also update section_ta in hierarchy if provided
                if section_ta is not None:
                    ta_result = db.category_hierarchy.update_one(
                        {"section": new_name},
                        {"$set": {"section_ta": section_ta}}
                    )
                    logger.info(f"   ✓ Hierarchy section_ta updated: Matched {ta_result.matched_count}, Modified {ta_result.modified_count}")
            else:
                # OLD STRUCTURE: Document has 'sections' array
                logger.info(f"   - Trying OLD structure (sections array)...")
                # Find document containing this section in the sections array
                old_doc = db.category_hierarchy.find_one({"sections": section_name})
                logger.info(f"   - Found doc with sections array: {old_doc is not None}")
                
                if old_doc:
                    logger.info(f"   - Using OLD structure (sections array)")
                    logger.info(f"   - Old doc ID: {old_doc.get('_id')}")
                    logger.info(f"   - Current sections array: {old_doc.get('sections')}")
                    
                    # Remove old name from array (FIRST operation)
                    result1 = db.category_hierarchy.update_one(
                        {"_id": old_doc["_id"]},
                        {"$pull": {"sections": section_name}}
                    )
                    logger.info(f"   ✓ Removed old name from array: Matched {result1.matched_count}, Modified {result1.modified_count}")
                    
                    # Add new name to array (SECOND operation)
                    result2 = db.category_hierarchy.update_one(
                        {"_id": old_doc["_id"]},
                        {"$push": {"sections": new_name}}
                    )
                    logger.info(f"   ✓ Added new name to array: Matched {result2.matched_count}, Modified {result2.modified_count}")
                    
                    # For old structure, also try to add section field for future compatibility
                    if "section" not in old_doc and len(old_doc.get("sections", [])) == 1:
                        logger.info(f"   - Migrating to new structure: adding section field")
                        db.category_hierarchy.update_one(
                            {"_id": old_doc["_id"]},
                            {"$set": {"section": new_name}}
                        )
                else:
                    logger.warning(f"   ⚠️  Section not found in either structure: '{section_name}'")
        else:
            logger.info(f"🔧 BACKEND STEP 3b: Section name unchanged, updating only section_ta...")
            # Even if name didn't change, update section_ta in hierarchy
            if section_ta is not None:
                # Try new structure first
                ta_result = db.category_hierarchy.update_one(
                    {"section": section_name},
                    {"$set": {"section_ta": section_ta}}
                )
                logger.info(f"   ✓ Hierarchy section_ta updated (new structure): Matched {ta_result.matched_count}, Modified {ta_result.modified_count}")
                
                # If not found, try old structure
                if ta_result.matched_count == 0:
                    ta_result = db.category_hierarchy.update_one(
                        {"sections": section_name},
                        {"$set": {"section_ta": section_ta}}
                    )
                    logger.info(f"   ✓ Hierarchy section_ta updated (old structure): Matched {ta_result.matched_count}, Modified {ta_result.modified_count}")
        
        # STEP 4: Update metadata
        update_doc = {"updated_at": datetime.utcnow()}
        if section_ta is not None:
            update_doc["name_ta"] = section_ta
        if image_url is not None:
            update_doc["image_url"] = image_url
        if new_name != section_name:
            update_doc["section"] = new_name
        
        logger.info(f"🔧 BACKEND STEP 4: Updating metadata...")
        logger.info(f"   - Filter: {{'section': '{section_name}', 'type': 'section'}}")
        logger.info(f"   - Update doc: {update_doc}")
        
        result = db.category_metadata.update_one(
            {"section": section_name, "type": "section"},
            {"$set": update_doc}
        )
        logger.info(f"   ✓ Metadata updated: Matched {result.matched_count}, Modified {result.modified_count}")
        
        # STEP 5: Update ALL child references if name changed
        if new_name != section_name:
            logger.info(f"🔧 BACKEND STEP 5: Updating all child references...")
            
            # Update all products with this section
            products_result = db.products.update_many(
                {"category_section": section_name},
                {"$set": {"category_section": new_name}}
            )
            logger.info(f"   ✓ Products updated: Matched {products_result.matched_count}, Modified {products_result.modified_count}")
            
            # Update all metadata documents with this section
            metadata_result = db.category_metadata.update_many(
                {"section": section_name},
                {"$set": {"section": new_name}}
            )
            logger.info(f"   ✓ Metadata documents updated: Matched {metadata_result.matched_count}, Modified {metadata_result.modified_count}")
            
            # Update most_bought entries
            most_bought_result = db.most_bought.update_many(
                {"section": section_name},
                {"$set": {"section": new_name}}
            )
            logger.info(f"   ✓ Most bought entries updated: Matched {most_bought_result.matched_count}, Modified {most_bought_result.modified_count}")
        
        # STEP 6: Verify the update by reading back
        logger.info(f"🔧 BACKEND STEP 6: Verifying update...")
        updated_hierarchy = db.category_hierarchy.find_one({"section": new_name})
        logger.info(f"   - Updated hierarchy section: '{updated_hierarchy.get('section') if updated_hierarchy else 'NOT FOUND'}'")
        logger.info(f"   - Updated hierarchy section_ta: '{updated_hierarchy.get('section_ta') if updated_hierarchy else 'NOT FOUND'}'")
        
        # Verify products were updated
        if new_name != section_name:
            sample_product = db.products.find_one({"category_section": new_name})
            logger.info(f"   - Sample product with new section: {sample_product.get('product_name') if sample_product else 'NONE'}")
        
        logger.info(f"✅ BACKEND STEP 7: Section update complete!")
        logger.info(f"=" * 80)
        
        return {"success": True, "message": "Section updated"}
    except Exception as e:
        logger.error(f"❌ BACKEND ERROR: Failed to update section: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/categories/main/{main_category_name}")
async def update_main_category_compat(main_category_name: str, data: dict):
    """Update main category (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        section = data.get("section")
        new_name = data.get("new_name", main_category_name)
        name_ta = data.get("name_ta")
        image_url = data.get("image_url")
        
        logger.info(f"🔄 Updating category: {main_category_name} (section: {section})")
        logger.info(f"   - new_name: {new_name}")
        logger.info(f"   - name_ta: {name_ta}")
        logger.info(f"   - image_url: {image_url if not image_url else image_url[:80]}")
        
        # Update metadata
        update_doc = {"updated_at": datetime.utcnow()}
        if name_ta is not None:
            update_doc["name_ta"] = name_ta
        if image_url is not None:
            update_doc["image_url"] = image_url
        if new_name != main_category_name:
            update_doc["name"] = new_name
        
        # Try to update as main category first
        filter_query_main = {
            "section": section, 
            "name": main_category_name, 
            "type": "main_category"
        }
        
        logger.info(f"   - Filter query (main): {filter_query_main}")
        logger.info(f"   - Update doc: {update_doc}")
        
        result = db.category_metadata.update_one(filter_query_main, {"$set": update_doc})
        
        logger.info(f"   ✓ Main category matched: {result.matched_count}, Modified: {result.modified_count}")
        
        # If not found, try alternative filters
        if result.matched_count == 0:
            logger.info(f"   ⚠️  Not found with type='main_category', trying alternatives...")
            
            alternative_filters = [
                {"section": section, "name": main_category_name, "type": "main"},
                {"section": section, "name": main_category_name},
                {"name": main_category_name, "type": "main_category"},
                {"name": main_category_name, "type": "main"},
                {"name": main_category_name}
            ]
            
            for alt_filter in alternative_filters:
                logger.info(f"   🔄 Trying alternative filter: {alt_filter}")
                result = db.category_metadata.update_one(alt_filter, {"$set": update_doc})
                if result.matched_count > 0:
                    logger.info(f"   ✅ Success with alternative filter! Matched: {result.matched_count}, Modified: {result.modified_count}")
                    break
            
            if result.matched_count == 0:
                logger.error(f"   ❌ No document found with any filter. Creating new document...")
                # Insert as new document
                new_doc = {
                    "section": section,
                    "name": new_name,
                    "type": "main_category",
                    "created_at": datetime.utcnow()
                }
                new_doc.update(update_doc)
                db.category_metadata.insert_one(new_doc)
                logger.info(f"   ✅ New document created for: {new_name}")
        
        # If name changed, perform UUID CASCADE UPDATE
        if new_name != main_category_name:
            logger.info(f"   🔄 CASCADE: Renaming main category '{main_category_name}' → '{new_name}'")
            old_main_cat_id = generate_category_id(section, main_category_name)
            new_main_cat_id = generate_category_id(section, new_name)

            # 1. Hierarchy update
            hierarchy_doc = db.category_hierarchy.find_one({"section": section})
            if hierarchy_doc:
                main_categories = hierarchy_doc.get("main_categories", {})
                if main_category_name in main_categories:
                    subcats = main_categories[main_category_name]
                    del main_categories[main_category_name]
                    main_categories[new_name] = subcats
                    db.category_hierarchy.update_one(
                        {"section": section},
                        {"$set": {"main_categories": main_categories}}
                    )
                    logger.info(f"   ✓ Hierarchy updated: main categories = {list(main_categories.keys())}")

            # 2. Primary CASCADE: UUID-based products
            products_result_uuid = db.products.update_many(
                {"category_main_id": old_main_cat_id},
                {"$set": {"category_main": new_name, "category_main_id": new_main_cat_id, "updated_at": datetime.utcnow()}}
            )
            logger.info(f"   ✓ CASCADE(UUID): Modified {products_result_uuid.modified_count} products")

            # 2b. Fallback CASCADE: name-based where UUID missing
            products_result_name = db.products.update_many(
                {
                    "category_section": section,
                    "category_main": main_category_name,
                    "$or": [
                        {"category_main_id": {"$exists": False}},
                        {"category_main_id": None},
                        {"category_main_id": ""}
                    ]
                },
                {"$set": {"category_main": new_name, "category_main_id": new_main_cat_id, "updated_at": datetime.utcnow()}}
            )
            if products_result_name.modified_count:
                logger.info(f"   ✓ CASCADE(FALLBACK): Modified {products_result_name.modified_count} products missing UUIDs")

            # 3. Subcategory metadata + products under subcategories
            subcats_cursor = db.category_metadata.find({"main_category_id": old_main_cat_id, "type": "subcategory"})
            subcat_count = 0
            for subcat_doc in subcats_cursor:
                subcat_name = subcat_doc.get("name")
                old_subcat_id = subcat_doc.get("category_id")
                new_subcat_id = generate_category_id(section, new_name, subcat_name)
                db.category_metadata.update_one(
                    {"_id": subcat_doc["_id"]},
                    {"$set": {"main_category": new_name, "main_category_id": new_main_cat_id, "category_id": new_subcat_id, "updated_at": datetime.utcnow()}}
                )
                # Products with old subcat UUID
                prod_update_uuid = db.products.update_many(
                    {"category_sub_id": old_subcat_id},
                    {"$set": {"category_main": new_name, "category_main_id": new_main_cat_id, "category_sub_id": new_subcat_id, "updated_at": datetime.utcnow()}}
                )
                # Fallback: products missing subcat UUID but matching names
                prod_update_name = db.products.update_many(
                    {
                        "category_section": section,
                        "category_main": main_category_name,
                        "category_sub": subcat_name,
                        "$or": [
                            {"category_sub_id": {"$exists": False}},
                            {"category_sub_id": None},
                            {"category_sub_id": ""}
                        ]
                    },
                    {"$set": {"category_main": new_name, "category_main_id": new_main_cat_id, "category_sub_id": new_subcat_id, "updated_at": datetime.utcnow()}}
                )
                if prod_update_name.modified_count or prod_update_uuid.modified_count:
                    logger.info(f"      • Subcat '{subcat_name}': UUID products={prod_update_uuid.modified_count}, fallback products={prod_update_name.modified_count}")
                subcat_count += 1
            if subcat_count:
                logger.info(f"   ✓ CASCADE: Processed {subcat_count} subcategories (UUID + fallback)")

            # 4. Backfill section UUID for any touched products missing it
            backfill_section_uuid = generate_category_id(section)
            backfill_result = db.products.update_many(
                {
                    "category_section": section,
                    "$or": [
                        {"category_section_id": {"$exists": False}},
                        {"category_section_id": None},
                        {"category_section_id": ""}
                    ]
                },
                {"$set": {"category_section_id": backfill_section_uuid}}
            )
            if backfill_result.modified_count:
                logger.info(f"   ✓ BACKFILL: Added section UUID to {backfill_result.modified_count} products")
        
        return {
            "success": True, 
            "message": "Main category updated",
            "reload_required": new_name != main_category_name,
            "old_name": main_category_name if new_name != main_category_name else None,
            "new_name": new_name if new_name != main_category_name else None
        }
    except Exception as e:
        logger.error(f"✗ Failed to update main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/categories/sub/{subcategory_name}")
async def update_subcategory_compat(subcategory_name: str, data: dict):
    """Update subcategory (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        section = data.get("section")
        main_category = data.get("main_category")
        new_name = data.get("new_name", subcategory_name)
        name_ta = data.get("name_ta")
        image_url = data.get("image_url")
        
        logger.info(f"🔄 Updating subcategory: {subcategory_name} (section: {section}, main_category: {main_category})")
        logger.info(f"   - new_name: {new_name}")
        logger.info(f"   - name_ta: {name_ta}")
        logger.info(f"   - image_url: {image_url if not image_url else image_url[:80]}")
        
        # Update metadata
        update_doc = {"updated_at": datetime.utcnow()}
        if name_ta is not None:
            update_doc["name_ta"] = name_ta
        if image_url is not None:
            update_doc["image_url"] = image_url
        if new_name != subcategory_name:
            update_doc["name"] = new_name
        
        # Query filter - must match exactly
        filter_query = {
            "section": section,
            "main_category": main_category,
            "name": subcategory_name,
            "type": "subcategory"
        }
        
        logger.info(f"   - Filter query: {filter_query}")
        logger.info(f"   - Update doc: {update_doc}")
        
        result = db.category_metadata.update_one(filter_query, {"$set": update_doc})
        
        logger.info(f"   ✓ Matched: {result.matched_count}, Modified: {result.modified_count}")
        
        if result.matched_count == 0:
            logger.warning(f"   ⚠️  No document found matching filter: {filter_query}")
            
            # Try alternative filters (maybe type field is missing or different)
            alternative_filters = [
                {"section": section, "main_category": main_category, "name": subcategory_name, "type": "sub"},
                {"section": section, "main_category": main_category, "name": subcategory_name},
                {"name": subcategory_name, "type": "subcategory"},
                {"name": subcategory_name}
            ]
            
            for alt_filter in alternative_filters:
                logger.info(f"   🔄 Trying alternative filter: {alt_filter}")
                result = db.category_metadata.update_one(alt_filter, {"$set": update_doc})
                if result.matched_count > 0:
                    logger.info(f"   ✅ Success with alternative filter! Matched: {result.matched_count}, Modified: {result.modified_count}")
                    break
            
            if result.matched_count == 0:
                logger.error(f"   ❌ No document found with any filter. Creating new document...")
                # Insert as new document
                new_doc = {
                    "section": section,
                    "main_category": main_category,
                    "name": new_name,
                    "type": "subcategory",
                    "created_at": datetime.utcnow()
                }
                new_doc.update(update_doc)
                db.category_metadata.insert_one(new_doc)
                logger.info(f"   ✅ New document created for: {new_name}")
        
        # If name changed, update category_hierarchy collection
        if new_name != subcategory_name:
            logger.info(f"   🔄 Updating hierarchy: '{subcategory_name}' → '{new_name}'")
            
            # Find the hierarchy document for THIS SPECIFIC SECTION (each document is a section)
            hierarchy_doc = db.category_hierarchy.find_one({"section": section})
            
            if hierarchy_doc:
                # Navigate to subcategories: main_categories.{main_category}
                main_categories = hierarchy_doc.get("main_categories", {})
                logger.info(f"   📊 Available main categories in section '{section}': {list(main_categories.keys())}")
                
                # Get the subcategories list for this main category
                if main_category in main_categories:
                    subcats = main_categories[main_category]
                    logger.info(f"   📊 Current subcategories for '{main_category}': {subcats}")
                    
                    # Replace old name with new name
                    if subcategory_name in subcats:
                        subcats_index = subcats.index(subcategory_name)
                        subcats[subcats_index] = new_name
                        
                        # Update the hierarchy using exact path
                        update_path = f"main_categories.{main_category}"
                        db.category_hierarchy.update_one(
                            {"section": section},
                            {"$set": {update_path: subcats}}
                        )
                        logger.info(f"   ✓ Hierarchy updated: section='{section}', {update_path} = {subcats}")
                    else:
                        logger.warning(f"   ⚠️  Old name '{subcategory_name}' not found in subcategories list: {subcats}")
                else:
                    logger.warning(f"   ⚠️  Main category '{main_category}' not found in section '{section}'. Available: {list(main_categories.keys())}")
            else:
                logger.warning(f"   ⚠️  Hierarchy document not found for section '{section}'")
        
        return {"success": True, "message": "Subcategory updated"}
    except Exception as e:
        logger.error(f"✗ Failed to update subcategory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/categories/section/{section_name}")
async def delete_section_compat(section_name: str):
    """Delete section (compatibility endpoint with Cloudinary cleanup)"""
    try:
        db = get_mongo_db()
        
        logger.info(f"🗑️ DELETING SECTION:")
        logger.info(f"   Section Name: {section_name}")
        logger.info(f"   Section name length: {len(section_name)} chars")
        logger.info(f"   Section name repr: {repr(section_name)}")
        
        # List all sections before deletion for debugging
        all_sections = list(db.category_hierarchy.find({}, {"section": 1, "sections": 1, "_id": 0}))
        logger.info(f"   📋 All sections in DB before delete: {len(all_sections)}")
        for idx, doc in enumerate(all_sections, 1):
            section_in_db = doc.get('section', 'NONE')
            sections_array = doc.get('sections', [])
            logger.info(f"      {idx}. section='{section_in_db}' sections={sections_array}")
        
        # === STEP 1: Delete all product images in this section ===
        logger.info(f"   📦 Searching for products with images...")
        products_with_images = db.products.find({
            "category_section": section_name,
            "image_url": {"$exists": True, "$ne": None}
        })
        
        product_image_count = 0
        for product in products_with_images:
            if product.get("image_url"):
                logger.info(f"      Deleting: {product.get('name', 'Unknown')} - {product['image_url']}")
                if delete_image_from_cloudinary(product["image_url"]):
                    product_image_count += 1
                    logger.info(f"      ✓ Deleted successfully")
                else:
                    logger.warning(f"      ⚠ Failed to delete")
        logger.info(f"   ✓ Product images deleted from Cloudinary: {product_image_count}")
        
        # === STEP 2: Delete all category metadata images (main + sub) ===
        logger.info(f"   🖼️ Searching for category/subcategory images...")
        metadata_with_images = db.category_metadata.find({
            "section": section_name,
            "image_url": {"$exists": True, "$ne": None}
        })
        
        category_image_count = 0
        for metadata in metadata_with_images:
            if metadata.get("image_url"):
                logger.info(f"      Deleting {metadata.get('type', 'category')}: {metadata.get('name', 'Unknown')} - {metadata['image_url']}")
                if delete_image_from_cloudinary(metadata["image_url"]):
                    category_image_count += 1
                    logger.info(f"      ✓ Deleted successfully")
                else:
                    logger.warning(f"      ⚠ Failed to delete")
        logger.info(f"   ✓ Category/subcategory images deleted from Cloudinary: {category_image_count}")
        
        # === STEP 3: Delete hierarchy document ===
        hierarchy_result = db.category_hierarchy.delete_one({"section": section_name})
        logger.info(f"   Hierarchy document deleted: {hierarchy_result.deleted_count} document(s)")
        
        # === STEP 4: Remove from sections array (old structure compatibility) ===
        array_result = db.category_hierarchy.update_many(
            {"sections": section_name},
            {"$pull": {"sections": section_name}}
        )
        logger.info(f"   Removed from sections arrays: {array_result.modified_count} document(s) updated")
        
        # === STEP 5: Delete metadata ===
        metadata_result = db.category_metadata.delete_many({"section": section_name})
        logger.info(f"   Metadata deleted: {metadata_result.deleted_count} document(s)")
        
        # === STEP 6: Delete products ===
        products_result = db.products.delete_many({"category_section": section_name})
        logger.info(f"   Products deleted: {products_result.deleted_count} document(s)")
        
        # === STEP 7: Delete from most_bought ===
        most_bought_result = db.most_bought.delete_many({"section": section_name})
        logger.info(f"   Most bought entries deleted: {most_bought_result.deleted_count} document(s)")
        
        total_images = product_image_count + category_image_count
        logger.info(f"✅ Section '{section_name}' deleted with {total_images} images from Cloudinary")
        
        return {"success": True, "message": f"Section deleted with {total_images} images"}
    except Exception as e:
        logger.error(f"✗ Failed to delete section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/categories/main/{section_name}/{main_category}")
async def delete_main_category_compat(section_name: str, main_category: str):
    """Delete main category and all its subcategories (cascading delete with Cloudinary cleanup)"""
    try:
        db = get_mongo_db()
        
        # Decode URL-encoded main_category
        from urllib.parse import unquote
        main_category = unquote(main_category)
        
        logger.info(f"🗑️ DELETING MAIN CATEGORY:")
        logger.info(f"   Section: {section_name}")
        logger.info(f"   Main Category: {main_category}")
        
        # === STEP 1: Delete all product images in this main category ===
        logger.info(f"   📦 Searching for products with images...")
        products_with_images = db.products.find({
            "category_section": section_name,
            "category_main": main_category,
            "image_url": {"$exists": True, "$ne": None}
        })
        
        image_delete_count = 0
        for product in products_with_images:
            if product.get("image_url"):
                logger.info(f"      Deleting: {product.get('name', 'Unknown')} - {product['image_url']}")
                if delete_image_from_cloudinary(product["image_url"]):
                    image_delete_count += 1
                    logger.info(f"      ✓ Deleted successfully")
                else:
                    logger.warning(f"      ⚠ Failed to delete")
        logger.info(f"   ✓ Product images deleted from Cloudinary: {image_delete_count}")
        
        # === STEP 2: Delete main category image ===
        main_metadata = db.category_metadata.find_one({
            "section": section_name,
            "name": main_category,
            "type": "main_category"
        })
        if main_metadata and main_metadata.get("image_url"):
            logger.info(f"   🖼️ Deleting main category image: {main_metadata['image_url']}")
            if delete_image_from_cloudinary(main_metadata["image_url"]):
                logger.info(f"   ✓ Main category image deleted from Cloudinary")
            else:
                logger.warning(f"   ⚠ Failed to delete main category image")
        
        # === STEP 3: Delete all subcategory images ===
        logger.info(f"   📂 Searching for subcategory images...")
        sub_metadata_with_images = db.category_metadata.find({
            "section": section_name,
            "main_category": main_category,
            "type": "subcategory",
            "image_url": {"$exists": True, "$ne": None}
        })
        
        sub_image_delete_count = 0
        for sub_meta in sub_metadata_with_images:
            if sub_meta.get("image_url"):
                logger.info(f"      Deleting: {sub_meta.get('name', 'Unknown')} - {sub_meta['image_url']}")
                if delete_image_from_cloudinary(sub_meta["image_url"]):
                    sub_image_delete_count += 1
                    logger.info(f"      ✓ Deleted successfully")
                else:
                    logger.warning(f"      ⚠ Failed to delete")
        logger.info(f"   ✓ Subcategory images deleted from Cloudinary: {sub_image_delete_count}")
        
        # === STEP 4: Remove from hierarchy ===
        result = db.category_hierarchy.update_one(
            {"section": section_name},
            {"$unset": {f"main_categories.{main_category}": ""}}
        )
        logger.info(f"   Hierarchy updated: matched={result.matched_count}, modified={result.modified_count}")
        
        # === STEP 5: Delete main category metadata ===
        main_metadata_result = db.category_metadata.delete_many({
            "section": section_name,
            "name": main_category,
            "type": "main_category"
        })
        logger.info(f"   Main category metadata deleted: {main_metadata_result.deleted_count} document(s)")
        
        # === STEP 6: Delete ALL subcategory metadata (cascading) ===
        sub_metadata_result = db.category_metadata.delete_many({
            "section": section_name,
            "main_category": main_category,
            "type": "subcategory"
        })
        logger.info(f"   Subcategory metadata deleted (cascade): {sub_metadata_result.deleted_count} document(s)")
        
        # === STEP 7: Delete all products (cascading) ===
        products_result = db.products.delete_many({
            "category_section": section_name,
            "category_main": main_category
        })
        logger.info(f"   Products deleted (cascade): {products_result.deleted_count} document(s)")
        
        # === STEP 8: Remove from most_bought ===
        most_bought_result = db.most_bought.delete_many({
            "section": section_name,
            "main_category": main_category
        })
        logger.info(f"   Most bought entries deleted: {most_bought_result.deleted_count} document(s)")
        
        logger.info(f"✅ Main category '{main_category}', all children, and {image_delete_count + sub_image_delete_count + 1} images deleted successfully")
        return {"success": True, "message": "Main category deleted with all images"}
    except Exception as e:
        logger.error(f"✗ Failed to delete main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/categories/sub/{section_name}/{main_category}/{subcategory}")
async def delete_subcategory_compat(section_name: str, main_category: str, subcategory: str):
    """Delete subcategory and all its products (cascading delete with Cloudinary cleanup)"""
    try:
        db = get_mongo_db()
        
        # Decode URL-encoded parameters
        from urllib.parse import unquote
        section_name = unquote(section_name)
        main_category = unquote(main_category)
        subcategory = unquote(subcategory)
        
        logger.info(f"🗑️ DELETING SUBCATEGORY:")
        logger.info(f"   Section: {section_name}")
        logger.info(f"   Main Category: {main_category}")
        logger.info(f"   Subcategory: {subcategory}")
        
        # === STEP 1: Delete all product images in this subcategory ===
        logger.info(f"   📦 Searching for products with images...")
        products_with_images = db.products.find({
            "category_section": section_name,
            "category_main": main_category,
            "category_sub": subcategory,
            "image_url": {"$exists": True, "$ne": None}
        })
        
        image_delete_count = 0
        for product in products_with_images:
            if product.get("image_url"):
                logger.info(f"      Deleting: {product.get('name', 'Unknown')} - {product['image_url']}")
                if delete_image_from_cloudinary(product["image_url"]):
                    image_delete_count += 1
                    logger.info(f"      ✓ Deleted successfully")
                else:
                    logger.warning(f"      ⚠ Failed to delete")
        logger.info(f"   ✓ Product images deleted from Cloudinary: {image_delete_count}")
        
        # === STEP 2: Delete subcategory image ===
        sub_metadata = db.category_metadata.find_one({
            "section": section_name,
            "main_category": main_category,
            "name": subcategory,
            "type": "subcategory"
        })
        if sub_metadata and sub_metadata.get("image_url"):
            logger.info(f"   🖼️ Deleting subcategory image: {sub_metadata['image_url']}")
            if delete_image_from_cloudinary(sub_metadata["image_url"]):
                logger.info(f"   ✓ Subcategory image deleted from Cloudinary")
            else:
                logger.warning(f"   ⚠ Failed to delete subcategory image")
        
        # === STEP 3: Remove from hierarchy ===
        result = db.category_hierarchy.update_one(
            {"section": section_name},
            {"$pull": {f"main_categories.{main_category}": subcategory}}
        )
        logger.info(f"   Hierarchy updated: matched={result.matched_count}, modified={result.modified_count}")
        
        # === STEP 4: Delete subcategory metadata ===
        metadata_result = db.category_metadata.delete_many({
            "section": section_name,
            "main_category": main_category,
            "name": subcategory,
            "type": "subcategory"
        })
        logger.info(f"   Subcategory metadata deleted: {metadata_result.deleted_count} document(s)")
        
        # === STEP 5: Delete all products (cascading) ===
        products_result = db.products.delete_many({
            "category_section": section_name,
            "category_main": main_category,
            "category_sub": subcategory
        })
        logger.info(f"   Products deleted (cascade): {products_result.deleted_count} document(s)")
        
        logger.info(f"✅ Subcategory '{subcategory}', all products, and {image_delete_count + 1} images deleted successfully")
        return {"success": True, "message": "Subcategory deleted with all images"}
    except Exception as e:
        logger.error(f"✗ Failed to delete subcategory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/products/{product_id}/best-seller")
async def toggle_best_seller(product_id: str, data: dict):
    """Toggle best seller status for a product"""
    try:
        db = get_mongo_db()
        is_best_seller = data.get("is_best_seller", False)
        
        result = db.products.update_one(
            {"item_id": product_id},
            {"$set": {"is_best_seller": is_best_seller}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        
        return {"success": True, "message": "Best seller status updated"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to toggle best seller: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/products/{product_id}")
async def update_product_compat(product_id: str, request: Request):
    """Update product (compatibility endpoint) - matches local admin format"""
    try:
        logger.info(f"=== UPDATING PRODUCT (PRODUCTION) ===")
        logger.info(f"Product ID: {product_id}")
        
        db = get_mongo_db()
        data = await request.json()
        
        logger.info(f"Update data: {data}")
        
        # Add update metadata
        data["updated_at"] = datetime.utcnow()
        data["updated_by"] = "admin"
        
        # Remove item_id if it's in the data (prevent modification)
        if "item_id" in data:
            logger.warning(f"⚠️ Attempt to modify item_id blocked for product {product_id}")
            del data["item_id"]
        
        # Remove _id if present
        data.pop("_id", None)
        
        logger.info(f"Updating product in MongoDB Atlas...")
        
        # Update in MongoDB
        result = db.products.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": data}
        )
        
        if result.matched_count == 0:
            logger.error(f"✗ Product not found: {product_id}")
            raise HTTPException(status_code=404, detail="Product not found")
        
        logger.info(f"✓ Product updated: matched={result.matched_count}, modified={result.modified_count}")
        
        # Get updated product
        product = db.products.find_one({"_id": ObjectId(product_id)})
        product["_id"] = str(product["_id"])
        
        # Convert datetime objects to ISO format strings for JSON serialization
        if "created_at" in product and isinstance(product["created_at"], datetime):
            product["created_at"] = product["created_at"].isoformat()
        if "updated_at" in product and isinstance(product["updated_at"], datetime):
            product["updated_at"] = product["updated_at"].isoformat()
        
        logger.info(f"✓ Product updated successfully: {product.get('item_id')}")
        return {"message": "Product updated successfully", "product": product}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to update product: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to update product: {str(e)}")


@router.delete("/products/{product_id}")
async def delete_product_compat(product_id: str):
    """Delete product (compatibility endpoint)"""
    return await delete_product(product_id)


@router.post("/upload/image/{product_id}")
async def upload_product_image_compat(product_id: str, file: UploadFile = File(...)):
    """Upload product image (compatibility endpoint)"""
    try:
        logger.info(f"=== UPLOADING PRODUCT IMAGE ===")
        logger.info(f"Product ID: {product_id}")
        logger.info(f"File: {file.filename}, Size: {file.size}, Type: {file.content_type}")
        
        cloudinary = get_cloudinary_manager()
        
        # Read file content
        file_content = await file.read()
        logger.info(f"File content read: {len(file_content)} bytes")
        
        # Upload to Cloudinary
        image_url = cloudinary.upload_product_image(
            file_content=file_content,
            filename=file.filename,
            product_id=product_id
        )
        
        if not image_url:
            logger.error(f"✗ Cloudinary returned no URL")
            raise HTTPException(status_code=500, detail="Failed to upload to Cloudinary")
        
        logger.info(f"✓ Cloudinary URL received: {image_url}")
        
        # Update product image URL in database
        db = get_mongo_db()
        # Try to update by _id first (if it's a MongoDB ObjectId), then by item_id as fallback
        from bson import ObjectId
        
        try:
            # Try as ObjectId first
            result = db.products.update_one(
                {"_id": ObjectId(product_id)},
                {"$set": {"image_url": image_url, "updated_at": datetime.utcnow()}, "$unset": {"image": ""}}
            )
        except:
            # Fall back to item_id
            result = db.products.update_one(
                {"item_id": product_id},
                {"$set": {"image_url": image_url, "updated_at": datetime.utcnow()}, "$unset": {"image": ""}}
            )
        
        if result.matched_count == 0:
            logger.warning(f"⚠️ No product found with ID: {product_id}")
        else:
            logger.info(f"✓ Database updated: matched={result.matched_count}, modified={result.modified_count}")
        
        # Verify the update
        product = db.products.find_one({"item_id": product_id}, {"image_url": 1, "product_name": 1})
        if product:
            logger.info(f"✓ Product '{product.get('product_name')}' now has image: {product.get('image_url')}")
        
        logger.info(f"✓ Product image uploaded successfully")
        return {
            "success": True, 
            "image_url": image_url,
            "message": "Image uploaded successfully to Cloudinary"
        }
    
    except Exception as e:
        logger.error(f"✗ Failed to upload product image: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories/metadata")
async def get_all_metadata():
    """Get all category metadata (images, Tamil names)"""
    try:
        db = get_mongo_db()
        metadata_list = list(db.category_metadata.find({}, {"_id": 0}))
        
        logger.info(f"✓ Returning {len(metadata_list)} metadata documents")
        
        # Log Cloudinary URLs for debugging
        for meta in metadata_list:
            if meta.get("image_url"):
                url = meta["image_url"]
                is_cloudinary = "cloudinary.com" in url
                logger.debug(f"  {meta.get('type')}/{meta.get('name', meta.get('section'))}: {'☁️ Cloudinary' if is_cloudinary else '📁 Local'} - {url[:80]}")
        
        return {"metadata": metadata_list}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch metadata: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/products/all")
async def get_all_products():
    """Get all products for dashboard"""
    try:
        db = get_mongo_db()
        products = list(db.products.find({}))
        
        # Convert ObjectId to string
        for product in products:
            product["_id"] = str(product["_id"])
        
        logger.info(f"✓ Returning {len(products)} products")
        
        # Log image URL types for debugging
        cloudinary_count = sum(1 for p in products if p.get("image_url") and "cloudinary.com" in p.get("image_url", ""))
        local_count = sum(1 for p in products if p.get("image_url") and "cloudinary.com" not in p.get("image_url", ""))
        no_image_count = sum(1 for p in products if not p.get("image_url"))
        
        logger.info(f"  Images: ☁️ {cloudinary_count} Cloudinary, 📁 {local_count} Local, ❌ {no_image_count} No image")
        
        return {"products": products}
    
    except Exception as e:
        logger.error(f"✗ Failed to fetch all products: {e}")
        raise HTTPException(status_code=500, detail=str(e))

