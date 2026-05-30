# Category CRUD API - Command Examples

Quick reference for testing Go backend category endpoints via curl.

---

## Base URL
```
http://localhost:9000/admin/api/categories
```

---

## GET Endpoints

### 1. Get Complete Hierarchy
```bash
curl http://localhost:9000/admin/api/categories
```

**Response**:
```json
[
  {
    "section": "testing",
    "main_categories": {
      "testing": [],
      "test_main": ["test_sub"]
    }
  }
]
```

### 2. Get All Sections
```bash
curl http://localhost:9000/admin/api/categories/sections
```

**Response**:
```json
{
  "sections": ["testing", "test_new_section", "பழைய பாக்கி முடித்ததும் புதிய ஆர்டர் போடவும்", "மளிகை பொருள் Only பெயர் மட்டும்"]
}
```

### 3. Get Main Categories for Section
```bash
curl http://localhost:9000/admin/api/categories/testing/main
```

**Response**:
```json
{
  "main_categories": ["testing", "test_main"]
}
```

### 4. Get Subcategories
```bash
curl http://localhost:9000/admin/api/categories/testing/test_main/subcategories
```

**Response**:
```json
{
  "subcategories": ["test_sub"]
}
```

---

## POST Endpoints (PowerShell)

### 1. Create Section

**PowerShell**:
```powershell
$body = @{section = "new_section"} | ConvertTo-Json -Compress
curl.exe -X POST http://localhost:9000/admin/api/categories/section `
  -H "Content-Type: application/json" `
  -d $body
```

**Response**:
```json
{"message": "Section 'new_section' created successfully"}
```

### 2. Create Main Category

**PowerShell**:
```powershell
$body = @{
  section = "testing"
  main_category = "Electronics"
} | ConvertTo-Json -Compress

curl.exe -X POST http://localhost:9000/admin/api/categories/main `
  -H "Content-Type: application/json" `
  -d $body
```

**With Metadata** (Tamil name + image):
```powershell
$body = @{
  section = "testing"
  main_category = "Electronics"
  metadata = @{
    tamil_name = "மின்னணு பொருட்கள்"
    image_url = "https://example.com/electronics.jpg"
  }
} | ConvertTo-Json -Compress -Depth 3

curl.exe -X POST http://localhost:9000/admin/api/categories/main `
  -H "Content-Type: application/json" `
  -d $body
```

**Response**:
```json
{"message": "Main category 'Electronics' created successfully"}
```

### 3. Create Subcategory

**PowerShell**:
```powershell
$body = @{
  section = "testing"
  main_category = "Electronics"
  subcategory = "Mobile Phones"
} | ConvertTo-Json -Compress

curl.exe -X POST http://localhost:9000/admin/api/categories/sub `
  -H "Content-Type: application/json" `
  -d $body
```

**Response**:
```json
{"message": "Subcategory 'Mobile Phones' created successfully"}
```

---

## POST Endpoints (Linux/Mac Bash)

### 1. Create Section
```bash
curl -X POST http://localhost:9000/admin/api/categories/section \
  -H "Content-Type: application/json" \
  -d '{"section": "new_section"}'
```

### 2. Create Main Category
```bash
curl -X POST http://localhost:9000/admin/api/categories/main \
  -H "Content-Type: application/json" \
  -d '{"section": "testing", "main_category": "Electronics"}'
```

### 3. Create Subcategory
```bash
curl -X POST http://localhost:9000/admin/api/categories/sub \
  -H "Content-Type: application/json" \
  -d '{"section": "testing", "main_category": "Electronics", "subcategory": "Mobile Phones"}'
```

---

## Error Responses

### 400 Bad Request (Missing Required Fields)
```json
{"error": "Section name is required"}
```

### 404 Not Found (Section/Main Category Doesn't Exist)
```json
{"error": "Section not found"}
```

### 409 Conflict (Already Exists)
```json
{"error": "Section already exists"}
```

---

## Validation Rules

### Section Name
- **Required**: Yes
- **Type**: String
- **Unique**: Yes (per section)

### Main Category Name
- **Required**: Yes
- **Type**: String
- **Unique**: Yes (per section)
- **Dependency**: Section must exist

### Subcategory Name
- **Required**: Yes
- **Type**: String
- **Unique**: Yes (per main category via `$addToSet`)
- **Dependencies**: Section + Main Category must exist

---

## Testing Workflow

1. **Create Section**:
   ```powershell
   $body = @{section = "Electronics"} | ConvertTo-Json -Compress
   curl.exe -X POST http://localhost:9000/admin/api/categories/section -H "Content-Type: application/json" -d $body
   ```

2. **Add Main Category**:
   ```powershell
   $body = @{section = "Electronics"; main_category = "Mobile"} | ConvertTo-Json -Compress
   curl.exe -X POST http://localhost:9000/admin/api/categories/main -H "Content-Type: application/json" -d $body
   ```

3. **Add Subcategory**:
   ```powershell
   $body = @{section = "Electronics"; main_category = "Mobile"; subcategory = "Smartphones"} | ConvertTo-Json -Compress
   curl.exe -X POST http://localhost:9000/admin/api/categories/sub -H "Content-Type: application/json" -d $body
   ```

4. **Verify**:
   ```powershell
   curl http://localhost:9000/admin/api/categories/Electronics/Mobile/subcategories
   # Should return: {"subcategories": ["Smartphones"]}
   ```

---

## Common PowerShell JSON Pitfalls

### ❌ WRONG (Escaped Quotes Fail)
```powershell
curl.exe -d "{`"section`": `"testing`"}"
# Error: JSON parsing fails due to quote escaping
```

### ✅ CORRECT (Use ConvertTo-Json)
```powershell
$body = @{section = "testing"} | ConvertTo-Json -Compress
curl.exe -d $body
```

### ✅ ALTERNATIVE (Invoke-RestMethod)
```powershell
$body = @{section = "testing"}
Invoke-RestMethod -Uri http://localhost:9000/admin/api/categories/section `
  -Method POST `
  -ContentType "application/json" `
  -Body ($body | ConvertTo-Json)
```

---

## Database Verification

After creating categories via API, verify in MongoDB:

```javascript
// Connect to MongoDB
use al_mathina

// Check category_hierarchy
db.category_hierarchy.find({section: "Electronics"}).pretty()

// Should return:
{
  "section": "Electronics",
  "main_categories": {
    "Mobile": ["Smartphones"]
  }
}
```

---

## Automated Testing

Run complete test suite:
```powershell
.\test_category_crud.ps1
```

This tests all 9 scenarios:
1. Get hierarchy
2. Get sections
3. Get main categories
4. Get subcategories
5. Create section
6. Create main category
7. Create subcategory
8. Verify changes
9. Check products
