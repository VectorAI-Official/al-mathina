"""
Flutter Mobile App API Routes
Provides optimized endpoints for Flutter mobile application.
"""
from fastapi import APIRouter, Query, HTTPException, Request
from typing import Optional, List, Dict, Any
from urllib.parse import unquote
import logging

from database.mongodb_client import get_mongo_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/flutter", tags=["Flutter Mobile App"])


def make_absolute(request: Request, path: str) -> str:
    """Normalize image paths to absolute URLs using request.base_url.

    - If path is empty, return empty string
    - If path already starts with http/https, replace host with current request host
    - Otherwise prefix with request.base_url
    """
    if not path:
        return ""
    p = path.strip()
    
    # Get current request's base URL
    base = str(request.base_url).rstrip('/')
    
    if p.startswith('http://') or p.startswith('https://'):
        # Extract the path part after the domain
        # Handle both http://127.0.0.1:8000/path and http://192.168.1.6:8000/path
        import re
        match = re.match(r'https?://[^/]+(/.+)', p)
        if match:
            path_part = match.group(1)
            return f"{base}{path_part}"
        return p  # Return as-is if no path part found
    
    # Relative path
    if not p.startswith('/'):
        p = '/' + p
    return f"{base}{p}"


@router.get("/home")
async def get_home_data(request: Request, lang: str = Query("en", description="Language code (en or ta)")):
    """
    Get all sections and main categories for home page with language support.
    
    Args:
    - lang: Language code ("en" for English, "ta" for Tamil). Default: "en"
    
    Returns:
    - Best Sellers section with main categories
    - All regular sections with their main categories
    - Product counts for each main category
    - Names in requested language when available
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        hierarchy_collection = db["category_hierarchy"]
        metadata_collection = db["category_metadata"]
        most_bought_collection = db["most_bought"]
        
        response = {
            "best_sellers": {
                "title": "Most Bought",
                "icon": "⭐",
                "main_categories": []
            },
            "sections": []
        }
        
        # Get Most Bought main categories from most_bought collection
        most_bought_items = list(most_bought_collection.find().sort("starred_at", -1))
        
        for item in most_bought_items:
            section = item.get("section")
            main_category = item.get("main_category")
            
            # Count products in this main category
            product_count = products_collection.count_documents({
                "category_section": section,
                "category_main": main_category,
                "active": True
            })
            
            # Get image from metadata
            # Try exact match with section and name
            metadata = metadata_collection.find_one({
                "type": "main_category",
                "section": section,
                "name": main_category
            })
            
            if not metadata:
                # Fallback: try to find by name alone (for backwards compatibility)
                metadata = metadata_collection.find_one({
                    "type": "main_category",
                    "name": main_category
                })
            
            if not metadata:
                # Legacy fallback: try main_category field (old format)
                metadata = metadata_collection.find_one({
                    "type": "main_category",
                    "main_category": main_category
                })
            
            # Get display name based on language
            display_name = main_category  # Default to English
            if lang == "ta" and metadata and metadata.get("name_ta"):
                display_name = metadata.get("name_ta")
            
            response["best_sellers"]["main_categories"].append({
                "id": f"most_bought_{section.lower().replace(' ', '_')}_{main_category.lower().replace(' ', '_')}",
                "name": display_name,
                "image_url": make_absolute(request, metadata.get("image_url", "") if metadata else ""),
                "product_count": product_count,
                "section": section,
                "main_category": main_category
            })
        
        # Get all regular sections from hierarchy
        sections = list(hierarchy_collection.find({}))
        
        for section_doc in sections:
            section_name = section_doc.get("section")
            
            # Skip Best Seller if it exists in hierarchy (it's handled separately)
            if section_name == "Most Bought":
                continue
            
            # Get display name for section based on language
            section_display_name = section_name  # Default to English
            if lang == "ta" and section_doc.get("section_ta"):
                section_display_name = section_doc.get("section_ta")
            
            section_data = {
                "title": section_display_name,
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
                    "type": "main_category",
                    "$or": [
                        {"main_category": main_cat_name},
                        {"name": main_cat_name}
                    ]
                })
                
                # Get display name based on language
                main_cat_display_name = main_cat_name  # Default to English
                if lang == "ta" and metadata and metadata.get("name_ta"):
                    main_cat_display_name = metadata.get("name_ta")
                
                section_data["main_categories"].append({
                    "id": f"{section_name.lower().replace(' ', '_')}_{main_cat_name.lower().replace(' ', '_')}",
                    "name": main_cat_display_name,
                    "image_url": make_absolute(request, metadata.get("image_url", "") if metadata else ""),
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
async def get_subcategories(request: Request, section: str, main_category: str, lang: str = Query("en", description="Language code (en or ta)")):
    """
    Get subcategories for a specific main category with language support.
    
    Args:
    - section: Section name (URL decoded)
    - main_category: Main category name (URL decoded)
    - lang: Language code ("en" for English, "ta" for Tamil). Default: "en"
    
    Returns:
    - List of subcategories with product counts and names in requested language
    """
    try:
        # URL decode parameters
        section = unquote(section)
        main_category = unquote(main_category)
        

        db = get_mongo_db()
        products_collection = db["products"]
        hierarchy_collection = db["category_hierarchy"]
        metadata_collection = db["category_metadata"]

        # Get subcategories from hierarchy
        section_doc = hierarchy_collection.find_one({"section": section})
        if not section_doc:
            raise HTTPException(status_code=404, detail=f"Section not found: {section}")

        main_categories = section_doc.get("main_categories", {})
        if main_category not in main_categories:
            raise HTTPException(status_code=404, detail=f"Main category not found: {main_category}")

        subcategories_list = main_categories[main_category]

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
            # Get image from metadata (type: subcategory)
            metadata = metadata_collection.find_one({
                "section": section,
                "main_category": main_category,
                "type": "subcategory",
                "$or": [
                    {"subcategory": subcategory},
                    {"name": subcategory}
                ]
            })
            
            # Get display name based on language
            subcategory_display_name = subcategory  # Default to English
            if lang == "ta" and metadata and metadata.get("name_ta"):
                subcategory_display_name = metadata.get("name_ta")
            
            image_url = metadata.get("image_url", "") if metadata else ""
            # Fallback: if no specific subcategory image, try main category metadata only.
            if not image_url:
                main_meta = metadata_collection.find_one({
                    "section": section,
                    "type": "main_category",
                    "$or": [
                        {"main_category": main_category},
                        {"name": main_category}
                    ]
                })
                if main_meta and main_meta.get("image_url"):
                    image_url = main_meta.get("image_url", "")
            # convert to absolute URL if needed
            image_url = make_absolute(request, image_url)
            response["subcategories"].append({
                "name": subcategory,  # Always English name for API queries
                "name_display": subcategory_display_name,  # Localized name for display
                "product_count": product_count,
                "icon": "📦",  # Default icon, can be customized
                "image_url": image_url
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
    request: Request,
    section: str = Query(None, description="Section name"),
    main_category: str = Query(None, description="Main category name"),
    subcategory: str = Query(None, description="Subcategory name"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Products per page")
):
    """
    Get products with optional filters and pagination.
    
    Args:
    - section: Section name (optional)
    - main_category: Main category name (optional)
    - subcategory: Subcategory name (optional)
    - page: Page number (default: 1)
    - limit: Products per page (default: 20, max: 100)
    
    Returns:
    - Paginated list of products
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Build query with optional filters
        query = {"active": True}
        
        if section:
            query["category_section"] = section
        if main_category:
            query["category_main"] = main_category
        if subcategory:
            query["category_sub"] = subcategory
        
        # Calculate pagination
        skip = (page - 1) * limit
        
        # Get total count
        total_products = products_collection.count_documents(query)
        total_pages = (total_products + limit - 1) // limit  # Ceiling division
        
        # Fetch products
        products_cursor = products_collection.find(query).skip(skip).limit(limit).sort("product_name", 1)
        
        products = []
        for prod in products_cursor:
            raw_image = prod.get("image_url", prod.get("image", ""))
            products.append({
                "item_id": prod.get("item_id"),
                "section": prod.get("section"),
                "main_category": prod.get("main_category"),
                "subcategory": prod.get("subcategory"),
                "product_name": prod.get("product_name"),
                "product_name_ta": prod.get("product_name_ta", ""),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": make_absolute(request, raw_image),
                "stock": prod.get("stock", 0),
                "in_stock": prod.get("stock", 0) > 0,
                "is_best_seller": prod.get("is_best_seller", False),
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
        
        # Add filter info if provided
        if section:
            response["section"] = section
        if main_category:
            response["main_category"] = main_category
        if subcategory:
            response["subcategory"] = subcategory
        
        logger.info(f"Retrieved {len(products)} products (filters: section={section}, main_category={main_category}, subcategory={subcategory}, page={page})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch products: {str(e)}")


@router.get("/product/{item_id}")
async def get_product_details(request: Request, item_id: str):
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
            "product_name_ta": product.get("product_name_ta", ""),
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
            "image_url": make_absolute(request, product.get("image_url", product.get("image", ""))),
            "images": [
                make_absolute(request, product.get("image_url", product.get("image", "")))
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
    request: Request,
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
                        {"product_name_ta": {"$regex": q, "$options": "i"}},
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
            raw_image = prod.get("image_url", prod.get("image", ""))
            results.append({
                "item_id": prod.get("item_id"),
                "product_name": prod.get("product_name"),
                "product_name_ta": prod.get("product_name_ta", ""),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": make_absolute(request, raw_image),
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
