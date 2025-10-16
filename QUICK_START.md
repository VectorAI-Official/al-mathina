# 🚀 AL-Madhina Local Development - Quick Start

Complete setup guide to get your Flutter + FastAPI + Supabase + MongoDB stack running locally.

## 📋 What You Just Built

A three-tier architecture:
- **Frontend**: Flutter app (Windows/Web/Android)
- **Backend**: FastAPI Python server (port 8000)
- **Databases**: 
  - Supabase/PostgreSQL (transactional data - orders, cart)
  - MongoDB (catalog data - products, categories)

## 🎯 Quick Start (Step by Step)

### Part 1: Start the Backend Services

#### 1. Start Supabase (PostgreSQL + Auth)
```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# First time only - initialize
supabase init

# Start Supabase stack
supabase start
```
**Result**: Supabase running at http://127.0.0.1:54321
- Studio UI: http://127.0.0.1:54323
- PostgreSQL: postgresql://postgres:postgres@localhost:54322/postgres

#### 2. Start MongoDB
```powershell
# Start MongoDB in Docker
docker run --name mongo-local -p 27017:27017 -d mongo:latest

# Verify it's running
docker ps
```
**Result**: MongoDB running at mongodb://localhost:27017

#### 3. Set Up Python Environment
```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Create virtual environment (first time only)
python -m venv venv

# Activate it
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
```

#### 4. Start FastAPI Backend
```powershell
# Make sure you're in Backend folder with venv activated
uvicorn main:app --reload
```

**Result**: 
```
✅ Backend Ready - Listening on http://127.0.0.1:8000
📖 API Docs: http://127.0.0.1:8000/docs
```

**Or use the automated script**:
```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
.\start.ps1
```

### Part 2: Run the Flutter App

```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview

# Get dependencies (already done)
flutter pub get

# Run on Chrome
flutter run -d chrome
```

## ✅ Verify Everything Works

### 1. Check Backend Health
Open browser: http://127.0.0.1:8000/health

You should see:
```json
{
  "status": "healthy",
  "databases": [
    {"name": "Supabase (PostgreSQL)", "connected": true},
    {"name": "MongoDB", "connected": true}
  ]
}
```

### 2. Check API Docs
Open browser: http://127.0.0.1:8000/docs

You should see interactive Swagger UI with all endpoints.

### 3. Test an API Endpoint
```powershell
curl http://127.0.0.1:8000/api/inventory/sections
```

Should return JSON with categories (Atta, Soap, etc.)

### 4. Check Databases

**Supabase Studio**: http://127.0.0.1:54323
- Look for `cart_items` and `orders` tables

**MongoDB** (using Compass or mongosh):
```powershell
docker exec -it mongo-local mongosh
use al_madhina_catalog
db.categories.find()
db.products.find()
```

## 📁 What Was Created

### Backend Files
```
Backend/
├── main.py                    # FastAPI app (DONE ✅)
├── config.py                  # Settings management (DONE ✅)
├── models.py                  # Pydantic models (DONE ✅)
├── requirements.txt           # Python dependencies (DONE ✅)
├── .env.example              # Environment template (DONE ✅)
├── start.ps1                 # Quick start script (DONE ✅)
├── README.md                 # Comprehensive docs (DONE ✅)
├── database/
│   ├── supabase_client.py    # PostgreSQL connection (DONE ✅)
│   └── mongodb_client.py     # MongoDB connection (DONE ✅)
└── routes/
    ├── inventory.py          # Catalog endpoints (DONE ✅)
    ├── cart.py              # Cart endpoints (DONE ✅)
    └── orders.py            # Order endpoints (DONE ✅)
```

### Flutter Files
```
flutter_preview/
├── lib/
│   ├── main.dart                    # Main app (existing)
│   └── api_service.dart            # API client (NEW ✅)
├── pubspec.yaml                     # Updated with http package (DONE ✅)
└── BACKEND_INTEGRATION.md          # Integration guide (NEW ✅)
```

## 🔌 Available API Endpoints

### Catalog (MongoDB)
- `GET /api/inventory/sections` - Get categories
- `GET /api/inventory/products?category=Atta` - Get products
- `GET /api/inventory/products/{category}/{brand}` - Get specific product

### Cart (Supabase)
- `GET /api/cart/{user_id}` - Get cart
- `POST /api/cart/add` - Add to cart
- `PUT /api/cart/{item_id}` - Update quantity
- `DELETE /api/cart/{user_id}/clear` - Clear cart

### Orders (Supabase)
- `POST /api/orders/create` - Create order
- `GET /api/orders/user/{user_id}` - Get order history
- `GET /api/orders/{order_id}` - Get order details

## 🔄 Daily Workflow

### Morning Startup
```powershell
# 1. Start Supabase
supabase start

# 2. Start MongoDB (if not running)
docker start mongo-local

# 3. Start FastAPI
cd Backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload

# 4. Start Flutter (in new terminal)
cd flutter_preview
flutter run -d chrome
```

### Shutdown
```powershell
# Stop FastAPI: Ctrl+C
# Stop Flutter: Ctrl+C or 'q' in Flutter console

# Optional: Stop databases
supabase stop
docker stop mongo-local
```

## 🧪 Quick Test

In Flutter app (or using curl):

```dart
// In Flutter
import 'api_service.dart';

// Test connection
final health = await ApiService.healthCheck();
print('Backend: ${health['status']}');

// Get categories
final categories = await ApiService.getCategories();
print('Found ${categories.length} categories');

// Get products
final products = await ApiService.getProducts(category: 'Atta');
print('Found ${products.length} Atta products');
```

## 📊 Database Schema

### Supabase (PostgreSQL)

**cart_items** table:
- id (primary key)
- user_id (string)
- category (string)
- brand (string)
- quantity (integer)
- price (float)
- created_at, updated_at (timestamps)

**orders** table:
- id (primary key)
- user_id (string)
- order_number (unique string)
- items_json (JSON string)
- total_amount (float)
- payment_method (string)
- status (string)
- created_at (timestamp)

### MongoDB

**categories** collection:
```json
{
  "name": "Atta",
  "name_ta": "மாவு",
  "icon": "local_dining",
  "image_path": "assets/categories/atta.png",
  "order": 1,
  "active": true
}
```

**products** collection:
```json
{
  "category": "Atta",
  "brand": "Aashirvaad",
  "name": "Aashirvaad Atta",
  "image_path": "assets/brands/aashirvaad.png",
  "weight": "10kg box",
  "price": 45.99,
  "stock": 120,
  "active": true,
  "description": "Premium quality..."
}
```

## 🎨 Frontend Integration Status

| Feature | Status | Notes |
|---------|--------|-------|
| API Service Created | ✅ | `api_service.dart` with all endpoints |
| HTTP Package Added | ✅ | Added to `pubspec.yaml` and installed |
| Mock Data | ⚠️ | Still using mock data (needs migration) |
| Categories | ⏳ | Can fetch from API, needs UI update |
| Products | ⏳ | Can fetch from API, needs UI update |
| Cart | ⏳ | Can sync with backend, needs integration |
| Orders | ⏳ | Can create via API, needs integration |

**Next Step**: Update Flutter UI to use `ApiService` instead of mock data.

## 🚨 Troubleshooting

### Backend won't start?
```powershell
# Check if port 8000 is busy
netstat -ano | findstr :8000

# Check if Supabase is running
supabase status

# Check if MongoDB is running
docker ps | findstr mongo
```

### Can't connect from Flutter?
```powershell
# Test backend manually
curl http://127.0.0.1:8000/health

# If it works via curl but not Flutter:
# - Make sure Flutter is using http://127.0.0.1:8000 (not localhost)
# - Check Chrome console for CORS errors
# - Verify api_service.dart BASE_URL is correct
```

### Database errors?
```powershell
# Restart FastAPI - it will recreate tables/collections
# Stop FastAPI (Ctrl+C) then:
uvicorn main:app --reload
```

## 📚 Documentation

- **Backend README**: `Backend/README.md` (comprehensive setup guide)
- **Integration Guide**: `flutter_preview/BACKEND_INTEGRATION.md` (Flutter usage)
- **API Docs**: http://127.0.0.1:8000/docs (interactive, when running)

## ✨ What's Next?

1. **Update Flutter UI** to use `ApiService` (replace mock data)
2. **Test the full flow**: Browse → Add to Cart → Place Order
3. **Add loading indicators** for better UX
4. **Implement error handling** for network issues
5. **Add authentication** (Supabase Auth is already set up)

## 🎉 You're All Set!

Your local development environment is ready:
- ✅ FastAPI backend running
- ✅ Supabase (PostgreSQL) running
- ✅ MongoDB running
- ✅ Flutter app ready with API service
- ✅ Sample data populated

**Start coding!** 🚀
