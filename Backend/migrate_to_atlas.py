"""
Database Migration Script
Migrates data from local MongoDB to MongoDB Atlas
"""
import os
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables
load_dotenv('.env.production')

# Get MongoDB password from environment
MONGO_PASSWORD = os.getenv('MONGO_PASSWORD')
if not MONGO_PASSWORD:
    print("❌ Error: MONGO_PASSWORD not set in environment")
    print("Please run: $env:MONGO_PASSWORD='your_password'")
    exit(1)

# Connection strings
LOCAL_MONGO_URI = "mongodb://localhost:27017"
ATLAS_MONGO_URI = f"mongodb+srv://vectoraiautomations_db_user:{MONGO_PASSWORD}@al-mathina.9xt8cbd.mongodb.net/"
DB_NAME = "almadhinadb"

# Collections to migrate
COLLECTIONS = [
    "products",
    "category_metadata",
    "category_hierarchy",
    "most_bought",
    "users",
    "orders",
    "user_profiles",
    "store_details",
    "favorites"
]

def migrate_database():
    """Migrate all collections from local MongoDB to Atlas"""
    print("🚀 Starting database migration to MongoDB Atlas...")
    print("=" * 60)
    
    try:
        # Connect to local MongoDB
        print("📊 Connecting to local MongoDB...")
        local_client = MongoClient(LOCAL_MONGO_URI)
        local_db = local_client[DB_NAME]
        print("✓ Connected to local MongoDB")
        
        # Connect to MongoDB Atlas
        print("📊 Connecting to MongoDB Atlas...")
        atlas_client = MongoClient(ATLAS_MONGO_URI)
        atlas_db = atlas_client[DB_NAME]
        # Test connection
        atlas_client.admin.command('ping')
        print("✓ Connected to MongoDB Atlas")
        
        print("=" * 60)
        
        # Migrate each collection
        for collection_name in COLLECTIONS:
            print(f"\n📦 Migrating collection: {collection_name}")
            
            # Check if collection exists in local DB
            if collection_name not in local_db.list_collection_names():
                print(f"  ⚠️  Collection '{collection_name}' not found in local DB, skipping...")
                continue
            
            # Get documents from local collection
            local_collection = local_db[collection_name]
            documents = list(local_collection.find({}))
            
            if not documents:
                print(f"  ℹ️  Collection '{collection_name}' is empty, skipping...")
                continue
            
            print(f"  Found {len(documents)} documents")
            
            # Insert into Atlas (drop existing data first)
            atlas_collection = atlas_db[collection_name]
            
            # Ask for confirmation before dropping
            response = input(f"  ⚠️  Drop existing data in Atlas '{collection_name}'? (y/N): ")
            if response.lower() == 'y':
                atlas_collection.delete_many({})
                print(f"  Dropped existing data")
            
            # Insert documents
            if documents:
                atlas_collection.insert_many(documents)
                print(f"  ✓ Migrated {len(documents)} documents")
        
        print("\n" + "=" * 60)
        print("✅ Migration completed successfully!")
        print(f"📊 Database: {DB_NAME}")
        print(f"🌐 Atlas Cluster: al-mathina.9xt8cbd.mongodb.net")
        print("=" * 60)
        
        # Close connections
        local_client.close()
        atlas_client.close()
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        exit(1)


if __name__ == "__main__":
    print("\n⚠️  WARNING: This will migrate data to MongoDB Atlas")
    print("Make sure you have set the MONGO_PASSWORD environment variable")
    print("\nTo set password, run:")
    print("  PowerShell: $env:MONGO_PASSWORD='your_password_here'")
    print("  Bash: export MONGO_PASSWORD='your_password_here'")
    
    response = input("\nContinue with migration? (y/N): ")
    if response.lower() == 'y':
        migrate_database()
    else:
        print("Migration cancelled")
