# Most Bought Section - Flutter Implementation

## Overview
Implemented a "Most Bought" section in the Flutter app that displays starred main categories at the top of the home screen, before all other sections.

## What Was Changed

### 1. **Flutter UI Update** (`flutter_preview/lib/main.dart`)

#### Home Screen Display (Lines ~1352-1377)
- **BEFORE**: Displayed best seller products directly in a grid
- **AFTER**: Displays Most Bought main category cards in a 3-column grid

```dart
// Most Bought Section - Display Main Categories First
if (_homeData!.bestSellers.mainCategories.isNotEmpty) ...[
  const SizedBox(height: 12),
  _buildSectionHeader(
    _homeData!.bestSellers.title,  // "Most Bought"
    _homeData!.bestSellers.icon,   // "⭐"
  ),
  const SizedBox(height: 12),
  _buildMainCategoryGrid(_homeData!.bestSellers.mainCategories, isBestSeller: true),
  const SizedBox(height: 12),
],
```

#### Category Card Behavior (Lines ~1427-1530)
- **Most Bought cards** navigate to `SubcategoryProductsScreen`
- Shows a golden "⭐ Most Bought" badge on each card
- Uses the same UI style as regular main category cards
- 3 columns per row layout (same as other sections)

### 2. **Navigation Flow**

#### Most Bought Card Click:
```
Most Bought Card → SubcategoryProductsScreen → Select Subcategory → View Products
```

This is the same flow as clicking a regular main category card, because Most Bought categories ARE existing main categories that were starred in the backend admin dashboard.

### 3. **Backend API** (Already Implemented)

The `/api/flutter/home` endpoint returns:
```json
{
  "best_sellers": {
    "title": "Most Bought",
    "icon": "⭐",
    "main_categories": [
      {
        "id": "most_bought_grocery_&_kitchen_vegetables_&_fruits",
        "name": "Vegetables & Fruits",
        "image_url": "http://...",
        "product_count": 4,
        "section": "Grocery & Kitchen",
        "main_category": "Vegetables & Fruits"
      }
    ]
  },
  "sections": [...]
}
```

## Key Features

### ✅ **Three Column Layout**
- Most Bought cards display in 3 columns per row
- Same grid configuration as other main category sections
- Responsive and consistent spacing

### ✅ **Visual Design**
- Section header: "Most Bought" with ⭐ icon
- Each card shows:
  - Main category image
  - Golden "⭐ Most Bought" badge (top-right)
  - Category name (bottom)
  - Subtle shadow for depth

### ✅ **Proper Navigation**
- Clicking a Most Bought card opens `SubcategoryProductsScreen`
- Shows all subcategories for that main category
- User selects subcategory to view products
- Full breadcrumb navigation maintained

### ✅ **Dynamic Updates**
- Categories displayed are fetched from `most_bought` database collection
- Admin can star/unstar categories in the backend dashboard
- Changes reflect immediately in the Flutter app after refresh

## Data Flow

1. **Backend Admin**: Admin stars main categories in mobile view
2. **Database**: Categories saved to `most_bought` collection
3. **API**: `/api/flutter/home` fetches starred categories
4. **Flutter App**: Displays Most Bought section at top of home screen
5. **User Navigation**: Clicks Most Bought card → Views subcategories → Selects products

## Current Data

As of now, 2 categories are starred:
- Grocery & Kitchen → Vegetables & Fruits (4 products)
- Grocery & Kitchen → Atta, Rice & Dal (2 products)

## Testing

### To Test in Flutter App:
1. Ensure backend is running: `http://192.168.1.6:8000`
2. Open Flutter app on device/emulator
3. Pull to refresh home screen
4. You should see "Most Bought" section at the very top
5. Click any Most Bought card
6. Should navigate to subcategory selection screen
7. Select a subcategory to view products

### To Add More Most Bought Items:
1. Open admin dashboard in mobile view
2. Navigate to any section
3. Click ⭐ star button on any main category card
4. Card will show "⭐ Starred" badge
5. Refresh Flutter app to see changes

## Code References

### Flutter Files:
- `flutter_preview/lib/main.dart` (lines ~1352-1530)
  - Home screen layout
  - Most Bought section display
  - Category card navigation

### Backend Files:
- `Backend/routes/flutter.py` (lines 45-95)
  - Home data API endpoint
  - Most Bought data fetching

- `Backend/static/admin/js/dashboard.js` (lines 2506-2565)
  - Toggle star main category function
  - Star/unstar logic

- `Backend/routes/admin_local.py` (lines 850-985)
  - POST /admin/api/most-bought (add category)
  - DELETE /admin/api/most-bought (remove category)
  - GET /admin/api/most-bought (list all)

## Notes

- Most Bought categories are **existing main categories** that were starred
- They appear in BOTH locations:
  1. Most Bought section (at top)
  2. Their original section (e.g., "Grocery & Kitchen")
- Navigation is identical to regular categories
- Images and data are shared with the original main category
- No duplication in database - only a reference in `most_bought` collection
