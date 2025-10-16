# Image Upload Guide for AL-Madhina

## Current Status
✅ Flutter app is fully integrated with backend
✅ All data fetched from MongoDB
⚠️ **Main Category images are not yet uploaded**

## How to Add Images

### Option 1: Using Admin Dashboard

1. **Start the backend:**
   ```powershell
   cd Backend
   & .\venv\Scripts\Activate.ps1
   python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000
   ```

2. **Open Admin Dashboard:**
   - Go to: http://127.0.0.1:8000/admin/login
   - Username: `admin`
   - Password: `admin123`

3. **Navigate to Categories:**
   - Click on "Category Management" in the sidebar
   - Select a Section (e.g., "Grocery & Kitchen")
   - Find the Main Category you want to add an image to
   - Click "Edit" or the edit icon

4. **Upload Image:**
   - Click "Upload Image" or "Choose File"
   - Select an image file (PNG, JPG, or WebP recommended)
   - Image will be uploaded to `/static/uploads/` folder
   - Save the changes

### Option 2: Direct Database Update

If you want to manually add images via MongoDB:

1. **Place images in the uploads folder:**
   ```
   Backend/static/uploads/
   ```

2. **Update MongoDB directly:**
   ```javascript
   db.category_metadata.updateOne(
     {
       section: "Grocery & Kitchen",
       main_category: "Atta, Rice & Dal"
     },
     {
       $set: {
         image_url: "/static/uploads/atta-rice-dal.jpg"
       }
     }
   )
   ```

### Image Specifications

**Recommended:**
- **Format**: JPG, PNG, or WebP
- **Size**: 500x500px (square aspect ratio)
- **File size**: Under 500KB for faster loading
- **Resolution**: 72 DPI is sufficient for web

**Minimum:**
- **Format**: Any image format
- **Size**: 300x300px minimum
- **File size**: Under 2MB

## Image URL Structure

Images are accessed via:
```
http://127.0.0.1:8000/static/uploads/filename.jpg
```

The Flutter app automatically constructs full URLs using `ApiService.getImageUrl()`.

## Default Behavior (No Images)

When no image is uploaded:
- Flutter app shows a placeholder icon (📂 for categories)
- App functions normally, just without images
- Users can still browse and add products to cart

## Testing Image Display

1. **Upload an image via admin dashboard**
2. **Restart the Flutter app** or pull to refresh the home screen
3. **Images should appear** in the category cards

## Troubleshooting

**Images not showing:**
1. Check if image file exists in `Backend/static/uploads/`
2. Verify `image_url` field in MongoDB is correct
3. Check browser console for 404 errors
4. Ensure backend is running on port 8000
5. Clear browser cache and reload

**Image upload fails:**
1. Check folder permissions for `Backend/static/uploads/`
2. Verify file size is under limit
3. Check admin dashboard console for errors

## Next Steps

To populate all category images:
1. Collect/create images for all 15+ main categories
2. Upload via admin dashboard
3. Verify in Flutter app
4. Done! ✅
