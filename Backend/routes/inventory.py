"""
API endpoints for inventory and catalog management.
Handles categories and products from MongoDB.
"""
from fastapi import APIRouter, HTTPException, Query
from typing import Optional
import logging

from models import CategoryListResponse, CategoryResponse, ProductListResponse, ProductResponse
from database.mongodb_client import get_mongo_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/inventory", tags=["Inventory"])


@router.get("/sections")
async def get_sections(
    active_only: bool = Query(default=True, description="Return only active products")
):
    """
    Get all unique product sections (category_section).
    Returns the hierarchical section structure for the home screen.
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query
        query = {}
        if active_only:
            query["active"] = True
        
        # Get distinct sections
        sections = products_collection.distinct("category_section", query)
        
        # Structure response with section details
        section_data = []
        for section in sorted(sections):
            # Count products in this section
            count = products_collection.count_documents({
                **query,
                "category_section": section
            })
            
            section_data.append({
                "name": section,
                "product_count": count
            })
        
        logger.info(f"Retrieved {len(section_data)} sections")
        
        return {
            "sections": section_data,
            "count": len(section_data)
        }
        
    except Exception as e:
        logger.error(f"Error fetching sections: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch sections: {str(e)}")


@router.get("/products", response_model=ProductListResponse)
async def get_products(
    section: Optional[str] = Query(None, description="Filter by section (category_section)"),
    main_category: Optional[str] = Query(None, description="Filter by main category (category_main)"),
    sub_category: Optional[str] = Query(None, description="Filter by subcategory (category_sub)"),
    active_only: bool = Query(default=True, description="Return only active products")
):
    """
    Get products from the catalog using hierarchical category filtering.
    Can filter by section, main_category, and/or sub_category.
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query
        query = {}
        if active_only:
            query["active"] = True
        if section:
            query["category_section"] = section
        if main_category:
            query["category_main"] = main_category
        if sub_category:
            query["category_sub"] = sub_category
        
        # Fetch products
        products_cursor = products_collection.find(query)
        products = []
        
        for prod in products_cursor:
            products.append(ProductResponse(
                item_id=prod["item_id"],
                product_name=prod["product_name"],
                category_section=prod["category_section"],
                category_main=prod["category_main"],
                category_sub=prod["category_sub"],
                image_url=prod.get("image_url"),
                weight=prod.get("weight", ""),
                price=prod.get("price", 0.0),
                stock=prod.get("stock", 0),
                active=prod.get("active", True),
                description=prod.get("description")
            ))
        
        logger.info(f"Retrieved {len(products)} products (section={section}, main={main_category}, sub={sub_category})")
        
        return ProductListResponse(
            products=products,
            count=len(products),
            category=main_category  # Use main_category for backward compatibility
        )
        
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch products: {str(e)}")


@router.get("/products/{item_id}", response_model=ProductResponse)
async def get_product_by_id(item_id: str):
    """
    Get a specific product by its item_id (SKU).
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        product = products_collection.find_one({"item_id": item_id, "active": True})
        
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Product not found: {item_id}"
            )
        
        return ProductResponse(
            item_id=product["item_id"],
            product_name=product["product_name"],
            category_section=product["category_section"],
            category_main=product["category_main"],
            category_sub=product["category_sub"],
            image_url=product.get("image_url"),
            weight=product.get("weight", ""),
            price=product.get("price", 0.0),
            stock=product.get("stock", 0),
            active=product.get("active", True),
            description=product.get("description")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching product: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch product: {str(e)}")
