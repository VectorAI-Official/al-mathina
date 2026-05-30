# Quick Start: Flutter + Go Backend Testing

## 1. Start Go Backend (ALREADY RUNNING ✅)
```powershell
cd C:\Users\faisa\AndroidStudioProjects\AlMathina\go-backend
docker-compose up -d
```

**Verify**:
```powershell
curl http://localhost:9000/health
# Should return: {"service":"AL-Madhina Go Backend","status":"healthy","version":"1.0.0"}
```

---

## 2. Test Backend Endpoints

### Home (Categories)
```powershell
curl http://localhost:9000/api/flutter/home
```

### Products (with filters)
```powershell
curl "http://localhost:9000/api/flutter/products?section=Provisions&limit=5"
```

### Product Details (NEW)
```powershell
# Replace RICE001 with actual item_id from your database
curl http://localhost:9000/api/flutter/product/RICE001
```

### Search
```powershell
curl "http://localhost:9000/api/flutter/search?q=rice&limit=5"
```

---

## 3. Run Flutter App

### For Android Emulator/Physical Phone (USB)
```powershell
cd C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview

# List available devices
flutter devices

# Run on connected device
flutter run -d <device_id>

# Or run on first available device
flutter run
```

**Connection**: App uses `http://10.0.2.2:9000` (maps to host localhost:9000)

---

### For Chrome (Desktop Testing)
```powershell
flutter run -d chrome
```

**⚠️ IMPORTANT**: For Chrome, temporarily change in `lib/api_service.dart`:
```dart
const String BASE_URL = "http://localhost:9000";  // Change from 10.0.2.2
```

---

## 4. Monitor Backend Logs
```powershell
# View live logs
docker-compose logs -f go-backend

# View last 50 lines
docker-compose logs --tail=50 go-backend
```

---

## 5. Restart Backend (If Needed)
```powershell
docker-compose restart
```

---

## 6. Stop Backend
```powershell
docker-compose down
```

---

## Common Test Scenarios

### Test 1: Home Screen Loads
1. Open Flutter app
2. Wait for home screen to load
3. **Expected**: Categories with images appear

### Test 2: Navigate to Products
1. Click any main category (e.g., "Rice")
2. **Expected**: Subcategories appear
3. Click subcategory (e.g., "Basmati Rice")
4. **Expected**: Product list with pagination

### Test 3: Product Details
1. Click any product from list
2. **Expected**: Product detail page with image, price, description

### Test 4: Search
1. Use search bar
2. Type "rice" or product name
3. **Expected**: Filtered results

### Test 5: Admin Buying Price (Use phone: 7339651541)
1. Login/register with admin phone
2. View products
3. **Expected**: See buying price alongside selling price
4. Test with regular phone number
5. **Expected**: No buying price shown

---

## Debug Commands

### Check Container Status
```powershell
docker ps | Select-String "almathina"
```

### Rebuild Backend (After Code Changes)
```powershell
docker-compose build
docker-compose up -d
```

### View MongoDB Connection
```powershell
docker-compose logs | Select-String "MongoDB"
```

### View Supabase Connection
```powershell
docker-compose logs | Select-String "Supabase"
```

---

## Environment Variables (If Missing)

**File**: `go-backend/.env.production`
```bash
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/almathina
SUPABASE_URL=https://zuhkndylyavedmfrovsj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
PORT=9000
```

---

## Network Configuration Summary

### Android Emulator/USB
- Flutter uses: `http://10.0.2.2:9000`
- Backend runs on: `localhost:9000`
- `10.0.2.2` = Special alias for host machine's localhost

### Physical Device (WiFi)
- Find computer's IP: `ipconfig` → Look for IPv4 (e.g., 192.168.1.5)
- Update Flutter: `http://192.168.1.5:9000`
- Ensure computer and phone on same WiFi network

### Chrome/Desktop
- Flutter uses: `http://localhost:9000`
- Backend runs on: `localhost:9000`
- Direct connection

---

**Current Status**: ✅ Backend running on port 9000  
**Next Step**: `flutter run -d <device>`  
**Documentation**: See `FLUTTER_GO_BACKEND_INTEGRATION.md` for details
