# Backend Performance Optimization - Copilot Instructions

## Core Principle: Database Efficiency

**RULE 1**: NEVER loop over results to make additional database queries
**RULE 2**: Use aggregation pipelines ($lookup) for JOINs instead of separate queries
**RULE 3**: Batch queries with $in operator to fetch multiple records at once
**RULE 4**: Project only needed fields to reduce network transfer
**RULE 5**: Create indexes on frequently queried fields

---

## MongoDB Query Optimization Patterns

### ❌ BAD: Multiple Queries in Loop (N+1 Problem)
```python
# DON'T DO THIS - Makes N database queries
orders = orders_collection.find()
for order in orders:
    # SLOW: One DB query per order
    user = users_collection.find_one({"phone": order['user_phone']})
    order['store_name'] = user.get('name')
```

**Problems:**
- If you have 100 orders, you make 100 separate database calls
- Each query has network latency (10-50ms)
- Total time: 100 orders × 30ms = 3+ seconds!
- Database connection overhead for each query

---

### ✅ GOOD: Aggregation Pipeline with $lookup (JOIN)
```python
# DO THIS - Single optimized query with JOIN
pipeline = [
    {"$match": {"order_id": order_id}},
    
    # JOIN with users collection (like SQL JOIN)
    {"$lookup": {
        "from": "users",              # Collection to join
        "localField": "user_phone",   # Field in orders
        "foreignField": "phone",      # Field in users
        "as": "user_data"             # Output array name
    }},
    
    # Extract only what we need
    {"$project": {
        "order_id": 1,
        "user_phone": 1,
        "items": 1,
        "total_amount": 1,
        "delivery_address": 1,
        "payment_method": 1,
        "store_name": {"$arrayElemAt": ["$user_data.name", 0]}  # Get first element
    }}
]

result = orders_collection.aggregate(pipeline)
```

**Benefits:**
- Single database call (no network latency multiplication)
- MongoDB joins data internally (optimized native code)
- Returns only needed fields (less data transfer)
- Total time: ~50ms (60x faster than loop!)

---

### ✅ GOOD: Batch Query with $in (Multiple Records)
```python
# DO THIS - Batch fetch all users at once
orders = list(orders_collection.find())

# Collect all unique phone numbers
user_phones = {order['user_phone'] for order in orders}

# Single query to fetch ALL users
users = users_collection.find({"phone": {"$in": list(user_phones)}})

# Build lookup dictionary
user_lookup = {user['phone']: user for user in users}

# Enrich orders using in-memory lookup (fast!)
for order in orders:
    user = user_lookup.get(order['user_phone'])
    order['store_name'] = user.get('name') if user else None
```

**Benefits:**
- Only 2 database queries total (orders + all users)
- No N+1 problem
- Dictionary lookup in memory is instant (O(1))
- 100 orders: ~80ms total (40x faster than loop!)

---

## Real-World Examples from AL-Madhina

### Optimized: Email Background Task
**File:** `Backend/routes/user_profile.py` - `send_order_email_background()`

```python
# ✅ OPTIMIZED: Single query with JOIN
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
        "store_name": {"$arrayElemAt": ["$user_data.name", 0]}
    }}
]
result = list(orders_collection.aggregate(pipeline))[0]
store_name = result['store_name']  # Already joined!
```

**Performance:**
- Before: 2 queries (order + user) = ~60ms
- After: 1 aggregation = ~30ms
- Improvement: 2x faster

---

### Optimized: Admin Orders List
**File:** `Backend/routes/admin_orders.py` - `get_all_orders()`

```python
# ✅ OPTIMIZED: Batch queries for all users and products
orders = list(orders_collection.find())

# Collect unique identifiers
user_phones = {order['user_phone'] for order in orders}
product_ids = {item['item_id'] for order in orders for item in order['items']}

# Batch fetch (2 queries for hundreds of records)
users = users_collection.find({"phone": {"$in": list(user_phones)}})
products = products_collection.find({"item_id": {"$in": list(product_ids)}})

# Build lookup dictionaries
user_lookup = {user['phone']: user for user in users}
product_lookup = {p['item_id']: p for p in products}

# Enrich orders (in-memory, instant)
for order in orders:
    order['user_name'] = user_lookup.get(order['user_phone'], {}).get('name')
    for item in order['items']:
        product = product_lookup.get(item['item_id'])
        item['product_details'] = product
```

**Performance:**
- Before: 100 orders × (1 user query + 5 items × 1 product query) = 600 queries = 18 seconds!
- After: 1 orders + 1 users + 1 products = 3 queries = 150ms
- Improvement: **120x faster!**

---

## Aggregation Pipeline Operators Cheat Sheet

### $lookup (JOIN)
```python
{"$lookup": {
    "from": "other_collection",      # Collection to join
    "localField": "my_field",        # Field in current doc
    "foreignField": "their_field",   # Field in other collection
    "as": "output_array"             # Output field name
}}
```

### $match (WHERE)
```python
{"$match": {
    "status": "pending",
    "total_amount": {"$gt": 1000}
}}
```

### $project (SELECT)
```python
{"$project": {
    "order_id": 1,                   # Include field
    "internal_id": 0,                # Exclude field
    "full_name": "$user_data.name",  # Rename/extract
    "item_count": {"$size": "$items"}  # Compute
}}
```

### $unwind (FLATTEN ARRAY)
```python
# Before: {order_id: "123", items: [{...}, {...}]}
{"$unwind": "$items"}
# After: Multiple docs: {order_id: "123", items: {...}}
#                       {order_id: "123", items: {...}}
```

### $group (GROUP BY)
```python
{"$group": {
    "_id": "$section",                    # Group by field
    "total_orders": {"$sum": 1},          # Count
    "total_revenue": {"$sum": "$total"},  # Sum
    "avg_order": {"$avg": "$total"}       # Average
}}
```

### $sort (ORDER BY)
```python
{"$sort": {"created_at": -1}}  # -1 = descending, 1 = ascending
```

### $limit (LIMIT)
```python
{"$limit": 100}  # Return only first 100 results
```

---

## Complete Aggregation Example: Order Analytics

```python
# Get top 10 customers by total spending with order counts
pipeline = [
    # Filter: Only completed orders
    {"$match": {"status": "completed"}},
    
    # Join: Get user details
    {"$lookup": {
        "from": "users",
        "localField": "user_phone",
        "foreignField": "phone",
        "as": "user"
    }},
    
    # Flatten user array
    {"$unwind": "$user"},
    
    # Group: Calculate per-user totals
    {"$group": {
        "_id": "$user_phone",
        "store_name": {"$first": "$user.name"},
        "total_orders": {"$sum": 1},
        "total_spent": {"$sum": "$total_amount"},
        "avg_order": {"$avg": "$total_amount"}
    }},
    
    # Sort: By total spent (descending)
    {"$sort": {"total_spent": -1}},
    
    # Limit: Top 10 only
    {"$limit": 10},
    
    # Project: Format output
    {"$project": {
        "_id": 0,
        "phone": "$_id",
        "store_name": 1,
        "total_orders": 1,
        "total_spent": {"$round": ["$total_spent", 2]},
        "avg_order": {"$round": ["$avg_order", 2]}
    }}
]

top_customers = list(orders_collection.aggregate(pipeline))
```

**What this does:**
1. Filters only completed orders
2. Joins user details (name, etc.)
3. Groups by phone number
4. Calculates order count, total, and average
5. Sorts by spending (highest first)
6. Returns only top 10
7. Formats numbers (2 decimal places)

**Performance:** Single query, ~100ms for 10,000+ orders

---

## When to Use Each Pattern

### Use Aggregation Pipeline When:
- ✅ Need to JOIN data from multiple collections
- ✅ Need to compute statistics (sum, count, average)
- ✅ Need to group and filter in complex ways
- ✅ Result needs complex transformation
- ✅ Fetching single record with related data

**Example Use Cases:**
- Order with user details (JOIN)
- Sales analytics (GROUP + SUM)
- Top products by revenue (GROUP + SORT + LIMIT)
- Customer lifetime value (JOIN + GROUP)

---

### Use Batch Queries ($in) When:
- ✅ Need to fetch many records from same collection
- ✅ Have list of IDs/keys to look up
- ✅ Need to enrich multiple documents
- ✅ Simple filtering, no complex transformations

**Example Use Cases:**
- Fetching all users for order list (IN query)
- Getting product details for cart items
- Loading metadata for multiple categories
- Enriching search results with details

---

### Use Simple find_one() When:
- ✅ Fetching single record by unique ID
- ✅ No related data needed
- ✅ Simple query with no transformations

**Example Use Cases:**
- Get user profile by phone
- Get specific order by order_id
- Check if product exists by item_id

---

## Indexing Strategy

### Critical Indexes for AL-Madhina

```python
# Orders collection
db.orders.create_index([("order_id", 1)], unique=True)
db.orders.create_index([("user_phone", 1)])
db.orders.create_index([("status", 1)])
db.orders.create_index([("created_at", -1)])
db.orders.create_index([("section", 1)])

# Users collection
db.users.create_index([("phone", 1)], unique=True)
db.users.create_index([("email", 1)])

# Products collection
db.products.create_index([("item_id", 1)], unique=True)
db.products.create_index([("section", 1), ("main_category", 1)])
db.products.create_index([("productName", "text")])  # Text search
```

### Index Benefits
- Queries with indexes: O(log N) - milliseconds
- Queries without indexes: O(N) - seconds for large collections
- Example: Finding order by order_id
  - With index: 5ms (even with 1M orders)
  - Without index: 2000ms (scans all documents)

---

## Supabase SQL Optimization

### Use JOINs Instead of Multiple Queries

```python
# ❌ BAD: N+1 queries
devices = supabase.table("user_devices").select("*").execute()
for device in devices.data:
    user = supabase.table("users").select("*").eq("phone", device['phone']).execute()
    device['user_name'] = user.data[0]['name']

# ✅ GOOD: Single JOIN query
result = supabase.table("user_devices") \
    .select("*, users!inner(name, email)") \
    .execute()
# Access: result.data[0]['users']['name']
```

---

## Performance Monitoring

### Add Timing Logs
```python
import time

start = time.time()
orders = orders_collection.find()
query_time = time.time() - start
logger.info(f"⏱️ Query took {query_time*1000:.0f}ms")
```

### Set Query Timeouts
```python
# Fail fast if query takes too long
orders = orders_collection.find().max_time_ms(5000)  # 5 second timeout
```

---

## Quick Wins Checklist

### For Every New Endpoint:
- [ ] No queries inside loops
- [ ] Use aggregation for JOINs
- [ ] Batch fetch with $in for multiple IDs
- [ ] Project only needed fields
- [ ] Add indexes for filter fields
- [ ] Test with realistic data volume (100+ records)
- [ ] Log query timing in development

### Before Deploying:
- [ ] Check all endpoints for N+1 patterns
- [ ] Verify indexes exist on production
- [ ] Test with production data volume
- [ ] Monitor query times in Render logs
- [ ] Set appropriate timeouts

---

## Common Mistakes to Avoid

### ❌ MISTAKE 1: Fetching Full Documents
```python
# BAD: Fetches ALL fields (slow, waste of bandwidth)
users = users_collection.find({"phone": phone})
```

```python
# GOOD: Fetch only what you need
users = users_collection.find(
    {"phone": phone},
    {"name": 1, "email": 1, "_id": 0}  # Only these fields
)
```

---

### ❌ MISTAKE 2: Not Using Indexes
```python
# SLOW: Full collection scan without index
order = orders_collection.find_one({"custom_field": value})
```

```python
# FAST: Create index first
db.orders.create_index([("custom_field", 1)])
order = orders_collection.find_one({"custom_field": value})
```

---

### ❌ MISTAKE 3: Loading All Data into Memory
```python
# BAD: Loads ALL orders (could be millions)
all_orders = list(orders_collection.find())
```

```python
# GOOD: Paginate with skip/limit
page = 0
page_size = 50
orders = list(orders_collection.find()
    .skip(page * page_size)
    .limit(page_size)
)
```

---

## Summary: The Rules

1. **One Query Per Request** - Use aggregation pipelines for JOINs
2. **Batch Everything** - Use $in to fetch multiple records at once
3. **Index All Filters** - Create indexes on frequently queried fields
4. **Project Selectively** - Don't fetch fields you don't need
5. **Monitor Performance** - Log query times, set timeouts
6. **Test at Scale** - Test with realistic data volumes (100+ records)

**Target Performance:**
- Simple queries: <50ms
- Complex aggregations: <200ms
- Admin dashboards: <500ms
- Never exceed 2 seconds for any query

**Follow these rules and your backend will scale to millions of orders! 🚀**
