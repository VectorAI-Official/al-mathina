"""
Script to display all data stored in MongoDB collections
Shows actual documents with all fields
"""

from pymongo import MongoClient
from config_local import Settings
import json
from datetime import datetime
from bson import ObjectId

class JSONEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle MongoDB types"""
    def default(self, obj):
        if isinstance(obj, ObjectId):
            return str(obj)
        if isinstance(obj, datetime):
            return obj.strftime('%Y-%m-%d %H:%M:%S')
        return super().default(obj)

def print_separator(char="=", length=100):
    print(char * length)

def print_header(text):
    print_separator()
    print(f"  {text}")
    print_separator()

def display_collection_data(collection, collection_name, limit=None):
    """Display all documents in a collection"""
    count = collection.count_documents({})
    
    print_header(f"📊 {collection_name.upper()} ({count} documents)")
    
    if count == 0:
        print("  ⚠️  No documents found\n")
        return
    
    # Get documents
    cursor = collection.find().sort("_id", -1)
    if limit:
        cursor = cursor.limit(limit)
    
    documents = list(cursor)
    
    for i, doc in enumerate(documents, 1):
        print(f"\n{'─' * 100}")
        print(f"Document #{i}:")
        print(f"{'─' * 100}")
        
        # Pretty print the document
        for key, value in doc.items():
            if isinstance(value, ObjectId):
                print(f"  {key:20} : {str(value)}")
            elif isinstance(value, datetime):
                print(f"  {key:20} : {value.strftime('%Y-%m-%d %H:%M:%S')}")
            elif isinstance(value, dict):
                print(f"  {key:20} :")
                print(f"    {json.dumps(value, indent=6, cls=JSONEncoder)}")
            elif isinstance(value, list):
                print(f"  {key:20} : {value}")
            else:
                # Truncate long strings
                str_value = str(value)
                if len(str_value) > 100:
                    str_value = str_value[:100] + "..."
                print(f"  {key:20} : {str_value}")
    
    print(f"\n{'═' * 100}\n")

def show_all_data():
    try:
        settings = Settings()
        client = MongoClient(settings.mongo_uri)
        db = client[settings.mongo_db_name]
        
        print("\n")
        print_separator("═")
        print(f"  🗄️  AL-MADHINA DATABASE - COMPLETE DATA DUMP")
        print(f"  Database: {settings.mongo_db_name}")
        print(f"  URI: {settings.mongo_uri}")
        print(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print_separator("═")
        
        # Get all collections
        collections = db.list_collection_names()
        print(f"\n📚 Found {len(collections)} collections: {', '.join(collections)}\n")
        
        # 1. PRODUCTS
        print_header("1️⃣  PRODUCTS COLLECTION")
        print("\n💡 Contains all product information with 3-level categorization\n")
        display_collection_data(db.products, "PRODUCTS")
        
        # 2. CATEGORY_HIERARCHY
        print_header("2️⃣  CATEGORY_HIERARCHY COLLECTION")
        print("\n💡 Contains the 3-level navigation structure (Section → Main → Sub)\n")
        display_collection_data(db.category_hierarchy, "CATEGORY_HIERARCHY")
        
        # 3. CATEGORY_METADATA
        print_header("3️⃣  CATEGORY_METADATA COLLECTION")
        print("\n💡 Contains images and metadata for all category levels\n")
        display_collection_data(db.category_metadata, "CATEGORY_METADATA")
        
        # 4. CATEGORIES (Legacy)
        if 'categories' in collections:
            print_header("4️⃣  CATEGORIES COLLECTION (Legacy)")
            print("\n💡 Legacy collection - may not be actively used\n")
            display_collection_data(db.categories, "CATEGORIES")
        
        # 5. Any other collections
        known_collections = ['products', 'category_hierarchy', 'category_metadata', 'categories']
        other_collections = [col for col in collections if col not in known_collections]
        
        if other_collections:
            for col_name in other_collections:
                print_header(f"📦 {col_name.upper()} COLLECTION")
                display_collection_data(db[col_name], col_name)
        
        # Summary
        print_separator("═")
        print("  ✅ DATA DUMP COMPLETE")
        print_separator("═")
        
        # Statistics
        print("\n📊 DATABASE SUMMARY:")
        print(f"  Total Collections: {len(collections)}")
        for col_name in collections:
            count = db[col_name].count_documents({})
            print(f"    • {col_name}: {count} documents")
        
        print(f"\n  Database Size: {db.command('dbstats')['dataSize'] / 1024:.2f} KB")
        print(f"  Storage Size: {db.command('dbstats')['storageSize'] / 1024:.2f} KB\n")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        client.close()

def show_specific_collection(collection_name):
    """Show data for a specific collection"""
    try:
        settings = Settings()
        client = MongoClient(settings.mongo_uri)
        db = client[settings.mongo_db_name]
        
        if collection_name not in db.list_collection_names():
            print(f"❌ Collection '{collection_name}' not found!")
            print(f"Available collections: {', '.join(db.list_collection_names())}")
            return
        
        display_collection_data(db[collection_name], collection_name)
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        # Show specific collection
        collection_name = sys.argv[1]
        show_specific_collection(collection_name)
    else:
        # Show all data
        show_all_data()
