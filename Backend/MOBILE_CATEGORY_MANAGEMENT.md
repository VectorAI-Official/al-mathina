# Mobile Category Management Feature

## Overview
The mobile preview panel now displays all categories from the database with the ability to edit category names and add custom images.

## Features

### 1. **Mobile Preview Panel**
- Click the "📱 Mobile View" button in the dashboard to open the mobile preview panel
- Panel slides in from the right side of the screen
- Displays categories in a 3-column grid layout with iOS-style device frame

### 2. **Category Cards**
Each category card shows:
- **Custom Image** (if uploaded) or default emoji icon
- **Category Name** from the database
- **Edit Button** (✏️) appears on hover

### 3. **Edit Category Features**

#### Edit Button
- Small edit icon (✏️) appears in the top-right corner of each category card on hover
- Click the edit button to open the edit modal

#### Edit Modal
The edit modal allows you to:

**A. Change Category Name**
- Update the spelling or name of the category
- Changes are automatically applied to:
  - Category hierarchy collection
  - All products using that category

**B. Add/Update Category Image**
Two methods to add images:

1. **Image URL**
   - Paste a direct URL to an image
   - Supports JPG, PNG, WebP formats

2. **Upload Image**
   - Click "Choose File" to select an image from your computer
   - Maximum size: 2MB
   - Supported formats: JPG, PNG, WebP
   - Image is automatically uploaded to the server
   - URL is auto-filled after successful upload

**C. Image Preview**
- See a preview of the image before saving
- Remove button to clear the image

### 4. **Data Persistence**
- **Category Names**: Stored in `category_hierarchy` collection
- **Category Images**: Stored in `category_metadata` collection
- All changes persist across sessions
- Updates are immediately reflected in the mobile preview

## API Endpoints

### Get Category Metadata
```
GET /admin/api/categories/metadata
```
Returns all category images and metadata.

### Upload Category Image
```
POST /admin/api/upload-image
Content-Type: multipart/form-data
Body: file (image file)

Response: {
    "message": "Image uploaded successfully",
    "url": "/static/uploads/category_xxx.jpg"
}
```
Uploads a category image to the server.

### Update Category
```
PUT /admin/api/categories/section/{section_name}
Body: {
    "new_name": "Updated Name",  // Optional
    "image_url": "https://..."    // Optional
}
```
Updates category name and/or image.

## Database Collections

### category_metadata
Stores additional category information:
```json
{
    "section": "Best Seller",
    "type": "section",
    "image_url": "https://example.com/image.jpg"
}
```

### category_hierarchy
Stores the hierarchical category structure:
```json
{
    "section": "Best Seller",
    "main_categories": {
        "Drinks & Juices": ["Soft Drinks", "Juices"],
        "Atta, Rice & Dal": ["Basmati Rice", "Wheat Flour"]
    }
}
```

## User Flow

1. **Open Mobile Preview**
   - Click "📱 Mobile View" button
   - Panel slides in from right

2. **View Categories**
   - See all categories with icons/images
   - Hover over a category card to reveal edit button

3. **Edit Category**
   - Click edit button (✏️)
   - Update name (optional)
   - Add/update image via URL or file upload
   - Preview the changes
   - Click "Save Changes"

4. **Verify Changes**
   - Category updates immediately in mobile preview
   - Image displays on the category card
   - Name changes reflect throughout the system

## Technical Details

### Frontend
- **JavaScript**: `dashboard.js`
  - `openEditCategoryModal()` - Opens edit modal
  - `handleCategoryEdit()` - Saves category changes
  - `handleCategoryImageUpload()` - Uploads image files
  - `loadMobileCategorySections()` - Renders categories with images

- **CSS**: `dashboard.css`
  - `.mobile-category-card` - Category card styling
  - `.edit-category-btn` - Edit button styling
  - `.image-preview` - Image preview styling

- **HTML**: `admin_dashboard.html`
  - Edit category modal with form
  - Image upload input and preview

### Backend
- **Routes**: `routes/admin_local.py`
  - `PUT /api/categories/section/{section_name}` - Update category
  - `GET /api/categories/metadata` - Get all metadata

- **Database**: MongoDB collections
  - `category_hierarchy` - Category structure
  - `category_metadata` - Category images and extra data

## Best Practices

1. **Image Sizes**
   - Keep images under 2MB for faster loading
   - Recommended dimensions: 300x300px or similar square format
   - Use compressed formats (WebP, optimized JPG/PNG)

2. **Category Names**
   - Keep names short and descriptive (2-3 words)
   - Avoid special characters that might cause issues

3. **Image URLs**
   - Use HTTPS URLs for security
   - Ensure images are publicly accessible
   - Test URLs before saving

## Error Handling

- **File Too Large**: Shows error if image > 2MB
- **Invalid File Type**: Only accepts image files
- **Upload Failed**: Shows error and allows retry
- **Update Failed**: Shows specific error message from backend

## Future Enhancements

Potential improvements:
- Bulk category editing
- Image cropping/resizing
- Category reordering
- Main category and subcategory image support
- Category analytics (product count, views)
