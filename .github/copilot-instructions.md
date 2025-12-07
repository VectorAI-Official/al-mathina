# Copilot / AI assistant guidance for AL-Madhina repo

This file gives compact, actionable rules and pointers so an AI coding assistant can be immediately productive in this repository.

Keep guidance concise. When in doubt, prefer small, safe edits and ask the developer before making large structural changes.

---
What this project is (big picture)

- Monorepo for the AL-Madhina app: Flutter frontend (in `flutter_preview`) + FastAPI backend (in `Backend`).
- Backend acts as a gateway to two databases: Supabase (Postgres) for transactions and MongoDB for catalog data.
- The Flutter preview runs in Chrome for quick dev; backend runs at `http://127.0.0.1:8000` by convention.

Key directories & files

- `Backend/` — FastAPI backend
  - `Backend/main.py`, `Backend/main_local.py` — app entrypoints used with uvicorn.
  - `Backend/main_production.py` — production entrypoint (deployed on Render).
  - `Backend/routes/flutter.py` — Flutter-optimized API endpoints (home, products, subcategories, Most Bought).
  - `Backend/routes/admin_local.py` — Admin dashboard API endpoints (categories, products, Most Bought management).
  - `Backend/routes/fcm.py` — Firebase Cloud Messaging endpoints for push notifications.
  - `Backend/routes/user_profile.py` — User profile and order creation with FCM notifications.
  - `Backend/utils/fcm_service.py` — Firebase Admin SDK notification service.
  - `Backend/category_metadata.py`, `Backend/database/*` — DB helpers and migration scripts.
  - `Backend/README.md` — canonical development & startup instructions.
  - `Backend/tools/` — small helper scripts (e.g., `check_subcategory_images.py`).
  - `Backend/static/admin/` — Admin dashboard frontend (HTML/CSS/JS).
  - **CRITICAL: Requirements files** (see "Deployment & Requirements" section below).

- flutter_preview/` — Flutter app used for mobile/web preview
  - `flutter_preview/lib/api_service.dart` — central API models and helper `getImageUrl()`.
  - `flutter_preview/lib/main.dart` — UI and navigation; look here for layout changes.
  - `flutter_preview/lib/services/fcm_service.dart` — Firebase Cloud Messaging service for push notifications.
  - `flutter_preview/lib/screens/phone_auth_screen.dart` — Phone auth with FCM token refresh on login.

Deployment & Requirements (CRITICAL)

**The backend has THREE different requirements files - ALL must be kept in sync when adding new dependencies:**

1. **`Backend/requirements.txt`** - Full development dependencies (500+ packages)
   - Used for: Local development with venv
   - When to update: When adding ANY new Python package during development

2. **`Backend/requirements.production.txt`** - Minimal production dependencies (~30 packages)
   - Used for: Render.com production deployment (non-Docker)
   - When to update: When adding packages needed for production runtime
   - **MUST include**: All packages imported in main_production.py and production routes

3. **`Backend/requirements-docker.txt`** - Minimal Docker build dependencies (~25 packages)
   - Used for: Docker builds (via Dockerfile)
   - Referenced in: `Backend/Dockerfile` (line 13: `COPY requirements-docker.txt requirements.txt`)
   - When to update: When adding packages needed for Docker/containerized deployment
   - **MUST include**: All packages imported in main_production.py and production routes

**CRITICAL RULE**: When adding a new Python dependency:
- ✅ ALWAYS update ALL THREE requirements files if the package is needed in production
- ✅ Test locally first, then update production files
- ✅ Common packages to sync: database clients (supabase, pymongo), cloud services (firebase-admin, cloudinary), API frameworks (fastapi, uvicorn)
- ❌ NEVER add dev-only packages (pytest, black, flake8) to production/docker requirements
- ❌ NEVER assume one requirements file will work for all environments

**Recent Example (Dec 2025)**: Added FCM push notifications:
- Added `supabase==2.25.0` and `firebase-admin==6.5.0`
- Updated requirements.txt ✅
- Updated requirements.production.txt ✅
- Updated requirements-docker.txt ✅
- Deployment failed twice because forgot to update production and docker files

**Deployment Target**: Render.com (https://al-mathina.onrender.com)
- Dockerfile-based deployment
- Auto-deploys on git push to main branch
- Uses `main_production.py` as entrypoint
- Monitor at: Render dashboard



Developer workflows (commands you can run)

- Backend dev start (PowerShell):
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000
```
- Flutter preview (Chrome):
```powershell
Set-Location -LiteralPath 'flutter_preview'
flutter run -d chrome
```
- Common debug helpers:
  - Use `Backend/check_most_bought_images.py` to verify Most Bought categories have images.
  - Use `Backend/check_most_bought.py` to list all starred categories in database.
  - Check FastAPI interactive docs at `http://127.0.0.1:8000/docs`.

Project-specific conventions & patterns

- Database-driven metadata
  - `category_metadata` collection stores `image_url` for sections/main_category/subcategory.
  - **IMPORTANT**: Metadata documents use `name` field (not `main_category`) for main category names.
  - API endpoints in `routes/flutter.py` read from metadata using the `name` field.
  - Backend now normalizes `image_url` to absolute URLs using `request.base_url` in `make_absolute(request, path)`.

- Most Bought System (replaces old "Best Seller")
  - `most_bought` collection stores starred main categories: `{section, main_category, starred_at}`.
  - Admin can star/unstar main categories in mobile view via star button (⭐/★).
  - Starred categories appear in dedicated "Most Bought" section at top of Flutter app.
  - Most Bought categories are EXISTING main categories (not duplicates) - they just get highlighted.
  - Clicking Most Bought card navigates to subcategories, same as regular main categories.

- API vs Admin UI separation
  - Public API for Flutter lives under `/api/flutter` (optimized responses).
  - Admin UI is served under `/admin/*` and contains client-side JS in `Backend/static/admin/`.
  - Admin API endpoints under `/admin/api/*` (e.g., `/admin/api/most-bought`).

- Fallback policy for images
  - Subcategory images should come from subcategory metadata. Main-category images are allowed as fallback only if subcategory metadata is missing.
  - Product images are not used as a substitute for subcategory images (the code previously had such a fallback but it was removed intentionally).

- Cache-busting strategy
  - All Flutter API calls include timestamp query parameter: `?t=${DateTime.now().millisecondsSinceEpoch}`
  - HTTP headers: `Cache-Control: no-cache, no-store, must-revalidate`, `Pragma: no-cache`, `Expires: 0`
  - This prevents stale data from being displayed after admin changes.

- FCM Push Notifications System
  - **Backend**: `Backend/routes/fcm.py` handles token save/retrieve
  - **Backend Service**: `Backend/utils/fcm_service.py` sends notifications via Firebase Admin SDK
  - **Database**: Supabase `users` table stores FCM tokens (columns: id, phone, fcm_token, store_name, email, name)
  - **Firebase Config**: `Backend/firebase-service-account.json` (secret, not in git)
  - **Environment Variables**: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY
  - **Order Notifications**: Sent automatically when orders are created in `routes/user_profile.py`
  - **Split Orders**: Single notification sent for all split orders combined
  - **Flutter**: `flutter_preview/lib/services/fcm_service.dart` handles token generation and refresh
  - **Token Refresh**: Automatically triggered after phone auth login
  - **Notification Branding**: Al-Mathina green (#28a745), sound, vibration enabled

Safety & small-edit policy

- Prefer minimal, local changes. Avoid wide refactors.
- When updating API responses, run `Backend/check_most_bought_images.py` and `uvicorn` locally to validate shape and runtime behavior.
- If any change touches DB schema or metadata, mention it and leave a migration path or a small script in `Backend/tools/`.

Examples & quick patterns

- To fetch Most Bought categories for Flutter:
  - Call `GET /api/flutter/home` - returns `best_sellers` object with `main_categories` array.
  - Each category object contains `name`, `image_url`, `product_count`, `section`, and `main_category`.

- To star/unstar main categories in admin:
  - POST `/admin/api/most-bought` with `{section, main_category}` to add.
  - DELETE `/admin/api/most-bought?section=X&main_category=Y` to remove.
  - GET `/admin/api/most-bought` to list all starred categories.

- To fetch subcategories for use in Flutter sidebar:
  - Call `GET /api/flutter/main-category/{section}/{main_category}/subcategories`.
  - Each subcategory object contains `name`, `product_count`, `icon`, and `image_url` (absolute URL if present).

- To ensure image URLs render in Flutter web preview, either:
  1. Store absolute URLs in `category_metadata.image_url`, or
  2. Store relative paths (e.g. `/static/uploads/..`) — the backend will convert them to absolute using the request base URL.

Files to inspect when debugging common issues

- Render overflow in Flutter: check `flutter_preview/lib/main.dart` for fixed heights inside Columns; look for `Expanded`/`Flexible` usage.
- Missing images in Flutter Most Bought: check `Backend/routes/flutter.py` (lines 74-95) and `Backend/check_most_bought_images.py`.
- Missing images in general: verify `category_metadata` documents use `name` field (not `main_category`).
- 422 or HTTP errors when loading products: `Backend/routes/flutter.py` `get_products` uses optional Query params now — verify query param names from `api_service.dart`.
- Star button not working: check `Backend/static/admin/js/dashboard.js` `toggleStarMainCategory` function (lines ~2506-2565).
- Starred badge not showing: check `Backend/static/admin/css/dashboard.css` `.starred-badge` styles (lines ~1860+).

If you modify or add an API endpoint

- Update `Backend/README.md` and `FLUTTER_ROUTES_TESTING.md` (or create a short note in `Backend/tools/` with curl examples).
- Add a small script under `Backend/tools/` to validate the response shape automatically (example: `check_most_bought_images.py`).

When to ask the developer

- If you need credentials, access tokens, or Supabase secrets from `.env` — ask; do not guess or modify secrets.
- If a change requires a DB migration or schema update that affects production data.

Most Bought System Details (Important)

- Database: `most_bought` collection with unique compound index on `(section, main_category)`.
- Backend API: 
  * POST `/admin/api/most-bought` - Add category (returns 409 if already exists)
  * DELETE `/admin/api/most-bought` - Remove category
  * GET `/admin/api/most-bought` - List all starred categories
- Frontend Admin: `Backend/static/admin/js/dashboard.js`
  * `toggleStarMainCategory()` - Add/remove stars dynamically
  * `showMainCategoryCards()` - Fetch and display starred status
  * Star button (⭐/★) appears on hover in mobile category cards
  * Starred categories show floating "⭐ Starred" badge
- Frontend Flutter: `flutter_preview/lib/main.dart`
  * "Most Bought" section appears at top of home screen (before other sections)
  * 3-column grid layout matching other main category sections
  * Golden "⭐ Most Bought" badge on each card
  * Clicking navigates to `SubcategoryProductsScreen` (same as regular categories)
- Migration: `Backend/migrate_to_most_bought.py` removed old `is_best_seller` field from products.

---
Key Architectural Notes:
1. **Metadata field names**: Always use `name` field when querying `category_metadata` for main categories.
2. **Most Bought ≠ Products**: Most Bought stars main categories, not individual products.
3. **Cache-busting**: Always include timestamp params and no-cache headers in Flutter API calls.
4. **Navigation consistency**: Most Bought cards navigate exactly like regular main category cards.
5. **Image resolution**: Backend uses cascading fallback (exact section match → name only → legacy main_category field).