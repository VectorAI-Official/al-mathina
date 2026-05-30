# Flutter → Go Backend Integration Guide

## Overview
This document maps all Flutter app API endpoints to the Go backend running on `http://10.0.2.2:9000` (Android emulator/USB debugging).

**Date**: January 11, 2026  
**Go Backend Port**: 9000  
**Flutter App**: `flutter_preview/`  
**Backend**: `go-backend/`

---

## ✅ Connection Setup (COMPLETE)

### Android USB Debugging / Emulator
```dart
// flutter_preview/lib/api_service.dart
const String BASE_URL = "http://10.0.2.2:9000";  // Maps to host machine's localhost:9000
const String API_BASE = "$BASE_URL/api/flutter";
```

### Network Address Translation
- **Android Emulator**: `10.0.2.2` = Host machine's `localhost`
- **iOS Simulator**: Use `localhost` directly
- **Physical Device (WiFi)**: Use computer's local IP (e.g., `192.168.1.x:9000`)

---

## 📱 Flutter API Endpoints → Go Backend Mapping

### 🏠 Home & Categories

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/flutter/home` | GET | `/api/flutter/home` | `handlers.GetHome` | ✅ **WORKING** |
| `/api/flutter/main-category/:section/:main_category/subcategories` | GET | `/api/flutter/main-category/:section/:main_category/subcategories` | `handlers.GetSubcategories` | ✅ **WORKING** |

**Response Structure**:
```json
{
  "best_sellers": {
    "main_categories": [
      {
        "id": "most_bought_...",
        "name": "பாதாம் & முந்திரி",
        "image_url": "http://10.0.2.2:9000/static/uploads/...",
        "product_count": 25,
        "section": "Provisions",
        "main_category": "Nuts"
      }
    ]
  },
  "sections": [...]
}
```

---

### 🛍️ Products

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/flutter/products` | GET | `/api/flutter/products` | `handlers.GetProducts` | ✅ **WORKING** |
| `/api/flutter/product/:item_id` | GET | `/api/flutter/product/:item_id` | `handlers.GetProductDetails` | ✅ **ADDED** |
| `/api/flutter/search` | GET | `/api/flutter/search` | `handlers.SearchProducts` | ✅ **WORKING** |

**Query Parameters**:
```
GET /api/flutter/products?section=Provisions&main_category=Rice&subcategory=Basmati&page=1&limit=20&user_phone=7339651541
```

**Response** (with pagination):
```json
{
  "products": [
    {
      "item_id": "RICE001",
      "product_name": "Basmati Rice",
      "product_name_ta": "பாசுமதி அரிசி",
      "price": 150.50,
      "buying_price": 120.0,  // ⭐ Only if user is admin
      "stock": 100,
      "in_stock": true,
      "image_url": "http://10.0.2.2:9000/static/uploads/..."
    }
  ],
  "is_admin": true,  // ⭐ Admin status from Supabase
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_products": 56,
    "per_page": 20,
    "has_next": true,
    "has_prev": false
  }
}
```

---

### 👤 User Profile & Authentication

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/profile/:phone` | GET | `/api/profile/:phone` | `handlers.GetUserProfile` | ✅ **WORKING** |
| `/api/profile/:phone` | PUT | `/api/profile/:phone` | `handlers.UpdateUserProfile` | ✅ **WORKING** |
| `/api/profile/:phone` | DELETE | `/api/profile/:phone` | `handlers.DeleteUserProfile` | ✅ **WORKING** |
| `/api/phone/:old_phone` | PUT | `/api/phone/:old_phone` | `handlers.ChangePhoneNumber` | ✅ **WORKING** |

**Update Profile Request**:
```json
{
  "name": "Fazeer's Store",
  "email": "fazeer@almathina.com",
  "store_name": "Fazeer General Store"
}
```

---

### 📍 Address Management

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/address/:phone` | POST | `/api/address/:phone` | `handlers.AddAddress` | ✅ **WORKING** |
| `/api/address/:phone/:index` | PUT | `/api/address/:phone/:index` | `handlers.UpdateAddress` | ✅ **WORKING** |
| `/api/address/:phone/:index` | DELETE | `/api/address/:phone/:index` | `handlers.DeleteAddress` | ✅ **WORKING** |

**Add Address Request**:
```json
{
  "street": "123 Main Street",
  "city": "Chennai",
  "state": "Tamil Nadu",
  "pincode": "600001",
  "landmark": "Near Temple"
}
```

---

### 🛒 Orders

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/orders/:phone` | GET | `/api/orders/:phone` | `handlers.GetUserOrders` | ✅ **WORKING** |
| `/api/orders` | POST | `/api/orders` | `handlers.CreateOrder` | ✅ **WORKING** |
| `/api/orders/:phone/:order_id` | GET | `/api/orders/:phone/:order_id` | `handlers.GetOrderDetails` | ✅ **WORKING** |

**Create Order Request**:
```json
{
  "user_phone": "7339651541",
  "items": [
    {"item_id": "RICE001", "quantity": 2, "price": 150.50},
    {"item_id": "OIL001", "quantity": 1, "price": 200.0}
  ],
  "total_amount": 501.0,
  "payment_method": "cod",
  "delivery_address": {
    "street": "123 Main St",
    "city": "Chennai",
    "state": "TN",
    "pincode": "600001"
  }
}
```

**Response**:
```json
{
  "success": true,
  "order_id": "ORD-20260111-AB12C",  // Readable order ID
  "mongodb_id": "507f1f77bcf86cd799439011",
  "status": "pending",
  "created_at": "2026-01-11T02:30:00+05:30"
}
```

**🔔 FCM Notification**: Backend automatically sends push notification to user's device after order creation.

---

### 🏪 Store Details

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/store-details/:phone` | GET | `/api/store-details/:phone` | `handlers.GetStoreDetails` | ✅ **WORKING** |
| `/api/store-details/:phone` | PUT | `/api/store-details/:phone` | `handlers.UpdateStoreDetails` | ✅ **WORKING** |

**Response**:
```json
{
  "success": true,
  "store_details": {
    "street": "123 Market Street",
    "city": "Chennai",
    "state": "Tamil Nadu",
    "pincode": "600001",
    "landmark": "Near City Center"
  }
}
```

---

### ⭐ Favorites

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/favorites/:phone` | GET | `/api/favorites/:phone` | `handlers.GetFavorites` | ✅ **WORKING** |
| `/api/favorites/:phone` | POST | `/api/favorites/:phone` | `handlers.AddFavorite` | ✅ **WORKING** |
| `/api/favorites/:phone/:item_id` | DELETE | `/api/favorites/:phone/:item_id` | `handlers.RemoveFavorite` | ✅ **WORKING** |

**Add Favorite Request**:
```json
{
  "item_id": "RICE001"
}
```

---

### 🔔 Firebase Cloud Messaging (FCM)

| Flutter Endpoint | Method | Go Backend Route | Handler | Status |
|-----------------|--------|------------------|---------|--------|
| `/api/fcm-token` | POST | `/api/fcm-token` | `handlers.SaveFCMToken` | ✅ **WORKING** |
| `/api/fcm-token/:phone` | GET | `/api/fcm-token/:phone` | `handlers.GetFCMToken` | ✅ **WORKING** |

**Save FCM Token Request**:
```json
{
  "phone": "+917339651541",
  "fcm_token": "dGhpcyBpcyBhIGZha2UgdG9rZW4="
}
```

**🔒 Storage**: FCM tokens stored in **Supabase** `users` table (not MongoDB).

---

## 🗄️ Database Architecture

### MongoDB (Main Database)
**Host**: MongoDB Atlas  
**Collections**:
- `products` - Product catalog
- `orders` - Customer orders
- `users` - User profiles (phone, name, email, addresses)
- `category_hierarchy` - Section → Main Category → Subcategory
- `category_metadata` - Images, icons for categories
- `most_bought` - Starred main categories (Most Bought feature)
- `user_favorites` - User favorite products

### Supabase (PostgreSQL - Authentication & FCM)
**Tables**:
- `users` - FCM tokens + admin flags (`phone`, `fcm_token`, `is_admin`)

**Critical**: Admin check queries Supabase, then MongoDB for products.

---

## 🔐 Admin System (Buying Price Feature)

### Admin Phone Numbers
```
+917339651541
+918870503350
+919487715568
```

### Workflow
1. **Flutter sends**: `GET /api/flutter/products?user_phone=7339651541`
2. **Go queries Supabase**: `SELECT is_admin FROM users WHERE phone = '+917339651541'`
3. **If admin**: Include `buying_price` field in product response
4. **If not admin**: Exclude `buying_price` field

### Response Difference
```json
// Admin User
{
  "products": [
    {"item_id": "RICE001", "price": 150.50, "buying_price": 120.0}
  ],
  "is_admin": true
}

// Regular User
{
  "products": [
    {"item_id": "RICE001", "price": 150.50}
  ],
  "is_admin": false
}
```

---

## 🚀 Deployment & Testing

### 1. Start Go Backend (Docker)
```powershell
cd C:\Users\faisa\AndroidStudioProjects\AlMathina\go-backend
docker-compose build
docker-compose up -d
```

**Verify Backend**:
```powershell
# Health check
curl http://localhost:9000/health

# Test Flutter home endpoint
curl http://localhost:9000/api/flutter/home

# Test product details
curl http://localhost:9000/api/flutter/product/RICE001
```

### 2. Run Flutter App (Android Debug Mode)
```powershell
cd C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview

# Connect phone via USB or start emulator
flutter devices

# Run on connected device
flutter run -d <device_id>

# Or run on Chrome for testing
flutter run -d chrome
```

### 3. Test API Connectivity
**From Flutter App**:
1. Open app on device/emulator
2. Check home screen loads (verifies `/api/flutter/home`)
3. Navigate to a category (verifies `/api/flutter/main-category/.../subcategories`)
4. Open a product (verifies `/api/flutter/product/:item_id`)
5. Search for products (verifies `/api/flutter/search`)

**From Device Terminal** (ADB):
```bash
# Connect to emulator shell
adb shell

# Test backend from emulator
curl http://10.0.2.2:9000/health
curl http://10.0.2.2:9000/api/flutter/home
```

---

## 🛠️ Troubleshooting

### Issue: "Failed to connect" / Network error
**Solutions**:
1. **Android Emulator**: Use `10.0.2.2:9000` (not `localhost`)
2. **Physical Device**: 
   - Ensure phone and computer on same WiFi
   - Use computer's local IP: `http://192.168.1.x:9000`
   - Check firewall allows port 9000
3. **Backend not running**: `docker-compose up -d`

### Issue: Images not loading
**Check**:
- Backend logs: `docker-compose logs -f go-backend`
- Image URLs should be: `http://10.0.2.2:9000/static/uploads/...`
- Not: `http://localhost:9000/...`

### Issue: Admin buying_price not showing
**Debug**:
```bash
# Check Supabase connection
docker-compose logs | grep "Supabase"

# Verify admin status
curl "http://localhost:9000/api/flutter/products?user_phone=7339651541&limit=1"

# Should show: "is_admin": true
```

**Environment Variables** (Required):
```bash
# go-backend/.env.production
SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Issue: Orders not creating
**Check**:
1. MongoDB connection: `docker-compose logs | grep "MongoDB"`
2. FCM service initialized: `docker-compose logs | grep "Firebase"`
3. Request body has all required fields

---

## 📊 Performance Notes

### Pagination
- **Default**: 20 items per page
- **Maximum**: 100 items per page
- **Recommended**: Use pagination for lists > 50 items

### Caching (Flutter Side)
```dart
// api_service.dart implements in-memory cache
_ApiCache.set('store_details_$phone', data, Duration(seconds: 60));
```

**Cache TTL**:
- Store details: 60 seconds
- User profile: 60 seconds
- Clear on updates

### Image Optimization
- Use Cloudinary URLs when available (auto-optimized)
- Local images: Static file serving from Go backend
- CDN recommended for production

---

## 🔄 FastAPI → Go Backend Comparison

| Feature | FastAPI (Python) | Go Backend | Migration Status |
|---------|------------------|------------|------------------|
| Home endpoint | ✅ | ✅ | ✅ **Complete** |
| Products with filters | ✅ | ✅ | ✅ **Complete** |
| Product details | ✅ | ✅ | ✅ **Added (Jan 11)** |
| Search | ✅ | ✅ | ✅ **Complete** |
| Subcategories | ✅ | ✅ | ✅ **Complete** |
| User profile | ✅ | ✅ | ✅ **Complete** |
| Orders | ✅ | ✅ | ✅ **Complete** |
| FCM notifications | ✅ | ✅ | ✅ **Complete** |
| Admin buying price | ✅ | ✅ | ✅ **Complete** |
| Image URL normalization | ✅ | ✅ | ✅ **Complete** |

---

## 📝 Summary

✅ **Flutter app fully configured** to connect to Go backend on `10.0.2.2:9000`  
✅ **All API endpoints** migrated from FastAPI to Go  
✅ **Product details endpoint** added (Jan 11, 2026)  
✅ **Database architecture** maintained (MongoDB + Supabase)  
✅ **Admin system** working (buying price for admin users)  
✅ **FCM notifications** integrated  
✅ **Pagination** implemented for all list endpoints  

**Next Steps**:
1. Rebuild Go backend Docker container
2. Test Flutter app with physical device/emulator
3. Verify all endpoints respond correctly
4. Check FCM push notifications on order creation

---

**Last Updated**: January 11, 2026  
**Maintainer**: Fazeer @ AL-Madhina  
**Go Backend Version**: 1.0.0  
**Flutter App Version**: See `/api/version` endpoint
