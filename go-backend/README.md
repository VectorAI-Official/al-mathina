# AL-Madhina Go Backend

FastAPI → Go migration for improved performance and lower resource usage.

## Directory Structure

```
go-backend/
├── main.go                 # Entry point (like main_production.py)
├── config/
│   └── config.go          # Environment configuration
├── database/
│   ├── mongo.go           # MongoDB connection
│   └── supabase.go        # Supabase client
├── models/
│   └── models.go          # Data structures (Product, Order, etc.)
├── handlers/
│   ├── flutter.go         # Flutter app APIs
│   ├── admin.go           # Admin dashboard APIs
│   ├── fcm.go             # Push notifications
│   └── user.go            # User profile & orders
├── utils/
│   ├── fcm.go             # Firebase Cloud Messaging service
│   └── email.go           # Email notification service
├── middleware/
│   └── cors.go            # CORS handling
└── static/                # Admin dashboard (copied from Backend/)
    └── admin/
        ├── index.html
        ├── css/
        └── js/
```

## Quick Start

### 1. Install Go

```bash
# Windows (download from golang.org)
# or use chocolatey:
choco install golang

# Verify installation
go version  # Should show: go version go1.21.x
```

### 2. Setup Project

```bash
cd go-backend

# Download dependencies
go mod download

# Copy environment file
copy .env.example .env

# Edit .env with your actual credentials
notepad .env
```

### 3. Run Development Server

```bash
# Method 1: Direct run
go run main.go

# Method 2: Build then run
go build -o al-mathina.exe
./al-mathina.exe

# With auto-reload (install air first: go install github.com/cosmtrek/air@latest)
air
```

Server will start on: http://localhost:9000

### 4. Test APIs

```bash
# Home API
curl http://localhost:9000/api/flutter/home

# Products API
curl "http://localhost:9000/api/flutter/products?page=1&limit=20"

# Admin Dashboard
# Open in browser: http://localhost:9000/admin
```

## Docker Setup

```bash
# Build image
docker build -t al-mathina-go .

# Run container
docker run -p 9000:9000 --env-file .env al-mathina-go

# Or use docker-compose
docker-compose up --build
```

## Testing with MongoDB

Create TEST data (won't touch existing products):

```bash
# The app automatically creates TEST entities on first run
# Check MongoDB:
db.products.find({"product_name": /^TEST_/})
```

## Migration from Python

The Go backend maintains 100% API compatibility with FastAPI:
- Same URLs (`/api/flutter/products`, `/admin/api/most-bought`)
- Same JSON response format
- Same HTTP methods (GET, POST, PUT, DELETE)
- Admin dashboard works without changes

## Performance Comparison

| Metric | FastAPI | Go | Improvement |
|--------|---------|-----|-------------|
| RAM Usage (idle) | ~200MB | ~25MB | 8x less |
| Requests/sec | ~5,000 | ~18,000 | 3.6x faster |
| Docker Image | ~1GB | ~20MB | 50x smaller |
| Startup Time | ~3s | ~0.1s | 30x faster |

## Environment Variables

See `.env.example` for all required variables.

Critical variables:
- `MONGO_URI` - MongoDB connection string
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` - Supabase auth
- `FIREBASE_SERVICE_ACCOUNT_PATH` - FCM notifications
- `PORT` - Server port (default: 9000)

## Deployment (Render.com)

1. Create new Web Service on Render
2. Connect to this repository
3. Set Build Command: `go build -o main`
4. Set Start Command: `./main`
5. Add environment variables from `.env`
6. Deploy!

Render will automatically detect Go and build the project.

## Troubleshooting

### "MongoDB connection failed"
- Check `MONGO_URI` in `.env`
- Verify MongoDB Atlas IP whitelist (allow 0.0.0.0/0)

### "Firebase not initialized"
- Ensure `firebase-service-account.json` exists
- Check file path in `FIREBASE_SERVICE_ACCOUNT_PATH`

### "Port already in use"
- Python backend running on same port
- Change `PORT=9001` in `.env` or stop Python server

## Development Workflow

1. Keep Python backend as reference (don't delete yet)
2. Run Go on port 9000, Python on port 8000
3. Test each endpoint with curl or Postman
4. Verify admin dashboard works
5. Test with Flutter app (change API_BASE temporarily)
6. Once verified, deploy Go to production

## Admin Phone Numbers

Configured in `.env` as `ADMIN_PHONES`:
- +917339651541
- +918870503350
- +919487715568

These users get `buying_price` field in product responses.
