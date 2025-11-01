# 📸 Image Upload Guidelines for AL-Madhina Admin Dashboard

## 🎯 **NEW STANDARD: All Images 400×400px**

**Universal Image Size:** All category and product images should now be **400×400 pixels** for consistency.

### **Quick Summary**
- **Dimensions:** 400 × 400 px (square)
- **File Size:** ~1MB or less
- **File Types:** JPG, JPEG, PNG, WEBP
- **Use the built-in Image Converter tool to prepare your images!**

---

## � **NEW: Built-in Image Converter Tool**

### How to Use:
1. Click the **🖼️ Image Converter** button in the admin dashboard
2. Upload any image (any size, any format)
3. The tool automatically:
   - Resizes to 400×400px
   - Crops and centers the image
   - Compresses to ~1MB
   - Maintains image quality
4. Adjust the quality slider if needed (60-100%)
5. Click **⬇️ Download Converted Image**
6. Upload the downloaded image to your categories/products

### Benefits:
- ✅ No need for external tools
- ✅ Consistent sizing across all images
- ✅ Automatic optimization
- ✅ Real-time preview of original vs converted
- ✅ Quality control slider
- ✅ File size feedback

---

## 📏 Standard Dimensions (All Categories)

| Category Type | Size | Aspect Ratio | Purpose |
|---------------|------|--------------|---------|
| **Section** | 400 × 400 px | 1:1 | Section headers |
| **Main Category** | 400 × 400 px | 1:1 | Category cards |
| **Subcategory** | 400 × 400 px | 1:1 | Subcategory cards |
| **Product** | 400 × 400 px | 1:1 | Product listings |

**Why 400×400?**
- Perfect for mobile displays
- Fast loading times
- Consistent look across all categories
- Maintains quality while keeping file size small
- Works on all screen sizes

---

## ⚙️ Technical Specifications

### File Validation (Frontend)
Location: `Backend/static/admin/js/dashboard.js`

```javascript
// Allowed file types
const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

// Max file size: 5MB
if (file.size > 5 * 1024 * 1024) {
    showToast('File too large. Maximum size is 5MB', 'error');
}
```

### Backend Validation
Location: `Backend/routes/admin_production.py`

```python
# Validate file type
if not file.content_type.startswith('image/'):
    raise HTTPException(status_code=400, detail="File must be an image")

# Validate file size (max 5MB)
if len(file_content) > 5 * 1024 * 1024:
    raise HTTPException(status_code=400, detail="File size must be less than 5MB")
```

### Image Storage
- **Platform:** Cloudinary
- **Folder:** `almathina/`
- **Format:** Original format preserved (JPEG, PNG, WEBP)
- **Settings:** Progressive loading enabled for web optimization
- **Transformation:** None - original images preserved

---

## 🎨 Best Practices

### 1. **Aspect Ratios**
- **Square images (1:1)** work best for:
  - Main categories
  - Subcategories
  - Products
- **Landscape images (2:1)** work best for:
  - Sections (headers/banners)

### 2. **Image Quality**
- Use high-quality images but keep file size under 5MB
- Aim for **72-150 DPI** for web display
- Compress images before upload (use tools like TinyPNG, Squoosh)

### 3. **Composition**
- Center the main subject for square crops
- Avoid text at edges (will be cropped on mobile)
- Use consistent lighting and background style

### 4. **File Naming**
- Use descriptive names: `vegetables-category.jpg` ✅
- Avoid special characters: `veg@!#$.jpg` ❌
- Lowercase with hyphens recommended

---

## 📱 Display Behavior

### Object-Fit: Cover
All images use `object-fit: cover`, which means:
- Images fill the entire container
- Aspect ratio is preserved
- Edges may be cropped if aspect ratio doesn't match
- Center of image is prioritized

**Example:**
```
Upload: 800 × 400 px (landscape)
Display: 100% width × 80px height
Result: Sides will be cropped, center shows
```

### Responsive Design
- Images scale automatically on different screen sizes
- Mobile dashboard uses fixed heights for consistency
- Flutter app uses flexible layouts

---

## 🚨 Common Issues & Solutions

### Issue: "File too large"
**Solution:** Compress your image
- Use online tools: [TinyPNG](https://tinypng.com), [Squoosh](https://squoosh.app)
- Reduce dimensions if over 2000px
- Save as JPEG with 80-90% quality

### Issue: "Invalid file type"
**Solution:** Convert to supported format
- Supported: JPG, JPEG, PNG, WEBP
- Not supported: GIF, BMP, TIFF, SVG
- Use image editor to convert (Paint, Photoshop, GIMP)

### Issue: Image looks cropped/zoomed
**Solution:** Use correct aspect ratio
- Main categories: Upload **square** images (1:1)
- Sections: Upload **landscape** images (2:1)
- Center important content

### Issue: Image looks pixelated
**Solution:** Upload higher resolution
- Minimum: 200px per side
- Recommended: 400-600px per side
- Don't upscale small images - find higher quality source

---

## 📊 Quick Reference Table

| Category Type | Min Size | Recommended | Max Size | Aspect Ratio | Display Size (Admin) |
|---------------|----------|-------------|----------|--------------|---------------------|
| **Section** | 300×200 | 800×400 | 1920×1080 | 2:1 | 100% × 80px |
| **Main Category** | 200×200 | 500×500 | 1024×1024 | 1:1 | 100% × 80px |
| **Subcategory** | 150×150 | 400×400 | 800×800 | 1:1 | 100% × 60px |
| **Product** | 200×200 | 600×600 | 1200×1200 | 1:1 | 70 × 70px |

**Universal Limits:**
- **Max File Size:** 5MB (enforced)
- **Supported Formats:** JPG, JPEG, PNG, WEBP
- **Storage:** Cloudinary (cloud-based)

---

## 🔗 Related Files

**Frontend Validation:**
- `Backend/static/admin/js/dashboard.js` (lines 930-942)

**Backend Validation:**
- `Backend/routes/admin_production.py` (lines 75-130)

**CSS Display Rules:**
- `Backend/static/admin/css/dashboard.css`
  - Main categories: lines 1718-1728
  - Subcategories: lines 1708-1715
  - Products: lines 2108-2127

**Image Upload Functions:**
- `uploadMainCategoryImage()` - line 3359
- `uploadSubCategoryImage()` - line 3611
- `uploadImageFile()` - line 1048

---

## ✅ Upload Checklist

Before uploading an image, verify:

- [ ] File size is under 5MB
- [ ] Format is JPG, PNG, or WEBP
- [ ] Dimensions meet minimum requirements
- [ ] Aspect ratio matches category type (1:1 for categories, 2:1 for sections)
- [ ] Main subject is centered
- [ ] Image is clear and not pixelated
- [ ] Filename is descriptive and clean

---

**Last Updated:** November 1, 2025  
**System:** AL-Madhina Admin Dashboard v2.0
