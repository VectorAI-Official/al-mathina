# Fly.io Backend Deployment - What You Need to Provide

## ✅ Checklist: Everything Required for Deployment

---

## 1. **Fly.io Account & Setup**

- [ ] **Fly.io Account** - Do you have one?
  - Sign up at https://fly.io/app/sign-up if not
  - Will need credit card on file (but won't charge without approval)

- [ ] **flyctl CLI Installed** - Do you have it?
  - Check: Run `flyctl version` in terminal
  - If not installed: https://fly.io/docs/getting-started/installing-flyctl/

- [ ] **Logged in to Fly.io** - Are you authenticated?
  - Check: Run `flyctl auth whoami` in terminal
  - If not logged in: Run `flyctl auth login`

---

## 2. **Environment Variables & Secrets**

These are **critical** - I need you to provide these values:

### **MongoDB Connection**
- [ ] `MONGODB_URI` - Your MongoDB Atlas connection string
  - Format: `mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority`
  - Where to find: MongoDB Atlas dashboard → Connect → Connection String

### **Cloudinary (Image Hosting)**
- [ ] `CLOUDINARY_CLOUD_NAME` - Your Cloudinary cloud name
- [ ] `CLOUDINARY_API_KEY` - Your Cloudinary API key
- [ ] `CLOUDINARY_API_SECRET` - Your Cloudinary API secret
  - Where to find: Cloudinary dashboard → Settings → API Keys

### **Database Credentials (If Using Direct DB)**
- [ ] `DB_USER` - Database username (if applicable)
- [ ] `DB_PASSWORD` - Database password (if applicable)

### **Optional - Supabase (If Using)**
- [ ] `SUPABASE_URL` - Supabase project URL (if you use it)
- [ ] `SUPABASE_KEY` - Supabase API key (if you use it)

### **App Configuration**
- [ ] `ENVIRONMENT` - Should be: `production`
- [ ] `DEBUG` - Should be: `false`
- [ ] `SECRET_KEY` - Random secure string for FastAPI
  - Can generate: `python -c "import secrets; print(secrets.token_urlsafe(32))"`

---

## 3. **Backend Code**

- [ ] **Backend directory cleaned** ✅ (Already done!)
- [ ] **All routes working locally** - Have you tested?
  - Test: Run backend locally, test order creation, product fetch, admin endpoints
- [ ] **No hardcoded credentials** - Check code for secrets
  - Search for hardcoded IPs, passwords, API keys

---

## 4. **Configuration Files**

These should already exist, but verify:

- [ ] `fly.toml` - Fly.io configuration file
  - Location: `/Backend/fly.toml`
  - Should specify: app name, regions, env variables

- [ ] `Dockerfile` - Docker container definition
  - Location: `/Backend/Dockerfile`
  - Should build Python FastAPI app

- [ ] `requirements.txt` - Python dependencies
  - Location: `/Backend/requirements.txt`
  - Latest versions specified

- [ ] `.dockerignore` - What to exclude from Docker image
  - Location: `/Backend/.dockerignore`

- [ ] `.env.production` - Production environment template
  - Location: `/Backend/.env.production` or `.env.example`

---

## 5. **Application Entry Point**

- [ ] `main_production.py` exists and is correct
  - Should have proper CORS settings
  - Should listen on port 8080 (Fly.io default)
  - Should import `config_production`

---

## 6. **Database & Collections**

- [ ] MongoDB Atlas database is **live and accessible**
  - Test: Connect from your local machine to verify
  - Collections needed: `orders`, `products`, `category_metadata`, `users`, etc.

- [ ] Database has all required data
  - Products loaded?
  - Categories set up?
  - Any initial data seeding done?

---

## 7. **API Endpoints Verified**

Test these locally before deployment (at `http://192.168.1.6:8000`):

- [ ] `GET /api/flutter/home` - Works?
- [ ] `GET /api/flutter/products?skip=0&limit=10` - Works?
- [ ] `POST /api/flutter/user/orders` - Can create order with order_id?
- [ ] `GET /api/flutter/user/orders/{phone}` - Can retrieve orders?
- [ ] `GET /api/flutter/user/favorites/{phone}` - Can get favorites?
- [ ] `GET /admin/api/orders` - Admin can see orders?

---

## 8. **Image URLs & Assets**

- [ ] All product images accessible
  - Images stored in Cloudinary? ✅ (You use Cloudinary)
  - Or on your backend? Verify in `/Backend/static/` if needed

- [ ] Static files configured
  - Admin dashboard assets in `/Backend/static/admin/`?
  - Verify they're included in Dockerfile

---

## 9. **Health Check Endpoint**

- [ ] Health check endpoint available
  - Typically: `GET /health`
  - Returns: `{"status": "ok"}` or similar
  - Used by Fly.io to verify app is running

---

## 10. **Monitoring & Logging**

Optional but recommended:

- [ ] Logging configured (see errors if something breaks)
- [ ] Error tracking (optional - Sentry integration)
- [ ] Database connection pooling (FastAPI + MongoDB)

---

---

## 📋 **Simple Form - Fill This Out**

```
ACCOUNT SETUP:
✓ Fly.io account: YES / NO
✓ flyctl installed: YES / NO
✓ Logged in: YES / NO

SECRETS (REQUIRED):
✓ MongoDB URI: _________________
✓ Cloudinary Cloud Name: _________________
✓ Cloudinary API Key: _________________
✓ Cloudinary API Secret: _________________

CODE READY:
✓ Backend cleaned: YES ✅
✓ All endpoints tested locally: YES / NO
✓ main_production.py working: YES / NO
✓ No hardcoded secrets: YES / NO

DATABASE:
✓ MongoDB Atlas accessible: YES / NO
✓ Collections populated: YES / NO
✓ Data looks correct: YES / NO

READY TO DEPLOY: YES / NO
```

---

## 🚀 **Deployment Steps (Preview)**

Once you provide everything above, here's what I'll do:

1. **Set environment variables** on Fly.io
   ```bash
   fly secrets set MONGODB_URI=... CLOUDINARY_CLOUD_NAME=... etc
   ```

2. **Deploy the app**
   ```bash
   cd Backend
   fly deploy
   ```

3. **Verify deployment**
   ```bash
   fly status
   fly logs
   ```

4. **Test production endpoints**
   - Test order creation on production URL
   - Test admin dashboard
   - Verify MongoDB connection works

---

## ⚠️ **Important Notes**

- **Secrets should NEVER be in code** - They go in Fly.io secrets
- **No hardcoded localhost URLs** - Backend should accept any domain
- **CORS must allow Flutter app domain** - Update if needed
- **Ensure MongoDB Atlas allows external connections** - Security group/IP whitelist

---

## 📞 **What to Send Me**

**TL;DR - Just provide these:**

1. Fly.io account email (or confirmation that you're logged in)
2. MongoDB Atlas URI (connection string)
3. Cloudinary credentials (cloud name, API key, secret)
4. Confirmation that:
   - You can run `flyctl version` successfully
   - Backend works locally
   - All endpoints tested

**That's it! I'll handle the rest.** ✅

---

**Ready? Reply with the checklist filled out and we'll deploy!** 🚀
