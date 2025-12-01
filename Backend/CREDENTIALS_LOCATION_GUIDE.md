# 📍 WHERE TO ADD CLOUDINARY CREDENTIALS

## Quick Reference

Your URLs:
- **Old**: `https://res.cloudinary.com/vectorai/image/upload/v1762544730/almathina/products/690e4c592ba9e5019c958faf.jpg`
- **New**: `https://res.cloudinary.com/al-mathina/image/upload/v1762876292/almathina/products/69135b821b0f0ffb25c45996.jpg`

Extracted:
- **Old cloud name**: `vectorai`
- **New cloud name**: `al-mathina`

---

## 🎯 Option 1: Edit Script Directly (Easiest)

Open `migrate_cloudinary_images.py` and find these lines (around line 450):

```python
# ========================================================================
# ADD YOUR OLD CLOUDINARY CREDENTIALS HERE (or use environment variables)
# ========================================================================
# Old account: https://res.cloudinary.com/vectorai/...
old_config = {
    'cloud_name': args.old_cloud_name or os.getenv('OLD_CLOUDINARY_CLOUD_NAME') or 'vectorai',  # ← ALREADY SET!
    'api_key': args.old_api_key or os.getenv('OLD_CLOUDINARY_API_KEY') or 'YOUR_OLD_API_KEY_HERE',  # ← REPLACE THIS
    'api_secret': args.old_api_secret or os.getenv('OLD_CLOUDINARY_API_SECRET') or 'YOUR_OLD_API_SECRET_HERE'  # ← REPLACE THIS
}

# ========================================================================
# ADD YOUR NEW CLOUDINARY CREDENTIALS HERE (or use environment variables)
# ========================================================================
# New account: https://res.cloudinary.com/al-mathina/...
new_config = {
    'cloud_name': args.new_cloud_name or os.getenv('NEW_CLOUDINARY_CLOUD_NAME') or os.getenv('CLOUDINARY_CLOUD_NAME') or 'al-mathina',  # ← ALREADY SET!
    'api_key': args.new_api_key or os.getenv('NEW_CLOUDINARY_API_KEY') or os.getenv('CLOUDINARY_API_KEY') or 'YOUR_NEW_API_KEY_HERE',  # ← REPLACE THIS
    'api_secret': args.new_api_secret or os.getenv('NEW_CLOUDINARY_API_SECRET') or os.getenv('CLOUDINARY_API_SECRET') or 'YOUR_NEW_API_SECRET_HERE'  # ← REPLACE THIS
}
```

### What to Replace:

#### Old Account (vectorai):
```python
'api_key': '123456789012345',  # ← Your old Cloudinary API key
'api_secret': 'abcdefghijklmnopqrstuvwxyz123456'  # ← Your old Cloudinary API secret
```

#### New Account (al-mathina):
```python
'api_key': '987654321098765',  # ← Your new Cloudinary API key
'api_secret': 'zyxwvutsrqponmlkjihgfedcba654321'  # ← Your new Cloudinary API secret
```

---

## 🎯 Option 2: Use Environment Variables (More Secure)

Create `.env.migration` file:

```bash
# Old Cloudinary Account (vectorai)
OLD_CLOUDINARY_CLOUD_NAME=vectorai
OLD_CLOUDINARY_API_KEY=your_old_api_key_here
OLD_CLOUDINARY_API_SECRET=your_old_api_secret_here

# New Cloudinary Account (al-mathina)
NEW_CLOUDINARY_CLOUD_NAME=al-mathina
NEW_CLOUDINARY_API_KEY=your_new_api_key_here
NEW_CLOUDINARY_API_SECRET=your_new_api_secret_here
```

Then load it before running:
```powershell
# PowerShell
Get-Content .env.migration | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}

python migrate_cloudinary_images.py --dry-run
```

---

## 🎯 Option 3: Command Line Arguments (Most Secure)

```powershell
python migrate_cloudinary_images.py `
    --old-cloud-name "vectorai" `
    --old-api-key "YOUR_OLD_API_KEY" `
    --old-api-secret "YOUR_OLD_API_SECRET" `
    --new-cloud-name "al-mathina" `
    --new-api-key "YOUR_NEW_API_KEY" `
    --new-api-secret "YOUR_NEW_API_SECRET" `
    --dry-run
```

---

## 📍 How to Find Your Cloudinary Credentials

### For Old Account (vectorai):
1. Go to https://cloudinary.com
2. Login to your **vectorai** account
3. Click on Dashboard
4. Look for "Account Details" section
5. Copy:
   - **Cloud name**: vectorai ✅ (already in script)
   - **API Key**: Copy this number
   - **API Secret**: Click "reveal" and copy

### For New Account (al-mathina):
1. Go to https://cloudinary.com
2. Login to your **al-mathina** account (or switch accounts)
3. Click on Dashboard
4. Look for "Account Details" section
5. Copy:
   - **Cloud name**: al-mathina ✅ (already in script)
   - **API Key**: Copy this number
   - **API Secret**: Click "reveal" and copy

---

## ✅ Verification

After adding credentials, the cloud names are already correct:
- Old: `vectorai` ✅
- New: `al-mathina` ✅

You just need to add the API keys and secrets!

---

## 🔒 Updated Migration Process

The script now follows this **SAFE** process for EACH image:

```
1. 📥 Download from old account (vectorai)
   ↓
2. 📤 Upload to new account (al-mathina)
   ↓
3. 🔍 VERIFY new image exists and is accessible
   ↓ (ONLY if verification succeeds)
4. 💾 Update database with new URL
   ↓ (ONLY if database update succeeds)
5. 🗑️ Delete from old account (vectorai)
   ↓
6. ✅ Complete
```

**Safety Features:**
- ✅ Downloads first before any changes
- ✅ Verifies upload succeeded before updating DB
- ✅ Verifies image is accessible at new URL
- ✅ Updates database before deleting old
- ✅ Only deletes from old after ALL steps succeed
- ✅ Logs every step with detailed status
- ✅ Tracks failed migrations separately

---

## 🚀 Running the Migration

### Step 1: Test with Dry Run (RECOMMENDED)
```powershell
python migrate_cloudinary_images.py --dry-run
```

This will:
- Show what would happen
- Test credentials
- Not make any actual changes

### Step 2: Run with Skip Delete (SAFER)
```powershell
python migrate_cloudinary_images.py --skip-delete
```

This will:
- Download images
- Upload to new account
- Update database
- **NOT delete from old account** (keep as backup)

### Step 3: Run Full Migration (with deletion)
```powershell
python migrate_cloudinary_images.py
```

This will:
- Do everything
- Delete from old account after verification

---

## 📊 Example Output

```
================================================================================
🚀 CLOUDINARY MIGRATION INITIALIZED
================================================================================
Old Account: vectorai
New Account: al-mathina
Mode: LIVE MIGRATION
Delete from old: YES (after verification)
================================================================================

[1/283] Processing image...
   📥 Migrating: https://res.cloudinary.com/vectorai/image/upload/.../product.jpg
   📦 STEP 1/5: Downloading from old account...
   ✓ Downloaded 45632 bytes
   📤 STEP 2/5: Uploading to new account...
   ✓ Uploaded to new account: https://res.cloudinary.com/al-mathina/image/upload/.../product.jpg
   🔍 STEP 3/5: Verifying new image exists...
   ✓ Verification successful - new image is accessible
   💾 STEP 4/5: Marking for database update...
   ✓ Migration map updated
   🗑️  STEP 5/5: Deleting from old account...
   ✓ Deleted from old account: almathina/products/69135b821b0f0ffb25c45996
   ✅ Migration complete!
   Old: https://res.cloudinary.com/vectorai/image/upload/.../product.jpg
   New: https://res.cloudinary.com/al-mathina/image/upload/.../product.jpg

================================================================================
📊 MIGRATION SUMMARY
================================================================================
Total Images Found:      283
Successfully Migrated:   283
Skipped:                 0
Failed:                  0
Database Updates:        283
Deleted from Old:        283
================================================================================
```

---

## ⚠️ Important Notes

### Before Running:
1. ✅ Add API keys and secrets (only thing missing!)
2. ✅ Backup database
3. ✅ Run dry run first
4. ✅ Consider using `--skip-delete` flag first

### The Script Will:
1. ✅ Download each image
2. ✅ Upload to new account
3. ✅ Verify upload succeeded
4. ✅ Update database
5. ✅ Delete from old (only if all above succeed)

### Safety:
- ✅ Cloud names already correct
- ✅ Verification before deletion
- ✅ Database updated before deletion
- ✅ Each image processed individually
- ✅ Failures don't stop entire migration
- ✅ Complete logs for audit trail

---

## 🎯 Quick Checklist

- [ ] Found OLD account API key and secret (from vectorai dashboard)
- [ ] Found NEW account API key and secret (from al-mathina dashboard)
- [ ] Added credentials to script OR environment variables
- [ ] Created database backup
- [ ] Ran dry run: `python migrate_cloudinary_images.py --dry-run`
- [ ] Reviewed dry run log
- [ ] Ready to run: `python migrate_cloudinary_images.py --skip-delete` (safer)
- [ ] Or full migration: `python migrate_cloudinary_images.py`

You're almost there! Just add the API keys and secrets, and you're ready to go! 🚀
