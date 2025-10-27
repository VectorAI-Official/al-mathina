"""
MongoDB client for catalog data.
Handles product categories, brand listings, inventory, and pricing.
Supports both local development and production (MongoDB Atlas).
"""
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError
from typing import Optional
import logging
import os
import ssl
import certifi

# Determine environment and import appropriate config
import sys

# Try to detect environment
try:
    # Check if config_production was already imported (set ENVIRONMENT in main_production.py)
    if 'config_production' in sys.modules or os.getenv('ENVIRONMENT') == 'production' or os.getenv('RENDER'):
        from config_production import settings
        logger = logging.getLogger(__name__)
        logger.info("🌐 Using PRODUCTION configuration (Render/MongoDB Atlas)")
    else:
        raise ImportError("Not in production, try local")
except Exception as e:
    try:
        from config_local import settings
        logger = logging.getLogger(__name__)
        logger.info("🏠 Using LOCAL configuration (MongoDB localhost)")
    except Exception:
        try:
            from config_production import settings
            logger = logging.getLogger(__name__)
            logger.info("🌐 Using PRODUCTION configuration (fallback)")
        except Exception:
            logger.error("❌ Failed to import any config - this should not happen")
            raise

# MongoDB Client (singleton pattern)
_mongo_client: Optional[MongoClient] = None
_mongo_db = None


def get_mongo_client() -> MongoClient:
    """
    Get or create MongoDB client instance.
    Uses singleton pattern to reuse connection.
    Note: For Python 3.13 SSL bug with MongoDB Atlas, connection is lazy.
    Connection will be established on first actual database operation.
    """
    global _mongo_client
    if _mongo_client is None:
        try:
            # Check if using MongoDB Atlas (production)
            is_atlas = 'mongodb.net' in settings.mongo_uri or os.getenv('ENVIRONMENT') == 'production'
            
            if is_atlas:
                # MongoDB Atlas connection - lazy initialization to avoid SSL handshake on startup
                # Python 3.13 has SSL bug that causes TLSV1_ALERT_INTERNAL_ERROR
                # Connection will work on first database operation (not on ping)
                _mongo_client = MongoClient(
                    settings.mongo_uri,
                    serverSelectionTimeoutMS=30000,  # Increased timeout
                    connectTimeoutMS=30000,
                    socketTimeoutMS=30000,
                    tls=True,
                    tlsAllowInvalidCertificates=True,
                    retryWrites=True,
                    connect=False  # Lazy connection - don't connect until first operation
                )
                logger.info("🌐 MongoDB Atlas client created (lazy connection - will connect on first use)")
            else:
                # Local MongoDB connection
                _mongo_client = MongoClient(
                    settings.mongo_uri,
                    serverSelectionTimeoutMS=5000,
                    connectTimeoutMS=10000,
                    socketTimeoutMS=10000
                )
                logger.info("🏠 Connecting to local MongoDB...")
            
            # Only test local connections
            if not is_atlas:
                _mongo_client.admin.command('ping')
                logger.info("✓ MongoDB connection established successfully")
            else:
                logger.info("⏳ Atlas connection will be tested on first database operation")
        except (ConnectionFailure, ServerSelectionTimeoutError) as e:
            logger.error(f"✗ MongoDB connection failed: {e}")
            raise
    return _mongo_client


def get_mongo_db():
    """
    Get MongoDB database instance.
    Returns the configured database for the application.
    """
    global _mongo_db
    if _mongo_db is None:
        client = get_mongo_client()
        _mongo_db = client[settings.mongo_db_name]
        logger.info(f"✓ Connected to MongoDB database: {settings.mongo_db_name}")
    return _mongo_db


def close_mongo_connection():
    """Close the MongoDB connection."""
    global _mongo_client, _mongo_db
    if _mongo_client:
        _mongo_client.close()
        _mongo_client = None
        _mongo_db = None
        logger.info("MongoDB connection closed")


def test_mongo_connection() -> bool:
    """
    Test the MongoDB connection.
    For Atlas with Python 3.13, we'll test by listing databases instead of ping.
    """
    try:
        client = get_mongo_client()
        is_atlas = 'mongodb.net' in settings.mongo_uri or os.getenv('ENVIRONMENT') == 'production'
        
        if is_atlas:
            # For Atlas, test with a lightweight operation
            # This will establish the connection if lazy
            db = get_mongo_db()
            # Just check if we can access the database
            _ = db.list_collection_names()
            logger.info("✓ MongoDB Atlas connection test successful (lazy connect)")
        else:
            # For local, use ping
            client.admin.command('ping')
            logger.info("✓ MongoDB connection test successful")
        return True
    except Exception as e:
        logger.error(f"✗ MongoDB connection test failed: {e}")
        return False


def init_mongo_collections():
    """
    Initialize MongoDB collections with sample data structure.
    Creates collections and indexes if they don't exist.
    """
    try:
        db = get_mongo_db()
        
        # Initialize category hierarchy
        from database.category_hierarchy import init_category_hierarchy
        init_category_hierarchy()
        
        # Categories Collection
        if "categories" not in db.list_collection_names():
            db.create_collection("categories")
            categories_collection = db["categories"]
            
            # Create sample categories matching your Flutter app
            sample_categories = [
                {
                    "name": "Atta",
                    "name_ta": "மாவு",
                    "icon": "local_dining",
                    "image_path": "assets/categories/atta.png",
                    "order": 1,
                    "active": True
                },
                {
                    "name": "Soap",
                    "name_ta": "சோப்பு",
                    "icon": "soap",
                    "order": 2,
                    "active": True
                },
                {
                    "name": "Shampoo",
                    "name_ta": "ஷாம்பூ",
                    "icon": "spa",
                    "order": 3,
                    "active": True
                },
                {
                    "name": "Paste",
                    "name_ta": "பேஸ்ட்",
                    "icon": "paste",
                    "order": 4,
                    "active": True
                },
                {
                    "name": "Oil",
                    "name_ta": "எண்ணெய்",
                    "icon": "oil_barrel",
                    "order": 5,
                    "active": True
                },
                {
                    "name": "Brush",
                    "name_ta": "தூரிகை",
                    "icon": "brush",
                    "order": 6,
                    "active": True
                }
            ]
            categories_collection.insert_many(sample_categories)
            categories_collection.create_index("name", unique=True)
            categories_collection.create_index("order")
            logger.info("✓ Categories collection initialized with sample data")
        
        # Products Collection
        if "products" not in db.list_collection_names():
            db.create_collection("products")
            products_collection = db["products"]
            
            # Create sample products with nested categorization
            sample_products = [
                # Best Seller → Drinks & Juices → Soft Drinks
                {
                    "item_id": "prod_sprite_001",
                    "product_name": "Sprite 600ml Bottle",
                    "category_section": "Best Seller",
                    "category_main": "Drinks & Juices",
                    "category_sub": "Soft Drinks",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Sprite",
                    "weight": "600ml",
                    "price": 40.00,
                    "stock": 150,
                    "active": True,
                    "description": "Refreshing lemon-lime flavored carbonated drink"
                },
                {
                    "item_id": "prod_cocacola_001",
                    "product_name": "Coca-Cola 1L Bottle",
                    "category_section": "Best Seller",
                    "category_main": "Drinks & Juices",
                    "category_sub": "Soft Drinks",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Coca-Cola",
                    "weight": "1L",
                    "price": 60.00,
                    "stock": 200,
                    "active": True,
                    "description": "Classic Coca-Cola carbonated soft drink"
                },
                # Best Seller → Atta, Rice & Dal → Basmati Rice
                {
                    "item_id": "prod_daawat_001",
                    "product_name": "Daawat Basmati Rice 5kg",
                    "category_section": "Best Seller",
                    "category_main": "Atta, Rice & Dal",
                    "category_sub": "Basmati Rice",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Daawat+Rice",
                    "weight": "5kg",
                    "price": 450.00,
                    "stock": 80,
                    "active": True,
                    "description": "Premium aged Basmati rice with extra long grains"
                },
                {
                    "item_id": "prod_indiagate_001",
                    "product_name": "India Gate Basmati Rice 1kg",
                    "category_section": "Best Seller",
                    "category_main": "Atta, Rice & Dal",
                    "category_sub": "Basmati Rice",
                    "image_url": "https://via.placeholder.com/300x300.png?text=India+Gate",
                    "weight": "1kg",
                    "price": 120.00,
                    "stock": 120,
                    "active": True,
                    "description": "Authentic Indian Basmati rice"
                },
                # Groceries → Cooking Essentials → Cooking Oil
                {
                    "item_id": "prod_fortune_oil_001",
                    "product_name": "Fortune Sunflower Oil 1L",
                    "category_section": "Groceries",
                    "category_main": "Cooking Essentials",
                    "category_sub": "Cooking Oil",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Fortune+Oil",
                    "weight": "1L",
                    "price": 150.00,
                    "stock": 100,
                    "active": True,
                    "description": "Pure sunflower oil for healthy cooking"
                },
                {
                    "item_id": "prod_saffola_001",
                    "product_name": "Saffola Gold Oil 2L",
                    "category_section": "Groceries",
                    "category_main": "Cooking Essentials",
                    "category_sub": "Cooking Oil",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Saffola",
                    "weight": "2L",
                    "price": 380.00,
                    "stock": 60,
                    "active": True,
                    "description": "Blended oil with losorb technology"
                },
                # Groceries → Atta, Rice & Dal → Wheat Flour
                {
                    "item_id": "prod_aashirvaad_001",
                    "product_name": "Aashirvaad Atta 10kg",
                    "category_section": "Groceries",
                    "category_main": "Atta, Rice & Dal",
                    "category_sub": "Wheat Flour",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Aashirvaad",
                    "weight": "10kg",
                    "price": 420.00,
                    "stock": 90,
                    "active": True,
                    "description": "100% MP Sharbati wheat flour"
                },
                {
                    "item_id": "prod_pillsbury_001",
                    "product_name": "Pillsbury Chakki Atta 5kg",
                    "category_section": "Groceries",
                    "category_main": "Atta, Rice & Dal",
                    "category_sub": "Wheat Flour",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Pillsbury",
                    "weight": "5kg",
                    "price": 230.00,
                    "stock": 110,
                    "active": True,
                    "description": "Chakki fresh atta for soft rotis"
                },
                # Personal Care → Bath & Body → Soap
                {
                    "item_id": "prod_lux_001",
                    "product_name": "Lux Soap Bar 125g (Pack of 3)",
                    "category_section": "Personal Care",
                    "category_main": "Bath & Body",
                    "category_sub": "Soap",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Lux",
                    "weight": "375g",
                    "price": 90.00,
                    "stock": 200,
                    "active": True,
                    "description": "Premium beauty soap with international fragrance"
                },
                {
                    "item_id": "prod_dove_001",
                    "product_name": "Dove Cream Beauty Bathing Bar 100g",
                    "category_section": "Personal Care",
                    "category_main": "Bath & Body",
                    "category_sub": "Soap",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Dove",
                    "weight": "100g",
                    "price": 48.00,
                    "stock": 180,
                    "active": True,
                    "description": "1/4 moisturizing cream for softer skin"
                },
                # Personal Care → Hair Care → Shampoo
                {
                    "item_id": "prod_clinic_001",
                    "product_name": "Clinic Plus Shampoo 650ml",
                    "category_section": "Personal Care",
                    "category_main": "Hair Care",
                    "category_sub": "Shampoo",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Clinic+Plus",
                    "weight": "650ml",
                    "price": 185.00,
                    "stock": 75,
                    "active": True,
                    "description": "Strong and long hair shampoo"
                },
                {
                    "item_id": "prod_pantene_001",
                    "product_name": "Pantene Pro-V Shampoo 340ml",
                    "category_section": "Personal Care",
                    "category_main": "Hair Care",
                    "category_sub": "Shampoo",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Pantene",
                    "weight": "340ml",
                    "price": 220.00,
                    "stock": 95,
                    "active": True,
                    "description": "Advanced hair fall solution"
                },
                # Snacks → Biscuits & Cookies → Cream Biscuits
                {
                    "item_id": "prod_oreo_001",
                    "product_name": "Oreo Cream Biscuits 300g",
                    "category_section": "Snacks",
                    "category_main": "Biscuits & Cookies",
                    "category_sub": "Cream Biscuits",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Oreo",
                    "weight": "300g",
                    "price": 60.00,
                    "stock": 140,
                    "active": True,
                    "description": "Chocolate sandwich cookies with vanilla cream"
                },
                {
                    "item_id": "prod_bourbon_001",
                    "product_name": "Britannia Bourbon 150g",
                    "category_section": "Snacks",
                    "category_main": "Biscuits & Cookies",
                    "category_sub": "Cream Biscuits",
                    "image_url": "https://via.placeholder.com/300x300.png?text=Bourbon",
                    "weight": "150g",
                    "price": 35.00,
                    "stock": 160,
                    "active": True,
                    "description": "Chocolate cream biscuits"
                }
            ]
            
            products_collection.insert_many(sample_products)
            products_collection.create_index("item_id", unique=True)
            products_collection.create_index("category_section")
            products_collection.create_index("category_main")
            products_collection.create_index("category_sub")
            products_collection.create_index([("category_section", 1), ("category_main", 1), ("category_sub", 1)])
            logger.info("✓ Products collection initialized with sample data")
        
        logger.info("MongoDB collections initialized successfully")
        return True
        
    except Exception as e:
        logger.error(f"Error initializing MongoDB collections: {e}")
        return False
