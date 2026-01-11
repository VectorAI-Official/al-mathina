"""
Flutter Mobile App API Routes
Provides optimized endpoints for Flutter mobile application.
"""
from fastapi import APIRouter, Query, HTTPException, Request
from typing import Optional, List, Dict, Any
from urllib.parse import unquote
import logging

from database.mongodb_client import get_mongo_db
from database.supabase_client import get_supabase_client
from utils.fcm_service import fcm_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/flutter", tags=["Flutter Mobile App"])


def make_absolute(request: Request, path: str) -> str:
    """Normalize image paths to absolute URLs using request.base_url.

    - If path is empty, return empty string
    - If path is a Cloudinary URL (https://res.cloudinary.com), return as-is
    - If path already starts with http/https (non-Cloudinary), extract path part and prefix with current base
    - Otherwise prefix with request.base_url
    """
    if not path:
        return ""
    p = path.strip()
    
    # If it's a Cloudinary URL, return it as-is (it's absolute and CDN-hosted)
    if 'cloudinary.com' in p:
        return p
    
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
            
            # Get IDs from metadata (added by migration)
            section_id = metadata.get("section_id") if metadata else None
            main_category_id = metadata.get("main_category_id") if metadata else None
            
            response["best_sellers"]["main_categories"].append({
                "id": f"most_bought_{section.lower().replace(' ', '_')}_{main_category.lower().replace(' ', '_')}",
                "name": display_name,
                "image_url": make_absolute(request, metadata.get("image_url", "") if metadata else ""),
                "product_count": product_count,
                "section": section,
                "main_category": main_category,
                "section_id": section_id,  # New: ID-based reference
                "main_category_id": main_category_id,  # New: ID-based reference
            })
        
        # Get all regular sections from hierarchy
        sections = list(hierarchy_collection.find({}))
        
        for section_doc in sections:
            section_name = section_doc.get("section")
            
            # Skip sections with no name or "Most Bought"
            if not section_name or section_name == "Most Bought":
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
                
                # Get IDs from metadata or hierarchy (added by migration)
                section_id = section_doc.get("section_id")
                # main_cat_data is a list (array of subcategories), not a dict, so get ID from metadata only
                main_category_id = metadata.get("main_category_id") if metadata else None
                
                section_data["main_categories"].append({
                    "id": f"{section_name.lower().replace(' ', '_')}_{main_cat_name.lower().replace(' ', '_')}",
                    "name": main_cat_display_name,
                    "image_url": make_absolute(request, metadata.get("image_url", "") if metadata else ""),
                    "product_count": product_count,
                    "section": section_name,
                    "main_category": main_cat_name,
                    "section_id": section_id,  # New: ID-based reference
                    "main_category_id": main_category_id,  # New: ID-based reference
                })
            
            # Sort main categories by name (handle None values)
            section_data["main_categories"].sort(key=lambda x: x["name"] or "")
            
            response["sections"].append(section_data)
        
        # Sort sections by name (handle None values)
        response["sections"].sort(key=lambda x: x["title"] or "")
        
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
    user_phone: str = Query(None, description="User phone number for admin check"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Products per page")
):
    """
    Get products with optional filters and pagination.
    NOW SUPPORTS ADMIN USERS: If user_phone belongs to an admin, buying_price is included in response.
    
    Args:
    - section: Section name (optional)
    - main_category: Main category name (optional)
    - subcategory: Subcategory name (optional)
    - user_phone: User phone number to check admin status (optional)
    - page: Page number (default: 1)
    - limit: Products per page (default: 20, max: 100)
    
    Returns:
    - Paginated list of products (with buying_price if admin user)
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Check if user is admin
        is_admin = False
        if user_phone:
            try:
                from database.supabase_client import get_supabase_client
                supabase = get_supabase_client()
                
                # Try with the phone as-is first
                user_response = supabase.table('users').select('is_admin').eq('phone', user_phone).execute()
                
                # If not found and phone doesn't have +91, try adding it
                if (not user_response.data or len(user_response.data) == 0) and not user_phone.startswith('+'):
                    user_response = supabase.table('users').select('is_admin').eq('phone', f'+91{user_phone}').execute()
                
                if user_response.data and len(user_response.data) > 0:
                    is_admin = user_response.data[0].get('is_admin', False)
                    logger.info(f"User {user_phone} admin status: {is_admin}")
            except Exception as e:
                logger.warning(f"Failed to check admin status for {user_phone}: {e}")
        
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
            product_data = {
                "item_id": prod.get("item_id"),
                "section": prod.get("category_section"),  # Fix: use category_section from DB
                "main_category": prod.get("category_main"),  # Fix: use category_main from DB
                "subcategory": prod.get("category_sub"),  # Fix: use category_sub from DB
                "product_name": prod.get("product_name"),
                "product_name_ta": prod.get("product_name_ta", ""),
                "weight": prod.get("weight", ""),
                "price": float(prod.get("price", 0.0)),
                "image_url": make_absolute(request, raw_image),
                "stock": prod.get("stock", 0),
                "in_stock": prod.get("stock", 0) > 0,
                "is_best_seller": prod.get("is_best_seller", False),
                "description": prod.get("description", "")
            }
            
            # Add buying_price ONLY for admin users
            if is_admin:
                product_data["buying_price"] = float(prod.get("buying_price", 0.0))
            
            products.append(product_data)
        
        response = {
            "products": products,
            "is_admin": is_admin,  # Include admin status in response
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
        
        logger.info(f"Retrieved {len(products)} products (admin={is_admin}, filters: section={section}, main_category={main_category}, subcategory={subcategory}, page={page})")
        
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
            "section": product.get("category_section"),  # Add flat section field
            "main_category": product.get("category_main"),  # Add flat main_category field
            "subcategory": product.get("category_sub"),  # Add flat subcategory field
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
    limit: int = Query(20, ge=1, le=100, description="Results per page"),
    regex: bool = Query(False, description="Enable regex search mode"),
    user_phone: Optional[str] = Query(None, description="User's phone number for admin check")
):
    """
    Search products globally across all categories.
    
    Args:
    - q: Search query
    - page: Page number (default: 1)
    - limit: Results per page (default: 20, max: 100)
    - regex: Enable regex pattern matching (default: False)
    - user_phone: User's phone number (optional, for admin buying price display)
    
    Returns:
    - Paginated search results with admin buying price if applicable
    """
    try:
        db = get_mongo_db()
        products_collection = db["products"]
        
        # Check if user is admin
        is_admin = False
        if user_phone:
            try:
                from database.supabase_client import get_supabase_client
                supabase = get_supabase_client()
                
                # Try with the phone as-is first
                user_response = supabase.table('users').select('is_admin').eq('phone', user_phone).execute()
                
                # If not found and phone doesn't have +91, try adding it
                if (not user_response.data or len(user_response.data) == 0) and not user_phone.startswith('+'):
                    user_response = supabase.table('users').select('is_admin').eq('phone', f'+91{user_phone}').execute()
                
                if user_response.data and len(user_response.data) > 0:
                    is_admin = user_response.data[0].get('is_admin', False)
                    logger.info(f"Search - User {user_phone} admin status: {is_admin}")
            except Exception as e:
                logger.warning(f"Failed to check admin status for {user_phone}: {e}")
        
        # Build search query with optional regex mode
        # If regex=true, use the query as a regex pattern directly
        # If regex=false, escape special chars and do case-insensitive substring match
        if regex:
            # Use query as regex pattern (be careful with user input!)
            import re
            try:
                # Validate regex pattern
                re.compile(q)
                search_pattern = q
            except re.error:
                # If invalid regex, fall back to escaped literal search
                search_pattern = re.escape(q)
        else:
            # Escape special regex characters for literal search
            import re
            search_pattern = re.escape(q)
        
        query = {
            "$and": [
                {"active": True},
                {
                    "$or": [
                        {"product_name": {"$regex": search_pattern, "$options": "i"}},
                        {"product_name_ta": {"$regex": search_pattern, "$options": "i"}},
                        {"category_main": {"$regex": search_pattern, "$options": "i"}},
                        {"category_sub": {"$regex": search_pattern, "$options": "i"}},
                        {"description": {"$regex": search_pattern, "$options": "i"}}
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
            product_data = {
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
            }
            
            # Add buying_price ONLY for admin users
            if is_admin:
                product_data["buying_price"] = float(prod.get("buying_price", 0.0))
            
            results.append(product_data)
        
        response = {
            "query": q,
            "results": results,
            "is_admin": is_admin,  # Include admin status in response
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_results": total_results,
                "per_page": limit,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
        
        logger.info(f"Search for '{q}' returned {len(results)} results (page {page}, admin={is_admin})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error searching products: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to search products: {str(e)}")


@router.get("/favorites/{user_id}")
async def get_user_favorites(
    request: Request,
    user_id: str,
    lang: str = Query("en", description="Language code (en or ta)")
):
    """
    Get user's favorite products.
    
    Args:
    - user_id: Unique user identifier
    - lang: Language code ("en" for English, "ta" for Tamil). Default: "en"
    
    Returns:
    - List of favorite products with details
    """
    try:
        db = get_mongo_db()
        favorites_collection = db["user_favorites"]
        products_collection = db["products"]
        
        # Get user's favorites
        favorites_doc = favorites_collection.find_one({"user_id": user_id})
        
        if not favorites_doc:
            return {
                "user_id": user_id,
                "favorites": [],
                "total_count": 0
            }
        
        favorite_items = favorites_doc.get("items", [])
        
        results = []
        for item_id in favorite_items:
            product = products_collection.find_one({"item_id": item_id, "active": True})
            if product:
                product_name = product.get("product_name")
                if lang == "ta" and product.get("product_name_ta"):
                    product_name = product.get("product_name_ta")
                
                results.append({
                    "item_id": product.get("item_id"),
                    "product_name": product.get("product_name"),
                    "product_name_display": product_name,
                    "product_name_ta": product.get("product_name_ta", ""),
                    "weight": product.get("weight", ""),
                    "price": float(product.get("price", 0.0)),
                    "image_url": make_absolute(request, product.get("image_url", product.get("image", ""))),
                    "category": {
                        "section": product.get("category_section"),
                        "main_category": product.get("category_main"),
                        "subcategory": product.get("category_sub")
                    },
                    "in_stock": product.get("stock", 0) > 0,
                    "stock": product.get("stock", 0)
                })
        
        logger.info(f"Retrieved {len(results)} favorites for user {user_id}")
        
        return {
            "user_id": user_id,
            "favorites": results,
            "total_count": len(results)
        }
        
    except Exception as e:
        logger.error(f"Error fetching favorites for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch favorites: {str(e)}")


@router.post("/favorites/{user_id}/{item_id}")
async def add_to_favorites(user_id: str, item_id: str):
    """
    Add product to user's favorites.
    
    Args:
    - user_id: Unique user identifier
    - item_id: Product item ID
    
    Returns:
    - Success message
    """
    try:
        db = get_mongo_db()
        favorites_collection = db["user_favorites"]
        products_collection = db["products"]
        
        # Verify product exists
        product = products_collection.find_one({"item_id": item_id, "active": True})
        if not product:
            raise HTTPException(status_code=404, detail=f"Product not found: {item_id}")
        
        # Add to favorites (avoid duplicates)
        result = favorites_collection.update_one(
            {"user_id": user_id},
            {
                "$addToSet": {"items": item_id},
                "$set": {"updated_at": __import__("datetime").datetime.utcnow()}
            },
            upsert=True
        )
        
        logger.info(f"Added product {item_id} to favorites for user {user_id}")
        
        return {
            "success": True,
            "message": "Product added to favorites",
            "item_id": item_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding to favorites: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to add to favorites: {str(e)}")


@router.delete("/favorites/{user_id}/{item_id}")
async def remove_from_favorites(user_id: str, item_id: str):
    """
    Remove product from user's favorites.
    
    Args:
    - user_id: Unique user identifier
    - item_id: Product item ID
    
    Returns:
    - Success message
    """
    try:
        db = get_mongo_db()
        favorites_collection = db["user_favorites"]
        
        result = favorites_collection.update_one(
            {"user_id": user_id},
            {
                "$pull": {"items": item_id},
                "$set": {"updated_at": __import__("datetime").datetime.utcnow()}
            }
        )
        
        logger.info(f"Removed product {item_id} from favorites for user {user_id}")
        
        return {
            "success": True,
            "message": "Product removed from favorites",
            "item_id": item_id
        }
        
    except Exception as e:
        logger.error(f"Error removing from favorites: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to remove from favorites: {str(e)}")


@router.get("/orders/{user_id}")
async def get_user_orders(
    request: Request,
    user_id: str,
    status: Optional[str] = Query(None, description="Filter by order status (pending, completed, cancelled)"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(10, ge=1, le=50, description="Orders per page"),
    lang: str = Query("en", description="Language code (en or ta)")
):
    """
    Get user's orders with optional status filter and pagination.
    
    Args:
    - user_id: Unique user identifier
    - status: Optional filter by order status
    - page: Page number (default: 1)
    - limit: Orders per page (default: 10, max: 50)
    - lang: Language code ("en" for English, "ta" for Tamil). Default: "en"
    
    Returns:
    - Paginated list of user's orders with details
    """
    try:
        db = get_mongo_db()
        orders_collection = db["orders"]
        products_collection = db["products"]
        
        # Build query
        query = {"user_id": user_id}
        if status:
            query["status"] = status
        
        # Calculate pagination
        skip = (page - 1) * limit
        
        # Get total count
        total_orders = orders_collection.count_documents(query)
        total_pages = (total_orders + limit - 1) // limit
        
        # Fetch orders
        orders_cursor = orders_collection.find(query).skip(skip).limit(limit).sort("created_at", -1)
        
        results = []
        for order in orders_cursor:
            # Get order items with product details
            items = []
            for item in order.get("items", []):
                product = products_collection.find_one({"item_id": item.get("item_id")})
                if product:
                    product_name = product.get("product_name")
                    if lang == "ta" and product.get("product_name_ta"):
                        product_name = product.get("product_name_ta")
                    
                    items.append({
                        "item_id": product.get("item_id"),
                        "product_name": product.get("product_name"),
                        "product_name_display": product_name,
                        "quantity": item.get("quantity", 1),
                        "price": float(item.get("price", 0.0)),
                        "total": float(item.get("quantity", 1)) * float(item.get("price", 0.0)),
                        "image_url": make_absolute(request, product.get("image_url", product.get("image", "")))
                    })
            
            results.append({
                "order_id": str(order.get("_id")),
                "user_id": order.get("user_id"),
                "status": order.get("status", "pending"),
                "total_amount": float(order.get("total_amount", 0.0)),
                "items_count": len(items),
                "items": items,
                "delivery_address": order.get("delivery_address", ""),
                "payment_method": order.get("payment_method", ""),
                "created_at": order.get("created_at", "").isoformat() if order.get("created_at") else "",
                "updated_at": order.get("updated_at", "").isoformat() if order.get("updated_at") else "",
                "estimated_delivery": order.get("estimated_delivery", "")
            })
        
        response = {
            "user_id": user_id,
            "orders": results,
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_orders": total_orders,
                "per_page": limit,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
        
        logger.info(f"Retrieved {len(results)} orders for user {user_id} (page {page})")
        
        return response
        
    except Exception as e:
        logger.error(f"Error fetching orders for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch orders: {str(e)}")


@router.post("/orders")
async def create_order(request: Request):
    """
    Create a new order.
    
    Request body:
    {
        "user_id": "user_123",
        "items": [
            {"item_id": "PROD001", "quantity": 2, "price": 100.0},
            {"item_id": "PROD002", "quantity": 1, "price": 50.0}
        ],
        "delivery_address": "123 Main St, City",
        "payment_method": "card|upi|cod",
        "total_amount": 250.0
    }
    
    Returns:
    - Created order details
    """
    try:
        db = get_mongo_db()
        orders_collection = db["orders"]
        data = await request.json()
        
        user_id = data.get("user_id")
        items = data.get("items", [])
        delivery_address = data.get("delivery_address")
        payment_method = data.get("payment_method")
        total_amount = data.get("total_amount", 0.0)
        
        if not user_id or not items or not delivery_address:
            raise HTTPException(status_code=400, detail="Missing required fields: user_id, items, delivery_address")
        
        from datetime import datetime, timedelta, timezone
        import random
        import string
        
        # Generate unique order_id (format: ORD-YYYYMMDD-XXXXX)
        # Use local timezone (India Standard Time - UTC+5:30)
        ist_offset = timezone(timedelta(hours=5, minutes=30))
        current_time = datetime.now(ist_offset)
        
        date_str = current_time.strftime("%Y%m%d")
        random_str = ''.join(random.choices(string.ascii_uppercase + string.digits, k=5))
        order_id = f"ORD-{date_str}-{random_str}"
        
        # Get user details for enrichment (supports both user_id and phone-based lookups)
        users_collection = db["users"]
        user_doc = users_collection.find_one({"user_id": user_id}) or users_collection.find_one({"phone": user_id})
        
        order_doc = {
            "order_id": order_id,  # NEW: Unique order ID
            "user_id": user_id,
            "user_phone": user_doc.get("phone") if user_doc else user_id,  # NEW: For admin compatibility
            "items": items,
            "delivery_address": delivery_address,
            "payment_method": payment_method or "cod",
            "total_amount": float(total_amount),
            "status": "pending",
            "created_at": current_time,
            "updated_at": current_time,
            "estimated_delivery": (current_time + timedelta(days=3)).isoformat()
        }
        
        result = orders_collection.insert_one(order_doc)
        
        logger.info(f"Created order {order_id} (MongoDB ID: {result.inserted_id}) for user {user_id} at {current_time.isoformat()}")
        
        # 🔔 SEND PUSH NOTIFICATION TO USER
        try:
            # Get user's FCM token from Supabase
            supabase = get_supabase_client()
            user_phone = user_doc.get("phone") if user_doc else user_id
            
            fcm_result = supabase.table("users").select("fcm_token, store_name").eq("phone", user_phone).execute()
            
            if fcm_result.data and fcm_result.data[0].get("fcm_token"):
                fcm_token = fcm_result.data[0]["fcm_token"]
                store_name = fcm_result.data[0].get("store_name")
                
                # Send notification
                notification_sent = await fcm_service.send_order_notification(
                    fcm_token=fcm_token,
                    order_id=order_id,
                    total_amount=float(total_amount),
                    items_count=len(items),
                    store_name=store_name
                )
                
                if notification_sent:
                    logger.info(f"✅ Push notification sent for order {order_id}")
                else:
                    logger.warning(f"⚠️ Failed to send push notification for order {order_id}")
            else:
                logger.info(f"ℹ️ No FCM token found for user {user_phone}. Notification not sent.")
                
        except Exception as fcm_error:
            # Don't fail order creation if notification fails
            logger.error(f"❌ Error sending FCM notification: {fcm_error}")
        
        return {
            "success": True,
            "message": "Order created successfully",
            "order_id": order_id,  # Return the readable order_id
            "mongodb_id": str(result.inserted_id),  # Also return MongoDB _id
            "status": "pending",
            "created_at": order_doc["created_at"].isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating order: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create order: {str(e)}")

