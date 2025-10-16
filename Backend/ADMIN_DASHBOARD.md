# Admin Dashboard Guide

## Overview

The Admin Dashboard is a web-based interface for managing the MongoDB product catalog. It provides a secure, user-friendly interface for CRUD operations on products and categories.

## Access

**URL**: http://127.0.0.1:8000/admin/login

**Default Credentials:**
- **Username**: `admin`
- **Password**: `admin123`

> ⚠️ **Security Note**: These are development credentials. In production, replace with proper authentication (OAuth, JWT, etc.) and secure password storage.

## Features

### 1. Authentication
- Session-based authentication with HTTPOnly cookies
- Automatic session management
- Secure logout functionality

### 2. Product Management
- **View All Products**: Searchable and filterable table with product details
- **Create Product**: Add new products with image upload
- **Edit Product**: Update existing product information and images
- **Delete Product**: Remove products with confirmation dialog

### 3. Image Management
- Upload product images to Supabase Storage
- Automatic image URL generation
- Support for common image formats (JPG, PNG, WebP)
- Image preview in product table

### 4. Search & Filter
- Real-time search by product name
- Filter by category
- View product statistics (total, active, categories, low stock)

### 5. Inventory Tracking
- Monitor stock levels
- Visual indicators for low stock items
- Active/inactive product status

## How to Use

### First-Time Setup

1. **Start Backend Server**:
   ```powershell
   cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
   .\venv\Scripts\Activate.ps1
   uvicorn main:app --reload --host 127.0.0.1 --port 8000
   ```

2. **Ensure Databases are Running**:
   - MongoDB: `docker ps` should show MongoDB on port 27017
   - Supabase: `supabase status` should show running on port 54322

3. **Create Supabase Storage Bucket** (first time only):
   - Go to http://127.0.0.1:54323
   - Navigate to Storage
   - Create bucket named: `product-images`
   - Set as **Public** bucket

### Login

1. Navigate to http://127.0.0.1:8000/admin/login
2. Enter credentials:
   - Username: `admin`
   - Password: `admin123`
3. Click "Login"
4. You'll be redirected to the dashboard

### Add New Product

1. Click **"Add New Product"** button
2. Fill in the form:
   - Product Name (required)
   - Brand (required)
   - Category (select from dropdown)
   - Price (required)
   - Stock (required)
   - Description (optional)
   - Status (Active/Inactive)
3. **Upload Image** (optional):
   - Click "Choose Image" button
   - Select image file (JPG, PNG, WebP)
   - Image will upload automatically after product creation
4. Click **"Save Product"**
5. Success notification will appear

### Edit Product

1. Find product in table
2. Click **"Edit"** button (pencil icon)
3. Update fields in modal
4. **Change Image** (optional):
   - Click "Change Image"
   - Select new image file
   - New image will replace old one
5. Click **"Save Product"**
6. Success notification will appear

### Delete Product

1. Find product in table
2. Click **"Delete"** button (trash icon)
3. Confirm deletion in dialog
4. Product will be removed from MongoDB
5. Success notification will appear

### Search & Filter

**Search by Name:**
- Type in search box at top
- Results update in real-time

**Filter by Category:**
- Select category from dropdown
- Table shows only products in that category
- Select "All Categories" to reset

### Logout

- Click **"Logout"** button in header
- Session will be cleared
- Redirected to login page

## Technical Details

### Architecture

```
┌─────────────────────────────────────────────────┐
│              Admin Dashboard                     │
│         (Jinja2 Templates + JS)                  │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│         FastAPI Backend (routes/admin.py)        │
│     Session-based Auth (admin_auth.py)           │
└─────────────────────────────────────────────────┘
                        ↓
        ┌──────────────────────────┐
        │         MongoDB          │  ← Product Catalog
        │   (categories, products) │
        └──────────────────────────┘
                        +
        ┌──────────────────────────┐
        │    Supabase Storage      │  ← Product Images
        │  (product-images bucket) │
        └──────────────────────────┘
```

### File Structure

```
Backend/
├── routes/
│   └── admin.py              # Admin API endpoints
├── templates/
│   ├── admin_login.html      # Login page
│   └── admin_dashboard.html  # Dashboard UI
├── static/
│   └── admin/
│       ├── css/
│       │   └── dashboard.css # Styling (green theme)
│       └── js/
│           └── dashboard.js  # Frontend logic
└── admin_auth.py             # Authentication system
```

### API Endpoints

**Authentication:**
- `GET /admin/login` - Login page
- `POST /admin/login` - Login submission
- `POST /admin/logout` - Logout

**Dashboard:**
- `GET /admin/dashboard` - Dashboard page (requires auth)

**Products:**
- `GET /admin/api/products/all` - Get all products
- `POST /admin/api/products/add` - Create product
- `PUT /admin/api/products/{id}` - Update product
- `DELETE /admin/api/products/{id}` - Delete product
- `POST /admin/api/upload/image/{id}` - Upload image

**Categories:**
- `GET /admin/api/categories/all` - Get all categories

### Session Management

- Sessions stored in-memory (dict)
- Session IDs are UUID4
- HTTPOnly cookies prevent XSS
- 24-hour session expiration
- Auto-logout on server restart

### Security Considerations

**Current Implementation (Development):**
- ✅ Session-based authentication
- ✅ HTTPOnly cookies
- ✅ CSRF protection via session validation
- ❌ Hardcoded credentials
- ❌ In-memory session storage

**For Production:**
- 🔒 Use environment variables for credentials
- 🔒 Implement proper password hashing (bcrypt)
- 🔒 Use Redis for session storage
- 🔒 Add rate limiting for login attempts
- 🔒 Implement role-based access control (RBAC)
- 🔒 Use HTTPS only
- 🔒 Add CSRF tokens to forms
- 🔒 Implement audit logging

## Troubleshooting

### Cannot Access Login Page

**Symptom**: Browser shows "Connection refused" or 404

**Solution**:
1. Check backend is running: http://127.0.0.1:8000/health
2. Check logs for errors: Look for "Backend Ready" message
3. Verify static files mounted: Check main.py includes `app.mount("/static", ...)`

### Login Fails with "Invalid Credentials"

**Symptom**: Error message after clicking Login

**Solution**:
1. Verify credentials:
   - Username: `admin` (lowercase)
   - Password: `admin123` (no spaces)
2. Check browser console for errors
3. Check backend logs for authentication errors

### Dashboard Loads but No Products

**Symptom**: Dashboard shows empty table

**Solution**:
1. Check MongoDB connection: http://127.0.0.1:8000/health
2. Verify MongoDB data initialized:
   ```powershell
   docker exec -it <mongo-container-id> mongosh
   use almadhinadb
   db.products.countDocuments()
   ```
3. Check browser console for API errors

### Image Upload Fails

**Symptom**: Error when uploading product image

**Solution**:
1. Check Supabase Storage bucket exists:
   - Go to http://127.0.0.1:54323
   - Navigate to Storage
   - Create `product-images` bucket if missing
2. Set bucket to **Public**
3. Check file size (max 5MB)
4. Check file format (JPG, PNG, WebP)
5. Check backend logs for Supabase errors

### CSS/JS Not Loading

**Symptom**: Dashboard has no styling or functionality

**Solution**:
1. Check static files directory exists:
   ```
   Backend/static/admin/css/dashboard.css
   Backend/static/admin/js/dashboard.js
   ```
2. Verify files were created correctly
3. Check browser DevTools Network tab for 404 errors
4. Restart backend server

### Session Expires Immediately

**Symptom**: Redirected to login after successful authentication

**Solution**:
1. Check browser cookies are enabled
2. Check backend logs for session creation
3. Verify time settings (session uses datetime)
4. Check browser is allowing HTTPOnly cookies

## Development Tips

### Testing Admin Features

1. **Test CRUD Flow**:
   - Create product → Edit product → Delete product
   - Verify MongoDB updates correctly

2. **Test Image Upload**:
   - Upload image → Check Supabase Storage
   - Verify public URL is accessible

3. **Test Search/Filter**:
   - Add multiple products
   - Test search with various queries
   - Test category filtering

4. **Test Session Management**:
   - Login → Close browser → Reopen
   - Check session persistence
   - Test logout functionality

### Customization

**Change Colors:**
- Edit `Backend/static/admin/css/dashboard.css`
- Update CSS variables at top of file:
  ```css
  :root {
    --primary-green: #004D40;  /* Dark green */
    --accent-green: #4CAF50;    /* Light green */
    /* ... */
  }
  ```

**Change Credentials:**
- Edit `Backend/admin_auth.py`
- Update `ADMIN_USERNAME` and `ADMIN_PASSWORD`
- Restart backend server

**Add New Fields:**
1. Update MongoDB schema in `database/mongodb_client.py`
2. Add field to form in `templates/admin_dashboard.html`
3. Update JavaScript in `static/admin/js/dashboard.js`
4. Update API in `routes/admin.py`

## Support

For issues or questions:
1. Check backend logs: Look for error messages
2. Check browser console: Look for JavaScript errors
3. Check MongoDB: Verify data structure
4. Check Supabase: Verify storage configuration
5. Review this guide and Backend/README.md

## Future Enhancements

Potential features to add:
- [ ] Multi-user support with roles (Admin, Manager, Viewer)
- [ ] Bulk product import (CSV/Excel)
- [ ] Product analytics dashboard
- [ ] Order management interface
- [ ] Customer management
- [ ] Inventory alerts (low stock notifications)
- [ ] Export product catalog (PDF, Excel)
- [ ] Product variants support
- [ ] Image gallery (multiple images per product)
- [ ] Product categories management (add/edit/delete)
- [ ] Audit logs (track changes)
- [ ] Dark mode toggle
