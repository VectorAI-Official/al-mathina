# AL-Madhina Wholesale Backend

FastAPI backend service for the AL-Madhina wholesale ordering system. Acts as the exclusive gateway between the Flutter frontend and the hybrid database architecture (Supabase + MongoDB).

## 🏗️ Architecture Overview

```
┌─────────────────┐
│  Flutter App    │  ← Frontend (Windows/Android)
│  http://client  │
└────────┬────────┘
         │
         │ HTTP REST API
         ↓
┌─────────────────┐
│   FastAPI       │  ← Backend Gateway
│   Port 8000     │
└────┬────────┬───┘
     │        │
     ↓        ↓
┌─────────┐  ┌──────────┐
│Supabase │  │ MongoDB  │  ← Databases
│  54321  │  │  27017   │
└─────────┘  └──────────┘
```

### Component Responsibilities

| Component | Technology | Port | Purpose |
|-----------|-----------|------|---------|
| **Frontend** | Flutter | - | User interface for ordering |
| **Backend API** | FastAPI | 8000 | Application logic & database gateway |
| **Transactional DB** | Supabase (PostgreSQL) | 54321/54322 | Orders, cart, user auth |
| **Catalog DB** | MongoDB | 27017 | Products, categories, inventory |

## 📋 Prerequisites

Before starting, ensure you have:

- **Python 3.9+** installed
- **Docker Desktop** (for Supabase and MongoDB)
- **Supabase CLI** installed
- **Git** (for version control)

### Install Required Tools

#### 1. Install Python
```powershell
# Check if Python is installed
python --version

# Download from python.org if needed
```

#### 2. Install Docker Desktop
Download and install from: https://www.docker.com/products/docker-desktop

#### 3. Install Supabase CLI
```powershell
# Using Scoop (recommended for Windows)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Or using npm
npm install -g supabase
```

## 🚀 Quick Start Guide

### Step 1: Set Up the Backend Environment

```powershell
# Navigate to the backend directory
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Create a Python virtual environment
python -m venv venv

# Activate the virtual environment
.\venv\Scripts\Activate.ps1

# Install Python dependencies
pip install -r requirements.txt
```

### Step 2: Configure Environment Variables

```powershell
# Copy the example environment file
cp .env.example .env

# Edit .env with your preferred editor
notepad .env
```

**Important**: The `.env.example` file contains all necessary defaults for local development. You typically don't need to change anything except the JWT secret.

### Step 3: Start Supabase Local Stack

```powershell
# Initialize Supabase (first time only)
supabase init

# Start the Supabase local development stack
supabase start
```

**Expected Output:**
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
```

**Important URLs:**
- **Supabase Studio**: http://127.0.0.1:54323 (Web UI for database management)
- **PostgreSQL**: postgresql://postgres:postgres@localhost:54322/postgres
- **API**: http://127.0.0.1:54321

### Step 4: Start MongoDB Local Instance

```powershell
# Start MongoDB using Docker
docker run --name mongo-local -p 27017:27017 -d mongo:latest

# Verify MongoDB is running
docker ps
```

**MongoDB Connection String**: `mongodb://localhost:27017`

### Step 5: Start the FastAPI Backend

```powershell
# Make sure you're in the Backend directory with venv activated
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend

# Start the FastAPI server
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Expected Output:**
```
🚀 AL-Madhina Wholesale Backend Starting Up
📊 Testing Database Connections...
✓ Supabase PostgreSQL connection successful
✓ MongoDB connection test successful
✅ All database connections successful!
✅ Backend Ready - Listening on http://127.0.0.1:8000
📖 API Docs: http://127.0.0.1:8000/docs
```

### Step 6: Verify Everything is Running

Open your browser and visit:

1. **API Docs**: http://127.0.0.1:8000/docs (Interactive API documentation)
2. **Health Check**: http://127.0.0.1:8000/health (Database status)
3. **Supabase Studio**: http://127.0.0.1:54323 (Database UI)

## 📡 API Endpoints

### Inventory & Catalog (MongoDB)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/inventory/sections` | Get all categories |
| GET | `/api/inventory/products` | Get all products (with filters) |
| GET | `/api/inventory/products/{category}/{brand}` | Get specific product |

### Cart Management (Supabase)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/cart/{user_id}` | Get user's cart |
| POST | `/api/cart/add` | Add item to cart |
| PUT | `/api/cart/{cart_item_id}` | Update cart item quantity |
| DELETE | `/api/cart/{user_id}/clear` | Clear cart |

### Order Management (Supabase)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/orders/create` | Create new order |
| GET | `/api/orders/user/{user_id}` | Get user's order history |
| GET | `/api/orders/{order_id}` | Get specific order |

### System

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information |
| GET | `/health` | Health check (database status) |

### Admin Dashboard (Web Interface)

Access the admin dashboard at: **http://127.0.0.1:8000/admin/login**

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

**Admin Features:**
- Product catalog management (CRUD operations)
- Image upload to Supabase Storage
- Search and filter products
- Category management
- Inventory tracking

**Admin API Endpoints:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/login` | Admin login page |
| POST | `/admin/login` | Login authentication |
| POST | `/admin/logout` | Logout admin session |
| GET | `/admin/dashboard` | Admin dashboard (requires auth) |
| GET | `/admin/api/products/all` | Get all products |
| GET | `/admin/api/categories/all` | Get all categories |
| POST | `/admin/api/products/add` | Create new product |
| PUT | `/admin/api/products/{id}` | Update product |
| DELETE | `/admin/api/products/{id}` | Delete product |
| POST | `/admin/api/upload/image/{id}` | Upload product image to Supabase Storage |

## 🔧 Development Workflow

### Daily Startup Sequence

```powershell
# 1. Start Supabase (if not already running)
supabase start

# 2. Start MongoDB (if not already running)
docker start mongo-local

# 3. Activate Python environment
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
.\venv\Scripts\Activate.ps1

# 4. Start FastAPI
uvicorn main:app --reload
```

### Stopping Services

```powershell
# Stop FastAPI: Press Ctrl+C in the terminal

# Stop Supabase
supabase stop

# Stop MongoDB
docker stop mongo-local
```

### Viewing Logs

```powershell
# FastAPI logs: visible in the terminal where uvicorn is running

# Supabase logs
supabase status

# MongoDB logs
docker logs mongo-local
```

## 🗄️ Database Management

### Supabase (PostgreSQL)

**Access Supabase Studio**: http://127.0.0.1:54323

**Direct SQL Access**:
```powershell
# Using psql (if installed)
psql postgresql://postgres:postgres@localhost:54322/postgres

# Or use Supabase Studio's SQL editor
```

**Tables Created**:
- `cart_items`: User shopping carts
- `orders`: Order history

### MongoDB

**Using MongoDB Compass**:
1. Download MongoDB Compass: https://www.mongodb.com/try/download/compass
2. Connect to: `mongodb://localhost:27017`
3. Database: `al_madhina_catalog`

**Collections Created**:
- `categories`: Product categories (Atta, Soap, etc.)
- `products`: Product catalog with pricing and stock

**Using mongo shell**:
```powershell
docker exec -it mongo-local mongosh

use al_madhina_catalog
db.categories.find()
db.products.find()
```

## 🧪 Testing the API

### Using the Interactive Docs (Swagger UI)

1. Visit http://127.0.0.1:8000/docs
2. Click on any endpoint to expand it
3. Click "Try it out"
4. Fill in parameters
5. Click "Execute"

### Using curl (PowerShell)

```powershell
# Get all categories
curl http://127.0.0.1:8000/api/inventory/sections

# Get products for a category
curl "http://127.0.0.1:8000/api/inventory/products?category=Atta"

# Add item to cart
curl -X POST http://127.0.0.1:8000/api/cart/add `
  -H "Content-Type: application/json" `
  -d '{\"user_id\":\"test_user\",\"category\":\"Atta\",\"brand\":\"Aashirvaad\",\"quantity\":2}'

# Get cart
curl http://127.0.0.1:8000/api/cart/test_user

# Health check
curl http://127.0.0.1:8000/health
```

## 🐛 Troubleshooting

### Issue: "Module not found" errors

**Solution**:
```powershell
# Make sure virtual environment is activated
.\venv\Scripts\Activate.ps1

# Reinstall dependencies
pip install -r requirements.txt
```

### Issue: "Connection refused" for Supabase

**Solution**:
```powershell
# Check if Supabase is running
supabase status

# If not running, start it
supabase start

# If issues persist, reset Supabase
supabase stop
supabase start
```

### Issue: "Connection refused" for MongoDB

**Solution**:
```powershell
# Check if MongoDB container is running
docker ps

# Start MongoDB if not running
docker start mongo-local

# If container doesn't exist, create it
docker run --name mongo-local -p 27017:27017 -d mongo:latest
```

### Issue: Port 8000 already in use

**Solution**:
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F

# Or use a different port
uvicorn main:app --reload --port 8001
```

### Issue: Tables not created in Supabase

**Solution**:
The tables are created automatically on first startup. If they're missing:
```powershell
# Restart the FastAPI server - it will recreate tables
uvicorn main:app --reload
```

### Issue: MongoDB collections empty

**Solution**:
Collections are initialized with sample data on first startup. To reinitialize:
```powershell
# Connect to MongoDB
docker exec -it mongo-local mongosh

# Drop the database
use al_madhina_catalog
db.dropDatabase()

# Restart FastAPI - it will recreate and populate collections
```

## 📁 Project Structure

```
Backend/
├── main.py                    # FastAPI application entry point
├── config.py                  # Configuration management
├── models.py                  # Pydantic models for API
├── requirements.txt           # Python dependencies
├── .env.example              # Environment variables template
├── .env                      # Your local environment config (gitignored)
├── database/
│   ├── supabase_client.py    # Supabase/PostgreSQL connection
│   └── mongodb_client.py     # MongoDB connection
└── routes/
    ├── inventory.py          # Catalog endpoints
    ├── cart.py              # Cart management endpoints
    └── orders.py            # Order management endpoints
```

## 🔐 Security Notes

For **local development**:
- Default credentials are fine (postgres/postgres)
- JWT secret can be any string
- CORS is wide open (`*`)

For **production**:
- Use strong, unique credentials
- Generate secure JWT secret: `openssl rand -hex 32`
- Restrict CORS to your frontend domain
- Use environment-specific `.env` files
- Enable HTTPS
- Implement rate limiting

## 📚 Additional Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Supabase Documentation**: https://supabase.com/docs
- **MongoDB Documentation**: https://docs.mongodb.com/
- **Flutter HTTP Package**: https://pub.dev/packages/http

## 🤝 Next Steps

1. ✅ Backend is running
2. 📱 Update Flutter app to use the API (see Flutter integration guide)
3. 🧪 Test the complete flow: Browse → Add to Cart → Place Order
4. 🚀 Deploy to production when ready

## 💡 Tips

- Keep the FastAPI server running with `--reload` for automatic restarts during development
- Use the Swagger UI at `/docs` to test endpoints interactively
- Check `/health` endpoint regularly to ensure database connections are stable
- Monitor the terminal logs for debugging information

---

**Need Help?** Check the troubleshooting section or review the FastAPI logs for detailed error messages.
