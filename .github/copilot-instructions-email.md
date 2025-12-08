# Email Notification System - Copilot Instructions

## System Architecture

### Email Flow (Unlimited Free via Vercel Webhook)
```
Order Created → Render Backend (FastAPI)
    ↓
Background Task (non-blocking)
    ↓
Fetch Order from MongoDB (order_id)
    ↓
Call Vercel Webhook (HTTP POST)
    ↓
Vercel Function (Node.js serverless)
    ↓
Gmail SMTP (nodemailer)
    ↓
Admin Email Delivered
```

## Critical Data Sources

### MongoDB Collections
1. **orders** - Complete order documents
   - Fields: `order_id`, `user_phone`, `items[]`, `total_amount`, `delivery_address`, `payment_method`, `section`, `status`
   - Items structure: `{productName, weight, quantity, price, section, mainCategory, subcategory}`

2. **users** - Customer profiles
   - Fields: `phone` (unique), `name` (STORE NAME), `email`, `addresses[]`
   - **IMPORTANT**: `name` field stores the store/business name, NOT personal name

3. **products** - Product catalog
   - Fields: `productName`, `price`, `weight`, `section`, `mainCategory`, `subcategory`, `imageUrl`

### Supabase Tables
1. **user_devices** - FCM tokens for push notifications
   - Fields: `phone`, `fcm_token`, `device_id`
   - Used ONLY for FCM, NOT for email

2. **users** - Legacy, NOT USED for store names
   - Do NOT query Supabase for store names
   - Store names are in MongoDB `users.name`

## Email Service Configuration

### Environment Variables (Render)
```bash
EMAIL_WEBHOOK_URL=al-mathina-email.vercel.app  # Just domain, no https://
EMAIL_WEBHOOK_SECRET=<32-char-secret>  # Must match Vercel API_SECRET
ADMIN_EMAIL=email1@gmail.com,email2@gmail.com  # Comma-separated
```

### Vercel Environment Variables
```bash
API_SECRET=<32-char-secret>  # Must match Render EMAIL_WEBHOOK_SECRET
SMTP_USER=almathina64@gmail.com
SMTP_PASSWORD=<gmail-app-password>  # 16-char app password
```

## Code Patterns & Best Practices

### ✅ Correct: Fetch Order Data from MongoDB
```python
# Background email task - ALWAYS fetch from MongoDB
async def send_order_email_background(order_id: str):
    db = get_mongo_db()
    
    # Get complete order
    order = db['orders'].find_one({"order_id": order_id})
    
    # Get store name from MongoDB users (NOT Supabase)
    user = db['users'].find_one({"phone": order['user_phone']})
    store_name = user.get("name") if user else None
    
    # Items already have productName, weight, price, quantity
    items = order.get('items', [])
```

### ❌ Wrong: Passing data from request
```python
# DON'T do this - data might be incomplete or wrong format
background_tasks.add_task(
    send_email,
    items=items,  # Request items may have wrong field names
    store_name=store_name  # Might be None if not fetched
)
```

### ✅ Correct: Item Field Mapping
```python
# MongoDB items have these fields:
item_name = item.get('productName')  # Primary field
weight = item.get('weight')           # Product size/weight
quantity = item.get('quantity')       # Order quantity
price = item.get('price')             # Unit price

# Display format: "Rice (25kg)"
display_name = f"{item_name} ({weight})" if weight else item_name
```

### ❌ Wrong: Using 'name' field
```python
# DON'T - 'name' field doesn't exist in order items
item_name = item.get('name', 'Unknown')  # Will always be Unknown
```

## Email Template Structure

### Required Sections
1. **Customer Information**
   - Store Name (from MongoDB users.name)
   - Phone
   - Payment Method

2. **Delivery Address**
   - street, city, state, pincode, landmark
   - Each on separate line with `<br>`

3. **Order Items Table**
   - Columns: #, Item (name + weight), Qty, Price, Total
   - Table must be responsive (word-wrap, not horizontal scroll)
   - Column widths: 8%, 40%, 12%, 20%, 20%

4. **Admin Panel Link**
   - Format: `https://al-mathina.onrender.com/admin/orders?search={order_id}`
   - URL parameter triggers auto-search in admin dashboard

### Mobile Optimization
```css
/* Full-width on mobile */
.container { max-width: 600px; padding: 10px; }
@media screen and (max-width: 640px) {
    .container { max-width: 100%; padding: 5px; }
}

/* Text wrapping instead of scroll */
.table { table-layout: fixed; }
.table td { word-wrap: break-word; }
```

## Debugging & Logging

### Render Logs
```python
# ALWAYS force stdout flush for Render visibility
import sys
sys.stdout.flush()
sys.stderr.flush()

print("🚀 ORDER ENDPOINT HIT", flush=True)
logger.info("📧 EMAIL: Sending notification")
```

### Log Levels
- 🚀 = Endpoint hit / Major milestone
- 📧 = Email operation
- ✅ = Success
- ❌ = Error
- ⚠️ = Warning
- 🔍 = Debug/Search
- 📤 = Sending data
- 📥 = Receiving data

## Common Issues & Solutions

### Issue: Email shows "Unknown" for item names
**Cause**: Using `item.get('name')` instead of `item.get('productName')`
**Fix**: Always use `productName` field from MongoDB order items

### Issue: Store name shows "Not provided"
**Cause**: Querying Supabase instead of MongoDB for store name
**Fix**: Query MongoDB `users` collection, use `name` field

### Issue: Email not sent (no logs in Render)
**Cause**: stdout/stderr not flushed
**Fix**: Add `flush=True` to all print statements, use `logging.basicConfig(force=True)`

### Issue: Admin panel link doesn't search order
**Cause**: Wrong URL format or admin JS not reading URL params
**Fix**: 
- URL: `/admin/orders?search={order_id}` (NOT `order_id=`)
- JS: `URLSearchParams` reads `search` param and fills search input

### Issue: Webhook returns 401 Unauthorized
**Cause**: Vercel `API_SECRET` ≠ Render `EMAIL_WEBHOOK_SECRET`
**Fix**: Ensure both have EXACT same value, redeploy both services

## Performance Optimization Rules

### Database Query Optimization
1. **Use aggregation pipelines** instead of multiple queries
2. **Fetch related data in single query** using `$lookup` (MongoDB joins)
3. **Project only needed fields** to reduce data transfer
4. **Use indexes** on frequently queried fields (order_id, user_phone)

### Email Processing
1. **Background tasks** - Never block order API response
2. **Batch operations** - Fetch user + order in single DB connection
3. **Connection pooling** - Reuse MongoDB connections
4. **Timeout limits** - 30s for webhook, 10s for Vercel function

## File Locations

### Backend Email Service
- `Backend/utils/email_service.py` - Email service singleton
- `Backend/routes/user_profile.py` - Order API + background task
- `Backend/main_production.py` - Production entry point

### Vercel Webhook
- `email-webhook/api/send-email.js` - Serverless function
- `email-webhook/package.json` - nodemailer dependency
- `email-webhook/vercel.json` - Function timeout config

### Admin Dashboard
- `Backend/static/admin/js/orders.js` - Order management UI
- Line 1384: `filterOrders()` - Reads URL params for auto-search
- Line 108: `loadOrders()` - Initializes with URL search parameter

## Testing Checklist

### Email Functionality
- [ ] Order created successfully (HTTP 200)
- [ ] FCM notification sent (push received on phone)
- [ ] Email sent to admin (check inbox/spam)
- [ ] Email shows correct store name (from MongoDB)
- [ ] Email shows correct item names with weights
- [ ] Admin panel link opens and searches order
- [ ] Table displays properly on mobile (no horizontal scroll)

### Render Logs Visibility
- [ ] "🚀🚀🚀 ORDER ENDPOINT HIT" visible in logs
- [ ] "📧 BACKGROUND: Order data loaded from MongoDB" visible
- [ ] "✅ EMAIL: Emails sent successfully via webhook!" visible

### Vercel Webhook
- [ ] Test with curl: `200 OK` response
- [ ] Vercel logs show "✅ Email sent successfully"
- [ ] Email arrives within 5 seconds

## Deployment Notes

### Render Auto-Deploy
- Push to `main` branch triggers deployment
- Wait ~2-3 minutes for deployment completion
- Check logs for "Build succeeded" and "Service live"

### Vercel Auto-Deploy
- Push to `main` branch triggers deployment
- Wait ~30-60 seconds for deployment
- Check Deployments tab for "Ready" status

### Environment Variable Updates
- Render: Changes trigger auto-redeploy
- Vercel: Changes require manual redeploy from Deployments tab

## Quick Reference Commands

### Test Vercel Webhook
```powershell
$h = @{'Content-Type'='application/json'; 'x-api-key'='<SECRET>'}
$b = '{"to":["email@gmail.com"],"subject":"Test","html":"<h1>Test</h1>"}'
Invoke-RestMethod -Uri 'https://al-mathina-email.vercel.app/api/send-email' -Method POST -Headers $h -Body $b
```

### Check MongoDB Order
```python
db = get_mongo_db()
order = db['orders'].find_one({"order_id": "ORD-12345678"})
print(order['items'])  # Shows productName, weight, etc.
```

### Check User Store Name
```python
user = db['users'].find_one({"phone": "+918870986738"})
print(user.get('name'))  # Store name
```

## Never Do This

❌ Query Supabase for store names
❌ Use `item.get('name')` for product names
❌ Pass incomplete data to background tasks
❌ Use horizontal scroll for email tables
❌ Forget `flush=True` in print statements
❌ Use different secrets on Vercel and Render
❌ Block order API with email sending
❌ Loop through collections instead of using aggregation
❌ Fetch data multiple times instead of joining

## Always Do This

✅ Fetch complete order from MongoDB by order_id
✅ Get store name from MongoDB users.name
✅ Use `productName` field for item names
✅ Use background tasks for email sending
✅ Force stdout flush for Render logs
✅ Use aggregation pipelines for complex queries
✅ Test locally before deploying
✅ Check both Render and Vercel logs
✅ Update ALL three requirements files when adding dependencies
