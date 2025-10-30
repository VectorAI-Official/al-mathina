# Product Details Tamil Language - Visual Guide

**Date**: October 30, 2025

---

## 🎯 User Journey

### Before Implementation
```
User Opens Product
        ↓
[Shows Static Data]
        ↓
Product name: Always English
        ↓
No language option
        ↓
Static, never refreshes
```

### After Implementation
```
User Opens Product
        ↓
[Shows Loading Spinner]
        ↓
App Fetches Fresh Data from Backend
        ↓
Backend Returns: English Name + Tamil Name
        ↓
[Shows Product with Current Language]
        ├─ If English selected → Shows English name
        └─ If Tamil selected → Shows Tamil name
        ↓
User Changes Language
        ↓
Product Name Changes Instantly
        ↓
App Saves Language Preference
        ↓
Next Product Opens → Already in Selected Language
```

---

## 🔄 Component Architecture

### Before
```
ProductDetailsSheet (StatelessWidget)
├─ Uses: passed-in product (static)
├─ No async operations
├─ No loading states
└─ No language support
```

### After
```
ProductDetailsSheet (StatefulWidget)
├─ State Fields:
│  ├─ _fetchedProduct (from backend)
│  ├─ _isLoading (show spinner)
│  └─ _error (error message)
├─ Async Methods:
│  └─ _loadProductDetails() (fetch from backend)
└─ UI:
   ├─ Loading Spinner
   ├─ Error Display with Retry
   └─ Product Details (with localized names)
```

---

## 🌐 API Integration

### Request Flow
```
ProductDetailsSheet.initState()
        ↓
Calls: _loadProductDetails()
        ↓
Makes HTTP GET Request:
  GET /api/flutter/product/{itemId}
        ↓
Backend (FastAPI)
        ↓
Queries Database
        ↓
Returns JSON:
  {
    "product_name": "Product (EN)",
    "product_name_ta": "தயாரிப்பு (TA)",
    "price": 299,
    "stock": 50,
    ...
  }
        ↓
setState(_fetchedProduct = response)
        ↓
Widget Rebuilds
        ↓
UI Shows Product with Localized Name
```

---

## 🌍 Language System Integration

### User Language Selection Flow
```
User Clicks Language Button
        ↓
Language Selector Appears
  ├─ English (EN)
  └─ Tamil (TA)
        ↓
User Selects "Tamil"
        ↓
AppProvider.changeLanguage('ta')
        ↓
├─ Saves to SharedPreferences
└─ Calls notifyListeners()
        ↓
All Listening Widgets Rebuild
        ↓
ProductDetailsSheet.build() Called
        ↓
product.getLocalizedName('ta')
        ↓
Returns Tamil Name
        ↓
UI Updates - Shows Tamil Product Name
```

---

## 💾 Language Persistence

### First Time (New User)
```
Default: Language = 'en'
        ↓
User Selects: 'ta' (Tamil)
        ↓
AppProvider.changeLanguage('ta')
        ↓
Save to SharedPreferences
  {
    "currentLanguage": "ta"
  }
        ↓
Later Sessions:
  App Restarts
        ↓
Load from SharedPreferences
        ↓
AppProvider._currentLanguage = 'ta'
        ↓
User Sees Products in Tamil
  (without selecting again)
```

---

## 🔧 Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Main App                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │             AppProvider                           │  │
│  │  • currentLanguage: 'en' or 'ta'                  │  │
│  │  • notifyListeners() on change                    │  │
│  │  • Persists to SharedPreferences                  │  │
│  └───────────┬───────────────────────────────────────┘  │
│              │                                            │
│              │ Provider.of<AppProvider>()                │
│              │                                            │
│  ┌───────────▼───────────────────────────────────────┐  │
│  │  ProductDetailsSheet/Page (StatefulWidget)        │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ State:                                       │  │  │
│  │  │ • _fetchedProduct: Product?                │  │  │
│  │  │ • _isLoading: bool                         │  │  │
│  │  │ • _error: String?                          │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Methods:                                    │  │  │
│  │  │ • _loadProductDetails(): Future<void>      │  │  │
│  │  │   └─ Calls ApiService.getProductDetails()  │  │  │
│  │  │   └─ Sets _fetchedProduct                  │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Build:                                       │  │  │
│  │  │ • Show Loading Spinner if _isLoading       │  │  │
│  │  │ • Show Error if _error != null             │  │  │
│  │  │ • Show Product UI with:                    │  │  │
│  │  │   product.getLocalizedName(                │  │  │
│  │  │     provider.currentLanguage)              │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │             ApiService                            │  │
│  │  getProductDetails(itemId):                       │  │
│  │    GET /api/flutter/product/{itemId}             │  │
│  │    Returns: Product {                            │  │
│  │      productName: "English"                      │  │
│  │      productNameTa: "தமிழ்"                      │  │
│  │      ...                                         │  │
│  │    }                                             │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │             Product Model                         │  │
│  │  getLocalizedName(language):                     │  │
│  │    if language == 'ta' && productNameTa != null  │  │
│  │      return productNameTa                        │  │
│  │    else                                          │  │
│  │      return productName                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 State Management Flow

### Widget Lifecycle
```
1. Widget Mounted
   ├─ initState() runs
   ├─ _loadProductDetails() called
   ├─ setState(_isLoading = true)
   └─ UI renders: Loading Spinner

2. Backend Response Received
   ├─ setState(_fetchedProduct = data)
   ├─ setState(_isLoading = false)
   └─ UI re-renders: Product Details

3. User Changes Language
   ├─ AppProvider.changeLanguage('ta')
   ├─ AppProvider notifies listeners
   ├─ Provider.of<AppProvider>() detects change
   ├─ Widget.build() called
   ├─ getLocalizedName('ta') returns Tamil name
   └─ UI updates: Shows Tamil Name

4. User Closes & Reopens App
   ├─ SharedPreferences.getString('currentLanguage')
   ├─ Returns 'ta' (saved from step 3)
   ├─ AppProvider restores 'ta'
   ├─ Product opens
   ├─ getLocalizedName('ta') called immediately
   └─ Shows Tamil name (no need to select again)
```

---

## ⚡ Event Timeline

### User Opens Product (English Selected)
```
T0:00 - User taps product card
T0:05 - ProductDetailsSheet mounts
T0:10 - initState() calls _loadProductDetails()
T0:15 - setState(_isLoading = true)
T0:20 - Loading spinner visible
T1:00 - Backend responds with data
T1:05 - setState(_fetchedProduct = product, _isLoading = false)
T1:10 - build() called
T1:15 - Product name: getLocalizedName('en') → "English Name"
T1:20 - UI shows: English product name
```

### User Changes to Tamil
```
T1:25 - User clicks Language button
T1:30 - Language selector appears
T1:35 - User taps "Tamil"
T1:40 - AppProvider.changeLanguage('ta')
T1:45 - SharedPreferences saves 'ta'
T1:50 - AppProvider notifies listeners
T1:55 - Provider.of<AppProvider> detects change
T2:00 - Widget rebuilds (no new HTTP call)
T2:05 - Product name: getLocalizedName('ta') → "தமிழ் பெயர்"
T2:10 - UI updates: Tamil product name shown
```

### User Closes and Restarts App
```
T3:00 - User closes app
...
T5:00 - User reopens app
T5:10 - SharedPreferences loaded
T5:15 - currentLanguage restored: 'ta'
T5:20 - AppProvider initialized with 'ta'
T5:25 - User opens same product
T5:30 - Product name: getLocalizedName('ta') → "தமிழ் பெயர்"
T5:35 - UI shows: Tamil product name (automatically!)
```

---

## 🛡️ Error Handling Flow

### Network Error Scenario
```
_loadProductDetails() called
        ↓
HTTP Request to Backend
        ↓
Network Error / Timeout
        ↓
catch (e) block executes
        ↓
setState(_error = e.toString())
        ↓
build() checks: if (_error != null)
        ↓
UI Renders Error Screen:
  ├─ Error Icon (red)
  ├─ Error Message
  ├─ "Retry" Button
        ↓
User Clicks Retry
        ↓
_loadProductDetails() runs again
        ↓
Backend Now Available
        ↓
setState(_fetchedProduct = data)
        ↓
UI Shows Product Details
```

---

## 📱 UI Layout

### ProductDetailsSheet (Modal)
```
┌─────────────────────────────────┐
│ [^] Header                      │ ← Can swipe down to close
├─────────────────────────────────┤
│                                 │
│    [Product Image]              │
│                                 │
├─────────────────────────────────┤
│ ⭐ Best Seller (if applicable) │
│                                 │
│ Product Name (English/Tamil)    │ ← Uses getLocalizedName()
│ [This shows fetched data]       │
│                                 │
│ Weight: 500g                    │
│ Category: Main > Sub            │
│ Price: ₹299                     │
│ Stock: 50 units                 │
│                                 │
│ Description:                    │
│ Product details...              │
│                                 │
│ [   Add to Cart Button  ]       │
│                                 │
└─────────────────────────────────┘

While Loading:
┌─────────────────────────────────┐
│                                 │
│      Loading Spinner...         │
│      (rotating indicator)        │
│                                 │
└─────────────────────────────────┘

On Error:
┌─────────────────────────────────┐
│                                 │
│      ⚠️ Error Message            │
│                                 │
│      [ Retry Button ]           │
│                                 │
└─────────────────────────────────┘
```

### ProductDetailsPage (Full Page)
```
┌─────────────────────────────────┐
│ < Product Name (English/Tamil)  │ ← Uses getLocalizedName()
│ (in AppBar)                     │
├─────────────────────────────────┤
│                                 │
│    [Large Product Image]        │
│                                 │
│ Product Name (Title)            │ ← Shows fetched data
│ Weight: 500g                    │
│                                 │
│ ₹299           Stock: 50        │
│ (Price)        (Inventory)      │
│                                 │
│ Description                     │
│ Full product description        │
│ shown here...                   │
│                                 │
│                                 │
│ [   Add to Cart Button  ]       │
│                                 │
└─────────────────────────────────┘
     ↑ Scrollable ↓
```

---

## 🔑 Key Methods

### ApiService.getProductDetails()
```dart
Future<Product> getProductDetails(String itemId) {
  // GET /api/flutter/product/{itemId}
  // Response contains:
  //   - product_name (English)
  //   - product_name_ta (Tamil)
  //   - price, stock, description, etc.
  // Returns: Product object
}
```

### Product.getLocalizedName()
```dart
String getLocalizedName(String language) {
  if (language == 'ta' && productNameTa?.isNotEmpty) {
    return productNameTa!;  // Tamil name
  }
  return productName;  // English name (default)
}
```

### AppProvider.changeLanguage()
```dart
Future<void> changeLanguage(String language) {
  _currentLanguage = language;
  await saveLangToSharedPreferences(language);
  notifyListeners();  // Triggers all listeners to rebuild
}
```

---

## 📊 Comparison Table

| Aspect | Before | After |
|--------|--------|-------|
| Data source | Passed product | Backend fetch |
| Loading | None | Spinner shown |
| Errors | No handling | Error UI + Retry |
| Language | English only | English + Tamil |
| Updates | Never | Fresh on each open |
| User experience | Static | Dynamic |

---

## ✨ Summary Diagram

```
┌──────────────────────────────────────────────────────────┐
│ Flutter App                                              │
│                                                          │
│ ┌─ AppProvider ────────────────────────────────────────┐ │
│ │ Language: 'en' or 'ta'                               │ │
│ │ Notifies widgets on change                           │ │
│ │ Persists to SharedPreferences                        │ │
│ └────────────────────────────────────────────────────── │ │
│         ▲                                    ▲           │ │
│         │ notifyListeners()                 │ Provider.of
│         │                                    │           │ │
│ ┌──────┴────────────────────────────────────┴─────────┐ │ │
│ │ ProductDetailsSheet/Page (StatefulWidget)           │ │ │
│ │                                                      │ │ │
│ │ Fetch Data              Show UI                     │ │ │
│ │ ↓                       ↓                           │ │ │
│ │ ApiService.getProductDetails()                     │ │ │
│ │    ↓                   ↓                           │ │ │
│ │    Backend API        product.getLocalizedName()   │ │ │
│ │    ↓                   ↓                           │ │ │
│ │    {                   if lang=='ta'               │ │ │
│ │      product_name       return product_name_ta     │ │ │
│ │      product_name_ta    else                       │ │ │
│ │    }                    return product_name        │ │ │
│ └──────────────────────────────────────────────────── │ │
└──────────────────────────────────────────────────────────┘
```

---

This visual guide shows exactly how all pieces fit together to provide Tamil language support in product details! 🎯
