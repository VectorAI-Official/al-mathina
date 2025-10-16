# 🎯 Quick Reference: 3-Level Mobile Navigation

## Visual Flow Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                         LEVEL 1                               │
│                     SECTION CARDS                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │    ⭐    │  │    🛒    │  │    🍿    │  │    💄    │     │
│  │   Best   │  │  Grocery │  │  Snacks  │  │  Beauty  │     │
│  │  Seller  │  │  Kitchen │  │  Drinks  │  │   Care   │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
│       │                                                        │
│       │ showMobileCategoryProducts('Best Seller')            │
│       └────────────────────┐                                  │
└────────────────────────────┼──────────────────────────────────┘
                             ↓
┌───────────────────────────────────────────────────────────────┐
│                         LEVEL 2                               │
│                   MAIN CATEGORY CARDS                         │
│  ← Back to Sections    🔍 Search main categories...          │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │    🥤    │  │    🧃    │  │    🍺    │  │    🍷    │     │
│  │   Soft   │  │  Juices  │  │   Beer   │  │   Wine   │     │
│  │  Drinks  │  │          │  │          │  │          │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
│       │                                                        │
│       │ showSubCategoryProducts('Best Seller', 'Soft Drinks') │
│       └────────────────────┐                                  │
└────────────────────────────┼──────────────────────────────────┘
                             ↓
┌───────────────────────────────────────────────────────────────┐
│                         LEVEL 3                               │
│              SIDEBAR WITH SUBCATEGORIES + PRODUCTS            │
│  ← Back to Main Categories                                    │
│  ┌─────────┬─────────────────────────────────────────┐       │
│  │ Sidebar │ Products (Soft Drinks)                  │       │
│  │  (20%)  │  (80%)                                  │       │
│  │         │                                         │       │
│  │ 🥤 Coca │  ┌────┐  ┌────┐  ┌────┐  ┌────┐       │       │
│  │   Cola  │  │IMG │  │IMG │  │IMG │  │IMG │       │       │
│  │   ✅    │  │Coke│  │Pepsi│ │Sprite││Fanta│       │       │
│  │   [✏️]  │  │₹45 │  │₹40 │  │₹42 │  │₹42 │       │       │
│  │         │  └────┘  └────┘  └────┘  └────┘       │       │
│  │ 🥤 Pepsi│                                         │       │
│  │   [✏️]  │  ┌────┐  ┌────┐  ┌────┐  ┌────┐       │       │
│  │         │  │IMG │  │IMG │  │IMG │  │IMG │       │       │
│  │ 🥤 Sprite│  │Prod│  │Prod│  │Prod│  │Prod│       │       │
│  │   [✏️]  │  │₹50 │  │₹48 │  │₹52 │  │₹55 │       │       │
│  │         │  └────┘  └────┘  └────┘  └────┘       │       │
│  │ ➕ Add  │                                         │       │
│  │   New   │  Click subcategory → Products refresh  │       │
│  └─────────┴─────────────────────────────────────────┘       │
│             selectSubCategory('Best Seller', ...)            │
└───────────────────────────────────────────────────────────────┘
```

---

## Function Call Chain

### Forward Navigation (Drill Down):

```javascript
// Step 1: Click Section Card
onclick="showMobileCategoryProducts('Best Seller')"
    ↓
showMobileCategoryProducts('Best Seller')
    ↓
showMainCategoryCards('Best Seller')
    → Displays: Level 2 (Main Category Cards)

// Step 2: Click Main Category Card
onclick="showSubCategoryProducts('Best Seller', 'Soft Drinks')"
    ↓
showSubCategoryProducts('Best Seller', 'Soft Drinks')
    ↓
loadSectionProducts('Best Seller', firstSubcategory)
    → Displays: Level 3 (Sidebar + Products)

// Step 3: Click Subcategory in Sidebar
onclick="selectSubCategory('Best Seller', 'Soft Drinks', 'Coca Cola', this)"
    ↓
selectSubCategory('Best Seller', 'Soft Drinks', 'Coca Cola', this)
    ↓
loadSectionProducts('Best Seller', 'Coca Cola')
    → Updates: Products only (sidebar stays)
```

### Backward Navigation (Go Back):

```javascript
// From Level 3 to Level 2
onclick="showMainCategoryCards('Best Seller')"
    ↓
showMainCategoryCards('Best Seller')
    → Returns to: Main Category Cards

// From Level 2 to Level 1
onclick="showMobileCategories()"
    ↓
showMobileCategories()
    → Returns to: Section Cards
```

---

## Data Structure Example

### categoryHierarchy Array:
```javascript
[
    {
        section: "Best Seller",           // LEVEL 1
        main_categories: {
            "Soft Drinks": [              // LEVEL 2 (Main Category)
                "Coca Cola",              // LEVEL 3 (Subcategory)
                "Pepsi",
                "Sprite"
            ],
            "Juices": [                   // LEVEL 2
                "Orange Juice",           // LEVEL 3
                "Apple Juice",
                "Mango Juice"
            ]
        }
    },
    {
        section: "Grocery & Kitchen",     // LEVEL 1
        main_categories: {
            "Rice Flour": [               // LEVEL 2
                "Basmati Rice",           // LEVEL 3
                "Sona Masoori",
                "Wheat Flour"
            ],
            "Pulses Dals": [              // LEVEL 2
                "Toor Dal",               // LEVEL 3
                "Moong Dal"
            ]
        }
    }
]
```

---

## What Each Level Shows

### Level 1: Section Cards
**Variable:** `categoryHierarchy[].section`  
**Examples:** Best Seller, Grocery & Kitchen, Snacks & Drinks  
**Display:** Large cards with icons  
**Function:** `showMobileCategoryProducts(section)`

### Level 2: Main Category Cards
**Variable:** `Object.keys(categoryHierarchy[].main_categories)`  
**Examples:** Soft Drinks, Juices, Rice Flour, Pulses Dals  
**Display:** Cards similar to Level 1  
**Function:** `showSubCategoryProducts(section, mainCategory)`

### Level 3: Subcategory Sidebar
**Variable:** `categoryHierarchy[].main_categories[mainCategory]` (array)  
**Examples:** Coca Cola, Pepsi, Basmati Rice, Toor Dal  
**Display:** Sidebar (20%) + Products (80%)  
**Function:** `selectSubCategory(section, mainCategory, subCategory, element)`

---

## Key Differences from Old Implementation

### OLD (2 Levels):
```
Section → Sidebar (all subcategories mixed)
```
**Problem:** Too many items in sidebar, unclear grouping

### NEW (3 Levels):
```
Section → Main Categories → Subcategories
```
**Benefits:** 
- Clear hierarchy
- Organized grouping
- Less clutter in sidebar
- Easier navigation

---

## Back Button Behavior

| Level | Back Button Text | Function Called | Goes To |
|-------|------------------|----------------|---------|
| Level 2 | ← Back to Sections | `showMobileCategories()` | Level 1 |
| Level 3 | ← Back to Main Categories | `showMainCategoryCards(section)` | Level 2 |

---

## Search Functionality

### Level 1: Section Search
- **Input ID:** `mobileCategorySearch`
- **Function:** `searchMobileCategories()`
- **Filters:** Section cards

### Level 2: Main Category Search
- **Input ID:** `mainCategorySearch`
- **Function:** `searchMainCategories()`
- **Filters:** Main category cards

### Level 3: No Search
- Sidebar is already filtered by main category
- Only shows subcategories of selected main category

---

## Container State Management

```javascript
// Level 1: Section Cards
categoriesContainer.style.display = 'block';   // Visible
productsContainer.style.display = 'none';      // Hidden

// Level 2: Main Category Cards
categoriesContainer.style.display = 'none';    // Hidden
productsContainer.style.display = 'block';     // Visible
productsContainer.innerHTML = /* Main category cards */

// Level 3: Sidebar Layout
categoriesContainer.style.display = 'none';    // Hidden
productsContainer.style.display = 'block';     // Visible
productsContainer.innerHTML = /* Sidebar + Products */
```

---

## Complete Example: Finding a Product

**Goal:** Find "Basmati Rice" products

```
1. Open Mobile Preview
   └─→ Shows: All sections

2. Click "Grocery & Kitchen"
   └─→ showMobileCategoryProducts('Grocery & Kitchen')
   └─→ Shows: Main categories (Rice Flour, Pulses Dals, Oils Ghee, ...)

3. Click "Rice Flour"
   └─→ showSubCategoryProducts('Grocery & Kitchen', 'Rice Flour')
   └─→ Shows: Sidebar with (Basmati Rice, Sona Masoori, Wheat Flour)
   └─→ Auto-loads: Basmati Rice products

4. See Products
   └─→ All products with sub_category="Basmati Rice" displayed

5. Optional: Click other subcategory
   └─→ selectSubCategory('Grocery & Kitchen', 'Rice Flour', 'Sona Masoori', ...)
   └─→ Products refresh with Sona Masoori items
```

---

## CSS Classes Reference

### Cards (Levels 1 & 2):
- `.mobile-category-card` - Card container
- `.mobile-category-card .icon` - Icon/emoji display
- `.mobile-category-card .name` - Category name
- `.mobile-category-card:hover` - Hover effect

### Search:
- `.mobile-search-container` - Search wrapper
- `.mobile-search-input` - Search text input

### Sidebar (Level 3):
- `.mobile-bestseller-layout` - Main container (flexbox)
- `.mobile-bestseller-sidebar` - Sidebar (20%)
- `.mobile-bestseller-content` - Products area (80%)
- `.mobile-sidebar-item` - Individual subcategory
- `.mobile-sidebar-item.active` - Selected subcategory
- `.mobile-sidebar-item .edit-btn` - Edit button

### Common:
- `.mobile-back-button` - Back navigation button
- `.mobile-empty-state` - No data message

---

## Testing Checklist

- [ ] Click section card → See main category cards
- [ ] Search main categories → Cards filter correctly
- [ ] Click main category → See sidebar with subcategories
- [ ] First subcategory auto-selected → Products load
- [ ] Click other subcategory → Products refresh
- [ ] Click "← Back to Main Categories" → Return to Level 2
- [ ] Click "← Back to Sections" → Return to Level 1
- [ ] Images display (or fallback to emoji)
- [ ] Edit buttons work on subcategories
- [ ] "Add New" button works

---

**Quick Start:** Just click any section card and you'll see the new 3-level navigation! 🚀

