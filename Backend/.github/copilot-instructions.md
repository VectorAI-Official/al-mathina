# Backend Copilot Instructions - AL-Madhina

## Project Overview
FastAPI backend for AL-Madhina wholesale management system. Acts as gateway to MongoDB (catalog) and Supabase (transactions/FCM tokens).

## Technology Stack
- **Framework**: FastAPI (Python 3.11+)
- **Databases**: MongoDB Atlas (products/orders/users), Supabase (FCM tokens)
- **Email**: Vercel serverless webhook → Gmail SMTP (unlimited free)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Image Storage**: Cloudinary CDN
- **Deployment**: Render.com (Docker)

## Critical File Structure

```
Backend/
├── main_production.py          # Production entrypoint (Render)
├── main.py / main_local.py     # Local development
├── routes/
│   ├── user_profile.py         # Order creation, user management (MOST IMPORTANT)
│   ├── flutter.py              # Flutter-optimized API (home, products, subcategories)
│   ├── admin_orders.py         # Admin order management
│   ├── fcm.py                  # FCM token save/retrieve
│   └── inventory.py            # Product inventory
├── utils/
│   ├── email_service.py        # Email notification via Vercel webhook
│   └── fcm_service.py          # Firebase push notifications
├── database/
│   └── mongodb.py              # MongoDB connection helper
└── static/admin/               # Admin dashboard HTML/CSS/JS
```

## Database Architecture

### MongoDB Collections

#### 1. **users** - Customer Profiles
```json
{
  "phone": "+918870986738",           // Unique identifier
  "name": "faizal",                   // Personal name (NOT store name!)
  "email": "user@example.com",
  "store_details": {                  // ⚠️ CRITICAL: Store business info
    "store_name": "Faizal Store",     // 🏪 USE THIS for orders/emails
    "street": "123 Main St",
    "city": "Chennai",
    "state": "Tamil Nadu",
    "pincode": "600001",
    "landmark": "Near Temple"
  },
  "addresses": [],
  "created_at": "2024-12-09T...",
  "updated_at": "2024-12-09T..."
}
```

**⚠️ CRITICAL RULE**: 
- `name` = Personal name → DON'T use for orders
- `store_details.store_name` = Business name → ALWAYS use for orders/emails

#### 2. **orders** - Order Documents
```json
{
  "order_id": "ORD-58DEB76C",
  "user_phone": "+918870986738",
  "section": "மளிகை பொருள்",          // Tamil section name
  "items": [
    {
      "product_name": "அரிசி",         // Flutter sends snake_case
      "weight": "25kg",
      "quantity": 2,
      "price": 1200.0,
      "section": "மளிகை பொருள்",
      "main_category": "Rice",
      "subcategory": "Basmati"
    }
  ],
  "total_amount": 2400.0,
  "status": "pending",
  "payment_method": "cod",
  "delivery_address": {
    "street": "123 Main St",
    "city": "Chennai",
    "state": "Tamil Nadu",
    "pincode": "600001"
  },
  "created_at": "2024-12-09T...",
  "estimated_delivery": "2024-12-12T..."
}
```

**⚠️ Item Field Names**:
- Flutter sends: `product_name` (snake_case)
- Legacy code might have: `productName` (camelCase)
- Always support both with fallback chain

#### 3. **products** - Product Catalog
```json
{
  "item_id": "uuid-string",
  "productName": "அரிசி",
  "weight": "25kg",
  "price": 1200.0,
  "section": "மளிகை பொருள்",
  "mainCategory": "Rice",
  "subcategory": "Basmati",
  "imageUrl": "https://res.cloudinary.com/...",
  "active": true
}
```

### Supabase Tables

#### **user_devices** - FCM Tokens (ONLY)
```sql
CREATE TABLE user_devices (
  phone TEXT PRIMARY KEY,
  fcm_token TEXT,
  device_id TEXT,
  updated_at TIMESTAMP
);
```

**⚠️ RULE**: Supabase is ONLY for FCM tokens, NOT for user data

## Critical API Endpoints

### Order Creation (MOST IMPORTANT)
**File**: `routes/user_profile.py`
**Endpoint**: `POST /api/flutter/user/orders`

**Flow**:
1. Receive order from Flutter
2. Split items by section → Create multiple orders
3. Save to MongoDB
4. Get store name from `store_details.store_name`
5. Send FCM notification (immediate)
6. Return HTTP 200 to user
7. Send email in background task (non-blocking)

**Critical Code Pattern**:
```python
# Get store name (CORRECT WAY)
user = db['users'].find_one({"phone": user_phone})
store_name = user.get("store_details", {}).get("store_name") if user else None

# ❌ WRONG:
store_name = user.get("name")  # This is personal name!
```

### Email Background Task
**File**: `routes/user_profile.py` → `send_order_email_background()`

**Optimized Pattern** (Single query with JOIN):
```python
pipeline = [
    {"$match": {"order_id": order_id}},
    {"$lookup": {
        "from": "users",
        "localField": "user_phone",
        "foreignField": "phone",
        "as": "user_data"
    }},
    {"$project": {
        "order_id": 1,
        "items": 1,
        "total_amount": 1,
        "delivery_address": 1,
        "payment_method": 1,
        # Extract store name from subdocument
        "store_name": {"$arrayElemAt": ["$user_data.store_details.store_name", 0]}
    }}
]
order = list(orders_collection.aggregate(pipeline))[0]
```

## Performance Rules (CRITICAL)

### ❌ NEVER Do This (N+1 Problem)
```python
orders = orders_collection.find()
for order in orders:
    user = users_collection.find_one({"phone": order['user_phone']})  # BAD!
```

### ✅ ALWAYS Do This (Aggregation Pipeline)
```python
pipeline = [
    {"$match": {"status": "pending"}},
    {"$lookup": {
        "from": "users",
        "localField": "user_phone",
        "foreignField": "phone",
        "as": "user"
    }}
]
orders = list(orders_collection.aggregate(pipeline))
```

### ✅ Or Batch Queries
```python
orders = list(orders_collection.find())
phones = {order['user_phone'] for order in orders}
users = users_collection.find({"phone": {"$in": list(phones)}})
user_lookup = {user['phone']: user for user in users}
```

**See**: `.github/copilot-instructions-performance.md` for complete guide

## Email Notification System

**Architecture**: Render → Vercel Webhook → Gmail SMTP (unlimited free)

**Vercel Webhook**: `https://al-mathina-email.vercel.app/api/send-email`

**Critical Code Pattern**:
```python
# Item name field compatibility
item_name = (
    item.get('product_name') or    # Primary: Flutter format
    item.get('productName') or      # Fallback: legacy
    item.get('name') or             # Old format
    'Unknown'
)
```

**See**: `.github/copilot-instructions-email.md` for complete guide

## Tamil Font Support

**Email CSS**:
```css
font-family: Arial, 'Noto Sans Tamil', 'Lohit Tamil', sans-serif;
```

**HTML Meta**:
```html
<meta charset="UTF-8">
```

## Deployment

### Requirements Files (ALL THREE MUST BE SYNCED!)
1. `requirements.txt` - Full dev dependencies (~500 packages)
2. `requirements.production.txt` - Production runtime (~30 packages)
3. `requirements-docker.txt` - Docker build (~25 packages)

**When adding a package**:
- Add to `requirements.txt` for local dev
- If needed in production, add to BOTH `requirements.production.txt` AND `requirements-docker.txt`

### Render Deployment
- Auto-deploy on `git push origin main`
- Dockerfile-based
- Uses `main_production.py` as entrypoint
- URL: `https://al-mathina.onrender.com`

### Environment Variables (Render)
```bash
MONGODB_URI=mongodb+srv://...
SUPABASE_URL=https://...
SUPABASE_SERVICE_KEY=...
EMAIL_WEBHOOK_URL=al-mathina-email.vercel.app
EMAIL_WEBHOOK_SECRET=<32-char>
ADMIN_EMAIL=faizalbashafaizalbasha07@gmail.com
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
```

## Local Development

### Start Backend
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000
```

### Test Endpoints
- Interactive docs: `http://127.0.0.1:8000/docs`
- Admin dashboard: `http://127.0.0.1:8000/admin/`

## Common Anti-Patterns to Avoid

### ❌ Using Personal Name for Store
```python
store_name = user.get('name')  # WRONG: This is personal name!
```

### ✅ Correct: Use Store Details
```python
store_name = user.get('store_details', {}).get('store_name')
```

### ❌ Wrong Item Field
```python
item_name = item.get('productName')  # Flutter sends product_name!
```

### ✅ Correct: Support All Formats
```python
item_name = item.get('product_name') or item.get('productName') or 'Unknown'
```

### ❌ Querying in Loops
```python
for order in orders:
    user = db.users.find_one({"phone": order['user_phone']})  # N+1!
```

### ✅ Correct: Aggregation or Batch
```python
# Use $lookup or batch with $in
```

## Logging Best Practices

### For Render Visibility
```python
import sys
sys.stdout.flush()
sys.stderr.flush()

print("🚀 ORDER ENDPOINT HIT", flush=True)
logger.info("📧 EMAIL: Sending notification")
```

### Log Prefixes
- 🚀 = Endpoint hit
- 📧 = Email operation  
- 🔔 = FCM notification
- ✅ = Success
- ❌ = Error
- ⚠️ = Warning
- 🔍 = Debug

## Testing

### Check Order Structure
```bash
python Backend/check_order_structure.py
```

### Test Email Webhook
```powershell
$h = @{'Content-Type'='application/json'; 'x-api-key'='<secret>'}
$b = '{"to":["admin@gmail.com"],"subject":"Test","html":"<h1>Test</h1>"}'
Invoke-RestMethod -Uri 'https://al-mathina-email.vercel.app/api/send-email' -Method POST -Headers $h -Body $b
```

## Quick Reference

**Get store name**: `user.get('store_details', {}).get('store_name')`  
**Item name**: `item.get('product_name') or item.get('productName')`  
**Aggregation**: Use `$lookup` for JOINs, never loop  
**Email**: Background task, non-blocking  
**FCM**: Immediate, before HTTP response  
**Logs**: Always `flush=True` for Render visibility

## Related Guides
- Performance optimization: `.github/copilot-instructions-performance.md`
- Email system: `.github/copilot-instructions-email.md`
- Main project guide: `.github/copilot-instructions.md`
