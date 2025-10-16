"""
Simple Demo Server for Admin Dashboard - No Database Required
This version runs without MongoDB/Supabase for testing the admin dashboard UI.
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request, Form, Cookie
import os
import uuid
from typing import Optional

# Create FastAPI app
app = FastAPI(
    title="AL-Madhina Admin Dashboard Demo",
    description="Demo version for testing admin dashboard without database",
    version="1.0.0-demo"
)

# Mount static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Setup templates
templates_dir = os.path.join(os.path.dirname(__file__), "templates")
templates = Jinja2Templates(directory=templates_dir)

# Simple session storage (in-memory)
active_sessions = {}

# Mock data
mock_categories = [
    {"_id": "1", "name": "اللحوم", "name_en": "Meat", "icon": "🥩"},
    {"_id": "2", "name": "البقالة", "name_en": "Groceries", "icon": "🛒"},
    {"_id": "3", "name": "الخضروات", "name_en": "Vegetables", "icon": "🥬"},
    {"_id": "4", "name": "الفواكه", "name_en": "Fruits", "icon": "🍎"},
    {"_id": "5", "name": "الألبان", "name_en": "Dairy", "icon": "🥛"},
    {"_id": "6", "name": "المشروبات", "name_en": "Beverages", "icon": "🥤"}
]

mock_products = [
    {
        "_id": "1",
        "name": "لحم بقري طازج",
        "name_en": "Fresh Beef",
        "brand": "نادك",
        "brand_en": "Nadec",
        "category": "اللحوم",
        "category_en": "Meat",
        "price": 85.50,
        "stock": 150,
        "description": "لحم بقري طازج عالي الجودة",
        "description_en": "High quality fresh beef",
        "image": "https://via.placeholder.com/100x100.png?text=Beef",
        "status": "active"
    },
    {
        "_id": "2",
        "name": "أرز بسمتي",
        "name_en": "Basmati Rice",
        "brand": "العلالي",
        "brand_en": "Al Alali",
        "category": "البقالة",
        "category_en": "Groceries",
        "price": 45.00,
        "stock": 200,
        "description": "أرز بسمتي هندي فاخر",
        "description_en": "Premium Indian Basmati Rice",
        "image": "https://via.placeholder.com/100x100.png?text=Rice",
        "status": "active"
    },
    {
        "_id": "3",
        "name": "طماطم طازجة",
        "name_en": "Fresh Tomatoes",
        "brand": "مزارع الخير",
        "brand_en": "Al Khair Farms",
        "category": "الخضروات",
        "category_en": "Vegetables",
        "price": 12.50,
        "stock": 300,
        "description": "طماطم طازجة محلية",
        "description_en": "Fresh local tomatoes",
        "image": "https://via.placeholder.com/100x100.png?text=Tomato",
        "status": "active"
    },
    {
        "_id": "4",
        "name": "تفاح أحمر",
        "name_en": "Red Apples",
        "brand": "مزارع الجوف",
        "brand_en": "Al Jouf Farms",
        "category": "الفواكه",
        "category_en": "Fruits",
        "price": 18.00,
        "stock": 120,
        "description": "تفاح أحمر طازج",
        "description_en": "Fresh red apples",
        "image": "https://via.placeholder.com/100x100.png?text=Apple",
        "status": "active"
    },
    {
        "_id": "5",
        "name": "حليب طازج",
        "name_en": "Fresh Milk",
        "brand": "المراعي",
        "brand_en": "Almarai",
        "category": "الألبان",
        "category_en": "Dairy",
        "price": 15.00,
        "stock": 180,
        "description": "حليب طازج كامل الدسم",
        "description_en": "Fresh full cream milk",
        "image": "https://via.placeholder.com/100x100.png?text=Milk",
        "status": "active"
    },
    {
        "_id": "6",
        "name": "عصير برتقال",
        "name_en": "Orange Juice",
        "brand": "ندى",
        "brand_en": "Nada",
        "category": "المشروبات",
        "category_en": "Beverages",
        "price": 8.50,
        "stock": 250,
        "description": "عصير برتقال طبيعي 100%",
        "description_en": "100% natural orange juice",
        "image": "https://via.placeholder.com/100x100.png?text=Juice",
        "status": "active"
    }
]

@app.get("/")
async def root():
    return {
        "message": "AL-Madhina Admin Dashboard Demo",
        "status": "running",
        "note": "This is a demo version without database connections",
        "admin_login": "/admin/login"
    }

@app.get("/admin/login", response_class=HTMLResponse)
async def admin_login_page(request: Request, error: Optional[str] = None):
    """Display admin login page"""
    return templates.TemplateResponse(
        "admin_login.html",
        {"request": request, "error": error}
    )

@app.post("/admin/login")
async def admin_login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...)
):
    """Handle admin login"""
    if username == "admin" and password == "admin123":
        # Create session
        session_id = str(uuid.uuid4())
        active_sessions[session_id] = {"username": username}
        
        # Redirect to dashboard with session cookie
        response = RedirectResponse(url="/admin/dashboard", status_code=302)
        response.set_cookie(
            key="session_id",
            value=session_id,
            httponly=True,
            max_age=86400  # 24 hours
        )
        return response
    else:
        return templates.TemplateResponse(
            "admin_login.html",
            {"request": request, "error": "Invalid credentials"}
        )

@app.post("/admin/logout")
async def admin_logout(session_id: Optional[str] = Cookie(None)):
    """Handle admin logout"""
    if session_id and session_id in active_sessions:
        del active_sessions[session_id]
    
    response = RedirectResponse(url="/admin/login", status_code=302)
    response.delete_cookie("session_id")
    return response

@app.get("/admin/dashboard", response_class=HTMLResponse)
async def admin_dashboard(
    request: Request,
    session_id: Optional[str] = Cookie(None)
):
    """Display admin dashboard"""
    # Check authentication
    if not session_id or session_id not in active_sessions:
        return RedirectResponse(url="/admin/login", status_code=302)
    
    session = active_sessions[session_id]
    return templates.TemplateResponse(
        "admin_dashboard.html",
        {"request": request, "username": session["username"]}
    )

@app.get("/admin/api/products/all")
async def get_all_products(session_id: Optional[str] = Cookie(None)):
    """Get all products (mock data)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    return {"products": mock_products}

@app.get("/admin/api/categories/all")
async def get_all_categories(session_id: Optional[str] = Cookie(None)):
    """Get all categories (mock data)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    # Return category names in English for the dropdown
    category_names = [cat["name_en"] for cat in mock_categories]
    return {"categories": category_names}

@app.post("/admin/api/products/add")
async def add_product(request: Request, session_id: Optional[str] = Cookie(None)):
    """Add new product (demo - no actual database)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    data = await request.json()
    new_product = {
        "_id": str(len(mock_products) + 1),
        **data
    }
    mock_products.append(new_product)
    
    return {"message": "Product added successfully (demo mode)", "product": new_product}

@app.put("/admin/api/products/{product_id}")
async def update_product(
    product_id: str,
    request: Request,
    session_id: Optional[str] = Cookie(None)
):
    """Update product (demo - no actual database)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    data = await request.json()
    
    # Find and update product
    for i, product in enumerate(mock_products):
        if product["_id"] == product_id:
            mock_products[i] = {**product, **data, "_id": product_id}
            return {"message": "Product updated successfully (demo mode)", "product": mock_products[i]}
    
    return {"error": "Product not found"}, 404

@app.delete("/admin/api/products/{product_id}")
async def delete_product(product_id: str, session_id: Optional[str] = Cookie(None)):
    """Delete product (demo - no actual database)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    # Find and remove product
    for i, product in enumerate(mock_products):
        if product["_id"] == product_id:
            deleted = mock_products.pop(i)
            return {"message": "Product deleted successfully (demo mode)", "product": deleted}
    
    return {"error": "Product not found"}, 404

@app.post("/admin/api/upload/image/{product_id}")
async def upload_image(product_id: str, session_id: Optional[str] = Cookie(None)):
    """Upload image (demo - returns placeholder)"""
    if not session_id or session_id not in active_sessions:
        return {"error": "Unauthorized"}, 401
    
    # In demo mode, just return a placeholder URL
    placeholder_url = f"https://via.placeholder.com/300x300.png?text=Product+{product_id}"
    
    return {
        "message": "Image upload simulated (demo mode)",
        "image_url": placeholder_url
    }

if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("🎨 AL-MADHINA ADMIN DASHBOARD DEMO")
    print("="*60)
    print("\n📌 Admin Dashboard: http://127.0.0.1:8000/admin/login")
    print("   Username: admin")
    print("   Password: admin123")
    print("\n⚠️  NOTE: This is demo mode with mock data (no database required)")
    print("\n" + "="*60 + "\n")
    
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
