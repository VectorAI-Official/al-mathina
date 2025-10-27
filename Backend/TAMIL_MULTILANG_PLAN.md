# Tamil Multi-Language Support Implementation Plan

## Database Changes

### 1. category_hierarchy collection
Add fields:
- section_ta: Tamil name for section
- For main categories: Add parallel structure or use metadata

### 2. category_metadata collection
Add field:
- name_ta: Tamil name for main categories and subcategories

## Backend API Changes

### Admin Endpoints to Update:
1. POST /api/categories/section - Add section_ta parameter
2. PUT /api/categories/section - Add section_ta parameter
3. POST /api/categories/main - Add main_category_ta parameter
4. PUT /api/categories/main - Add main_category_ta parameter
5. POST /api/categories/subcategory - Add subcategory_ta parameter
6. PUT /api/categories/subcategory - Add subcategory_ta parameter

### Flutter API Endpoints to Update:
1. GET /api/flutter/home - Accept language parameter, return appropriate names
2. GET /api/flutter/main-category/{section}/{main_category}/subcategories - Accept language parameter

## Frontend Changes

### Admin Dashboard (HTML/JS):
1. Add Tamil input fields to all category forms
2. Update form submission to include Tamil names

### Flutter App:
1. Update API calls to pass current language
2. Update models to handle Tamil names
3. Display Tamil names when Tamil language is selected

## Implementation Order:
1. Backend database schema (category_metadata)
2. Backend API endpoints (admin routes)
3. Admin dashboard forms
4. Flutter API endpoints
5. Flutter app models and UI
