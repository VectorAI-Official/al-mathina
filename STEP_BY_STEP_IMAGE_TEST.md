# Step-by-Step Image Replacement Testing Guide

## Current Issue & Fix

### Problem
When replacing an image, Cloudinary converts PNG → WebP (or other formats) due to account-level optimization settings.

### Root Cause
Cloudinary account has automatic format conversion enabled. Our code wasn't explicitly setting the format.

### Solution Applied (Just Now)
Added `format=file_ext.lstrip('.')` to force the exact file format:

```python
result = cloudinary.uploader.upload(
    file_content,
    public_id=public_id,
    format=file_ext.lstrip('.'),  # ✅ Force PNG to stay PNG
    transformation=None  # ✅ No auto-conversions
)
```

---

## Step-by-Step Testing

### Step 1: Verify Backend is Ready
```powershell
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "healthy",
  "mongodb": "connected",
  "cloudinary": true
}
```

✅ If you see this, proceed to Step 2.

---

### Step 2: Check Current Product Image
Open dashboard and check Green Chilli product:

**URL:** http://localhost:8000/admin/dashboard

**Look for:**
- Product name: "Green Chilli"
- Product ID: 68f7ba16d426db882816c99a
- Current image (if any)

Note the current image format (PNG, JPG, WebP, etc.)

---

### Step 3: Prepare Test Image

Use ANY image file. For this test, we recommend:
- **test.png** - Small PNG file
- **test.jpg** - Small JPG file
- **test.webp** - Small WebP file

(Any image works; sizes vary)

---

### Step 4: Edit Green Chilli Product

1. In dashboard, find "Green Chilli"
2. Click **Edit** button
3. Change one field (e.g., price or weight) to mark it as modified
4. **DO NOT** upload image yet
5. Click **Save Product**

Expected: Product updates successfully

✅ If successful, proceed to Step 5.

---

### Step 5: Upload New Image (THE TEST)

1. **On the same edit page**, look for image upload field
2. Select your test image (e.g., test.png)
3. Click **Upload Image** button
4. Watch for success message

Expected messages in browser console:
```
Upload response status: 200
Upload successful: {success: true, image_url: '...'}
Image URL: https://res.cloudinary.com/vectorai/image/upload/...
```

✅ If you see these, proceed to Step 6.

---

### Step 6: Verify Format in Console

**IMPORTANT:** Check the returned URL in Step 5.

If you uploaded **test.png**, the URL should end with:
- ✅ `.png` (CORRECT - format preserved)
- ❌ `.webp` (WRONG - still converting)
- ❌ `.jpg` (WRONG - wrong format)

**Copy the Image URL** from the console. It should look like:
```
https://res.cloudinary.com/vectorai/image/upload/v1761577302/almathina/products/68f7ba16d426db882816c99a.png
```

---

### Step 7: Check Backend Logs

Open terminal and run:
```powershell
docker-compose logs backend --tail 30 | Select-String "Image uploaded successfully|Database updated" -Context 1
```

Expected output:
```
Image uploaded successfully: https://...png
Database updated: matched=1, modified=1
Product image uploaded successfully
```

✅ If you see "matched=1, modified=1", database update succeeded!

---

### Step 8: Refresh Dashboard

1. **Go back to dashboard** (or refresh page)
2. Look for Green Chilli product
3. **Should display the new image**

### Verification Points:
- [ ] Image displays in dashboard
- [ ] Image has correct format (PNG not WebP)
- [ ] Image is the one you uploaded
- [ ] Not showing old image
- [ ] Not showing broken image icon

✅ If all checkmarks pass, the fix is working!

---

### Step 9: Test Again with Different Format

Repeat Steps 4-8 but upload a **JPG file** this time.

Expected:
- Upload JPG → URL ends with `.jpg` (not `.webp`)
- Image displays correctly
- Format preserved

---

### Step 10: Verify in API

Get all products via API:
```powershell
curl http://localhost:8000/admin/api/products/all | ConvertFrom-Json | 
  Select-Object -ExpandProperty products | 
  Where-Object {$_.product_name -eq "Green Chilli"} | 
  Select-Object product_name, image_url | 
  ConvertTo-Json
```

Expected:
```json
{
  "product_name": "Green Chilli",
  "image_url": "https://res.cloudinary.com/vectorai/image/upload/.../68f7ba16d426db882816c99a.png"
}
```

✅ Image URL should:
- Not be empty
- Contain your uploaded file format (`.png`, `.jpg`, etc.)
- Match the image shown in dashboard

---

## Troubleshooting If Still Broken

### Issue 1: Still Showing WebP Format

**If URL still ends with `.webp`:**

1. Check backend logs for errors:
   ```powershell
   docker-compose logs backend --tail 50 | Select-String "Error|error|ERROR"
   ```

2. Verify hot-reload applied changes:
   ```powershell
   docker-compose logs backend | Select-String "Shutting down|Startup complete"
   ```

3. If no restart happened, force restart:
   ```powershell
   docker-compose down
   docker-compose up -d
   ```

### Issue 2: Image Not Showing in Dashboard

**If upload succeeds but image doesn't display:**

1. Check database was updated:
   ```powershell
   docker-compose logs backend --tail 30 | Select-String "Database updated"
   ```

2. If shows "matched=0", database update failed
3. Check that URL is Cloudinary URL (not local path)

### Issue 3: Upload Returns Error

**If upload fails:**

1. Check Cloudinary credentials:
   ```powershell
   python validate_credentials.py
   ```

2. Check backend logs:
   ```powershell
   docker-compose logs backend --tail 50 | Select-String "UPLOADING|Error|error"
   ```

3. Verify file size < 50MB
4. Try different image format

---

## Quick Reference Commands

```powershell
# Terminal 1: Watch logs during upload
docker-compose logs -f backend | Select-String "UPLOADING|Image uploaded|Database updated"

# Terminal 2: Test API
curl http://localhost:8000/admin/api/products/all

# Terminal 3: Check specific product
curl http://localhost:8000/admin/api/products/all | ConvertFrom-Json | Where {$_.product_name -eq "Green Chilli"}

# Restart if needed
docker-compose down && docker-compose up -d

# Verify hot-reload
docker-compose logs backend | Select-String "Will watch for changes"
```

---

## Expected Behavior After Fix

| Action | Before | After |
|--------|--------|-------|
| Upload PNG | Converted to WebP | Stays PNG ✅ |
| Upload JPG | Converted to WebP | Stays JPG ✅ |
| Replace image | Format changes | Format preserved ✅ |
| Database saves | Wrong URL or empty | Correct URL ✅ |
| Dashboard shows | Wrong/broken image | Correct image ✅ |

---

## Success Criteria

✅ All of these must be true:

1. Upload PNG → URL ends with `.png` (not `.webp`)
2. Upload JPG → URL ends with `.jpg` (not `.webp`)
3. Backend logs show "Database updated: matched=1, modified=1"
4. Dashboard displays the uploaded image
5. Image format is preserved correctly
6. Replacing images works (not just new uploads)

If all 6 are working → **FIX IS COMPLETE** ✅

---

## Next Steps

Once all 6 criteria are met:

1. Test in Flutter mobile app
2. Test with different file sizes
3. Test uploading to multiple products
4. Ready for production deployment

---

## Important Note

The fix uses:
- `format=file_ext.lstrip('.')` - Forces exact format
- `transformation=None` - Removes all transformations

This overrides Cloudinary account-level settings and ensures format preservation.

If you see WebP still appearing, it means hot-reload didn't apply the change. Run `docker-compose restart` and try again.
