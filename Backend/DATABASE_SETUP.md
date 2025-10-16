# Real Database Setup - No Mocks, No Demos

## Prerequisites

You need MongoDB running locally. Choose one option:

### Option 1: Docker (Recommended)

1. **Install Docker Desktop**: https://www.docker.com/products/docker-desktop
2. **Start Docker Desktop** application
3. **Run MongoDB container**:
```powershell
docker run -d --name almathina-mongodb -p 27017:27017 mongo:latest
```

### Option 2: MongoDB Community Edition (No Docker)

1. **Download MongoDB**: https://www.mongodb.com/try/download/community
2. **Install** with default settings
3. **Start MongoDB Service**:
```powershell
net start MongoDB
```

## Quick Start (After MongoDB is Running)

### Terminal 1: Verify MongoDB
```powershell
# Check MongoDB is running
docker ps
# OR (if installed locally)
mongosh --eval "db.version()"
```

### Terminal 2: Start Backend
```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
.\venv\Scripts\python.exe .\main_local.py
```

### Access Dashboard
Open: http://127.0.0.1:8000/admin/login
- Username: `admin`
- Password: `admin123`

## What Happens on First Run

1. Backend connects to MongoDB on `localhost:27017`
2. Creates database: `almadhinadb`
3. Creates collections: `categories`, `products`
4. Inserts sample data:
   - 6 categories (Meat, Groceries, Vegetables, Fruits, Dairy, Beverages)
   - 24 products across all categories
5. Admin dashboard loads real data from MongoDB

## All CRUD Operations Work with Real Database

✅ **Add Product** → Saved to MongoDB  
✅ **Edit Product** → Updated in MongoDB  
✅ **Delete Product** → Removed from MongoDB  
✅ **Upload Image** → Saved to `Backend/static/uploads/` + URL in MongoDB  
✅ **Search/Filter** → Queries MongoDB  

## Currently Active

❌ Demo mode (main_demo.py) - Will be removed
✅ Real database mode (main_local.py) - Production ready
