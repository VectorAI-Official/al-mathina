# 🔄 Cloudinary Account Migration Guide

This guide explains how to transfer all images from your old Cloudinary account to a new one and update the database with new URLs.

---

## 📋 What This Script Does

1. **Scans Database** - Finds all images in:
   - Products collection (`image_url` field)
   - Category metadata collection (`image_url` field)

2. **Downloads Images** - Downloads each image from old Cloudinary account

3. **Uploads to New Account** - Uploads to new Cloudinary account maintaining folder structure:
   - `almathina/products/` - Product images
   - `almathina/categories/` - Category/subcategory images

4. **Updates Database** - Replaces all old URLs with new URLs in MongoDB

5. **Comprehensive Logging** - Tracks every step with detailed logs

---

## 🚀 Quick Start

### Step 1: Set Environment Variables

Create a `.env.migration` file or add to your existing `.env`:

```bash
# Old Cloudinary Account (source)
OLD_CLOUDINARY_CLOUD_NAME=your_old_cloud_name
OLD_CLOUDINARY_API_KEY=your_old_api_key
OLD_CLOUDINARY_API_SECRET=your_old_api_secret

# New Cloudinary Account (destination)
NEW_CLOUDINARY_CLOUD_NAME=your_new_cloud_name
NEW_CLOUDINARY_API_KEY=your_new_api_key
NEW_CLOUDINARY_API_SECRET=your_new_api_secret
```

Or use existing production variables:
```bash
# The script will use these as new account credentials
CLOUDINARY_CLOUD_NAME=your_new_cloud_name
CLOUDINARY_API_KEY=your_new_api_key
CLOUDINARY_API_SECRET=your_new_api_secret
```

### Step 2: Install Required Package

```powershell
cd Backend
.\venv\Scripts\Activate.ps1
pip install requests
```

### Step 3: Run Dry Run (Test)

**ALWAYS run dry run first to see what will happen:**

```powershell
python migrate_cloudinary_images.py --dry-run
```

This will:
- ✅ Scan database and show all images found
- ✅ Show what would be migrated
- ✅ NO actual downloads, uploads, or database changes
- ✅ Generate a log file for review

### Step 4: Review Dry Run Output

Check the log file: `cloudinary_migration_YYYYMMDD_HHMMSS.log`

Look for:
- Total images found
- Any invalid URLs
- Expected migration count

### Step 5: Execute Real Migration

Once satisfied with dry run:

```powershell
python migrate_cloudinary_images.py
```

The script will:
1. Ask for confirmation before starting
2. Migrate each image one by one
3. Update database with new URLs
4. Generate migration map (JSON file)
5. Show final summary

---

## 📊 Command Line Options

### Basic Usage:
```powershell
# Dry run (recommended first)
python migrate_cloudinary_images.py --dry-run

# Real migration
python migrate_cloudinary_images.py
```

### With Credentials in Command Line:
```powershell
python migrate_cloudinary_images.py \
    --old-cloud-name "old_account" \
    --old-api-key "old_key" \
    --old-api-secret "old_secret" \
    --new-cloud-name "new_account" \
    --new-api-key "new_key" \
    --new-api-secret "new_secret"
```

### Dry Run with Credentials:
```powershell
python migrate_cloudinary_images.py --dry-run \
    --old-cloud-name "old_account" \
    --old-api-key "old_key" \
    --old-api-secret "old_secret" \
    --new-cloud-name "new_account" \
    --new-api-key "new_key" \
    --new-api-secret "new_secret"
```

---

## 📝 Console Output Example

### Dry Run Output:
```
================================================================================
🚀 CLOUDINARY MIGRATION INITIALIZED
================================================================================
Old Account: vectorai_old
New Account: vectorai_new
Mode: DRY RUN (no changes)
================================================================================

================================================================================
🔍 SCANNING DATABASE FOR IMAGES
================================================================================

📦 Scanning Products...
   Found 245 product images

📂 Scanning Category Metadata...
   Found 38 category/subcategory images

================================================================================
📊 TOTAL UNIQUE IMAGES TO MIGRATE: 283
================================================================================

================================================================================
🚀 STARTING MIGRATION
================================================================================

[1/283] Processing image...
   📥 Migrating: https://res.cloudinary.com/vectorai_old/image/upload/v123/almathina/products/rice.jpg
   [DRY RUN] Would upload to: almathina/products/rice
   ✅ Migration complete!
   Old: https://res.cloudinary.com/vectorai_old/image/upload/v123/almathina/products/rice.jpg
   New: https://res.cloudinary.com/vectorai_new/image/upload/v1/almathina/products/rice.jpg

[2/283] Processing image...
...

================================================================================
📊 UPDATING DATABASE
================================================================================
[DRY RUN] Would update database with new URLs

================================================================================
📊 MIGRATION SUMMARY
================================================================================
Total Images Found:      283
Successfully Migrated:   283
Skipped:                 0
Failed:                  0
Database Updates:        0 (dry run)
================================================================================

✅ DRY RUN COMPLETE - No actual changes made
```

### Real Migration Output:
```
================================================================================
🚀 CLOUDINARY MIGRATION INITIALIZED
================================================================================
Old Account: vectorai_old
New Account: vectorai_new
Mode: LIVE MIGRATION
================================================================================

⚠️  WARNING: This will migrate images and update database URLs!
   Old account: vectorai_old
   New account: vectorai_new

   Continue? (yes/no): yes

[1/283] Processing image...
   📥 Migrating: https://res.cloudinary.com/vectorai_old/image/upload/v123/almathina/products/rice.jpg
   📦 Downloading from old account...
   ✓ Downloaded 45632 bytes
   📤 Uploading to new account...
   ✓ Uploaded to new account: https://res.cloudinary.com/vectorai_new/image/upload/v1234567890/almathina/products/rice.jpg
   ✅ Migration complete!

================================================================================
📊 UPDATING DATABASE
================================================================================

📦 Updating Products...
   ✓ Updated product: Basmati Rice
   ✓ Updated product: Brown Rice
   ...
   Products updated: 245

📂 Updating Category Metadata...
   ✓ Updated main_category: Groceries
   ✓ Updated subcategory: Rice & Grains
   ...
   Metadata updated: 38

================================================================================
📊 MIGRATION SUMMARY
================================================================================
Total Images Found:      283
Successfully Migrated:   283
Skipped:                 0
Failed:                  0
Database Updates:        283
================================================================================

💾 Migration map saved to: migration_map_20251111_143025.json

✅ MIGRATION COMPLETE!
```

---

## 📁 Output Files

### 1. Log File
**Format:** `cloudinary_migration_YYYYMMDD_HHMMSS.log`

Contains complete migration log with:
- All images processed
- Success/failure for each
- Database updates
- Errors and warnings

### 2. Migration Map (JSON)
**Format:** `migration_map_YYYYMMDD_HHMMSS.json`

Contains mapping of old URLs to new URLs:
```json
{
  "https://res.cloudinary.com/old/image/upload/v123/almathina/products/rice.jpg": "https://res.cloudinary.com/new/image/upload/v456/almathina/products/rice.jpg",
  "https://res.cloudinary.com/old/image/upload/v124/almathina/products/wheat.jpg": "https://res.cloudinary.com/new/image/upload/v457/almathina/products/wheat.jpg"
}
```

Use this file to:
- Verify migrations
- Rollback if needed (manual process)
- Debug issues

---

## ⚠️ Important Notes

### Before Migration:

1. **Backup Database**
   ```bash
   # MongoDB backup command
   mongodump --uri="your_mongo_uri" --out=./backup_before_migration
   ```

2. **Run Dry Run First** - ALWAYS test before actual migration

3. **Check New Cloudinary Account** - Ensure enough storage space

4. **Verify Old Account Access** - Test credentials work

### During Migration:

- ✅ Don't interrupt the process
- ✅ Monitor log file for errors
- ✅ Check network connection
- ✅ Script handles rate limiting (0.5s delay between uploads)

### After Migration:

1. **Verify Images**
   - Check a few products in admin dashboard
   - Verify images load correctly
   - Check Flutter app displays images

2. **Check Database**
   ```python
   # Quick verification script
   db = get_mongo_db()
   
   # Check products
   old_urls = db.products.count_documents({"image_url": {"$regex": "old_cloud_name"}})
   new_urls = db.products.count_documents({"image_url": {"$regex": "new_cloud_name"}})
   
   print(f"Products with old URLs: {old_urls}")
   print(f"Products with new URLs: {new_urls}")
   ```

3. **Update Config**
   - Make sure production config uses new Cloudinary credentials
   - Remove old credentials from environment

---

## 🐛 Troubleshooting

### Issue: "Old Cloudinary credentials not provided"
**Solution:** Set environment variables or pass via command line args

### Issue: "Failed to download" errors
**Possible Causes:**
- Old Cloudinary credentials invalid
- Network issues
- Image URL format changed

**Solution:**
- Verify old account credentials
- Check network connection
- Review failed_migrations list in log

### Issue: "Failed to upload" errors
**Possible Causes:**
- New Cloudinary credentials invalid
- Storage quota exceeded
- Network issues

**Solution:**
- Verify new account credentials
- Check Cloudinary storage quota
- Retry failed images

### Issue: Images not updating in database
**Possible Causes:**
- MongoDB connection issues
- Image URLs don't match

**Solution:**
- Verify MongoDB connection
- Check old URL format in database
- Review migration_map.json

---

## 🔄 Rollback Procedure

If something goes wrong:

### Option 1: Restore Database Backup
```bash
mongorestore --uri="your_mongo_uri" ./backup_before_migration
```

### Option 2: Manual URL Revert (if you have migration_map.json)
```python
import json
from database.mongodb_client import get_mongo_db

# Load migration map
with open('migration_map_YYYYMMDD_HHMMSS.json') as f:
    migration_map = json.load(f)

# Reverse mapping (new -> old)
reverse_map = {v: k for k, v in migration_map.items()}

db = get_mongo_db()

# Revert products
for new_url, old_url in reverse_map.items():
    db.products.update_many(
        {"image_url": new_url},
        {"$set": {"image_url": old_url}}
    )

# Revert metadata
for new_url, old_url in reverse_map.items():
    db.category_metadata.update_many(
        {"image_url": new_url},
        {"$set": {"image_url": old_url}}
    )

print("Rollback complete!")
```

---

## 📊 Migration Statistics

Example from a typical migration:

```
Database Size: ~500 products, ~50 categories
Total Images: 283 unique images
Migration Time: ~15 minutes (depends on image sizes and network)
Success Rate: 100%
Database Updates: 283 records
Log File Size: ~150 KB
Migration Map Size: ~30 KB
```

---

## ✅ Post-Migration Checklist

- [ ] All images migrated successfully (check summary)
- [ ] Database URLs updated (verify with MongoDB query)
- [ ] Admin dashboard images loading
- [ ] Flutter app images loading
- [ ] Migration map saved
- [ ] Log file reviewed for errors
- [ ] Old Cloudinary credentials removed from production config
- [ ] New Cloudinary credentials active in production
- [ ] Backup created before migration
- [ ] Can delete images from old account (optional - keep as backup initially)

---

## 🚀 Ready to Migrate!

**Recommended Steps:**

1. ✅ Create database backup
2. ✅ Set environment variables
3. ✅ Run dry run: `python migrate_cloudinary_images.py --dry-run`
4. ✅ Review dry run log
5. ✅ Run real migration: `python migrate_cloudinary_images.py`
6. ✅ Verify images in admin/app
7. ✅ Update production config
8. ✅ Test thoroughly

**Need Help?**
- Check log files for detailed error messages
- Review migration_map.json for URL mappings
- Contact support if issues persist

Good luck with your migration! 🎉
