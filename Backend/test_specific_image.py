"""
Test migration with a specific image URL
"""
from migrate_cloudinary_images import CloudinaryMigration
import os

def test_specific_url():
    # Configuration (same as migrate_cloudinary_images.py)
    old_config = {
        'cloud_name': 'vectorai',
        'api_key': '315192596216358',
        'api_secret': 'JFpyMTpUZ01pRxaFpZjm_Na6H-s'
    }
    
    new_config = {
        'cloud_name': 'al-mathina',
        'api_key': os.getenv('NEW_CLOUDINARY_API_KEY') or os.getenv('CLOUDINARY_API_KEY') or '514621122679917',
        'api_secret': os.getenv('NEW_CLOUDINARY_API_SECRET') or os.getenv('CLOUDINARY_API_SECRET') or 'F6XWJAY0OeJeCckC2iXYf7fyuyA'
    }
    
    # Specific URL to test
    test_url = "https://res.cloudinary.com/vectorai/image/upload/v1762544730/almathina/products/690e4c592ba9e5019c958faf.jpg"
    
    print("=" * 80)
    print("🧪 TESTING SPECIFIC IMAGE MIGRATION")
    print("=" * 80)
    print()
    print(f"Test URL: {test_url}")
    print()
    
    # Create migration instance
    migration = CloudinaryMigration(
        old_config=old_config,
        new_config=new_config,
        dry_run=False,
        skip_delete=False,
        test_limit=None
    )
    
    # Migrate single image
    print("Starting migration...")
    print()
    new_url = migration.migrate_single_image(test_url)
    
    if new_url:
        print()
        print("=" * 80)
        print("✅ MIGRATION SUCCESSFUL")
        print("=" * 80)
        print()
        print(f"Old URL: {test_url}")
        print(f"New URL: {new_url}")
        print()
        
        # Update database
        print("Updating database...")
        migration.update_database_urls()
        
        # Print summary
        migration.print_summary()
        
        # Save migration map
        import json
        from datetime import datetime
        map_file = f"migration_map_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(map_file, 'w') as f:
            json.dump(migration.migration_map, f, indent=2)
        print(f"\n💾 Migration map saved to: {map_file}")
        
    else:
        print()
        print("=" * 80)
        print("❌ MIGRATION FAILED")
        print("=" * 80)
        print()

if __name__ == '__main__':
    test_specific_url()
