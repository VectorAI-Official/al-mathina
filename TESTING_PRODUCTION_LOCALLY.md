# 🎯 Testing Production Backend Locally

## ✅ Backend is Running!

Your production backend with MongoDB Atlas and Cloudinary is now accessible at:

### 🌐 Available URLs:

1. **Admin Dashboard** (Main Interface)
   - URL: http://127.0.0.1:8000/admin
   - Login with your admin credentials
   - Test all category and product management features

2. **API Documentation** (Interactive)
   - URL: http://127.0.0.1:8000/docs
   - Try all endpoints interactively
   - Test image uploads to Cloudinary

3. **Health Check** (System Status)
   - URL: http://127.0.0.1:8000/health
   - Shows MongoDB Atlas and Cloudinary status

4. **Flutter API** (Mobile App Endpoints)
   - Home: http://127.0.0.1:8000/api/flutter/home
   - Products: http://127.0.0.1:8000/api/flutter/products

## 🧪 Testing Checklist

### 1. Test Admin Dashboard
- [x] Open: http://127.0.0.1:8000/admin
- [ ] Login (if authentication is enabled)
- [ ] Navigate to categories
- [ ] View products from MongoDB Atlas
- [ ] Try adding/editing categories
- [ ] Upload an image (will go to Cloudinary!)

### 2. Test Image Upload to Cloudinary
Open http://127.0.0.1:8000/docs and:

1. Find **POST /admin/api/upload/image**
2. Click "Try it out"
3. Choose a test image file
4. Add parameters:
   ```
   category_type: product
   product_id: TEST001
   ```
5. Click "Execute"
6. Check response - you should get a Cloudinary URL like:
   ```json
   {
     "success": true,
     "image_url": "https://res.cloudinary.com/vectorai/image/upload/almathina/products/TEST001.jpg"
   }
   ```

### 3. Test MongoDB Atlas Data Retrieval
Open http://127.0.0.1:8000/api/flutter/home in browser

You should see:
```json
{
  "sections": [...],
  "best_sellers": {...},
  "featured_products": [...]
}
```

This data is coming from **MongoDB Atlas** in the cloud! 🌐

### 4. Test Product CRUD Operations

**Using API Docs (http://127.0.0.1:8000/docs):**

#### Create Product:
1. Find **POST /admin/api/product**
2. Try it out with:
   ```json
   {
     "section": "Groceries",
     "main_category": "Rice & Grains",
     "subcategory": "Basmati Rice",
     "product_name": "Test Product Cloud",
     "product_name_ta": "சோதனை தயாரிப்பு",
     "item_id": "CLOUD001",
     "unit": "1kg",
     "price": 150.00,
     "stock": 100
   }
   ```

#### Upload Image for Product:
1. Find **POST /admin/api/upload/image**
2. Upload image with `product_id: CLOUD001`
3. Get the Cloudinary URL

#### Update Product with Image:
1. Find **PUT /admin/api/product/{product_id}**
2. Use the product ID from create response
3. Update with:
   ```json
   {
     "image_url": "cloudinary_url_from_previous_step"
   }
   ```

#### Get Product:
1. Find **GET /admin/api/products**
2. Filter by: `section=Groceries&subcategory=Basmati Rice`
3. See your product with Cloudinary image URL!

## 🎨 What's Different from Local Development?

| Feature | Local Dev (main_local.py) | Production (main_production.py) |
|---------|--------------------------|--------------------------------|
| **Database** | MongoDB localhost:27017 | MongoDB Atlas (cloud) |
| **Images** | Static files (`/static/uploads/`) | Cloudinary CDN |
| **Image URLs** | `http://localhost:8000/static/uploads/...` | `https://res.cloudinary.com/vectorai/...` |
| **Data Location** | Your computer | Cloud (accessible anywhere) |
| **Scalability** | Single machine | Auto-scales globally |

## 📊 Verify Cloud Integration

### Check MongoDB Atlas:
```bash
# In PowerShell
Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing | Select-Object -ExpandProperty Content
```

Expected:
```json
{
  "mongodb": "connected",  ✅ Reading from Atlas
  "cloudinary": true       ✅ Ready for uploads
}
```

### Check Cloudinary Dashboard:
1. Go to: https://cloudinary.com/console
2. Click "Media Library"
3. Look for folder: `almathina/`
4. After uploading images via API, they'll appear here!

## 🔄 Test Complete Workflow

### Scenario: Add New Product with Image

1. **Upload Image First**
   - POST /admin/api/upload/image
   - Set: `product_id=NEW001`
   - Get Cloudinary URL: `https://res.cloudinary.com/vectorai/.../NEW001.jpg`

2. **Create Product**
   - POST /admin/api/product
   - Include the image_url from step 1
   - Product saved to MongoDB Atlas

3. **View in Flutter API**
   - GET /api/flutter/products?subcategory=YourCategory
   - See product with Cloudinary image URL

4. **Verify in Browser**
   - Open the Cloudinary URL directly
   - Image loads from global CDN!

## 🎯 Key Testing Points

### ✅ Verify These Work:

1. **Data from Cloud**
   - Products list shows items from MongoDB Atlas
   - Counts and statistics are accurate

2. **Images from Cloudinary**
   - Upload works (returns Cloudinary URL)
   - URLs are in format: `https://res.cloudinary.com/...`
   - Images load when opened in browser

3. **Admin Dashboard**
   - Can browse categories
   - Can view products
   - UI loads correctly

4. **API Endpoints**
   - All CRUD operations work
   - Search and filters work
   - Tamil multi-language works

## 🐛 Troubleshooting

### Issue: Can't access dashboard
- Check server is running: http://127.0.0.1:8000/health
- Look for errors in terminal

### Issue: Image upload fails
- Check `.env.production` has correct Cloudinary credentials
- Verify file size < 5MB
- Check file is valid image format

### Issue: Products not showing
- Verify MongoDB Atlas connection in health check
- Check products exist in Atlas dashboard

## 📱 Next Step: Test with Flutter App

Once you've verified backend works:

1. Update Flutter `api_service.dart`:
   ```dart
   const String BASE_URL = "http://127.0.0.1:8000";
   ```

2. Run Flutter app:
   ```bash
   cd flutter_preview
   flutter run -d chrome
   ```

3. Verify:
   - Products load from MongoDB Atlas
   - Images display from Cloudinary
   - All features work

## 🚀 When Ready to Deploy to Fly.io

Once everything works locally:

```bash
# Set Cloudinary secrets
fly secrets set CLOUDINARY_API_SECRET=your_actual_secret

# Deploy
fly deploy

# Your app will be live at:
# https://almathina-backend.fly.dev
```

---

**🎉 You're now testing a production-ready backend with cloud services!**

Everything you do now uses:
- ☁️ MongoDB Atlas (cloud database)
- 🖼️ Cloudinary (global CDN)
- 🚀 Production code (same as Fly.io will use)
