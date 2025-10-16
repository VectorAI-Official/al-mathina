# Image Upload - Quick Testing Guide

## 🎯 What Was Fixed

**Problem**: Images weren't showing after upload  
**Root Cause**: Wrong field priority - checking placeholder before actual image  
**Solution**: Swapped check order to `product.image` first, then `product.image_url`

## ✅ Testing Steps

### Test 1: Check Existing Product With Image

1. **Open**: http://127.0.0.1:8000/admin/login
2. **Login**: admin / admin123
3. **Switch to Mobile View**
4. **Navigate to**: Best Seller → Atta, Rice & Dal → Atta
5. **Find product**: "bngf"
6. **Expected**: Should show uploaded image (not placeholder)

### Test 2: Add New Product With Image

1. **Navigate to**: Best Seller → Drinks & Juices → Soft Drinks
2. **Click**: "Add New" button
3. **Fill in**:
   - Product Name: Test Image Upload
   - Weight: 500ml
   - Price: 25
   - Stock: 100
   - **Select an image file**
4. **Click**: Save
5. **Expected**: 
   - ✅ "Product saved successfully" toast
   - ✅ "Image uploaded successfully" toast
   - ✅ Product appears in list with image immediately
   - ✅ No placeholder image

### Test 3: Desktop View

1. **Click** three-dot menu → Switch to Desktop
2. **Find** the product you just created
3. **Expected**: Image shows in table

## 🔍 Browser Console Logs to Check

After clicking Save, you should see:

```
=== PRODUCT SUBMISSION DEBUG ===
Product Data: {...}

=== IMAGE UPLOAD CHECK ===
Image file selected: yourfile.jpg
Product ID: 68f06...

=== UPLOADING IMAGE FILE ===
Product ID: 68f06...
File name: yourfile.jpg
File size: 123456
File type: image/jpeg
Upload response status: 200
Upload successful: {...}
Image URL: /static/uploads/68f06...uuid.jpg

Reloading products and categories...
```

## ❌ If Images Still Don't Show

### Step 1: Clear Browser Cache
- Press **Ctrl + Shift + R** (Windows/Linux)
- Or **Cmd + Shift + R** (Mac)

### Step 2: Check Console for Errors
- Press **F12** to open DevTools
- Look for red error messages

### Step 3: Verify Database
```bash
cd Backend
venv\Scripts\python.exe diagnose_image_upload.py
```

Look for:
```
🖼️ IMAGE FIELDS:
  image: /static/uploads/... ← Should have path
  image_url: ... ← Can be placeholder
```

### Step 4: Check Files on Disk
```bash
dir Backend\static\uploads
```

Should show files like:
```
68f06e1990ffb03b451875b2_bf4a228d-8684-41f5-bfc4-968b2173863c.png
```

## 🐛 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Image not uploading | No file selected | Select image before saving |
| 500 error | File type not allowed | Use JPG, PNG, or WebP only |
| Image path wrong | Backend not running | Restart server |
| Still seeing placeholder | Browser cache | Hard refresh (Ctrl+Shift+R) |

## ✅ Success Indicators

1. ✅ Product card shows actual image (not 📦 emoji)
2. ✅ Image loads without 404 error
3. ✅ Both desktop and mobile views show image
4. ✅ Console shows "Upload successful"
5. ✅ Toast says "Image uploaded successfully"

## 📞 Need Help?

If still not working, provide:
1. Browser console logs (F12 → Console tab)
2. Backend terminal logs
3. Screenshot of the issue
4. Output from `diagnose_image_upload.py`
