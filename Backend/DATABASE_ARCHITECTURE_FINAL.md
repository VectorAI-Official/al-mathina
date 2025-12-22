# Database Architecture - CORRECTED (Dec 22, 2025)

## ✅ Actual Database Architecture (After Code Investigation)

### Summary

The Al-Mathina backend uses **TWO databases** with a specific division of responsibilities:

1. **Supabase (PostgreSQL/SQL)** - Lightweight authentication ONLY
2. **MongoDB (NoSQL)** - ALL application data

---

## 📊 Complete Database Breakdown

### 🔵 Supabase (PostgreSQL/SQL)

**Purpose**: Minimal authentication and admin flags

**Single Table**: `users`

| Column | Type | Purpose |
|--------|------|---------|
| id | UUID | Primary key |
| phone | TEXT | User's phone number (unique) |
| fcm_token | TEXT | Firebase Cloud Messaging token |
| is_admin | BOOLEAN | Admin flag for buying price feature |

**That's it!** Supabase stores ONLY:
- Admin status (`is_admin`)
- FCM push notification tokens (`fcm_token`)
- Phone number for linking to MongoDB user

**NOT stored in Supabase**:
- ❌ User names, emails, addresses (in MongoDB!)
- ❌ Orders (in MongoDB!)
- ❌ Products (in MongoDB!)
- ❌ Store details (in MongoDB!)

---

### 🟢 MongoDB (NoSQL)

**Purpose**: ALL application data

**Collections**:

#### 1. `users` Collection (Full User Profiles)
```javascript
{
  phone: "7339651541",
  name: "John Doe",
  email: "john@example.com",
  store_details: {
    store_name: "John's Store",
    street: "123 Main St",
    city: "Chennai",
    state: "Tamil Nadu",
    pincode: "600001"
  },
  addresses: [
    {
      street: "...",
      city: "...",
      is_default: true
    }
  ],
  created_at: ISODate("..."),
  updated_at: ISODate("...")
}
```

#### 2. `orders` Collection (ALL Orders)
```javascript
{
  order_id: "ORD-20251222-ABC12",
  user_phone: "7339651541",
  items: [
    {
      product_name: "Basmati Rice",
      quantity: 2,
      price: 100.0
    }
  ],
  total_amount: 200.0,
  status: "pending",
  delivery_address: "...",
  payment_method: "cod",
  created_at: ISODate("..."),
  updated_at: ISODate("...")
}
```

#### 3. `products` Collection (Catalog with Buying Prices)
```javascript
{
  item_id: "550e8400-...",
  product_name: "Basmati Rice",
  price: 100.0,
  buying_price: 80.0,  // Admin sees this
  category_section: "Provisions",
  category_main: "Rice & Pulses",
  category_sub: "Rice",
  image_url: "...",
  stock: 100,
  active: true
}
```

#### 4. Other Collections
- `category_metadata` - Category images
- `category_hierarchy` - Category structure
- `most_bought` - Starred categories

---

## 🔄 Why Two Databases?

### Supabase Advantages:
- ✅ Fast authentication queries
- ✅ Built-in Row Level Security (RLS)
- ✅ Real-time subscriptions for FCM tokens
- ✅ Easy admin flag management

### MongoDB Advantages:
- ✅ Flexible schema for user profiles
- ✅ Embedded documents (addresses, store_details)
- ✅ Fast aggregation for orders and analytics
- ✅ No schema migrations for product fields
- ✅ Efficient for large catalogs

---

## 🔧 Admin System Implementation (Corrected)

### Step 1: Check Admin Status (Supabase)
```python
# File: routes/flutter.py
from database.supabase_client import get_supabase_client

supabase = get_supabase_client()
user_response = supabase.table('users').select('is_admin').eq('phone', user_phone).execute()
is_admin = user_response.data[0].get('is_admin', False)
```

### Step 2: Fetch Products (MongoDB)
```python
from database.mongodb_client import get_mongo_db

db = get_mongo_db()
products_collection = db["products"]
products = products_collection.find({category_sub: "Rice"})
```

### Step 3: Conditionally Add Buying Price
```python
for product in products:
    product_data = {
        "product_name": product["product_name"],
        "price": float(product["price"]),
        # ... other fields
    }
    
    # Add buying_price ONLY if admin
    if is_admin:
        product_data["buying_price"] = float(product.get("buying_price", 0.0))
    
    response_products.append(product_data)
```

---

## 📍 Where Data Actually Lives

| Data Type | Location | Database | Collection/Table |
|-----------|----------|----------|------------------|
| Admin flag | Supabase | users | is_admin column |
| FCM tokens | Supabase | users | fcm_token column |
| User profiles | **MongoDB** | users | Full document |
| User addresses | **MongoDB** | users | addresses array |
| Store details | **MongoDB** | users | store_details object |
| Orders | **MongoDB** | orders | Full document |
| Products | **MongoDB** | products | Full document |
| Buying prices | **MongoDB** | products | buying_price field |
| Categories | **MongoDB** | category_* | Multiple collections |

---

## 🚨 Common Misconceptions (CORRECTED)

### ❌ WRONG Assumption:
"Supabase stores all user data and orders (relational SQL)"

### ✅ CORRECT Reality:
"Supabase ONLY stores admin flags and FCM tokens for authentication"

### ❌ WRONG Assumption:
"MongoDB only has product catalog data"

### ✅ CORRECT Reality:
"MongoDB has EVERYTHING - users, orders, products, categories"

---

## 🧪 Verification Queries

### Check Admin Status (Supabase)
```sql
-- In Supabase SQL Editor
SELECT phone, is_admin, fcm_token FROM users WHERE phone = '7339651541';

-- Result should be:
-- phone: 7339651541
-- is_admin: true
-- fcm_token: <FCM token string>
-- That's ALL the columns in Supabase!
```

### Check User Profile (MongoDB)
```javascript
// In MongoDB Atlas or local mongo shell
use almadhinadb;
db.users.findOne({phone: "7339651541"});

// Result has:
// - phone, name, email
// - store_details object
// - addresses array
// - created_at, updated_at
```

### Check Orders (MongoDB)
```javascript
db.orders.find({user_phone: "7339651541"}).limit(5);

// Results show ALL orders for this user
```

---

## 📝 Migration Implications

### Supabase Migration (Simple)
```sql
-- Only need to add is_admin column
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Mark admins
UPDATE users SET is_admin = true WHERE phone IN ('7339651541', '8870503350', '9487715568');
```

### MongoDB Migration (NOT Needed)
- `users` collection already exists ✅
- `orders` collection already exists ✅
- `products.buying_price` already exists ✅
- No migration required for MongoDB!

---

## 🎯 Summary

**Supabase**: Tiny auth table (3 columns: phone, is_admin, fcm_token)  
**MongoDB**: Everything else (users, orders, products, categories)

**Admin System**:
1. Query Supabase: "Is this user an admin?"
2. Query MongoDB: "Get products"
3. If admin: Include buying_price from MongoDB
4. Return response

**Orders**: 100% in MongoDB `orders` collection  
**User Profiles**: 100% in MongoDB `users` collection  
**Buying Prices**: 100% in MongoDB `products` collection

---

**Verified**: December 22, 2025  
**Evidence**: Codebase investigation of `routes/flutter.py`, `routes/admin_stores.py`, `routes/user_profile.py`
