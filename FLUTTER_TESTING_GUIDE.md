# Flutter App Testing & Deployment Guide

Complete step-by-step guide to test the Flutter app with the Docker-hosted backend.

---

## Quick Start Testing

### Step 1: Start Docker Backend

```powershell
# Navigate to project root
cd c:\Users\faisa\AndroidStudioProjects\AlMathina

# Start backend
docker-compose up -d

# Verify backend is running
docker ps

# Expected output shows backend-backend-1 running on port 8000:8080
```

### Step 2: Test Backend API Endpoints

```powershell
# Check API health
curl http://localhost:8000/docs

# Test home endpoint
curl "http://localhost:8000/api/flutter/home?lang=en" | ConvertFrom-Json | ConvertTo-Json

# Test subcategories (URL encode spaces as %20)
curl "http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories" | ConvertFrom-Json | ConvertTo-Json

# Test search
curl "http://localhost:8000/api/flutter/search?q=rice" | ConvertFrom-Json | ConvertTo-Json
```

### Step 3: Launch Flutter App

```powershell
# Open new PowerShell terminal
cd flutter_preview

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Or for web
flutter run -d web-server --web-port=5000
```

### Step 4: Test Each Page

#### Home Page
1. Should show "Most Bought" section at top with categories
2. Should show all sections below (Groceries, Dairy, etc.)
3. Each card should display image, name, and product count
4. Language toggle should work (English/Tamil)

#### Subcategory Page
1. Click on a main category card
2. Should show list of subcategories
3. Each should show product count and image
4. Click on a subcategory to go to products

#### Products Page
1. Should display products in a grid (2 columns)
2. Show image, name, weight, and price
3. Infinite scroll should load more products
4. Click on product to view details

#### Product Details Page
1. Should show full product image
2. Display product name in English and Tamil
3. Show price, weight, stock status
4. Quantity selector and add to cart button

#### Favorites Page
1. Add products from product detail page
2. Should display in favorites list
3. Remove button should work
4. Should update in real-time

#### Orders Page
1. Click "Create Order" button
2. Fill in delivery address
3. Should show order confirmation
4. View previous orders in history

---

## API Endpoint Testing

### Test All 12 Endpoints

#### 1. Home Data
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/home?lang=en" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: best_sellers and sections
```

#### 2. Subcategories
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/main-category/Groceries/Rice%20%26%20Grains/subcategories" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: list of subcategories with names and images
```

#### 3. Products
```powershell
$params = "section=Groceries&main_category=Rice%20%26%20Grains&subcategory=Basmati%20Rice&page=1&limit=20"
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/products?$params" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: paginated products list
```

#### 4. Product Details
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/product/PROD001" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: full product details with all fields
```

#### 5. Search
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/search?q=rice&page=1&limit=20" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: search results with pagination
```

#### 6. Get Favorites
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/favorites/user_123" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: empty array or list of favorite items
```

#### 7. Add to Favorites
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/favorites/user_123/PROD001" -Method Post
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: success message
```

#### 8. Remove from Favorites
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/favorites/user_123/PROD001" -Method Delete
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: success message
```

#### 9. Get Orders
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/orders/user_123?page=1&limit=10" -Method Get
$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: user's orders list
```

#### 10. Create Order
```powershell
$body = @{
    user_id = "user_123"
    items = @(
        @{ item_id = "PROD001"; quantity = 2; price = 150.0 }
    )
    delivery_address = "123 Main St, City"
    payment_method = "cod"
    total_amount = 300.0
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/orders" `
    -Method Post `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body

$response.Content | ConvertFrom-Json | ConvertTo-Json

# Expected: order created confirmation with order_id
```

---

## Database Verification

### Check Database State

```powershell
# List all collections
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
print('Collections:', db.list_collection_names())
"

# Count products
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
print('Products:', db.products.count_documents({}))
print('Categories:', db.category_hierarchy.count_documents({}))
print('Metadata:', db.category_metadata.count_documents({}))
"

# Check category structure
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
doc = db.category_hierarchy.find_one()
print(doc)
"
```

---

## Common Testing Scenarios

### Scenario 1: User Browsing Products
1. Open home page → View categories
2. Click category → View subcategories
3. Click subcategory → View products (with pagination)
4. Click product → View details
5. Add to favorites → Check favorites page

### Scenario 2: Search & Filter
1. Use search box on home page
2. Enter "rice" in search
3. Should show relevant products
4. Pagination should work

### Scenario 3: Place Order
1. Add items to cart
2. Click checkout
3. Enter delivery address
4. Select payment method
5. Confirm order
6. Check orders page for new order

### Scenario 4: Language Switching
1. Switch to Tamil from English
2. All text should be in Tamil
3. Images should remain same
4. Navigation should work

### Scenario 5: Multiple Users
1. Test with user_123
2. Add favorites for user_123
3. Switch to user_456
4. Should show different favorites

---

## Debugging Issues

### Issue: Backend Not Responding

**Symptoms:**
- `Connection refused` error
- API calls timeout

**Solutions:**
```powershell
# Check if backend is running
docker ps

# If not running, start it
docker-compose up -d

# Check logs
docker logs backend-backend-1

# Restart backend
docker-compose restart

# Check health endpoint
curl http://localhost:8000/health

# Rebuild if needed
docker-compose down
docker-compose up -d --build
```

### Issue: Images Not Loading

**Symptoms:**
- Images show as broken in Flutter app
- Error logs: "Image network error"

**Solutions:**
```powershell
# Check image URLs in response
curl "http://localhost:8000/api/flutter/home" | jq '.sections[0].main_categories[0].image_url'

# Should start with http://localhost:8000

# Check if image file exists
docker exec backend-backend-1 ls -la /app/static/uploads/

# Verify image in database
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
doc = db.category_metadata.find_one({'type': 'main_category'})
print(doc.get('image_url'))
"
```

### Issue: Tamil Text Shows as Squares

**Symptoms:**
- Tamil text displays as empty boxes
- Only English text shows properly

**Solutions:**
1. Ensure Flutter app has Tamil font configured:
```dart
// In pubspec.yaml
dev_dependencies:
  google_fonts: ^latest

// In main.dart
import 'package:google_fonts/google_fonts.dart';

// In ThemeData
TextTheme: GoogleFonts.notoSansTamilTextTheme(),
```

2. Check API response contains Tamil text:
```powershell
curl "http://localhost:8000/api/flutter/home?lang=ta" | jq '.sections[0].main_categories[0]'
```

### Issue: Favorites Not Persisting

**Symptoms:**
- Add to favorites works
- But favorites don't show on next visit
- Get favorites returns empty

**Solutions:**
```powershell
# Check user_favorites collection exists
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
doc = db.user_favorites.find_one({'user_id': 'user_123'})
print(doc)
"

# Manually add favorite for testing
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
db.user_favorites.insert_one({'user_id': 'user_123', 'items': ['PROD001']})
"

# Verify it shows up
curl http://localhost:8000/api/flutter/favorites/user_123 | jq '.'
```

### Issue: Orders Not Creating

**Symptoms:**
- Create order returns error
- Status code 500
- Error: "Missing fields"

**Solutions:**
```powershell
# Verify all required fields
$body = @{
    user_id = "user_123"
    items = @(@{ item_id = "PROD001"; quantity = 2; price = 150.0 })
    delivery_address = "123 Main St, City"
    payment_method = "cod"
    total_amount = 300.0
} | ConvertTo-Json

# Test create order
curl -X POST http://localhost:8000/api/flutter/orders `
    -H "Content-Type: application/json" `
    -d $body | jq '.'

# Check orders collection
docker exec backend-backend-1 python -c "
from database.mongodb_client import get_mongo_db
db = get_mongo_db()
docs = list(db.orders.find({'user_id': 'user_123'}))
for doc in docs:
    print(doc)
"
```

---

## Performance Testing

### Load Test Products Endpoint

```powershell
# Test with large limit
$response = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/products?limit=100&page=1" `
    -Method Get

$startTime = Get-Date
$obj = $response.Content | ConvertFrom-Json
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalMilliseconds

Write-Host "Products returned: $($obj.products.Count)"
Write-Host "Response time: ${duration}ms"

# Expected: < 500ms for full response
```

### Test Pagination

```powershell
# Get first page
$page1 = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/products?page=1&limit=20" | ConvertFrom-Json
Write-Host "Page 1: $($page1.products.Count) items"

# Get next page
$page2 = Invoke-WebRequest -Uri "http://localhost:8000/api/flutter/products?page=2&limit=20" | ConvertFrom-Json
Write-Host "Page 2: $($page2.products.Count) items"

# Verify no duplicates
$ids1 = $page1.products | Select -ExpandProperty item_id
$ids2 = $page2.products | Select -ExpandProperty item_id
$duplicates = Compare-Object $ids1 $ids2 -ExcludeDifferent -IncludeEqual
Write-Host "Duplicates: $($duplicates.Count)"
```

---

## Browser DevTools Debugging

### Monitor Network Requests

1. Open Chrome DevTools (F12)
2. Go to Network tab
3. Refresh Flutter web app
4. Check API calls:
   - Status codes should be 200
   - Response time should be < 1s
   - Size should be reasonable

### Check Console for Errors

1. Open Console tab (F12)
2. Look for HTTP errors
3. Check for CORS issues
4. Verify image load errors

### Test Local Storage

```javascript
// In browser console
localStorage.setItem('user_id', 'user_123');
localStorage.getItem('user_id');

// Check cached data
JSON.parse(localStorage.getItem('homeData'));
```

---

## Production Checklist

- [ ] All API endpoints tested and working
- [ ] Images loading correctly
- [ ] Tamil text displaying properly
- [ ] Favorites persisting correctly
- [ ] Orders creating successfully
- [ ] Pagination working on all list pages
- [ ] Error handling implemented
- [ ] Loading indicators showing
- [ ] No console errors
- [ ] Response times acceptable (< 1s)
- [ ] Database backups configured
- [ ] Logging enabled
- [ ] API rate limiting configured
- [ ] CORS headers correct
- [ ] HTTPS configured for production

---

## Deployment Steps

### Step 1: Build Flutter Web App

```powershell
cd flutter_preview
flutter build web --web-port=5000
```

### Step 2: Update Production API URL

```dart
// In api_service.dart
const String BASE_URL = "https://yourdomain.com:8000";
```

### Step 3: Deploy Backend

```powershell
# Build Docker image
docker build -t almathina-backend:latest .

# Push to registry
docker tag almathina-backend:latest yourusername/almathina-backend:latest
docker push yourusername/almathina-backend:latest
```

### Step 4: Deploy Flutter Web

```powershell
# Copy web build to server
xcopy build\web\ \\server\almathina-web /E /Y

# Or use Docker
docker run -p 80:80 -v "$(pwd)/build/web:/usr/share/nginx/html" nginx:alpine
```

---

## Monitoring

### View Backend Logs

```powershell
# Real-time logs
docker logs -f backend-backend-1

# Last 100 lines
docker logs --tail 100 backend-backend-1

# Logs from last hour
docker logs --since 1h backend-backend-1
```

### Database Monitoring

```powershell
# Connect to MongoDB
docker exec -it mongo mongo

# In MongoDB shell
use almathina_db
db.stats()
db.products.count()
db.orders.count()
```

### API Metrics

```powershell
# Check API response times
curl -w "Response time: %{time_total}s\n" http://localhost:8000/api/flutter/home
```

---

## Rollback Procedures

### If Backend Breaks

```powershell
# Stop current container
docker-compose down

# Restore from backup
docker-compose up -d --build

# Or revert to previous image
docker run --name backend -p 8000:8080 almathina-backend:previous
```

### If Database Corrupts

```powershell
# Create backup
docker exec mongodb mongodump --out /backup

# Restore from backup
docker exec mongodb mongorestore /backup
```

---

## Success Criteria

✅ **All tests pass when:**
1. Backend API responds to all 12 endpoints
2. Flutter app loads home page without errors
3. All categories display with images
4. Subcategories show on category click
5. Products load with pagination
6. Favorites add/remove work
7. Orders create successfully
8. Tamil text displays correctly
9. No network errors in console
10. Response times < 1 second

---

## Support

For issues or questions:
1. Check Docker backend logs: `docker logs backend-backend-1`
2. Test API directly: `curl http://localhost:8000/api/flutter/home`
3. Review Flutter debug console for errors
4. Check database state with MongoDB tools
5. Refer to API documentation: `FLUTTER_API_DOCUMENTATION.md`

