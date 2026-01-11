# AL-Madhina FastAPI → Go Migration

**Status**: 🚧 In Progress  
**Start Date**: January 10, 2026  
**Target Completion**: February 10, 2026 (4 weeks)

## Phase 1: Foundation & Setup ✅ COMPLETE

**Status**: ✅ Done  
**Duration**: Day 1

### Completed:
- [x] Project structure created (`go-backend/`)
- [x] Directory layout (config, models, database, handlers, utils, middleware)
- [x] `go.mod` with all dependencies
- [x] `.env.example` template
- [x] Config loader (`config/config.go`)
- [x] README.md with setup instructions

### Next Steps:
Continue to Phase 2

---

## Phase 2: Database Connections (IN PROGRESS)

**Target**: Day 1-2  
**Status**: 🔄 Starting Now

### Tasks:
- [ ] `database/mongo.go` - MongoDB connection with context
- [ ] `database/supabase.go` - Supabase REST client
- [ ] Test scripts (`test_connections.go`)
- [ ] Verify connectivity to production databases

### Files to Create:
1. `database/mongo.go` (350 lines)
2. `database/supabase.go` (200 lines)
3. `test_connections.go` (150 lines)

---

## Phase 3: Models & Structs

**Target**: Day 2-3  
**Status**: ⏳ Pending

### Tasks:
- [ ] Define all MongoDB document structs
- [ ] Define all API request/response models
- [ ] BSON and JSON tags for each field

### Structs Needed:
1. Product (30+ fields)
2. Order (25+ fields)
3. User (15 fields)
4. Category, Subcategory (10 fields each)
5. MostBought, Pagination, etc.

---

## Phase 4: Utilities

**Target**: Day 3-4  
**Status**: ⏳ Pending

### Tasks:
- [ ] `utils/fcm.go` - Firebase Cloud Messaging
- [ ] `utils/email.go` - Vercel webhook emails
- [ ] Helper functions (makeAbsolute, pagination, etc.)

---

## Phase 5: Flutter APIs (19 endpoints)

**Target**: Week 2 (Day 5-10)  
**Status**: ⏳ Pending

### Endpoints:
1. GET `/api/flutter/home`
2. GET `/api/flutter/products` (with pagination)
3. GET `/api/flutter/main-category/{section}/{main}/subcategories`
4. GET `/api/flutter/product/{item_id}`
5. GET `/api/flutter/search`
6. POST `/api/flutter/user/profile`
7. POST `/api/flutter/user/orders`
8. GET `/api/flutter/user/orders/{phone}`
9. POST `/fcm/token`
10. GET `/fcm/token/{phone}`
... (9 more)

---

## Phase 6: Admin APIs (12 endpoints)

**Target**: Week 3 (Day 11-15)  
**Status**: ⏳ Pending

### Endpoints:
1. GET/POST/DELETE `/admin/api/most-bought`
2. GET/POST/PUT `/admin/api/products`
3. GET `/admin/api/categories`
4. GET `/admin/api/orders`
5. GET `/admin/api/revenue`
... (7 more)

---

## Phase 7: Static Files & Admin Dashboard

**Target**: Day 16  
**Status**: ⏳ Pending

### Tasks:
- [ ] Copy `Backend/static/` to `go-backend/static/`
- [ ] Set up static file serving in Gin
- [ ] Test admin dashboard in browser
- [ ] Verify all admin API calls work

---

## Phase 8: Testing & Validation

**Target**: Week 4 (Day 17-21)  
**Status**: ⏳ Pending

### Tasks:
- [ ] Unit tests for each handler
- [ ] Integration tests with MongoDB
- [ ] Curl tests for all endpoints
- [ ] Admin dashboard manual testing
- [ ] Flutter app testing (parallel with Python)

---

## Phase 9: Docker & Deployment

**Target**: Day 22-23  
**Status**: ⏳ Pending

### Tasks:
- [ ] Create `Dockerfile` (multi-stage build)
- [ ] Create `docker-compose.yml`
- [ ] Test locally with Docker
- [ ] Deploy to Render.com (staging)
- [ ] Monitor logs and performance

---

## Phase 10: Production Cutover

**Target**: Day 24-28  
**Status**: ⏳ Pending

### Tasks:
- [ ] Run Python and Go in parallel for 1 week
- [ ] Monitor error rates (Go should be <0.1%)
- [ ] Gradual traffic shift (10% → 50% → 100%)
- [ ] Final cutover
- [ ] Keep Python backup for 2 weeks

---

## API Compatibility Checklist

### Flutter APIs:
- [ ] `/api/flutter/home` - Same response structure
- [ ] `/api/flutter/products` - Pagination metadata exact match
- [ ] `/api/flutter/subcategories` - Image URLs, product counts
- [ ] `/api/flutter/search` - Pagination support
- [ ] `/api/flutter/user/orders` - FCM notifications
- [ ] All other Flutter endpoints

### Admin APIs:
- [ ] `/admin/api/most-bought` - Star/unstar categories
- [ ] `/admin/api/products` - CRUD operations
- [ ] `/admin/api/orders` - Order management
- [ ] `/admin/api/revenue` - Analytics
- [ ] All other admin endpoints

---

## Testing Strategy

### Unit Tests (Go):
```bash
go test ./... -v
```

### Integration Tests (Curl):
```bash
# Home API
curl http://localhost:9000/api/flutter/home | jq

# Products with pagination
curl "http://localhost:9000/api/flutter/products?page=1&limit=20" | jq

# Admin most-bought
curl http://localhost:9000/admin/api/most-bought | jq
```

### Flutter App Tests:
1. Change `API_BASE` to `http://192.168.1.x:9000/api/flutter`
2. Test browse products
3. Test add to cart
4. Test place order
5. Verify FCM notification received
6. Verify admin email received

---

## Rollback Plan

If issues occur after Go deployment:

1. **Immediate**: Switch DNS back to Python (5 minutes)
2. **Monitor**: Check error logs in Render dashboard
3. **Fix**: Deploy hotfix or revert code
4. **Retry**: Deploy again after fixing issues

Keep Python backend running for 2 weeks as safety net.

---

## Current Status Summary

### ✅ Completed:
- Project structure
- Config system
- Environment variables
- README documentation

### 🔄 In Progress:
- Database connections (MongoDB, Supabase)

### ⏳ Next:
- Complete database layer
- Define all models/structs
- Implement utilities (FCM, Email)

---

## File Count Estimate

| Category | Files | Lines of Code |
|----------|-------|---------------|
| Config | 1 | ~150 |
| Database | 2 | ~550 |
| Models | 1 | ~800 |
| Handlers | 5 | ~3,500 |
| Utils | 3 | ~900 |
| Middleware | 1 | ~100 |
| Main | 1 | ~200 |
| Tests | 10+ | ~1,500 |
| **Total** | **24+** | **~7,700** |

Python Backend: ~5,000 lines  
Go Backend: ~7,700 lines (more verbose due to types)

---

## Questions/Decisions Log

**Q1**: Email system?  
**A**: ✅ Found - Uses Vercel webhook (unlimited free)

**Q2**: Background jobs?  
**A**: ✅ FastAPI BackgroundTasks for email - Go will use goroutines

**Q3**: Special libraries?  
**A**: Firebase Admin, Cloudinary, Supabase - all have Go equivalents

**Q4**: Timeline?  
**A**: 4 weeks (conservative, includes testing)

---

## Reference Commands

### Python Backend (Keep Running):
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python -m uvicorn main_production:app --reload --host 0.0.0.0 --port 8000
```

### Go Backend (New):
```powershell
cd go-backend
go run main.go
# or
air  # for auto-reload
```

### MongoDB Test Query:
```javascript
// Find TEST products only
db.products.find({"product_name": /^TEST_/})

// Count real vs test
db.products.countDocuments({"product_name": {$regex: /^TEST_/}})  // Test
db.products.countDocuments({"product_name": {$not: {$regex: /^TEST_/}}})  // Real
```

---

**Next**: Continuing Phase 2 - Database connections...
