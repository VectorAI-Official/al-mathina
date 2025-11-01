# 🧪 White Screen Debugging - Step-by-Step Guide

## Problem Summary

When working on the backend dashboard mobile view section, a white screen appears after some time or after making changes. The mobile frame (shown in the bottom section of admin dashboard) goes blank.

## 🎯 Root Causes (Most to Least Likely)

1. **categoryHierarchy is empty/undefined** (50% probability)
   - API call to `/admin/api/categories/all` fails or returns no data
   - Data not assigned to global variable

2. **API returns error** (25% probability)
   - Network issue with MongoDB Atlas
   - Authentication error
   - Malformed request

3. **JavaScript error in rendering** (15% probability)
   - Exception in `loadMobileCategorySections()` function
   - Exception in `showMobileCategoryProducts()` function
   - Uncaught error preventing rendering

4. **CSS/Display issue** (10% probability)
   - Container has `display: none` or `visibility: hidden`
   - CSS rule hiding content unexpectedly

---

## 🚀 QUICK START - 5-Minute Test

### Step 1: Set Up Local Environment

```powershell
cd Backend

# Copy .env.local from template
Copy-Item .env.local.template .env.local

# Create/activate virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Start Backend

```powershell
# Still in Backend directory
python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000
```

**✅ Expected output:**
```
Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

### Step 3: Access Dashboard

Open browser: **http://127.0.0.1:8000/admin**

**Login credentials:**
- Username: `admin`
- Password: `admin123`

### Step 4: Enable Debug Mode

Open Browser **DevTools** (F12) and run in **Console** tab:

```javascript
enableMobileViewDebugging()
```

**Expected output:**
```
╔════════════════════════════════════════════════════════════╗
║          MOBILE VIEW DEBUGGING ENABLED                     ║
╚════════════════════════════════════════════════════════════╝
Available debug functions:
  loadMobileCategorySections_DEBUG()
  ...
```

### Step 5: Test Mobile View Flow

In console, run:

```javascript
testMobileViewFlow()
```

**Expected behavior:**
- Sections appear in mobile frame
- Click on section shows main categories
- No console errors (red 🔴)

---

## 🔍 DETAILED DEBUGGING - All Possible Issues

### Scenario 1: Empty categoryHierarchy

**Symptom:** Mobile view shows only "Add Section" button, nothing else

**Debug Steps:**

```javascript
// In browser console
console.log('categoryHierarchy:', categoryHierarchy);
console.log('categoryHierarchy.length:', categoryHierarchy?.length);

// Expected: Array with at least 1 item
// If empty: categoryHierarchy = []
// If undefined: categoryHierarchy is not initialized
```

**If categoryHierarchy is empty:**

1. Check if database has categories:
```javascript
// In console
fetch('/admin/api/categories/all')
    .then(r => r.json())
    .then(d => console.log('API Response:', d));

// Expected: { hierarchy: [...] } with items
// If empty: { hierarchy: [] }
```

2. If API returns empty, check MongoDB:
```bash
# Use MongoDB Atlas UI or mongo shell
# Or run this backend script:
python Backend/check_all_products.py
```

3. **Fix:** Add test categories manually:
   - In admin dashboard, click "Add Section"
   - Name: "Test Section"
   - Then click "Add Main Category"
   - Name: "Test Category"

**If categoryHierarchy is undefined:**

```javascript
// This means loadCategories() never ran or failed
// Fix: Manually call it in console

loadCategories().then(() => {
    console.log('Categories loaded:', categoryHierarchy);
    loadMobileCategorySections();
});
```

---

### Scenario 2: API Error (Network/Connection)

**Symptom:** Console shows error like: `GET /admin/api/categories/all 500` or `Failed to fetch`

**Debug Steps:**

```javascript
// In browser console - Test API directly
const response = await fetch('/admin/api/categories/all');
console.log('Status:', response.status);
console.log('Data:', await response.json());

// Status 200 = OK
// Status 500 = Server error (check backend logs)
// Status 0 = Network error (backend not running)
```

**If Status 500:**

Check **backend terminal** for error messages:

```
ERROR: Connection to MongoDB failed
ERROR: Database not available
```

**Fix Options:**

```powershell
# 1. Verify .env.local has correct MONGO_URI
cat Backend\.env.local | grep MONGO_URI

# 2. Test MongoDB connection
python -c "from pymongo import MongoClient; MongoClient('YOUR_MONGO_URI')"

# 3. If still failing, check MongoDB Atlas status
# Go to: https://cloud.mongodb.com/
```

**If Status 0 (Network error):**

```powershell
# 1. Ensure backend is running
# Check: Is terminal showing "Uvicorn running..."?

# 2. If not running, start it:
python -m uvicorn main_production:app --reload

# 3. If running but not accessible:
# Check if URL is correct: http://127.0.0.1:8000
```

---

### Scenario 3: JavaScript Error (Rendering)

**Symptom:** Mobile frame is white, console shows RED ❌ error

**Debug Steps:**

```javascript
// In console, look for errors like:
// Uncaught TypeError: Cannot read property 'innerHTML' of null
// Uncaught ReferenceError: categoryHierarchy is not defined

// Test rendering function directly
loadMobileCategorySections_DEBUG();

// This will show DETAILED errors in console
```

**Check for specific errors:**

```javascript
// Error 1: Container not found
const container = document.getElementById('mobileCategorySections');
console.log('Container found:', !!container);

// Expected: Container found: true
// If false: Container missing from HTML

// Error 2: categoryHierarchy error
if (!categoryHierarchy) {
    console.error('categoryHierarchy is undefined - loadCategories() failed');
}

// Error 3: HTML generation error
try {
    const html = '<div>test</div>';
    container.innerHTML = html;
    console.log('✅ innerHTML works');
} catch (e) {
    console.error('❌ innerHTML failed:', e);
}
```

**If Container missing:**

```html
<!-- Check admin_dashboard.html has these divs -->
<div id="mobileCategorySections"></div>
<div id="mobileProductsList"></div>

<!-- If missing, add them after <body> tag -->
```

---

### Scenario 4: CSS Display Issue

**Symptom:** Mobile frame has content but it's hidden

**Debug Steps:**

```javascript
// In console
const container = document.getElementById('mobileCategorySections');
const styles = window.getComputedStyle(container);

console.log('Display:', styles.display);           // Should be 'block'
console.log('Visibility:', styles.visibility);     // Should be 'visible'
console.log('Opacity:', styles.opacity);           // Should be '1'
console.log('Width:', styles.width);               // Should not be '0'
console.log('Height:', styles.height);             // Should not be '0'

// If any are wrong:
// Fix by forcing styles
container.style.display = 'block !important';
container.style.visibility = 'visible !important';
container.style.opacity = '1';
```

**Check CSS file:**

```bash
# Look for any rules that might hide mobile containers
grep -n "mobileCategorySections\|mobileProductsList" Backend/static/admin/css/dashboard.css

# Look for display: none in default state
grep -n "display: none" Backend/static/admin/css/dashboard.css | head -20
```

---

## 🎬 Complete Test Scenario

### Setup

```powershell
# Terminal 1: Start backend
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000
```

### Browser

1. Open: http://127.0.0.1:8000/admin
2. Login: admin / admin123
3. Press F12 (DevTools)
4. Go to Console tab

### Test Sequence

**Test 1: Check data loaded**

```javascript
console.log('Test 1: Check data');
console.log('categoryHierarchy:', categoryHierarchy.length, 'items');
console.log('allProducts:', allProducts.length, 'items');
console.log('categoryMetadata:', Object.keys(categoryMetadata).length, 'keys');
```

**Test 2: Check containers exist**

```javascript
console.log('Test 2: Check containers');
console.log('mobileCategorySections:', !!document.getElementById('mobileCategorySections'));
console.log('mobileProductsList:', !!document.getElementById('mobileProductsList'));
```

**Test 3: Check API works**

```javascript
console.log('Test 3: Check API');
const resp = await fetch('/admin/api/categories/all');
const data = await resp.json();
console.log('API Status:', resp.status, 'Data items:', data.hierarchy?.length);
```

**Test 4: Test rendering**

```javascript
console.log('Test 4: Test rendering');
loadMobileCategorySections();
console.log('Mobile sections rendered');
```

**Test 5: Check CSS**

```javascript
console.log('Test 5: Check CSS');
const container = document.getElementById('mobileCategorySections');
const style = window.getComputedStyle(container);
console.log('Display:', style.display, 'Visibility:', style.visibility);
```

**Expected results:**

```
Test 1: categoryHierarchy: 5 items
        allProducts: 150 items
        categoryMetadata: 25 keys

Test 2: mobileCategorySections: true
        mobileProductsList: true

Test 3: API Status: 200 Data items: 5

Test 4: Mobile sections rendered ✅

Test 5: Display: block Visibility: visible
```

---

## 📊 Collecting Debug Information

If you still see white screen, run this and share the output:

```javascript
getMobileViewDebugReport()
```

This will show:
- ✅ System state (data loaded?)
- ✅ Container state (elements exist?)
- ✅ Debug logs (what happened?)
- ✅ Errors (any exceptions?)

---

## 🔧 Common Fixes

### Fix 1: Reload Everything

```javascript
// Clear all data and reload
categoryHierarchy = [];
allProducts = [];
categoryMetadata = {};

// Then reload
loadCategories().then(() => {
    loadMobileCategorySections();
});
```

### Fix 2: Force Render

```javascript
// If data exists but not showing
const container = document.getElementById('mobileCategorySections');
container.style.display = 'block';
container.innerHTML = ''; // Clear
loadMobileCategorySections(); // Re-render
```

### Fix 3: Check Network

```javascript
// Disable cache and retry
const timestamp = Date.now();
const resp = await fetch(`/admin/api/categories/all?t=${timestamp}`);
const data = await resp.json();
console.log('Fresh data:', data);
```

### Fix 4: Restart Everything

```powershell
# Stop backend (Ctrl+C in terminal)
# Clear browser cache (Ctrl+Shift+Delete)
# Refresh page (Ctrl+R or F5)
# Login again and test
```

---

## 📝 Debug Logs Locations

**Backend logs:** Terminal where you ran `uvicorn`
```
INFO:     Uvicorn running on http://127.0.0.1:8000
ERROR:    Connection failed
WARNING:  Slow query
```

**Browser logs:** DevTools → Console tab
```
✅ Category metadata loaded: 25 items
📂 Sections: 5 items
⚠️  Warning message
❌ Error message
```

**Network logs:** DevTools → Network tab
- Check each API call
- 200 = Good
- 404 = Not found
- 500 = Server error
- 0 = Network failed

---

## 🎯 When to Ask for Help

Before asking for help, collect:

1. **Backend log output** (copy full error from terminal)
2. **Browser console output** (screenshot or paste from console)
3. **Network errors** (DevTools → Network tab)
4. **Debug report** (run `getMobileViewDebugReport()`)
5. **Environment info**:
   ```javascript
   console.log({
       categoryHierarchy_length: categoryHierarchy?.length,
       allProducts_length: allProducts?.length,
       categoryMetadata_keys: Object.keys(categoryMetadata).length,
       hasError: MOBILE_VIEW_DEBUG.errors.length > 0
   });
   ```

---

## ✅ Success Criteria

Mobile view is working correctly when:

- ✅ Sections appear in mobile frame
- ✅ Can click section to see main categories
- ✅ Can click main category to see subcategories
- ✅ Can click subcategory to see products
- ✅ No console errors (red 🔴)
- ✅ All API calls return 200 status
- ✅ Images load correctly
- ✅ "Add Section" button visible
- ✅ Can make changes without white screen

---

**Ready to debug? Start with the Quick Start section above!** 🚀
