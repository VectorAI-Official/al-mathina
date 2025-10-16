"""
Script to list all databases and collections in MongoDB
"""
import sys
import os

# Add Backend directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from database.mongodb_client import get_mongo_client, get_mongo_db
    from config_local import settings
    
    print("=" * 60)
    print("📊 AL-MADHINA DATABASE INFORMATION")
    print("=" * 60)
    
    # Connect to MongoDB
    client = get_mongo_client()
    
    print("\n🗄️  MONGODB DATABASES:")
    print("-" * 60)
    databases = client.list_database_names()
    for i, db_name in enumerate(databases, 1):
        marker = "👉" if db_name == settings.mongo_db_name else "  "
        print(f"{marker} {i}. {db_name}")
    
    print(f"\n📌 Current Database: {settings.mongo_db_name}")
    print("=" * 60)
    
    # Get current database
    db = get_mongo_db()
    
    print(f"\n📂 COLLECTIONS IN '{settings.mongo_db_name}':")
    print("-" * 60)
    collections = db.list_collection_names()
    
    if not collections:
        print("   (No collections found)")
    else:
        for i, col_name in enumerate(collections, 1):
            count = db[col_name].count_documents({})
            print(f"   {i}. {col_name:<25} ({count:>6} documents)")
    
    print("\n" + "=" * 60)
    print("📈 DETAILED COLLECTION INFORMATION:")
    print("=" * 60)
    
    for col_name in collections:
        collection = db[col_name]
        count = collection.count_documents({})
        
        print(f"\n🗂️  {col_name.upper()}")
        print(f"   Total Documents: {count}")
        
        if count > 0:
            # Get sample document
            sample = collection.find_one()
            if sample:
                print(f"   Sample Fields: {', '.join(list(sample.keys())[:10])}")
        
        # Get indexes
        indexes = collection.index_information()
        if indexes:
            print(f"   Indexes: {len(indexes)}")
            for idx_name, idx_info in indexes.items():
                if idx_name != '_id_':
                    keys = ', '.join([f"{k[0]}" for k in idx_info.get('key', [])])
                    print(f"      - {idx_name}: {keys}")
    
    print("\n" + "=" * 60)
    print("✅ Database listing complete!")
    print("=" * 60)
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()
