"""
Category hierarchy management for nested categorization.
Handles dynamic category relationships and persistence.
"""
from typing import List, Dict, Optional
from database.mongodb_client import get_mongo_db
import logging

logger = logging.getLogger(__name__)


def init_category_hierarchy():
    """Initialize category hierarchy collection with sample data."""
    try:
        db = get_mongo_db()
        
        if "category_hierarchy" not in db.list_collection_names():
            db.create_collection("category_hierarchy")
            
            # Create initial hierarchy structure
            initial_hierarchy = [
                {
                    "section": "Best Seller",
                    "main_categories": {
                        "Drinks & Juices": ["Soft Drinks", "Juices", "Energy Drinks"],
                        "Atta, Rice & Dal": ["Basmati Rice", "Non-Basmati Rice", "Wheat Flour", "Pulses"]
                    }
                },
                {
                    "section": "Groceries",
                    "main_categories": {
                        "Cooking Essentials": ["Cooking Oil", "Ghee", "Salt", "Sugar", "Spices"],
                        "Atta, Rice & Dal": ["Wheat Flour", "Rice Varieties", "Pulses & Lentils"],
                        "Snacks & Beverages": ["Biscuits", "Namkeen", "Chips", "Tea & Coffee"]
                    }
                },
                {
                    "section": "Personal Care",
                    "main_categories": {
                        "Bath & Body": ["Soap", "Body Wash", "Bath Accessories"],
                        "Hair Care": ["Shampoo", "Conditioner", "Hair Oil", "Hair Color"],
                        "Oral Care": ["Toothpaste", "Toothbrush", "Mouthwash"]
                    }
                },
                {
                    "section": "Snacks",
                    "main_categories": {
                        "Biscuits & Cookies": ["Cream Biscuits", "Glucose Biscuits", "Cookies"],
                        "Chips & Namkeen": ["Potato Chips", "Namkeen", "Popcorn"],
                        "Chocolates & Candies": ["Chocolates", "Candies", "Toffees"]
                    }
                }
            ]
            
            db.category_hierarchy.insert_many(initial_hierarchy)
            db.category_hierarchy.create_index("section", unique=True)
            logger.info("✓ Category hierarchy initialized")
            
    except Exception as e:
        logger.error(f"Error initializing category hierarchy: {e}")


def get_all_sections() -> List[str]:
    """Get all section names."""
    db = get_mongo_db()
    return [doc["section"] for doc in db.category_hierarchy.find({}, {"section": 1})]


def get_main_categories_for_section(section: str) -> List[str]:
    """Get main categories for a specific section."""
    db = get_mongo_db()
    doc = db.category_hierarchy.find_one({"section": section})
    if doc and "main_categories" in doc:
        return list(doc["main_categories"].keys())
    return []


def get_subcategories_for_main(section: str, main_category: str) -> List[str]:
    """Get subcategories for a specific section and main category."""
    db = get_mongo_db()
    doc = db.category_hierarchy.find_one({"section": section})
    if doc and "main_categories" in doc and main_category in doc["main_categories"]:
        return doc["main_categories"][main_category]
    return []


def add_new_section(section: str) -> bool:
    """Add a new section to the hierarchy."""
    try:
        db = get_mongo_db()
        result = db.category_hierarchy.insert_one({
            "section": section,
            "main_categories": {}
        })
        logger.info(f"Added new section: {section}")
        return result.inserted_id is not None
    except Exception as e:
        logger.error(f"Error adding section: {e}")
        return False


def add_main_category_to_section(section: str, main_category: str) -> bool:
    """Add a new main category to a section."""
    try:
        db = get_mongo_db()
        result = db.category_hierarchy.update_one(
            {"section": section},
            {"$set": {f"main_categories.{main_category}": []}},
            upsert=True  # Create section if it doesn't exist
        )
        logger.info(f"Added main category '{main_category}' to section '{section}' (matched: {result.matched_count}, modified: {result.modified_count}, upserted: {result.upserted_id})")
        # Return True if either modified or upserted
        return result.modified_count > 0 or result.upserted_id is not None
    except Exception as e:
        logger.error(f"Error adding main category: {e}")
        return False


def add_subcategory(section: str, main_category: str, subcategory: str) -> bool:
    """Add a new subcategory to a main category."""
    try:
        db = get_mongo_db()
        result = db.category_hierarchy.update_one(
            {"section": section},
            {"$addToSet": {f"main_categories.{main_category}": subcategory}}
        )
        logger.info(f"Added subcategory '{subcategory}' to '{main_category}' in '{section}'")
        return result.modified_count > 0
    except Exception as e:
        logger.error(f"Error adding subcategory: {e}")
        return False


def get_full_hierarchy() -> List[Dict]:
    """Get the complete category hierarchy."""
    db = get_mongo_db()
    return list(db.category_hierarchy.find({}, {"_id": 0}))
