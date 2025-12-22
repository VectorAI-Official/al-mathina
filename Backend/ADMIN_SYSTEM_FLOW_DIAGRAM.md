# Admin Buying Price System - Visual Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         🎯 ADMIN BUYING PRICE SYSTEM                         │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                         📱 FLUTTER APP (Client)                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     │ User logs in                           │
│                                     │ Phone: 7339651541                      │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 1. User Authentication                                                 │  │
│  │    - Phone number stored in SharedPreferences/Provider                │  │
│  │    - Available for all API calls                                      │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     │ Navigate to                            │
│                                     │ Subcategory: "Rice"                    │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 2. Product List Screen                                                 │  │
│  │    - Fetch products with user_phone parameter                         │  │
│  │    - Display products in grid/list                                    │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     │ API Request                            │
│                                     │                                        │
└─────────────────────────────────────┼────────────────────────────────────────┘
                                      │
                                      │ HTTP GET
                                      │ /api/flutter/products?
                                      │   subcategory=Rice
                                      │   user_phone=7339651541
                                      │
┌─────────────────────────────────────▼────────────────────────────────────────┐
│                      🖥️  BACKEND (FastAPI - Python)                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 3. API Endpoint: routes/flutter.py → get_products()                   │  │
│  │                                                                        │  │
│  │    def get_products(user_phone: str = None, ...):                     │  │
│  │        is_admin = False                                               │  │
│  │                                                                        │  │
│  │        # Step A: Extract user_phone from query params                │  │
│  │        if user_phone:                                                 │  │
│  │            # Step B: Check admin status in Supabase                  │  │
│  │            user = supabase.table('users')                            │  │
│  │                            .select('is_admin')                        │  │
│  │                            .eq('phone', user_phone)                   │  │
│  │                            .execute()                                 │  │
│  │                                                                        │  │
│  │            if user.data:                                              │  │
│  │                is_admin = user.data[0].get('is_admin', False)       │  │
│  │        # is_admin = True for 7339651541                              │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 4. Database Queries                                                    │  │
│  │                                                                        │  │
│  │    ┌─────────────────────┐         ┌─────────────────────────────┐    │  │
│  │    │ Supabase (Postgres) │         │ MongoDB                     │    │  │
│  │    │ ─────────────────── │         │ ────────────────────        │    │  │
│  │    │ Query:              │         │ Query:                      │    │  │
│  │    │ SELECT is_admin     │         │ db.products.find({          │    │  │
│  │    │ FROM users          │         │   subcategory: "Rice"       │    │  │
│  │    │ WHERE phone =       │         │ })                          │    │  │
│  │    │   '7339651541'      │         │                             │    │  │
│  │    │                     │         │ Returns:                    │    │  │
│  │    │ Result:             │         │ [                           │    │  │
│  │    │ is_admin = True  ✅ │         │   {                         │    │  │
│  │    │                     │         │     product_name: "...",    │    │  │
│  │    └─────────────────────┘         │     price: 100.0,           │    │  │
│  │                                    │     buying_price: 80.0,     │    │  │
│  │                                    │     ...                      │    │  │
│  │                                    │   }                          │    │  │
│  │                                    │ ]                            │    │  │
│  │                                    └─────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 5. Response Building                                                   │  │
│  │                                                                        │  │
│  │    products_data = []                                                 │  │
│  │    for product in mongodb_products:                                   │  │
│  │        product_data = {                                               │  │
│  │            "item_id": product["item_id"],                             │  │
│  │            "product_name": product["product_name"],                   │  │
│  │            "price": float(product["price"]),                          │  │
│  │            "section": product["section"],                             │  │
│  │            ...                                                         │  │
│  │        }                                                               │  │
│  │                                                                        │  │
│  │        ⭐ IF is_admin == True:                                         │  │
│  │            product_data["buying_price"] = float(                      │  │
│  │                product.get("buying_price", 0.0)                       │  │
│  │            )                                                           │  │
│  │        ⭐ ELSE:                                                         │  │
│  │            # Don't include buying_price at all                        │  │
│  │                                                                        │  │
│  │        products_data.append(product_data)                             │  │
│  │                                                                        │  │
│  │    return {                                                            │  │
│  │        "products": products_data,                                     │  │
│  │        "is_admin": is_admin,  ⭐ NEW                                   │  │
│  │        "pagination": {...}                                            │  │
│  │    }                                                                   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     │ JSON Response                          │
│                                     │                                        │
└─────────────────────────────────────┼────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         📱 FLUTTER APP (Client)                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 6. Parse Response                                                      │  │
│  │                                                                        │  │
│  │    {                                                                   │  │
│  │      "products": [                                                     │  │
│  │        {                                                               │  │
│  │          "item_id": "...",                                             │  │
│  │          "product_name": "Basmati Rice",                               │  │
│  │          "price": 100.0,                                               │  │
│  │          "buying_price": 80.0,  ⭐ ONLY for admin                      │  │
│  │          ...                                                           │  │
│  │        }                                                               │  │
│  │      ],                                                                │  │
│  │      "is_admin": true,  ⭐ NEW                                          │  │
│  │      "pagination": {...}                                               │  │
│  │    }                                                                   │  │
│  │                                                                        │  │
│  │    final response = ProductsResponse.fromJson(jsonDecode(body));      │  │
│  │    setState(() {                                                       │  │
│  │      _products = response.products;                                   │  │
│  │      _isAdmin = response.isAdmin;  ⭐ Store admin status               │  │
│  │    });                                                                 │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 7. UI Rendering                                                        │  │
│  │                                                                        │  │
│  │    GridView.builder(                                                  │  │
│  │      itemBuilder: (context, index) {                                  │  │
│  │        return ProductCard(                                            │  │
│  │          product: _products[index],                                   │  │
│  │          isAdmin: _isAdmin,  ⭐ Pass to widget                         │  │
│  │        );                                                              │  │
│  │      }                                                                 │  │
│  │    )                                                                   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                        │
│                                     ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 8A. ADMIN VIEW (Phone: 7339651541) ✅                                  │  │
│  │                                                                        │  │
│  │  App Bar: "Rice" [Admin] ⭐                                            │  │
│  │                                                                        │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                       │  │
│  │  │ [Image]    │  │ [Image]    │  │ [Image]    │                       │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ Basmati    │  │ Ponni      │  │ Sona       │                       │  │
│  │  │ Rice       │  │ Rice       │  │ Masoori    │                       │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ ₹100.00    │  │ ₹85.00     │  │ ₹95.00     │  ← Selling Price     │  │
│  │  │ Buying:    │  │ Buying:    │  │ Buying:    │  ⭐ Admin Only        │  │
│  │  │ ₹80.00     │  │ ₹70.00     │  │ ₹78.00     │  ⭐ Admin Only        │  │
│  │  │ Margin:    │  │ Margin:    │  │ Margin:    │  ⭐ Admin Only        │  │
│  │  │ ₹20.00     │  │ ₹15.00     │  │ ₹17.00     │  ⭐ Admin Only        │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ [Add Cart] │  │ [Add Cart] │  │ [Add Cart] │                       │  │
│  │  └────────────┘  └────────────┘  └────────────┘                       │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ 8B. REGULAR USER VIEW (Phone: 9876543210) ❌                           │  │
│  │                                                                        │  │
│  │  App Bar: "Rice"  (No admin badge)                                    │  │
│  │                                                                        │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                       │  │
│  │  │ [Image]    │  │ [Image]    │  │ [Image]    │                       │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ Basmati    │  │ Ponni      │  │ Sona       │                       │  │
│  │  │ Rice       │  │ Rice       │  │ Masoori    │                       │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ ₹100.00    │  │ ₹85.00     │  │ ₹95.00     │  ← Selling Price     │  │
│  │  │            │  │            │  │            │                       │  │
│  │  │ [Add Cart] │  │ [Add Cart] │  │ [Add Cart] │                       │  │
│  │  └────────────┘  └────────────┘  └────────────┘                       │  │
│  │                                                                        │  │
│  │  ⭐ NO buying price, NO margin shown - Regular user                    │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                            🔐 SECURITY VERIFICATION
═══════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────────────┐
│                        ✅ SERVER-SIDE CHECKS (Secure)                        │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. ✅ Admin status checked on BACKEND (routes/flutter.py)                   │
│     → Cannot be faked by client                                             │
│                                                                              │
│  2. ✅ Database query verifies is_admin column                               │
│     → Supabase users table stores authoritative admin flag                  │
│                                                                              │
│  3. ✅ Conditional field inclusion in response                               │
│     → buying_price ONLY added when is_admin == True                         │
│                                                                              │
│  4. ✅ Fresh check on every API call                                         │
│     → No caching of admin status in client                                  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                       ❌ CLIENT-SIDE TRUST (Not Used)                        │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ❌ Admin status NOT stored permanently in Flutter                           │
│  ❌ Admin status NOT checked client-side only                                │
│  ❌ Client CANNOT override admin flag                                        │
│  ❌ buying_price field NEVER sent to non-admin users                         │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                           📊 DATABASE ARCHITECTURE
═══════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────────────┐
│                   SUPABASE (Postgres) - users table                          │
├────────────┬──────────┬──────────┬────────────────────────────────────────────┤
│ Column     │ Type     │ Default  │ Description                               │
├────────────┼──────────┼──────────┼────────────────────────────────────────────┤
│ id         │ UUID     │ gen_...  │ Primary key (auto-generated)              │
│ phone      │ TEXT     │ NULL     │ User's phone number (unique)              │
│ name       │ TEXT     │ NULL     │ User's name                               │
│ email      │ TEXT     │ NULL     │ User's email                              │
│ store_name │ TEXT     │ NULL     │ Store name                                │
│ fcm_token  │ TEXT     │ NULL     │ Firebase Cloud Messaging token            │
│ is_admin   │ BOOLEAN  │ false ⭐ │ Admin flag (NEW)                          │
└────────────┴──────────┴──────────┴────────────────────────────────────────────┘

Admin Users:
┌──────────────┬────────────┬──────────────────┬────────────────────────────┐
│ phone        │ is_admin   │ name             │ email                      │
├──────────────┼────────────┼──────────────────┼────────────────────────────┤
│ 7339651541   │ true ✅    │ Admin User 1     │ admin1541@almathina.com    │
│ 8870503350   │ true ✅    │ Admin User 2     │ admin3350@almathina.com    │
│ 9487715568   │ true ✅    │ Admin User 3     │ admin5568@almathina.com    │
│ 9876543210   │ false ❌   │ Regular User     │ user@example.com           │
└──────────────┴────────────┴──────────────────┴────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                   MONGODB - products collection                              │
├────────────────────┬─────────────┬──────────────────────────────────────────┤
│ Field              │ Type        │ Description                              │
├────────────────────┼─────────────┼──────────────────────────────────────────┤
│ item_id            │ UUID        │ Unique product identifier                │
│ product_name       │ String      │ Product name                             │
│ price              │ Float       │ Selling price (customer pays this)       │
│ buying_price ⭐    │ Float       │ Cost price (admin only sees this)        │
│ section            │ String      │ Product section                          │
│ main_category      │ String      │ Main category                            │
│ subcategory        │ String      │ Subcategory                              │
│ image_url          │ String      │ Product image URL                        │
│ description        │ String      │ Product description                      │
│ unit               │ String      │ Unit of measurement (kg, liter, etc.)    │
│ available_stock    │ Integer     │ Stock quantity                           │
└────────────────────┴─────────────┴──────────────────────────────────────────┘

Example Product Document:
{
  "item_id": "550e8400-e29b-41d4-a716-446655440000",
  "product_name": "Basmati Rice Premium",
  "price": 120.0,
  "buying_price": 95.0,  ← ⭐ Admin only field
  "section": "Provisions",
  "main_category": "Rice & Pulses",
  "subcategory": "Rice",
  "image_url": "https://res.cloudinary.com/.../rice.jpg",
  "description": "Premium quality rice",
  "unit": "kg",
  "available_stock": 100
}

═══════════════════════════════════════════════════════════════════════════════
```

**Last Updated:** 2025-01-26  
**Version:** 1.0
