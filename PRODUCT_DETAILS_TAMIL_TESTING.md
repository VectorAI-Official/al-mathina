# Product Details Tamil Language - Testing Guide

**Date**: October 30, 2025

---

## Quick Start Testing

### Prerequisites
- Backend running at `http://127.0.0.1:8000`
- Flutter app running in Chrome
- At least one product in the database

### Test Case 1: Basic Product Loading

**Steps**:
1. Launch Flutter app in Chrome
2. Navigate to Home screen
3. Click on any product card
4. **Expected**: 
   - Loading spinner appears briefly
   - Product details sheet slides up
   - Product name, price, image, and description display

**Success Criteria**:
- ✓ Loading indicator shows for 1-2 seconds
- ✓ No errors in console
- ✓ All product details visible
- ✓ Sheet closes when swiped down

---

### Test Case 2: Tamil Language Display

**Steps**:
1. Open product details (sheet or page)
2. Look for language selector (top-right corner)
3. Current language should show "EN" or flag
4. Click to open language menu
5. Select "Tamil" (தமிழ்)
6. **Expected**: Product name changes to Tamil

**Success Criteria**:
- ✓ Product name immediately changes to Tamil
- ✓ Other UI text also changes to Tamil
- ✓ No page reload needed
- ✓ Both sheet and page views update

---

### Test Case 3: Language Persistence

**Steps**:
1. In product details, select Tamil language
2. Close the product details
3. Navigate to a different product
4. Open new product details
5. **Expected**: Product name is ALREADY in Tamil

**Success Criteria**:
- ✓ Language preference remembered across products
- ✓ No need to select Tamil again
- ✓ All subsequent products show Tamil names

---

### Test Case 4: App Restart Persistence

**Steps**:
1. In any product details, select Tamil
2. Close the product sheet
3. Navigate to Home
4. Close the entire app (refresh page in Chrome)
5. Navigate back to product
6. **Expected**: Product name is STILL in Tamil

**Success Criteria**:
- ✓ Language setting survived app restart
- ✓ SharedPreferences successfully restored language
- ✓ No errors during app startup

---

### Test Case 5: Full Product Details Page

**Steps**:
1. Open product details sheet
2. Scroll down and tap product image (or use "View Details" button if available)
3. **Expected**: Full product details page opens
4. Product name should be in current language (English or Tamil)
5. Switch language to Tamil
6. **Expected**: Product name updates

**Success Criteria**:
- ✓ Full page view works correctly
- ✓ Product name displays with correct localization
- ✓ Price, stock, description visible
- ✓ Language switching works on full page too

---

### Test Case 6: Add to Cart with Localization

**Steps**:
1. Open product details in Tamil
2. Scroll to bottom
3. Click "Add to Cart" button
4. **Expected**: 
   - Toast notification appears
   - Product name in toast is in Tamil
   - Message "added to cart" is in Tamil

**Success Criteria**:
- ✓ Toast notification appears
- ✓ Product name in Tamil
- ✓ Localized message
- ✓ App doesn't crash

---

### Test Case 7: Error Handling

**Steps**:
1. Disconnect internet / turn off backend
2. Open new product
3. **Expected**: Error message appears with "Retry" button
4. Turn internet/backend back on
5. Click "Retry"
6. **Expected**: Product loads successfully

**Success Criteria**:
- ✓ Error message is clear and helpful
- ✓ Retry button is functional
- ✓ Product loads after reconnection
- ✓ No app crash

---

### Test Case 8: Multiple Products in Tamil

**Steps**:
1. Set language to Tamil
2. Navigate through multiple products
3. Each product should show Tamil name
4. Close and reopen products
5. Names should still be Tamil

**Success Criteria**:
- ✓ All products show Tamil names
- ✓ No products stuck in English
- ✓ Consistent experience across app

---

## API Verification

### Check Backend Response

Use curl to verify backend returns Tamil names:

```bash
curl -X GET "http://127.0.0.1:8000/api/flutter/product/123"
```

**Expected Response Should Include**:
```json
{
  "product_name": "English Product Name",
  "product_name_ta": "தமிழ் பெயர்",
  ...
}
```

If `product_name_ta` is missing or empty, products won't have Tamil names.

---

## Debugging Tips

### If Product Name Doesn't Change to Tamil:

1. **Check backend response**:
   - Open browser DevTools (F12)
   - Go to Network tab
   - Click on a product
   - Find `/api/flutter/product/` request
   - Check if response has `product_name_ta` field

2. **Check language state**:
   - In browser console: `console.log(currentLanguage)`
   - Should be 'ta' when Tamil is selected

3. **Check Product model**:
   - Verify `getLocalizedName()` method exists in `api_service.dart`
   - It should check if language is 'ta' and return Tamil name

### If Loading Spinner Doesn't Appear:

1. Product may already be cached
2. Try opening a different product
3. Check if `_isLoading` state is being set in `_loadProductDetails()`

### If Language Doesn't Persist:

1. Check SharedPreferences is working:
   - Look for "currentLanguage" key in local storage
   - Browser DevTools → Application → Local Storage
2. Verify `AppProvider` is calling `saveLangToSharedPreferences()`

---

## Console Logs to Monitor

When debugging, watch for these in browser console:

```dart
// Expected logs during product load:
"Loading product details for itemId: 123"
"Product loaded: Tamil name = 'தமிழ் பெயர்'"
"Language changed to: ta"
```

**Do NOT expect** these logs if they're not in the code. They're just examples.

---

## Performance Expectations

| Action | Expected Time | What's Happening |
|--------|---------------|------------------|
| Open product | 1-2 sec | Fetching from backend |
| Change language | Instant | Local state update, no network call |
| Load another product | 1-2 sec | New fetch from backend |
| Close and reopen app | < 1 sec | Loading language from SharedPreferences |

---

## Rollback Steps (If Issues Found)

If Tamil language in product details causes issues:

1. **Revert ProductDetailsSheet changes**:
   - In `main.dart`, convert `ProductDetailsSheet` back to `StatelessWidget`
   - Remove `_fetchedProduct`, `_isLoading`, `_loadProductDetails()`
   - Keep original UI code

2. **Revert ProductDetailsPage changes**:
   - Convert `ProductDetailsPage` back to `StatelessWidget`
   - Keep original navigation behavior

3. **Fallback**: Product names will display in English, but backend Tamil names are still available for future use

---

## Success Criteria Summary

### ✅ Feature is Working If:
1. Product loads with loading spinner
2. Product name appears in English by default
3. Changing to Tamil shows product name in Tamil
4. Language persists when reopening products
5. Language persists after app restart
6. Add to Cart shows localized feedback
7. Error handling works gracefully
8. No console errors

### ❌ Issues If:
1. Product name never changes when language changes
2. Wrong language shows even after language selection
3. App crashes when opening products
4. Language resets after app restart
5. Backend shows error in network tab

---

## Questions?

If you encounter issues:
1. Check the `PRODUCT_DETAILS_TAMIL_IMPLEMENTATION.md` for architecture details
2. Review code at lines 2430-2660 (ProductDetailsSheet) and 4861-5013 (ProductDetailsPage) in `main.dart`
3. Verify backend at `http://127.0.0.1:8000/docs` for API response structure
