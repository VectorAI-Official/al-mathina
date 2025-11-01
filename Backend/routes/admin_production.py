"""
Admin Routes with Cloudinary Integration (Production)
Handles category management, product CRUD, and image uploads via Cloudinary
"""
import logging
import os
import json
from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends, Request, Response, Form, UploadFile, File
from pydantic import BaseModel, Field
from bson import ObjectId

from database.mongodb_client import get_mongo_db
from utils.cloudinary_helper import upload_image_to_cloudinary, delete_image_from_cloudinary, get_cloudinary_manager

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin/api", tags=["admin"])


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
    """Create a new section"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
        # Check if section exists
        hierarchy = hierarchy_collection.find_one({})
        if hierarchy and section.name in hierarchy.get("sections", []):
            raise HTTPException(status_code=400, detail="Section already exists")
        
        # Add section to hierarchy
        hierarchy_collection.update_one(
            {},
            {"$addToSet": {"sections": section.name}},
            upsert=True
        )
        
        # Save metadata if Tamil name provided
        if section.name_ta:
            db.category_metadata.update_one(
                {"section": section.name, "type": "section"},
                {
                    "$set": {
                        "section": section.name,
                        "type": "section",
                        "name_ta": section.name_ta,
                        "updated_at": datetime.utcnow()
                    }
                },
                upsert=True
            )
        
        logger.info(f"✓ Section created: {section.name}")
        return {"success": True, "message": "Section created successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Failed to create section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/section/{section_name}")
async def update_section(section_name: str, update: CategoryUpdate):
    """Update a section's name, Tamil name, and/or image"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
        # Prepare update data
        update_data = {"updated_at": datetime.utcnow()}
        
        if update.name_ta:
            update_data["name_ta"] = update.name_ta
        
        if update.image_url:
            update_data["image_url"] = update.image_url
        
        # Update or create metadata
        result = metadata_collection.update_one(
            {"section": section_name, "type": "section"},
            {"$set": update_data},
            upsert=True
        )
        
        logger.info(f"✓ Section updated: {section_name}")
        return {"success": True, "message": "Section updated successfully"}
    
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
    """Create a new main category"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
        # Add to hierarchy
        hierarchy_collection.update_one(
            {},
            {"$addToSet": {f"main_categories.{category.section}": category.name}},
            upsert=True
        )
        
        # Save metadata if Tamil name provided
        if category.name_ta:
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
                        "name_ta": category.name_ta,
                        "updated_at": datetime.utcnow()
                    }
                },
                upsert=True
            )
        
        logger.info(f"✓ Main category created: {category.section}/{category.name}")
        return {"success": True, "message": "Main category created successfully"}
    
    except Exception as e:
        logger.error(f"✗ Failed to create main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/main-category/{section}/{main_category}")
async def update_main_category(section: str, main_category: str, update: CategoryUpdate):
    """Update a main category's Tamil name and/or image"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
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
        
        # Update or create metadata
        result = metadata_collection.update_one(
            {
                "section": section,
                "name": main_category,
                "type": "main_category"
            },
            {"$set": update_data},
            upsert=True
        )
        
        logger.info(f"✓ Main category updated: {section}/{main_category}")
        
        # If name changed, update category_hierarchy collection
        if new_name != main_category:
            logger.info(f"🔄 Updating hierarchy: '{main_category}' → '{new_name}'")
            
            # Find the hierarchy document for this section
            hierarchy_doc = db.category_hierarchy.find_one({"sections": section})
            
            if hierarchy_doc:
                # Get main categories list for this section
                main_cats = hierarchy_doc.get("main_categories", {}).get(section, [])
                
                # Replace old name with new name
                if main_category in main_cats:
                    main_cats.remove(main_category)
                    if new_name not in main_cats:
                        main_cats.append(new_name)
                        
                        # Update the hierarchy
                        db.category_hierarchy.update_one(
                            {"_id": hierarchy_doc["_id"]},
                            {"$set": {f"main_categories.{section}": main_cats}}
                        )
                        logger.info(f"✓ Hierarchy updated: main categories for '{section}' = {main_cats}")
                    else:
                        logger.warning(f"⚠️  New name '{new_name}' already exists in main categories")
                else:
                    logger.warning(f"⚠️  Old name '{main_category}' not found in main categories")
            else:
                logger.warning(f"⚠️  Hierarchy document not found for section '{section}'")
        
        return {"success": True, "message": "Main category updated successfully"}
    
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
    """Create a new subcategory"""
    try:
        db = get_mongo_db()
        hierarchy_collection = db.category_hierarchy
        
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
        
        # Save metadata if Tamil name provided
        if subcategory.name_ta:
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
                        "name_ta": subcategory.name_ta,
                        "updated_at": datetime.utcnow()
                    }
                },
                upsert=True
            )
        
        logger.info(f"✓ Subcategory created: {subcategory.section}/{subcategory.main_category}/{subcategory.name}")
        return {"success": True, "message": "Subcategory created successfully"}
    
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
    """Update a subcategory's Tamil name and/or image"""
    try:
        db = get_mongo_db()
        metadata_collection = db.category_metadata
        
        # Prepare update data
        update_data = {"updated_at": datetime.utcnow()}
        
        if update.name_ta:
            update_data["name_ta"] = update.name_ta
        
        if update.image_url:
            update_data["image_url"] = update.image_url
        
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
        return {"success": True, "message": "Subcategory updated successfully"}
    
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
        
        # Create product document
        product_doc = {
            "section": product.section,
            "main_category": product.main_category,
            "subcategory": product.subcategory,
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
        
        logger.info(f"✓ Product created: {product.product_name} ({product.item_id})")
        
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
        
        # Delete image from Cloudinary if exists
        if "image_url" in product and product["image_url"]:
            delete_image_from_cloudinary(product["image_url"])
        
        # Delete product
        result = products_collection.delete_one({"_id": ObjectId(product_id)})
        
        logger.info(f"✓ Product deleted: {product_id}")
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
        db = get_mongo_db()
        new_name = data.get("new_name", section_name)
        name_ta = data.get("name_ta")
        image_url = data.get("image_url")
        
        logger.info(f"🔄 Updating section: '{section_name}'")
        logger.info(f"   - new_name: {new_name}")
        logger.info(f"   - name_ta: {name_ta}")
        logger.info(f"   - image_url: {image_url if not image_url else image_url[:80]}")
        
        # Update hierarchy if name changed
        if new_name != section_name:
            logger.info(f"   🔄 Section name changed, updating hierarchy...")
            # Find the specific section document (each document is a section)
            hierarchy_doc = db.category_hierarchy.find_one({"section": section_name})
            if hierarchy_doc:
                # Update the section field in this document
                result = db.category_hierarchy.update_one(
                    {"section": section_name},
                    {"$set": {"section": new_name}}
                )
                logger.info(f"   ✓ Hierarchy updated: Matched {result.matched_count}, Modified {result.modified_count}")
            else:
                logger.warning(f"   ⚠️  Section document not found in hierarchy: '{section_name}'")
        
        # Update metadata
        update_doc = {"updated_at": datetime.utcnow()}
        if name_ta is not None:
            update_doc["name_ta"] = name_ta
        if image_url is not None:
            update_doc["image_url"] = image_url
        if new_name != section_name:
            update_doc["section"] = new_name
        
        logger.info(f"   📝 Updating metadata with: {update_doc}")
        result = db.category_metadata.update_one(
            {"section": section_name, "type": "section"},
            {"$set": update_doc}
        )
        logger.info(f"   ✓ Metadata updated: Matched {result.matched_count}, Modified {result.modified_count}")
        
        return {"success": True, "message": "Section updated"}
    except Exception as e:
        logger.error(f"✗ Failed to update section: {e}")
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
        
        # If name changed and document was found/created, update hierarchy
        if new_name != main_category_name:
            logger.info(f"   🔄 Updating hierarchy for main category: '{main_category_name}' → '{new_name}'")
            
            # Find the section document
            hierarchy_doc = db.category_hierarchy.find_one({"section": section})
            
            if hierarchy_doc:
                # Get main_categories dict
                main_categories = hierarchy_doc.get("main_categories", {})
                
                # Check if old main category name exists as a key
                if main_category_name in main_categories:
                    # Get the subcategories list
                    subcats = main_categories[main_category_name]
                    
                    # Remove old key and add with new key
                    del main_categories[main_category_name]
                    main_categories[new_name] = subcats
                    
                    # Update the hierarchy
                    db.category_hierarchy.update_one(
                        {"section": section},
                        {"$set": {"main_categories": main_categories}}
                    )
                    logger.info(f"   ✓ Hierarchy updated: main categories = {list(main_categories.keys())}")
                else:
                    logger.warning(f"   ⚠️  Main category '{main_category_name}' not found in hierarchy for section '{section}'")
            else:
                logger.warning(f"   ⚠️  Hierarchy document not found for section '{section}'")
        
        return {"success": True, "message": "Main category updated"}
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
    """Delete section (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        
        logger.info(f"🗑️ Deleting section: {section_name}")
        
        # Delete the section document from hierarchy (each document IS a section)
        hierarchy_result = db.category_hierarchy.delete_one({"section": section_name})
        logger.info(f"   Hierarchy deleted: {hierarchy_result.deleted_count} document(s)")
        
        # Delete metadata for this section
        metadata_result = db.category_metadata.delete_many({"section": section_name})
        logger.info(f"   Metadata deleted: {metadata_result.deleted_count} document(s)")
        
        # Delete products in this section
        products_result = db.products.delete_many({"category_section": section_name})
        logger.info(f"   Products deleted: {products_result.deleted_count} document(s)")
        
        # Also delete from most_bought if any categories from this section were starred
        most_bought_result = db.most_bought.delete_many({"section": section_name})
        logger.info(f"   Most bought entries deleted: {most_bought_result.deleted_count} document(s)")
        
        logger.info(f"✅ Section '{section_name}' deleted successfully")
        
        return {"success": True, "message": "Section deleted"}
    except Exception as e:
        logger.error(f"✗ Failed to delete section: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/categories/main/{section_name}/{main_category}")
async def delete_main_category_compat(section_name: str, main_category: str):
    """Delete main category (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        
        # Decode URL-encoded main_category
        from urllib.parse import unquote
        main_category = unquote(main_category)
        
        # Remove from hierarchy - use $unset to remove the field
        result = db.category_hierarchy.update_one(
            {"section": section_name},
            {"$unset": {f"main_categories.{main_category}": ""}}
        )
        
        logger.info(f"Removed from hierarchy: matched={result.matched_count}, modified={result.modified_count}")
        
        # Delete metadata
        db.category_metadata.delete_many({
            "section": section_name,
            "name": main_category,
            "type": "main_category"
        })
        
        # Delete products
        db.products.delete_many({
            "category_section": section_name,
            "category_main": main_category
        })
        
        logger.info(f"✓ Main category deleted: {section_name} → {main_category}")
        return {"success": True, "message": "Main category deleted"}
    except Exception as e:
        logger.error(f"✗ Failed to delete main category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/categories/sub/{section_name}/{main_category}/{subcategory}")
async def delete_subcategory_compat(section_name: str, main_category: str, subcategory: str):
    """Delete subcategory (compatibility endpoint)"""
    try:
        db = get_mongo_db()
        
        # Decode URL-encoded parameters
        from urllib.parse import unquote
        section_name = unquote(section_name)
        main_category = unquote(main_category)
        subcategory = unquote(subcategory)
        
        # Remove from hierarchy - $pull from the subcategory array
        result = db.category_hierarchy.update_one(
            {"section": section_name},  # Filter by section
            {"$pull": {f"main_categories.{main_category}": subcategory}}  # Remove subcategory from array
        )
        
        logger.info(f"Removed from hierarchy: matched={result.matched_count}, modified={result.modified_count}")
        
        # Delete metadata
        db.category_metadata.delete_many({
            "section": section_name,
            "main_category": main_category,
            "name": subcategory,
            "type": "subcategory"
        })
        
        # Delete products
        db.products.delete_many({
            "category_section": section_name,
            "category_main": main_category,
            "category_sub": subcategory
        })
        
        logger.info(f"✓ Subcategory deleted: {section_name} → {main_category} → {subcategory}")
        return {"success": True, "message": "Subcategory deleted"}
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

