Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d chrome --verbose

Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d emulator-5554

# LOCAL DEVELOPMENT (Local MongoDB)
cd "D:\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000

cd "c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; $env:ENVIRONMENT='production' ; python -m uvicorn main_production:app --reload --host 0.0.0.0 --port 8000

cd Backend; python -m uvicorn main_local:app --reload --host 0.0.0.0 --port 8000




# FOR PHYSICAL ANDROID DEVICE
# Terminal 1: Start Backend (production with MongoDB Atlas)
cd "c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; $env:ENVIRONMENT='production' ; python -m uvicorn main_production:app --reload --host 0.0.0.0 --port 8000


# Terminal 1: Start docker Backend 
cd backend; docker-compose restart

# Terminal 2: Run Flutter on physical device (RZ8NA1WCLWL)
Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d RZ8NA1WCLWL    

# Terminal 3: Build APK
Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter clean && flutter pub get; flutter build apk --release 2>&1 | tee apk_build.log    



# Terminal 1: Start docker Backend
cd backend; docker-compose restart

# Terminal 2: Run Flutter on physical device (103223138K111296)
flutter run -d 103223138K111296

# Terminal 3: Build APK
flutter clean ; flutter pub get; flutter build apk --release 2>&1 | tee apk_build.log


# ==============================================================
# GO BACKEND (NEW - Port 9000) - Migration from FastAPI
# ==============================================================

# Start Go Backend in Docker (Session 4 COMPLETE - 20/20 endpoints)
cd go-backend; docker-compose up -d

# Rebuild Docker after code changes
cd go-backend; docker-compose up --build -d

# Stop Docker container
cd go-backend; docker-compose down

# View logs
docker logs almathina-go-backend --tail 50

# ==============================================================
# ADMIN DASHBOARD (Web UI)
# ==============================================================
# Revenue Management (Stores): http://localhost:9000/admin/static/stores.html
# Orders Management: http://localhost:9000/admin/static/orders.html

# ==============================================================
# TEST COMMANDS
# ==============================================================

# Test Flutter APIs (4 endpoints)
Invoke-RestMethod -Uri "http://localhost:9000/health" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/api/flutter/home" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/api/flutter/products?limit=5" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/api/flutter/search?q=rice&limit=5" | ConvertTo-Json

# Test Admin APIs (9 endpoints)
Invoke-RestMethod -Uri "http://localhost:9000/admin/api/products/all" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/admin/api/categories/all" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/admin/api/most-bought" | ConvertTo-Json

# Test FCM APIs (2 endpoints)
$fcm = '{"phone":"7339651541","fcm_token":"test_token_123"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/fcm-token" -Method POST -Headers @{'Content-Type'='application/json'} -Body $fcm
Invoke-RestMethod -Uri "http://localhost:9000/api/fcm-token/7339651541" | ConvertTo-Json

# Test User Profile APIs (5 endpoints)
Invoke-RestMethod -Uri "http://localhost:9000/api/version" | ConvertTo-Json
$profile = '{"name":"John Doe","email":"john@example.com"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/profile/9876543210" -Method PUT -Headers @{'Content-Type'='application/json'} -Body $profile
Invoke-RestMethod -Uri "http://localhost:9000/api/profile/9876543210" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/api/orders/9876543210" | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:9000/api/orders/9876543210/ORD-1768041195363" | ConvertTo-Json

# Test Order Creation (1 endpoint)
$order = @{user_phone="9876543210";user_name="John Doe";delivery_address="123 Main St";total_amount=150.5;notes="Test order";items=@(@{product_name="Rice";quantity=2;price=50;subtotal=100})} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "http://localhost:9000/api/orders" -Method POST -Headers @{'Content-Type'='application/json'} -Body $order

# Test Address Management (3 endpoints)
$addr = '{"label":"Home","street":"123 Test St","city":"Chennai","state":"TN","pincode":"600001","is_default":true}'; Invoke-RestMethod -Uri "http://localhost:9000/api/address/9876543210" -Method POST -Headers @{'Content-Type'='application/json'} -Body $addr
$addr = '{"label":"Office","street":"456 Office St","city":"Mumbai","state":"MH","pincode":"400001"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/address/9876543210/0" -Method PUT -Headers @{'Content-Type'='application/json'} -Body $addr
Invoke-RestMethod -Uri "http://localhost:9000/api/address/9876543210/0" -Method DELETE

# Test Store Details (2 endpoints)
Invoke-RestMethod -Uri "http://localhost:9000/api/store-details/9876543210" | ConvertTo-Json
$store = '{"store_name":"Al-Mathina","street":"456 Store St","city":"Mumbai","state":"MH","pincode":"400001"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/store-details/9876543210" -Method PUT -Headers @{'Content-Type'='application/json'} -Body $store

# Test Favorites (3 endpoints)
Invoke-RestMethod -Uri "http://localhost:9000/api/favorites/9876543210" | ConvertTo-Json
$fav = '{"item_id":"ITEM001"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/favorites/9876543210" -Method POST -Headers @{'Content-Type'='application/json'} -Body $fav
Invoke-RestMethod -Uri "http://localhost:9000/api/favorites/9876543210/ITEM001" -Method DELETE

# Test User Management (2 endpoints)
$phone = '{"new_phone":"+919876543211"}'; Invoke-RestMethod -Uri "http://localhost:9000/api/phone/9876543210" -Method PUT -Headers @{'Content-Type'='application/json'} -Body $phone
Invoke-RestMethod -Uri "http://localhost:9000/api/profile/9876543210" -Method DELETE

# ==============================================================
# API ENDPOINTS SUMMARY (20 total)
# ==============================================================
# Flutter APIs: 4 (home, products, search, subcategories)
# Admin APIs: 9 (products, categories, sections, main, sub, metadata, most-bought CRUD)
# FCM APIs: 2 (save token, get token)
# User Profile: 5 (version, profile CRUD, orders list/details)
# Orders: 1 (create order with email notification)
# Address Management: 3 (add, update, delete)
# Store Details: 2 (get, update)
# Favorites: 3 (get, add, remove)
# User Management: 2 (change phone, delete profile)
# ==============================================================    



