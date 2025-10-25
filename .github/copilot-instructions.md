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
  - `Backend/routes/flutter.py` — Flutter-optimized API endpoints (home, products, subcategories, best-sellers).
  - `Backend/category_metadata.py`, `Backend/database/*` — DB helpers and migration scripts.
  - `Backend/README.md` — canonical development & startup instructions.
  - `Backend/tools/` — small helper scripts (e.g., `check_subcategory_images.py`).

- `flutter_preview/` — Flutter app used for mobile/web preview
  - `flutter_preview/lib/api_service.dart` — central API models and helper `getImageUrl()`.
  - `flutter_preview/lib/main.dart` — UI and navigation; look here for layout changes.

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
  - Use `Backend/tools/check_subcategory_images.py` to list subcategory image_url values.
  - Check FastAPI interactive docs at `http://127.0.0.1:8000/docs`.

Project-specific conventions & patterns

- Database-driven metadata
  - `category_metadata` collection stores `image_url` for sections/main_category/subcategory; API endpoints in `routes/flutter.py` read from it.
  - Backend now normalizes `image_url` to absolute URLs using `request.base_url` in `make_absolute(request, path)`.

- API vs Admin UI separation
  - Public API for Flutter lives under `/api/flutter` (optimized responses).
  - Admin UI is served under `/admin/*` and contains client-side JS in `Backend/static/admin/`.

- Fallback policy for images
  - Subcategory images should come from subcategory metadata. Main-category images are allowed as fallback only if subcategory metadata is missing.
  - Product images are not used as a substitute for subcategory images (the code previously had such a fallback but it was removed intentionally).

Safety & small-edit policy

- Prefer minimal, local changes. Avoid wide refactors.
- When updating API responses, run `Backend/tools/check_subcategory_images.py` and `uvicorn` locally to validate shape and runtime behavior.
- If any change touches DB schema or metadata, mention it and leave a migration path or a small script in `Backend/tools/`.

Examples & quick patterns

- To fetch subcategories for use in Flutter sidebar:
  - Call `GET /api/flutter/main-category/{section}/{main_category}/subcategories`.
  - Each subcategory object contains `name`, `product_count`, `icon`, and `image_url` (absolute URL if present).

- To ensure image URLs render in Flutter web preview, either:
  1. Store absolute URLs in `category_metadata.image_url`, or
  2. Store relative paths (e.g. `/static/uploads/..`) — the backend will convert them to absolute using the request base URL.

Files to inspect when debugging common issues

- Render overflow in Flutter: check `flutter_preview/lib/main.dart` for fixed heights inside Columns; look for `Expanded`/`Flexible` usage.
- Missing images in Flutter: check `Backend/routes/flutter.py` (subcategories endpoint) and `Backend/tools/check_subcategory_images.py` for presence of `image_url`.
- 422 or HTTP errors when loading products: `Backend/routes/flutter.py` `get_products` uses optional Query params now — verify query param names from `api_service.dart`.

If you modify or add an API endpoint

- Update `Backend/README.md` and `FLUTTER_ROUTES_TESTING.md` (or create a short note in `Backend/tools/` with curl examples).
- Add a small script under `Backend/tools/` to validate the response shape automatically (example: `check_subcategory_images.py`).

When to ask the developer

- If you need credentials, access tokens, or Supabase secrets from `.env` — ask; do not guess or modify secrets.
- If a change requires a DB migration or schema update that affects production data.

---
Please review and tell me if you'd like me to: (a) reduce the guidance to <20 lines for a strict assistant persona, (b) expand examples into runnable scripts under `Backend/tools/`, or (c) include automated test snippets for critical endpoints.