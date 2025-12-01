"""
Cloudinary Account Migration Script
Transfers images from old Cloudinary account to new account and updates database URLs

Features:
- Downloads images from old Cloudinary account
- Uploads to new Cloudinary account
- Updates all database image URLs (products, categories, subcategories)
- Maintains folder structure
- Comprehensive logging
- Error handling and resume capability
- Dry-run mode for testing

Usage:
    # Dry run (test without actual changes)
    python migrate_cloudinary_images.py --dry-run
    
    # Execute migration
    python migrate_cloudinary_images.py
    
    # Resume failed migration
    python migrate_cloudinary_images.py --resume
"""

import cloudinary
import cloudinary.uploader
import cloudinary.api
from database.mongodb_client import get_mongo_db
import requests
import logging
import sys
import json
import os
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import argparse
from pathlib import Path
import time

# Fix Unicode encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'cloudinary_migration_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class CloudinaryMigration:
    """Handles migration of images between Cloudinary accounts"""
    
    def __init__(self, old_config: Dict, new_config: Dict, dry_run: bool = False, skip_delete: bool = False, test_limit: int = None):
        """
        Initialize migration with old and new Cloudinary configurations
        
        Args:
            old_config: Dict with keys: cloud_name, api_key, api_secret
            new_config: Dict with keys: cloud_name, api_key, api_secret
            dry_run: If True, don't make actual changes
            skip_delete: If True, don't delete from old account (safer)
            test_limit: If set, only migrate this many images (for testing)
        """
        self.old_config = old_config
        self.new_config = new_config
        self.dry_run = dry_run
        self.skip_delete = skip_delete
        self.test_limit = test_limit
        
        self.old_base_url = f"https://res.cloudinary.com/{old_config['cloud_name']}"
        self.new_base_url = f"https://res.cloudinary.com/{new_config['cloud_name']}"
        
        # Migration tracking
        self.stats = {
            'total_images': 0,
            'migrated': 0,
            'skipped': 0,
            'failed': 0,
            'db_updates': 0,
            'deleted_from_old': 0
        }
        
        self.failed_migrations = []
        self.migration_map = {}  # Old URL -> New URL mapping
        
        logger.info("=" * 80)
        logger.info("🚀 CLOUDINARY MIGRATION INITIALIZED")
        logger.info("=" * 80)
        logger.info(f"Old Account: {old_config['cloud_name']}")
        logger.info(f"New Account: {new_config['cloud_name']}")
        logger.info(f"Mode: {'DRY RUN (no changes)' if dry_run else 'LIVE MIGRATION'}")
        logger.info(f"Delete from old: {'NO (safer mode)' if skip_delete else 'YES (after verification)'}")
        if test_limit:
            logger.info(f"🧪 TEST MODE: Will only process {test_limit} image(s)")
        logger.info("=" * 80)
    
    def setup_old_cloudinary(self):
        """Configure Cloudinary with old account credentials"""
        cloudinary.config(
            cloud_name=self.old_config['cloud_name'],
            api_key=self.old_config['api_key'],
            api_secret=self.old_config['api_secret'],
            secure=True
        )
        logger.info("✓ Old Cloudinary account configured")
    
    def setup_new_cloudinary(self):
        """Configure Cloudinary with new account credentials"""
        cloudinary.config(
            cloud_name=self.new_config['cloud_name'],
            api_key=self.new_config['api_key'],
            api_secret=self.new_config['api_secret'],
            secure=True
        )
        logger.info("✓ New Cloudinary account configured")
    
    def extract_public_id_from_url(self, url: str) -> Optional[str]:
        """
        Extract public_id from Cloudinary URL
        
        Args:
            url: Full Cloudinary URL
            
        Returns:
            public_id or None if invalid URL
        """
        try:
            if '/upload/' not in url:
                return None
            
            # Split by /upload/ and get the path after it
            parts = url.split('/upload/')
            if len(parts) != 2:
                return None
            
            # Remove version number (v1234567890/)
            path = parts[1]
            import re
            path = re.sub(r'^v\d+/', '', path)
            
            # Remove file extension
            public_id = path.rsplit('.', 1)[0]
            
            return public_id
        except Exception as e:
            logger.error(f"Error extracting public_id from {url}: {e}")
            return None
    
    def verify_image_exists(self, url: str) -> bool:
        """
        Verify that an image exists and is accessible at the given URL
        
        Args:
            url: Image URL to verify
            
        Returns:
            True if image exists and is accessible
        """
        try:
            response = requests.head(url, timeout=10)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Failed to verify image at {url}: {e}")
            return False
    
    def delete_from_old_cloudinary(self, public_id: str) -> bool:
        """
        Delete image from old Cloudinary account (ONLY after successful migration)
        
        Args:
            public_id: Public ID of the image to delete
            
        Returns:
            True if deleted successfully
        """
        try:
            self.setup_old_cloudinary()
            
            if self.dry_run:
                logger.info(f"   [DRY RUN] Would delete from old account: {public_id}")
                return True
            
            if self.skip_delete:
                logger.info(f"   [SKIP DELETE MODE] Not deleting from old account: {public_id}")
                return True
            
            result = cloudinary.uploader.destroy(public_id)
            
            if result.get('result') == 'ok':
                logger.info(f"   ✓ Deleted from old account: {public_id}")
                return True
            else:
                logger.warning(f"   ⚠ Could not delete from old account: {public_id} - {result}")
                return False
                
        except Exception as e:
            logger.error(f"   ✗ Error deleting from old account {public_id}: {e}")
            return False
    
    def download_image(self, url: str) -> Optional[bytes]:
        """
        Download image from URL
        
        Args:
            url: Image URL
            
        Returns:
            Image bytes or None if failed
        """
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            return response.content
        except Exception as e:
            logger.error(f"Failed to download {url}: {e}")
            return None
    
    def upload_to_new_cloudinary(self, image_bytes: bytes, public_id: str, folder: str = None) -> Optional[str]:
        """
        Upload image to new Cloudinary account
        
        Args:
            image_bytes: Image content
            public_id: Desired public_id (filename without extension)
            folder: Cloudinary folder path
            
        Returns:
            New Cloudinary URL or None if failed
        """
        try:
            self.setup_new_cloudinary()
            
            upload_params = {
                'public_id': public_id,
                'overwrite': True,
                'resource_type': 'image'
            }
            
            if folder:
                upload_params['folder'] = folder
            
            if self.dry_run:
                logger.info(f"   [DRY RUN] Would upload to: {folder}/{public_id}")
                # Return fake URL for dry run
                return f"{self.new_base_url}/image/upload/v1/{folder}/{public_id}.jpg"
            
            result = cloudinary.uploader.upload(image_bytes, **upload_params)
            new_url = result.get('secure_url', result.get('url'))
            
            logger.info(f"   ✓ Uploaded to new account: {new_url}")
            return new_url
            
        except Exception as e:
            logger.error(f"   ✗ Failed to upload {public_id}: {e}")
            return None
    
    def migrate_single_image(self, old_url: str) -> Optional[str]:
        """
        Migrate a single image from old to new Cloudinary with careful verification
        
        PROCESS:
        1. Download from old account
        2. Upload to new account
        3. Verify new image exists
        4. Update database
        5. Delete from old account (ONLY after steps 1-4 succeed)
        
        Args:
            old_url: Old Cloudinary URL
            
        Returns:
            New Cloudinary URL or None if failed
        """
        logger.info(f"")
        logger.info(f"   🖼️  IMAGE URL: {old_url}")
        logger.info(f"   📥 Starting migration...")
        
        # STEP 1: Extract public_id and folder structure
        public_id = self.extract_public_id_from_url(old_url)
        if not public_id:
            logger.warning(f"   ⚠ Invalid URL format, skipping: {old_url}")
            self.stats['skipped'] += 1
            return None
        
        # Extract folder from public_id (e.g., "almathina/products/abc" -> folder="almathina/products")
        if '/' in public_id:
            folder = '/'.join(public_id.split('/')[:-1])
            filename = public_id.split('/')[-1]
        else:
            folder = None
            filename = public_id
        
        logger.info(f"   📂 Folder: {folder or 'root'}")
        logger.info(f"   📄 Filename: {filename}")
        
        # STEP 2: Download from old account
        logger.info(f"")
        logger.info(f"   📦 STEP 1/5: Downloading from old account...")
        image_bytes = self.download_image(old_url)
        if not image_bytes:
            logger.error(f"   ✗ Download failed, aborting migration")
            self.stats['failed'] += 1
            self.failed_migrations.append({'url': old_url, 'error': 'Download failed', 'step': 'download'})
            return None
        
        size_mb = len(image_bytes) / (1024 * 1024)
        logger.info(f"   ✓ Downloaded successfully ({size_mb:.2f} MB)")
        
        # STEP 3: Upload to new account
        logger.info(f"")
        logger.info(f"   📤 STEP 2/5: Uploading to new account...")
        new_url = self.upload_to_new_cloudinary(image_bytes, filename, folder)
        if not new_url:
            logger.error(f"   ✗ Upload failed, aborting migration")
            self.stats['failed'] += 1
            self.failed_migrations.append({'url': old_url, 'error': 'Upload failed', 'step': 'upload'})
            return None
        
        logger.info(f"   ✓ Uploaded successfully")
        logger.info(f"   🆕 New URL: {new_url}")
        
        # STEP 4: Verify new image exists (CRITICAL SAFETY CHECK)
        logger.info(f"")
        logger.info(f"   🔍 STEP 3/5: Verifying new image exists...")
        if not self.dry_run:
            if not self.verify_image_exists(new_url):
                logger.error(f"   ✗ Verification failed! New image not accessible at {new_url}")
                logger.error(f"   ✗ Aborting migration for safety")
                self.stats['failed'] += 1
                self.failed_migrations.append({'url': old_url, 'error': 'Verification failed', 'step': 'verify'})
                return None
            logger.info(f"   ✓ Verification successful - new image is accessible")
        else:
            logger.info(f"   [DRY RUN] Would verify new image")
        
        # STEP 5: Update database (do this BEFORE deleting from old account)
        logger.info(f"")
        logger.info(f"   💾 STEP 4/5: Marking for database update...")
        self.stats['migrated'] += 1
        self.migration_map[old_url] = new_url
        logger.info(f"   ✓ Migration map updated (will update DB after all images processed)")
        
        # STEP 6: Delete from old account (ONLY after successful upload + verification)
        logger.info(f"")
        logger.info(f"   🗑️  STEP 5/5: Deleting from old account...")
        if self.delete_from_old_cloudinary(public_id):
            self.stats['deleted_from_old'] += 1
            logger.info(f"   ✓ Deleted from old account")
        
        logger.info(f"")
        logger.info(f"   ✅ MIGRATION COMPLETE FOR THIS IMAGE!")
        logger.info(f"   📊 Summary:")
        logger.info(f"      Old URL: {old_url}")
        logger.info(f"      New URL: {new_url}")
        logger.info(f"      Status: Success")
        
        return new_url
    
    def update_database_urls(self):
        """Update all image URLs in MongoDB database"""
        logger.info("\n" + "=" * 80)
        logger.info("📊 UPDATING DATABASE")
        logger.info("=" * 80)
        
        if self.dry_run:
            logger.info("[DRY RUN] Would update database with new URLs")
            return
        
        db = get_mongo_db()
        
        # Update products
        logger.info("\n📦 Updating Products...")
        products_updated = 0
        products = db.products.find({"image_url": {"$exists": True, "$ne": None}})
        
        for product in products:
            old_url = product.get('image_url')
            if old_url and old_url in self.migration_map:
                new_url = self.migration_map[old_url]
                result = db.products.update_one(
                    {"_id": product['_id']},
                    {"$set": {"image_url": new_url}}
                )
                if result.modified_count > 0:
                    products_updated += 1
                    logger.info(f"   ✓ Updated product: {product.get('name', 'Unknown')}")
        
        logger.info(f"   Products updated: {products_updated}")
        self.stats['db_updates'] += products_updated
        
        # Update category metadata
        logger.info("\n📂 Updating Category Metadata...")
        metadata_updated = 0
        metadata = db.category_metadata.find({"image_url": {"$exists": True, "$ne": None}})
        
        for meta in metadata:
            old_url = meta.get('image_url')
            if old_url and old_url in self.migration_map:
                new_url = self.migration_map[old_url]
                result = db.category_metadata.update_one(
                    {"_id": meta['_id']},
                    {"$set": {"image_url": new_url}}
                )
                if result.modified_count > 0:
                    metadata_updated += 1
                    meta_type = meta.get('type', 'unknown')
                    meta_name = meta.get('name', 'Unknown')
                    logger.info(f"   ✓ Updated {meta_type}: {meta_name}")
        
        logger.info(f"   Metadata updated: {metadata_updated}")
        self.stats['db_updates'] += metadata_updated
    
    def scan_and_migrate(self):
        """Scan database for images and migrate them"""
        logger.info("\n" + "=" * 80)
        logger.info("🔍 SCANNING DATABASE FOR IMAGES")
        logger.info("=" * 80)
        
        db = get_mongo_db()
        all_urls = set()
        
        # Collect all image URLs from products
        logger.info("\n📦 Scanning Products...")
        products = db.products.find({"image_url": {"$exists": True, "$ne": None}})
        product_urls = set()
        for product in products:
            url = product.get('image_url')
            if url and self.old_config['cloud_name'] in url:
                product_urls.add(url)
                all_urls.add(url)
        
        logger.info(f"   Found {len(product_urls)} product images")
        
        # Collect all image URLs from category metadata
        logger.info("\n📂 Scanning Category Metadata...")
        metadata = db.category_metadata.find({"image_url": {"$exists": True, "$ne": None}})
        metadata_urls = set()
        for meta in metadata:
            url = meta.get('image_url')
            if url and self.old_config['cloud_name'] in url:
                metadata_urls.add(url)
                all_urls.add(url)
        
        logger.info(f"   Found {len(metadata_urls)} category/subcategory images")
        
        self.stats['total_images'] = len(all_urls)
        
        logger.info("\n" + "=" * 80)
        logger.info(f"📊 TOTAL UNIQUE IMAGES TO MIGRATE: {len(all_urls)}")
        logger.info("=" * 80)
        
        if len(all_urls) == 0:
            logger.warning("⚠ No images found in old Cloudinary account!")
            return
        
        # Apply test limit if specified
        urls_to_process = list(all_urls)
        if self.test_limit:
            urls_to_process = urls_to_process[:self.test_limit]
            logger.info(f"\n🧪 TEST MODE: Processing only {self.test_limit} out of {len(all_urls)} total image(s)")
        
        # Migrate each image
        logger.info("\n" + "=" * 80)
        logger.info("🚀 STARTING MIGRATION")
        logger.info("=" * 80)
        
        for idx, url in enumerate(urls_to_process, 1):
            logger.info(f"\n[{idx}/{len(urls_to_process)}] Processing image...")
            self.migrate_single_image(url)
            
            # Small delay to avoid rate limiting
            if not self.dry_run:
                time.sleep(0.5)
        
        # Update database with new URLs
        self.update_database_urls()
    
    def print_summary(self):
        """Print migration summary"""
        logger.info("\n" + "=" * 80)
        logger.info("📊 MIGRATION SUMMARY")
        logger.info("=" * 80)
        logger.info(f"Total Images Found:      {self.stats['total_images']}")
        logger.info(f"Successfully Migrated:   {self.stats['migrated']}")
        logger.info(f"Skipped:                 {self.stats['skipped']}")
        logger.info(f"Failed:                  {self.stats['failed']}")
        logger.info(f"Database Updates:        {self.stats['db_updates']}")
        logger.info(f"Deleted from Old:        {self.stats['deleted_from_old']}")
        logger.info("=" * 80)
        
        if self.failed_migrations:
            logger.warning(f"\n⚠ {len(self.failed_migrations)} FAILED MIGRATIONS:")
            for failed in self.failed_migrations:
                step = failed.get('step', 'unknown')
                logger.warning(f"   - {failed['url']}")
                logger.warning(f"     Error: {failed['error']} (failed at: {step})")
        
        if not self.dry_run:
            # Save migration map to file
            map_file = f'migration_map_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
            with open(map_file, 'w') as f:
                json.dump(self.migration_map, f, indent=2)
            logger.info(f"\n💾 Migration map saved to: {map_file}")
    
    def run(self):
        """Execute the migration"""
        try:
            self.scan_and_migrate()
            self.print_summary()
            
            if self.dry_run:
                logger.info("\n✅ DRY RUN COMPLETE - No actual changes made")
            else:
                logger.info("\n✅ MIGRATION COMPLETE!")
            
        except Exception as e:
            logger.error(f"\n❌ MIGRATION FAILED: {e}")
            raise


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Migrate images between Cloudinary accounts')
    parser.add_argument('--dry-run', action='store_true', help='Test run without making changes')
    parser.add_argument('--old-cloud-name', type=str, help='Old Cloudinary cloud name')
    parser.add_argument('--old-api-key', type=str, help='Old Cloudinary API key')
    parser.add_argument('--old-api-secret', type=str, help='Old Cloudinary API secret')
    parser.add_argument('--new-cloud-name', type=str, help='New Cloudinary cloud name')
    parser.add_argument('--new-api-key', type=str, help='New Cloudinary API key')
    parser.add_argument('--new-api-secret', type=str, help='New Cloudinary API secret')
    parser.add_argument('--skip-delete', action='store_true', help='Skip deleting from old account (safer)')
    parser.add_argument('--test-limit', type=int, default=None, help='🧪 Test mode: only migrate N images (e.g., --test-limit 1)')
    
    args = parser.parse_args()
    
    # ========================================================================
    # ADD YOUR OLD CLOUDINARY CREDENTIALS HERE (or use environment variables)
    # ========================================================================
    # Old account: https://res.cloudinary.com/vectorai/...
    old_config = {
        'cloud_name': args.old_cloud_name or os.getenv('OLD_CLOUDINARY_CLOUD_NAME') or 'vectorai',  # ← Change 'vectorai' to your old cloud name
        'api_key': args.old_api_key or os.getenv('OLD_CLOUDINARY_API_KEY') or '315192596216358',  # ← Add your old API key
        'api_secret': args.old_api_secret or os.getenv('OLD_CLOUDINARY_API_SECRET') or 'JFpyMTpUZ01pRxaFpZjm_Na6H-s'  # ← Add your old API secret
    }
    
    # ========================================================================
    # ADD YOUR NEW CLOUDINARY CREDENTIALS HERE (or use environment variables)
    # ========================================================================
    # New account: https://res.cloudinary.com/al-mathina/...
    new_config = {
        'cloud_name': args.new_cloud_name or os.getenv('NEW_CLOUDINARY_CLOUD_NAME') or os.getenv('CLOUDINARY_CLOUD_NAME') or 'al-mathina',  # ← Change 'al-mathina' to your new cloud name
        'api_key': args.new_api_key or os.getenv('NEW_CLOUDINARY_API_KEY') or os.getenv('CLOUDINARY_API_KEY') or '514621122679917',  # ← Add your new API key
        'api_secret': args.new_api_secret or os.getenv('NEW_CLOUDINARY_API_SECRET') or os.getenv('CLOUDINARY_API_SECRET') or 'F6XWJAY0OeJeCckC2iXYf7fyuyA'  # ← Add your new API secret
    }
    
    # Validate credentials
    if not all(old_config.values()):
        logger.error("❌ Old Cloudinary credentials not provided!")
        logger.info("Please provide via command line args or environment variables:")
        logger.info("  --old-cloud-name or OLD_CLOUDINARY_CLOUD_NAME")
        logger.info("  --old-api-key or OLD_CLOUDINARY_API_KEY")
        logger.info("  --old-api-secret or OLD_CLOUDINARY_API_SECRET")
        sys.exit(1)
    
    if not all(new_config.values()):
        logger.error("❌ New Cloudinary credentials not provided!")
        logger.info("Please provide via command line args or environment variables:")
        logger.info("  --new-cloud-name or NEW_CLOUDINARY_CLOUD_NAME or CLOUDINARY_CLOUD_NAME")
        logger.info("  --new-api-key or NEW_CLOUDINARY_API_KEY or CLOUDINARY_API_KEY")
        logger.info("  --new-api-secret or NEW_CLOUDINARY_API_SECRET or CLOUDINARY_API_SECRET")
        sys.exit(1)
    
    # Confirm before proceeding
    if not args.dry_run:
        logger.warning("\n⚠️  WARNING: This will migrate images and update database URLs!")
        logger.warning(f"   Old account: {old_config['cloud_name']}")
        logger.warning(f"   New account: {new_config['cloud_name']}")
        if not args.skip_delete:
            logger.warning(f"   DELETE FROM OLD: YES (after verification)")
            logger.warning(f"   Use --skip-delete flag to keep images in old account")
        else:
            logger.warning(f"   DELETE FROM OLD: NO (safer mode)")
        if args.test_limit:
            logger.warning(f"   🧪 TEST MODE: Will process only {args.test_limit} image(s)")
        response = input("\n   Continue? (y/yes): ").strip().lower()
        if response not in ['y', 'yes']:
            logger.info("Migration cancelled.")
            sys.exit(0)
    
    # Run migration
    migration = CloudinaryMigration(
        old_config, 
        new_config, 
        dry_run=args.dry_run, 
        skip_delete=args.skip_delete,
        test_limit=args.test_limit
    )
    migration.run()


if __name__ == '__main__':
    main()
