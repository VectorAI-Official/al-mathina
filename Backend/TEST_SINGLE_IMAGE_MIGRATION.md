# 🧪 Test Single Image Migration - Quick Guide

## Purpose
Test the entire Cloudinary migration flow with **exactly 1 image** before running the full migration.

## What This Tests
1. ✅ Download from old account (vectorai)
2. ✅ Upload to new account (al-mathina)
3. ✅ Verification (checks if new image is accessible)
4. ✅ Database update (updates MongoDB with new URL)
5. ✅ Delete from old account (only if all above succeed)

---

## Step 1: Add Your API Credentials

Open `migrate_cloudinary_images.py` and find lines **522-535**:

```python
# OLD ACCOUNT (vectorai)
old_config = {
    'cloud_name': 'vectorai',  # ✅ Already set
    'api_key': '315192596216358',  # ✅ Already set
    'api_secret': 'JFpyMTpUZ01pRxaFpZjm_Na6H-s'  # ✅ Already set
}

# NEW ACCOUNT (al-mathina)
new_config = {
    'cloud_name': 'al-mathina',  # ✅ Already set
    'api_key': 'YOUR_NEW_API_KEY_HERE',  # ⏳ ADD THIS
    'api_secret': 'YOUR_NEW_API_SECRET_HERE'  # ⏳ ADD THIS
}
```

**Replace the placeholder values** with your actual credentials from Cloudinary dashboard.

---

## Step 2: Run Test Migration with 1 Image

Open PowerShell in the `Backend` folder and run:

```powershell
# Make sure you're in Backend directory
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Activate virtual environment (if using one)
.\venv\Scripts\Activate.ps1

# Run migration with test limit
python migrate_cloudinary_images.py --test-limit 1
```

### What Happens:
- Script will scan database for images
- **Only process the FIRST image** found
- Shows detailed step-by-step logs with emojis
- Creates `cloudinary_migration_map.json` with results
- Creates `cloudinary_migration.log` with complete logs

---

## Step 3: Watch the Console Output

You should see output like this:

```
================================================================================
🚀 CLOUDINARY MIGRATION INITIALIZED
================================================================================
Old Account: vectorai
New Account: al-mathina
Mode: LIVE MIGRATION
Delete from old: YES (after verification)
🧪 TEST MODE: Will only process 1 image(s)
================================================================================

🔍 STEP 1: Scanning database for old Cloudinary URLs...
📊 Found 287 total images in database
   - Category metadata: 120 images
   - Products: 167 images

🧪 TEST MODE: Processing only 1 out of 287 total image(s)

================================================================================
🚀 STARTING MIGRATION
================================================================================

[1/1] Processing image...
  Old URL: https://res.cloudinary.com/vectorai/image/upload/v.../almathina/products/ID.jpg

  📥 STEP 1: Downloading from old account...
     ✅ Downloaded successfully (2.3 MB)

  📤 STEP 2: Uploading to new account...
     ✅ Uploaded successfully
     New URL: https://res.cloudinary.com/al-mathina/image/upload/v.../almathina/products/ID.jpg

  🔍 STEP 3: VERIFYING new image exists...
     ✅ Verification successful! Image is accessible at new URL

  💾 STEP 4: Marking for database update...
     ✅ Added to update queue

  🗑️ STEP 5: Deleting from old account...
     ✅ Deleted successfully from old account

✅ Migration successful for this image!
```

---

## Step 4: Verify Results

### Check Migration Map
Open `cloudinary_migration_map.json`:

```json
{
  "https://res.cloudinary.com/vectorai/image/upload/.../ID.jpg": 
  "https://res.cloudinary.com/al-mathina/image/upload/.../ID.jpg"
}
```

### Check Database
1. Open MongoDB Compass or Atlas
2. Find the product/category with the migrated image
3. Verify `image_url` now points to `al-mathina` instead of `vectorai`

### Check New Cloudinary Account
1. Log in to Cloudinary dashboard (al-mathina account)
2. Go to Media Library
3. Verify the image appears in `almathina/products/` or `almathina/categories/`

### Check Old Cloudinary Account
1. Log in to old Cloudinary dashboard (vectorai account)
2. Verify the image is **deleted** (no longer appears in Media Library)

---

## If Test Succeeds ✅

Run the full migration:

```powershell
# Without skip-delete (deletes from old account after verification)
python migrate_cloudinary_images.py

# OR with skip-delete (keeps images in old account as backup)
python migrate_cloudinary_images.py --skip-delete
```

---

## If Test Fails ❌

### Common Issues:

**1. "Old Cloudinary credentials not provided"**
- You forgot to add API key/secret for old account
- Check lines 522-527 in script

**2. "New Cloudinary credentials not provided"**
- You forgot to add API key/secret for new account
- Check lines 530-535 in script

**3. "Failed to download from old account"**
- Old API credentials are incorrect
- Old cloud name is wrong
- Image doesn't exist in old account

**4. "Failed to upload to new account"**
- New API credentials are incorrect
- Upload limit reached on new account
- Network issue

**5. "Verification failed"**
- New image was uploaded but URL is not accessible
- Cloudinary processing delay (wait 1 minute and check URL manually)

**6. Database not updated**
- MongoDB connection issue
- Check MongoDB Atlas connection string
- Verify network access in Atlas

---

## Safety Features

✅ **Verification Step**: Confirms image exists at new URL before deleting old  
✅ **Database Update First**: Updates DB before deleting from old account  
✅ **Individual Processing**: Each image is independent (one failure doesn't affect others)  
✅ **Complete Logging**: Every step logged to console and `cloudinary_migration.log`  
✅ **Migration Map**: JSON file maps old URLs to new URLs  
✅ **Test Mode**: Test with 1 image before committing to full migration

---

## Alternative: Safer Test with Dry-Run

If you want to test **without making ANY changes**:

```powershell
# Dry run: shows what would happen without actually doing it
python migrate_cloudinary_images.py --dry-run --test-limit 1
```

This will:
- ✅ Scan database
- ✅ Show which image would be migrated
- ❌ NOT download/upload/delete/update anything

---

## Next Steps After Successful Test

1. ✅ Test passed with 1 image
2. Check Flutter app - does the migrated image display correctly?
3. Check admin dashboard - does the image appear correctly?
4. Run full migration: `python migrate_cloudinary_images.py`

---

## Questions?

- Check `cloudinary_migration.log` for detailed logs
- Check `cloudinary_migration_map.json` for URL mappings
- Re-run with `--dry-run` to simulate without changes
- Re-run with `--skip-delete` to keep old images as backup
