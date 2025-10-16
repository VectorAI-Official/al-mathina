# How to Upload Product Images - Step by Step Guide

## 🖼️ The Issue You're Experiencing

**Problem**: Products are being created WITHOUT images because the image file is not being selected before saving.

**What the logs show**:
```
=== IMAGE UPLOAD CHECK ===
Image file selected: None  ← No file was selected!
Skipping image upload: No file selected
```

## ✅ Correct Process to Add Product WITH Image

### Step 1: Open Add Product Modal
- Navigate to any subcategory (e.g., Best Seller → Drinks & Juices → Soft Drinks)
- Click **"➕ Add New"** button

### Step 2: Fill Product Details
- **Product Name**: Enter the product name (e.g., "Coca Cola")
- **Weight**: Enter weight/size (e.g., "500ml")
- **Price**: Enter price (e.g., 25)
- **Stock**: Enter stock quantity (e.g., 100)
- **Description**: Optional

### Step 3: ⚠️ **SELECT IMAGE FILE** (This is the critical step!)

Look for this section in the form:
```
┌─────────────────────────────────────┐
│ Product Image                       │
│ [Choose File] No file chosen        │ ← Click here!
│                                     │
│ ┌─────────────────────┐            │
│ │  [Image Preview]    │            │
│ │   Will appear here   │            │
│ └─────────────────────┘            │
└─────────────────────────────────────┘
```

**Actions**:
1. Click the **"Choose File"** button
2. Browse to your image file (JPG, PNG, or WebP)
3. Select the image
4. You should see a **preview** of the image appear

**Accepted formats**: JPEG, JPG, PNG, WebP  
**Max size**: 800KB recommended  
**Aspect ratio**: 1:1 (square) works best

### Step 4: Save the Product
- Click **"Save"** button
- Wait for the success messages

### Step 5: Verify Upload Success

You should see these toasts appear in sequence:
1. ✅ **"Product saved successfully"**
2. 📤 **"Uploading image..."** ← This confirms image is uploading
3. ✅ **"Image uploaded successfully!"** ← This confirms image is saved

**Browser console should show**:
```javascript
=== IMAGE UPLOAD CHECK ===
Image file selected: your-image.jpg  ← File name appears!
Product ID: 68f07138425ba27fe7b1203d

=== UPLOADING IMAGE FILE ===
Product ID: 68f07138425ba27fe7b1203d
File name: your-image.jpg
File size: 123456
File type: image/jpeg
Upload response status: 200
Upload successful: {...}
Image URL: /static/uploads/68f07138...uuid.jpg
```

## ❌ What Happens If You DON'T Select an Image

If you click "Save" without selecting an image:
- ✅ Product will be created successfully
- ℹ️ Toast will say: **"Product saved without image"**
- 📦 Product card will show emoji placeholder instead of image
- ❌ No image upload will happen

**Console shows**:
```
Image file selected: None
Skipping image upload: No file selected
```

## 🔄 How to Add Image to Existing Product

If you created a product without an image, you can add one later:

1. **Find the product** in the list
2. **Click the edit button** (✏️) on the product card
3. **Select an image** using "Choose File"
4. **Click "Save"**
5. Image will be uploaded and updated

## 🐛 Troubleshooting

### Problem: No "Choose File" button visible
**Solution**: Check if the modal has a "Product Image" field. If not, the HTML template may need updating.

### Problem: Image selected but not uploading
**Check console logs** (Press F12 → Console tab):
- Look for "=== IMAGE UPLOAD CHECK ==="
- Check if file name appears
- Look for any error messages

### Problem: Image uploads but doesn't display
**Hard refresh the browser**:
- Press **Ctrl + Shift + R** (Windows/Linux)
- Or **Cmd + Shift + R** (Mac)

### Problem: "Failed to upload image" error
**Possible causes**:
1. File size too large (max 800KB recommended)
2. Wrong file format (only JPG, PNG, WebP allowed)
3. Backend server not running
4. Upload directory permissions issue

## 📊 Visual Indicators

### When Image IS Selected:
```
=== IMAGE UPLOAD CHECK ===
✓ Image file selected: coca-cola.jpg
✓ Product ID: 68f07138425ba27fe7b1203d
→ Uploading image for product...
```

### When Image IS NOT Selected:
```
=== IMAGE UPLOAD CHECK ===
✗ Image file selected: None
✗ Skipping image upload: No file selected
```

## 📝 Summary

**To see product images**:
1. ✅ Open "Add Product" modal
2. ✅ Fill in product details
3. ✅ **Click "Choose File" and select image** ← CRITICAL STEP!
4. ✅ Verify image preview appears
5. ✅ Click "Save"
6. ✅ Wait for "Image uploaded successfully" toast
7. ✅ Image should appear in product card immediately

**The key is**: You must actively select an image file using the "Choose File" button BEFORE clicking Save!

## 🎯 Quick Test

Try this right now:
1. Go to any subcategory
2. Click "Add New"
3. Fill: Name: "Test Image", Weight: "100g", Price: 10, Stock: 50
4. **Click "Choose File"** ← Don't skip this!
5. Select ANY image from your computer
6. See the preview appear? Good!
7. Click "Save"
8. Watch for 3 toast messages
9. Product should appear with your image!

If you follow these steps exactly, the image WILL upload and display! 🎉
