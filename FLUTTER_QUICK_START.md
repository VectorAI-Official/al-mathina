# 🚀 AL-Madhina Flutter App - Quick Start (5 Minutes)

Get the complete Flutter app running with Docker backend in 5 minutes!

---

## Prerequisites

- ✅ Docker Desktop installed
- ✅ Flutter SDK installed
- ✅ Chrome browser
- ✅ MongoDB Atlas account configured (for production)

---

## Step 1: Start Docker Backend (2 min)

Open PowerShell and run:

```powershell
# Navigate to project root
cd c:\Users\faisa\AndroidStudioProjects\AlMathina

# Start backend container
docker-compose up -d

# Verify it's running (should show backend-backend-1)
docker ps

# Test API is working
curl http://localhost:8000/docs
```

**Expected Output:**
```
CONTAINER ID   IMAGE         STATUS          PORTS
abc123def456   backend:latest   Up 2 minutes   0.0.0.0:8000->8080/tcp
```

✅ **Backend is running on `http://localhost:8000`**

---

## Step 2: Launch Flutter App (2 min)

Open a **new PowerShell terminal** and run:

```powershell
# Navigate to Flutter project
cd flutter_preview

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```

**Expected Output:**
```
Launching lib/main.dart on Chrome in debug mode...
Building Chrome application...
Connecting to Service Protocol...
Chrome is being started...
Application running at http://localhost:XXXX/
```

✅ **Flutter app is running in Chrome**

---

## Step 3: Test All Features (1 min)

### 🏠 Home Page
- Should see "Most Bought" section at top
- Should see product categories below
- Click on a category card

### 📦 Subcategory Page
- Should show list of subcategories
- Click on a subcategory

### 🛒 Products Page
- Should show products in grid
- Click on a product card

### 📄 Product Details
- Should show product image, name, price
- Should show "Add to Cart" button

### ❤️ Favorites
- Click heart icon to add to favorites
- Go to Favorites page (from menu)
- Should see product in favorites list

### 📋 Orders
- Go to Orders page
- Should show order history (if any)
- Can create new order

### 🇮🇳 Language Support
- Look for language toggle
- Switch to Tamil (தமிழ்)
- Text should change to Tamil

---

## API Testing (Optional)

Test the 10 endpoints directly:

### Test 1: Home Page
```powershell
curl http://localhost:8000/api/flutter/home
```

### Test 2: Search
```powershell
curl "http://localhost:8000/api/flutter/search?q=rice"
```

### Test 3: Favorites
```powershell
curl http://localhost:8000/api/flutter/favorites/user_123
```

### Test 4: Orders
```powershell
curl http://localhost:8000/api/flutter/orders/user_123
```

---

## Common Issues & Quick Fixes

### ❌ "Connection refused" error

**Fix:**
```powershell
# Make sure backend is running
docker ps

# If not, start it
docker-compose up -d
```

### ❌ "Cannot GET /docs"

**Fix:**
```powershell
# Wait a few seconds for backend to start
Start-Sleep -Seconds 5

# Then try again
curl http://localhost:8000/docs
```

### ❌ Flutter app showing blank screen

**Fix:**
```powershell
# Restart Flutter app (press 'R' in terminal where flutter is running)
# Then try again
```

### ❌ Images not loading

**Fix:**
```powershell
# Check backend is serving images
curl http://localhost:8000/static/health

# Verify image URLs are absolute (start with http://)
curl http://localhost:8000/api/flutter/home | findstr image_url
```

---

## What You Should See

### ✅ Home Page
```
┌─────────────────────────────────────┐
│  AL-Madhina              [EN/TA]    │
├─────────────────────────────────────┤
│  ⭐ Most Bought                     │
│  ┌─────────────────────────────────┐
│  │ [Image] Rice & Grains  (15)    │
│  │ [Image] Beverages      (12)    │
│  └─────────────────────────────────┘
├─────────────────────────────────────┤
│  🛒 Groceries                       │
│  ┌─────────────────────────────────┐
│  │ [Image] Rice & Grains  (15)    │
│  │ [Image] Spices         (8)     │
│  └─────────────────────────────────┘
└─────────────────────────────────────┘
```

### ✅ Products Page
```
Basmati Rice - Page 1/5
┌──────────────────────────────────────┐
│ [Image] Premium Basmati 1kg  │ ❤️    │
│ ₹150 | 1kg | In Stock              │
├──────────────────────────────────────┤
│ [Image] Brown Rice 1kg      │ ❤️    │
│ ₹120 | 1kg | In Stock              │
└──────────────────────────────────────┘
```

### ✅ Favorites Page
```
Favorites (5 items)
┌──────────────────────────────────────┐
│ Premium Basmati 1kg  │ ₹150  │ [X]  │
│ [Image]              │      │      │
├──────────────────────────────────────┤
│ Brown Rice 1kg       │ ₹120  │ [X]  │
│ [Image]              │      │      │
└──────────────────────────────────────┘
```

---

## Next Steps

### After Testing

1. **Read Full Documentation**
   - `API_ENDPOINT_REFERENCE.md` - All 10 endpoints
   - `FLUTTER_INTEGRATION_GUIDE.md` - Implementation details
   - `FLUTTER_TESTING_GUIDE.md` - Comprehensive testing

2. **Admin Dashboard**
   - Open: `http://localhost:8000/admin`
   - Add new categories
   - Add Tamil names for subcategories
   - Upload product images

3. **Build for Production**
   - Update API URL in `api_service.dart`
   - Build APK/AAB for Android
   - Build IPA for iOS
   - Deploy to app stores

4. **Implement Missing Features**
   - User authentication
   - Payment integration
   - Push notifications
   - Order tracking

---

## Useful Commands

```powershell
# View backend logs
docker logs -f backend-backend-1

# Stop backend
docker-compose down

# Restart backend
docker-compose restart

# Clean and rebuild
docker-compose down
docker-compose up -d --build

# Check backend health
curl http://localhost:8000/health

# Run Flutter on specific port
flutter run -d chrome --web-port=5000

# Build Flutter web
flutter build web

# Clear Flutter cache
flutter clean
```

---

## File Locations

| Item | Location |
|------|----------|
| Backend | `/Backend/main_production.py` |
| API Routes | `/Backend/routes/flutter.py` |
| Flutter App | `/flutter_preview/lib/main.dart` |
| Admin Dashboard | `http://localhost:8000/admin` |
| API Docs | `http://localhost:8000/docs` |

---

## Support & Resources

📖 **Documentation**
- API Reference: `API_ENDPOINT_REFERENCE.md`
- Integration Guide: `FLUTTER_INTEGRATION_GUIDE.md`
- Testing Guide: `FLUTTER_TESTING_GUIDE.md`
- Complete Docs: `FLUTTER_API_DOCUMENTATION.md`

🔧 **Quick Links**
- Backend API: http://localhost:8000
- FastAPI Docs: http://localhost:8000/docs
- Admin Dashboard: http://localhost:8000/admin
- Flutter App: http://localhost:XXXX (auto-assigned)

📞 **If You Get Stuck**
1. Check Docker logs: `docker logs backend-backend-1`
2. Test API manually: Use curl commands above
3. Review documentation files
4. Verify database connection

---

## Success Checklist

- [ ] Docker backend started
- [ ] Backend API responding (http://localhost:8000/docs works)
- [ ] Flutter app launched in Chrome
- [ ] Home page showing categories
- [ ] Can click and navigate to subcategories
- [ ] Products loading with images
- [ ] Can add/remove favorites
- [ ] Language toggle works
- [ ] No errors in Chrome console
- [ ] API response times < 1 second

✅ **If all checked, you're ready to go!**

---

## Performance Tips

1. **Clear Browser Cache**: Press Ctrl+Shift+Delete in Chrome
2. **Use Incognito Mode**: Avoid cached API responses
3. **Monitor Backend**: Keep `docker logs` open in separate terminal
4. **Check Response Times**: Look at Network tab in Chrome DevTools
5. **Profile Flutter**: Use Flutter DevTools for performance analysis

---

## Deployment Ready

🚀 **Your app is ready for:**
- ✅ Development testing
- ✅ Beta releases
- ✅ Production deployment
- ✅ Multiple language support
- ✅ Real-time favorites/orders
- ✅ Full product catalog

---

**Happy Testing! 🎉**

*For detailed implementation, see documentation files.*

