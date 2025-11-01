# ⚡ Quick Reference - White Screen Debugging

## 🚀 30-Second Quick Start

```powershell
# Terminal 1: Setup and Start Backend
cd Backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000

# Terminal 2: Browser
# Open: http://127.0.0.1:8000/admin
# Login: admin / admin123
```

---

## 🔍 Debug Checklist

In browser console (F12):

```javascript
// 1. Data loaded?
console.log('Hierarchy:', categoryHierarchy?.length);  // Should be > 0
console.log('Products:', allProducts?.length);          // Should be > 0
console.log('Metadata:', Object.keys(categoryMetadata).length);  // Should be > 0

// 2. API working?
fetch('/admin/api/categories/all').then(r => r.json()).then(d => console.log(d));
// Should return 200 with { hierarchy: [...] }

// 3. Containers exist?
console.log('Sections:', !!document.getElementById('mobileCategorySections'));
console.log('Products:', !!document.getElementById('mobileProductsList'));
// Both should be true

// 4. CSS correct?
let s = document.getElementById('mobileCategorySections');
console.log('Display:', window.getComputedStyle(s).display);  // Should be 'block'
console.log('Visibility:', window.getComputedStyle(s).visibility);  // Should be 'visible'

// 5. Try rendering?
loadMobileCategorySections();  // Should display sections

// 6. Enable debug mode?
enableMobileViewDebugging();
testMobileViewFlow();
```

---

## 🆘 Common Issues Quick Fixes

| Issue | Check | Fix |
|-------|-------|-----|
| White screen | `categoryHierarchy.length === 0` | Add test categories in dashboard |
| Nothing loads | API returns 500 | Check backend logs for errors |
| API fails | Network tab shows errors | Verify .env.local has correct credentials |
| Containers not found | `getElementById()` returns null | Check admin_dashboard.html |
| Content hidden | `display: none` in CSS | Force `style.display = 'block'` |
| Page stuck | Async issue | Refresh page (Ctrl+R) |
| Images missing | `image_url` undefined | Check category metadata |

---

## 📞 Get Debug Report

```javascript
getMobileViewDebugReport()  // Shows everything in one view
```

---

## 📂 Key Files

- **Local Debugging:** `LOCAL_DEBUGGING_GUIDE.md`
- **Step-by-Step:** `MOBILE_VIEW_DEBUG_STEPS.md`
- **Debug Console:** `DEBUG_MOBILE_VIEW.js`
- **Setup Script:** `Backend/setup_local_env.ps1`
- **Config Template:** `Backend/.env.local.template`

---

## 🔧 Manual Fixes to Try

```javascript
// Fix 1: Force reload everything
loadCategories().then(() => {
    loadMobileCategorySections();
});

// Fix 2: Clear and retry
categoryHierarchy = [];
allProducts = [];
loadCategories();

// Fix 3: Force container display
document.getElementById('mobileCategorySections').style.display = 'block';

// Fix 4: Check container content
console.log(document.getElementById('mobileCategorySections').innerHTML);
```

---

## 📊 Performance Metrics

```javascript
// Check data volume
{
    sections: new Set(categoryHierarchy.map(c => c.section)).size,
    mainCategories: categoryHierarchy.length,
    products: allProducts.length,
    metadata: Object.keys(categoryMetadata).length,
    memory: `${(JSON.stringify(categoryHierarchy).length / 1024).toFixed(2)} KB`
}
```

---

## 🎯 Success Signs

- ✅ Sections visible in mobile frame
- ✅ Can click section without white screen
- ✅ Main categories load
- ✅ No console red 🔴 errors
- ✅ All API calls return 200
- ✅ Images display correctly
- ✅ Can refresh without data loss

---

## 📝 Minimal Test

```javascript
// Minimal reproduction test
async function testMinimal() {
    // Load data
    await loadCategories();
    
    // Check it loaded
    console.assert(categoryHierarchy.length > 0, 'No categories');
    console.assert(allProducts.length > 0, 'No products');
    
    // Render
    loadMobileCategorySections();
    
    // Check rendered
    const container = document.getElementById('mobileCategorySections');
    console.assert(container.innerHTML.length > 0, 'No HTML content');
    
    console.log('✅ All tests passed');
}

testMinimal();
```

---

## 🚨 Emergency Commands

```javascript
// If stuck
location.reload();  // Refresh page

// If data missing
indexedDB.deleteDatabase('almathina');  // Clear cache
location.reload();

// Force debug mode
MOBILE_VIEW_DEBUG.enabled = true;
testMobileViewFlow();

// Get all errors
MOBILE_VIEW_DEBUG.errors.forEach(e => console.log(e));

// Export debug info
JSON.stringify(MOBILE_VIEW_DEBUG, null, 2);  // Copy paste to file
```

---

## 🔗 Resource Links

- **MongoDB Atlas:** https://cloud.mongodb.com/
- **Cloudinary:** https://cloudinary.com/console/
- **FastAPI Docs:** http://127.0.0.1:8000/docs
- **API Routes:** http://127.0.0.1:8000/admin/api/categories/

---

## 💻 Terminal Commands Reference

```powershell
# Start backend (simple)
python -m uvicorn main_production:app --reload

# Start backend (with specific host/port)
python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000

# Test MongoDB connection
python -c "from pymongo import MongoClient; print(MongoClient('YOUR_MONGO_URI').admin.command('ping'))"

# Test API endpoint
curl http://127.0.0.1:8000/admin/api/categories/all

# View logs in real-time
python -m uvicorn main_production:app --log-level debug

# Run with production config
python -m uvicorn main_production:app --host 0.0.0.0 --port 8000
```

---

**Still stuck? Run `getMobileViewDebugReport()` and share the full console output!** 🆘
