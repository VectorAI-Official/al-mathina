# Testing Guide - AL-Madhina Fixes

## Quick Test Steps

### 1. Test Main Category Creation ✅
1. Open admin dashboard: `http://127.0.0.1:8000/admin/dashboard`
2. Navigate to "Grocery & Kitchen" section
3. Click "+" button to add new main category
4. Enter name: `Test Main Category 1`
5. Upload an image (260x260px, square)
6. Click "Add Main Category"
7. **Expected:** Card appears under "Grocery & Kitchen" section with image

### 2. Test Subcategory Creation ✅
1. Click on any main category card (e.g., "Vegetables & Fruits")
2. Click "+" button to add subcategory
3. Enter name: `Test Subcategory 1`
4. Upload an image (square, max 800KB)
5. Click "Add Subcategory"
6. **Expected:** Subcategory card appears with image under the main category

### 3. Test Delete Main Category ✅
1. Hover over the newly created main category card
2. Click the delete (trash) icon
3. Confirm deletion in the modal
4. **Expected:** Card disappears from UI AND database (check with: `docker exec backend-backend-1 python check_hdthd_creation.py`)

### 4. Test Delete Subcategory ✅
1. Hover over a subcategory card
2. Click the delete (trash) icon
3. Confirm deletion
4. **Expected:** Subcategory disappears from UI and database

---

## Console Checks

### View Browser Console (F12)
Look for successful logs like:
```javascript
✅ handleAddMainCategory called with section: Grocery & Kitchen
✅ Form values - name: Test Main Category 1
✅ Image uploaded successfully: https://res.cloudinary.com/...
✅ Category creation successful: {success: true, message: '...'}
```

### Check Backend Logs
```bash
docker logs backend-backend-1 | tail -20
```

Look for:
```
✓ Main category created: Grocery & Kitchen → Test Main Category 1
✓ Image uploaded successfully: https://res.cloudinary.com/...
```

### Check Database
```bash
docker exec backend-backend-1 python check_hdthd_creation.py
```

Should show:
```
✓ Found 'Grocery & Kitchen' section:
  Main categories: ['Vegetables & Fruits', 'Test Main Category 1', ...]
  ✓ 'Test Main Category 1' found in main_categories
```

---

## Known Issues (If Any)

If you still see issues after these fixes:

1. **Docker container not reloading:**
   - Check that watchfiles is installed: `pip list | grep watchfiles`
   - Manually restart: `docker-compose restart`

2. **Images not uploading:**
   - Check Cloudinary is configured in `.env`
   - Verify image is square (1:1 ratio)
   - Check image file size < 800KB

3. **Category not appearing after creation:**
   - Refresh the page (Ctrl+F5 - hard refresh)
   - Check browser console for errors (F12)
   - Check backend logs: `docker logs backend-backend-1`

---

## Docker Cleanup (If Needed)

If things get stuck, try:

```bash
# Stop all containers
docker-compose down

# Remove volumes (will delete data!)
docker-compose down -v

# Start fresh
docker-compose up -d
```

---

## Files to Reference

- Backend API: http://127.0.0.1:8000/docs
- Admin Dashboard: http://127.0.0.1:8000/admin/dashboard
- Check script: `Backend/check_hdthd_creation.py`
- Summary of fixes: `BUG_FIXES_SUMMARY_20251027.md`
