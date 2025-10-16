"""
Flutter Mobile App API Routes
Provides optimized endpoints for Flutter mobile application.
"""
from fastapi import APIRouter, Query, HTTPException
from typing import Optional, List, Dict, Any
from urllib.parse import unquote
import logging

from database.mongodb_client import get_mongo_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/flutter", tags=["Flutter Mobile App"])


@router.get("/home")
async def get_home_data():
    """
    Get all sections and main categories for home page.
    
    Returns:
    - Best Sellers section with main categories
    - All regular sections with their main categories
    - Product counts for each main category
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        hierarchy_collection = db["category_hierarchy"]
        metadata_collection = db["category_metadata"]
        
        response = {
            "best_sellers": {
                "title": "Best Sellers",
                "icon": "⭐",
                "main_categories": []
            },
            "sections": []
        }
        
        # Get Best Seller main categories
        best_seller_pipeline = [
            {"$match": {"is_best_seller": True, "active": True}},
            {"$group": {
                "_id": "$category_main",
                "count": {"$sum": 1}
            }},
            {"$sort": {"count": -1}}
        ]
        
        best_seller_mains = list(products_collection.aggregate(best_seller_pipeline))
        
        for main_cat in best_seller_mains:
            main_category_name = main_cat["_id"]
            
            # Get image from metadata if exists
            # Note: Best seller items come from various sections, so we need to find
            # any metadata for this main_category regardless of section
            metadata = metadata_collection.find_one({
                "main_category": main_category_name,
                "type": "main_category"
            })
            
            response["best_sellers"]["main_categories"].append({
                "id": f"best_seller_{main_category_name.lower().replace(' ', '_')}",
                "name": main_category_name,
                "image_url": metadata.get("image_url", "") if metadata else "",
                "product_count": main_cat["count"],
                "section": "Best Seller",
                "main_category": main_category_name
            })
        
        # Get all regular sections from hierarchy
        sections = list(hierarchy_collection.find({}))
        
        for section_doc in sections:
            section_name = section_doc.get("section")
            
            # Skip Best Seller if it exists in hierarchy (it's handled separately)
            if section_name == "Best Seller":
                continue
            
            section_data = {
                "title": section_name,
                "icon": "📂",
                "section_name": section_name,
                "main_categories": []
            }
            
            main_categories = section_doc.get("main_categories", {})
            
            for main_cat_name, main_cat_data in main_categories.items():
                # Count products in this main category
                product_count = products_collection.count_documents({
                    "category_section": section_name,
                    "category_main": main_cat_name,
                    "active": True
                })
                
                # Get image from metadata
                metadata = metadata_collection.find_one({
                    "section": section_name,
                    "main_category": main_cat_name,
                    "type": "main_category"
                })
                
                section_data["main_categories"].append({
                    "id": f"{section_name.lower().replace(' ', '_')}_{main_cat_name.lower().replace(' ', '_')}",
                    "name": main_cat_name,
                    "image_url": metadata.get("image_url", "") if metadata else "",
                    "product_count": product_count,
                    "section": section_name,
                    "main_category": main_cat_name
                })
            
            # Sort main categories by name
            section_data["main_categories"].sort(key=lambda x: x["name"])
            
            response["sections"].append(section_data)
        
        # Sort sections by name
        response["sections"].sort(key=lambda x: x["title"])
        
        logger.info(f"Home data prepared: {len(response['best_sellers']['main_categories'])} best seller categories, {len(response['sections'])} sections")
        
        return response
        
    except Exception as e:
        logger.error(f"Error fetching home data: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch home data: {str(e)}")


@router.get("/main-category/{section}/{main_category}/subcategories")
async def get_subcategories(section: str, main_category: str):
    """
    Get subcategories for a specific main category.
    
    Args:
    - section: Section name (URL decoded)
    - main_category: Main category name (URL decoded)
    
    Returns:
    - List of subcategories with product counts
    """
    try:
        # URL decode parameters
        section = unquote(section)
        main_category = unquote(main_category)
        
        db = get_mongo_db()
        products_collection = db["products"]
        hierarchy_collection = db["category_hierarchy"]
        
        # Get subcategories from hierarchy
        section_doc = hierarchy_collection.find_one({"section": section})
        
        if not section_doc:
            raise HTTPException(status_code=404, detail=f"Section not found: {section}")
        
        main_categories = section_doc.get("main_categories", {})
        
        if main_category not in main_categories:
            raise HTTPException(status_code=404, detail=f"Main category not found: {main_category}")
        
        # main_categories[main_category] is already a list of subcategories
        subcategories_list = main_categories[main_category]
        
        # Build response with product counts
        response = {
            "section": section,
            "main_category": main_category,
            "subcategories": []
        }
        
        for subcategory in subcategories_list:
            # Count products in this subcategory
            product_count = products_collection.count_documents({
                "category_section": section,
                "category_main": main_category,
                "category_sub": subcategory,
                "active": True
            })
            
            response["subcategories"].append({
                "name": subcategory,
                "product_count": product_count,
                "icon": "📦"  # Default icon, can be customized
            })
        
        logger.info(f"Retrieved {len(response['subcategories'])} subcategories for {section} > {main_category}")
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching subcategories: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch subcategories: {str(e)}")


@router.get("/products")
async def get_products(
    section: str = Query(..., description="Section name"),
    main_category: str = Query(..., description="Main category name"),
    subcategory: str = Query(..., description="Subcategory name"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Products per page")
):
    """
    Get products for a specific subcategory with pagination.
    
    Args:
    - section: Section name
    - main_category: Main category name
    - subcategory: Subcategory name
    - page: Page number (default: 1)
    - limit: Products per page (default: 20, max: 100)
    
    Returns:
    - Paginated list of products
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query
        query = {
            "category_section": section,
            "category_main": main_category,
            "category_sub": subcategory,
            "active": True
        }
        
        # Calculate pagination
        skip = (page - 1) * limit
        
        # Get total count
        total_products = products_collection.count_documents(query)
        total_pages = (total_products + limit - 1) // limit  # Ceiling division
        
        # Fetch products
        products_cursor = products_collection.find(query).skip(skip).limit(limit).sort("product_name", 1)
        
        products = []
        for prod in products_cursor:
            products.append({
                "item_id": prod.get("item_id"),
                "product_name": prod.get("product_name"),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": prod.get("image_url", prod.get("image", "")),
                "stock": prod.get("stock", 0),
                "in_stock": prod.get("stock", 0) > 0,
                "is_best_seller": prod.get("is_best_seller", False),
                "description": prod.get("description", "")
            })
        
        response = {
            "section": section,
            "main_category": main_category,
            "subcategory": subcategory,
            "products": products,
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_products": total_products,
                "per_page": limit,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
        
        logger.info(f"Retrieved {len(products)} products for {section} > {main_category} > {subcategory} (page {page})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch products: {str(e)}")


@router.get("/product/{item_id}")
async def get_product_details(item_id: str):
    """
    Get detailed information for a single product.
    
    Args:
    - item_id: Product item ID
    
    Returns:
    - Complete product details
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        product = products_collection.find_one({"item_id": item_id, "active": True})
        
        if not product:
            raise HTTPException(status_code=404, detail=f"Product not found: {item_id}")
        
        response = {
            "item_id": product.get("item_id"),
            "product_name": product.get("product_name"),
            "category": {
                "section": product.get("category_section"),
                "main_category": product.get("category_main"),
                "subcategory": product.get("category_sub")
            },
            "weight": product.get("weight", ""),
            "price": float(product.get("price", 0.0)),
            "stock": product.get("stock", 0),
            "in_stock": product.get("stock", 0) > 0,
            "is_best_seller": product.get("is_best_seller", False),
            "description": product.get("description", ""),
            "image_url": product.get("image_url", product.get("image", "")),
            "images": [
                product.get("image_url", product.get("image", ""))
            ]  # Can be extended for multiple images
        }
        
        logger.info(f"Retrieved product details for {item_id}")
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching product details: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch product details: {str(e)}")


@router.get("/search")
async def search_products(
    q: str = Query(..., min_length=1, description="Search query"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Results per page")
):
    """
    Search products globally across all categories.
    
    Args:
    - q: Search query
    - page: Page number (default: 1)
    - limit: Results per page (default: 20, max: 100)
    
    Returns:
    - Paginated search results
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build search query
        query = {
            "$and": [
                {"active": True},
                {
                    "$or": [
                        {"product_name": {"$regex": q, "$options": "i"}},
                        {"category_main": {"$regex": q, "$options": "i"}},
                        {"category_sub": {"$regex": q, "$options": "i"}},
                        {"description": {"$regex": q, "$options": "i"}}
                    ]
                }
            ]
        }
        
        # Calculate pagination
        skip = (page - 1) * limit
        
        # Get total count
        total_results = products_collection.count_documents(query)
        total_pages = (total_results + limit - 1) // limit
        
        # Fetch products
        products_cursor = products_collection.find(query).skip(skip).limit(limit).sort("product_name", 1)
        
        results = []
        for prod in products_cursor:
            results.append({
                "item_id": prod.get("item_id"),
                "product_name": prod.get("product_name"),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": prod.get("image_url", prod.get("image", "")),
                "category_breadcrumb": f"{prod.get('category_section')} → {prod.get('category_main')} → {prod.get('category_sub')}",
                "section": prod.get("category_section"),
                "main_category": prod.get("category_main"),
                "subcategory": prod.get("category_sub"),
                "in_stock": prod.get("stock", 0) > 0,
                "is_best_seller": prod.get("is_best_seller", False)
            })
        
        response = {
            "query": q,
            "results": results,
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_results": total_results,
                "per_page": limit,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
        
        logger.info(f"Search for '{q}' returned {len(results)} results (page {page})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error searching products: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to search products: {str(e)}")


@router.get("/best-sellers")
async def get_best_sellers(
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Products per page")
):
    """
    Get all best seller products with pagination.
    
    Args:
    - page: Page number (default: 1)
    - limit: Products per page (default: 20, max: 100)
    
    Returns:
    - Paginated list of best seller products
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query
        query = {
            "is_best_seller": True,
            "active": True
        }
        
        # Calculate pagination
        skip = (page - 1) * limit
        
        # Get total count
        total_products = products_collection.count_documents(query)
        total_pages = (total_products + limit - 1) // limit
        
        # Fetch products
        products_cursor = products_collection.find(query).skip(skip).limit(limit).sort("product_name", 1)
        
        products = []
        for prod in products_cursor:
            products.append({
                "item_id": prod.get("item_id"),
                "product_name": prod.get("product_name"),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": prod.get("image_url", prod.get("image", "")),
                "section": prod.get("category_section"),
                "main_category": prod.get("category_main"),
                "subcategory": prod.get("category_sub"),
                "category_breadcrumb": f"{prod.get('category_section')} → {prod.get('category_main')} → {prod.get('category_sub')}",
                "stock": prod.get("stock", 0),
                "in_stock": prod.get("stock", 0) > 0,
                "is_best_seller": True,  # All products in this endpoint are best sellers
                "description": prod.get("description", "")
            })
        
        response = {
            "products": products,
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_products": total_products,
                "per_page": limit,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
        
        logger.info(f"Retrieved {len(products)} best seller products (page {page})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error fetching best sellers: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch best sellers: {str(e)}")
