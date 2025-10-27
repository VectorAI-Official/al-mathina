# Step-by-Step: Test Image Upload with Cache-Busting Fix

## Setup (Already Done)

✅ Cache-busting added to dashboard.js  
✅ Backend running with hot-reload  
✅ MongoDB database connected  
✅ Cloudinary credentials working  
✅ Dashboard open at http://localhost:8000/admin/dashboard

---

## Test Procedure

### TEST 1: Upload to Existing Product (Green Chilli)

**Step 1.1: Open Green Chilli**
- Go to dashboard
- Find "Green Chilli" in the products table
- Click the product row to edit

**Step 1.2: Upload Image**
- Click "Upload Image" button
- Select a PNG file from your computer
- Wait for "Image uploaded successfully" message

**Step 1.3: Check Browser Console**
- Open Developer Tools: Press F12
- Go to "Console" tab
- Look for this message:
  ```
  Image URL: https://res.cloudinary.com/vectorai/image/upload/.../68f7ba16d426db882816c99a.png
  ```
- **VERIFY:** URL ends with `.png` (NOT `.webp`)

**Step 1.4: Check Dashboard Update**
- Close the edit dialog
- Wait 1-2 seconds
- Green Chilli product row should now show the NEW image
- Hover over the product image - it should be the image you just uploaded

**Step 1.5: Verify Database**
- Open terminal:
  ```powershell
  curl http://localhost:8000/admin/api/products/all | ConvertFrom-Json | 
    Select-Object -ExpandProperty products | 
    Where-Object {$_.product_name -eq "Green Chilli"} | 
    Select-Object product_name, image_url
  ```
- **VERIFY:** `image_url` contains the new Cloudinary URL and ends with `.png`

**✅ Test 1 Success Indicators:**
- [ ] Console shows `.png` URL
- [ ] Dashboard displays new image immediately
- [ ] API returns new URL from database
- [ ] No stale cache issues

---

### TEST 2: Upload Different Format (JPG)

**Step 2.1: Create New Product**
- Click "Add Product" button
- Enter:
  - Name: "Test JPG"
  - Category: "Vegetables & Fruits" → "Vegetables"
  - Weight: "1kg"
  - Price: "50"
- Click "Save Product"

**Step 2.2: Upload JPG Image**
- Select a JPG file from your computer
- Wait for success message

**Step 2.3: Check Console**
- Open Developer Tools: F12
- Console should show URL ending with `.jpg`
- **VERIFY:** Not `.webp`, not `.png`, but `.jpg`

**Step 2.4: Verify Display**
- Dashboard should show the JPG image immediately
- No caching delays

**✅ Test 2 Success Indicators:**
- [ ] JPG URL ends with `.jpg`
- [ ] Image displays correctly
- [ ] No format conversion to WebP

---

### TEST 3: Replace Image on Existing Product

**Step 3.1: Edit Green Chilli Again**
- Find Green Chilli in products table
- Click to edit

**Step 3.2: Upload Different Image**
- Click "Upload Image"
- Select a DIFFERENT PNG file (not the first one)
- Wait for success

**Step 3.3: Verify Old Image Gone**
- Console should show new URL (different v-number)
  ```
  Old: https://.../v1761578207/...png
  New: https://.../v1761578999/...png  ← Different timestamp
  ```

**Step 3.4: Check Dashboard**
- Close edit dialog
- Dashboard should show the NEW image (not old)
- Product list should update immediately

**✅ Test 3 Success Indicators:**
- [ ] New URL generated (different timestamp)
- [ ] Old image replaced (not cached)
- [ ] Dashboard updates without manual refresh

---

### TEST 4: Verify No Cache Issues

**Step 4.1: Edit 3 Different Products**
- Upload images to 3 different products
- Each time, verify console shows correct URL
- Each time, verify dashboard updates immediately

**Step 4.2: Check Console Logs**
- All requests should have `?t=` parameter
- Example in Network tab:
  ```
  GET /admin/api/products/all?t=1761578999999 HTTP/1.1
  GET /admin/api/categories/all?t=1761578999999 HTTP/1.1
  ```

**Step 4.3: Verify Statistics Update**
- Product count should be correct
- Image count statistics should match reality
- "3 Cloudinary, 4 Local, 0 No image" should be accurate

**✅ Test 4 Success Indicators:**
- [ ] No stale data displayed
- [ ] All API calls include `?t=` parameter
- [ ] Statistics match actual database
- [ ] Multi-product uploads work smoothly

---

## Troubleshooting

### Problem: Dashboard still shows old image

**Solution 1: Hard Refresh**
- Press Ctrl+Shift+R (or Cmd+Shift+R on Mac)
- This clears browser cache completely

**Solution 2: Check Network Tab**
- Open DevTools: F12
- Go to Network tab
- Look for `/admin/api/products/all` requests
- **VERIFY:** URL has `?t=` parameter
- If not, reload page (old cached JS file)

**Solution 3: Check Backend Logs**
```powershell
docker-compose logs backend --tail 50 | Select-String "Database updated|Image uploaded"
```
- Should show "Database updated: matched=1, modified=1"
- If not, backend didn't save the URL

### Problem: URL shows .webp instead of .png

**Reason:** Format parameter fix not applied or reverted

**Solution:**
```powershell
cd Backend
docker-compose down
docker-compose up -d --build
```

Then check `Backend/utils/cloudinary_helper.py` line 91 has:
```python
format=file_ext.lstrip('.'),
```

### Problem: Console errors when uploading

**Check backend logs:**
```powershell
docker-compose logs backend --tail 100 | Select-String "ERROR|Error|error"
```

Common issues:
- Cloudinary credentials wrong (run `python validate_credentials.py`)
- File too large
- MongoDB not connected

---

## Expected Console Output

When everything works correctly:

```
dashboard.js:713 Product Data: {..., weight: "5kg", price: 500}
dashboard.js:742 Response Status: 200
dashboard.js:756 === PRODUCT SAVED SUCCESSFULLY ===
dashboard.js:765 Product Image (REQUIRED): banana 2.png
dashboard.js:773 Uploading required product image: 68f7ba16d426db882816c99a
dashboard.js:955 === UPLOADING IMAGE FILE ===
dashboard.js:958 File size: 5076
dashboard.js:979 Upload successful: {success: true, image_url: '...png'}
dashboard.js:980 Image URL: https://res.cloudinary.com/vectorai/image/upload/.../68f7ba16d426db882816c99a.png
dashboard.js:792 Reloading products and categories...
```

**✅ Key Line:** `image_url: '...png'` (ends with .png, not .webp)

---

## Success Checklist

Complete all tests, then mark these:

- [ ] Test 1: PNG uploads with correct `.png` format
- [ ] Test 1: Dashboard shows new image immediately
- [ ] Test 1: Database has correct URL
- [ ] Test 2: JPG uploads with `.jpg` format
- [ ] Test 2: No conversion to WebP
- [ ] Test 3: Image replacement works (old image gone)
- [ ] Test 3: New image displays without refresh
- [ ] Test 4: Multiple uploads work smoothly
- [ ] Test 4: No cache issues observed
- [ ] Network tab shows `?t=` parameter in all requests

---

## After All Tests Pass

✅ Image upload is fully working  
✅ Format preservation confirmed  
✅ Cache-busting validated  
✅ Dashboard updates correctly  

**Next Steps:**
1. Test in Flutter app
2. Deploy to Fly.io when confident
3. Add more products with images
4. Test in production environment

---

## Dashboard URL

```
http://localhost:8000/admin/dashboard
```

**Open it now and start testing!** 🚀
