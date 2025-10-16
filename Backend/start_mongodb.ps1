# Start MongoDB and Backend Server
# This script starts a local MongoDB instance and the admin dashboard

Write-Host "🚀 Starting AL-Madhina Backend with Local MongoDB" -ForegroundColor Green
Write-Host "="*60

# Check if Docker is installed
try {
    docker --version | Out-Null
    Write-Host "✓ Docker found" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker not found. Please install Docker Desktop." -ForegroundColor Red
    Write-Host "Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
try {
    docker ps | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check if MongoDB container exists
$mongoExists = docker ps -a --format "{{.Names}}" | Select-String -Pattern "^almathina-mongodb$"

if ($mongoExists) {
    Write-Host "✓ MongoDB container exists" -ForegroundColor Green
    
    # Check if it's running
    $mongoRunning = docker ps --format "{{.Names}}" | Select-String -Pattern "^almathina-mongodb$"
    
    if ($mongoRunning) {
        Write-Host "✓ MongoDB is already running" -ForegroundColor Green
    } else {
        Write-Host "⚙ Starting existing MongoDB container..." -ForegroundColor Yellow
        docker start almathina-mongodb
        Start-Sleep -Seconds 2
        Write-Host "✓ MongoDB started" -ForegroundColor Green
    }
} else {
    Write-Host "⚙ Creating new MongoDB container..." -ForegroundColor Yellow
    docker run -d `
        --name almathina-mongodb `
        -p 27017:27017 `
        -e MONGO_INITDB_DATABASE=almadhinadb `
        mongo:latest
    
    Start-Sleep -Seconds 3
    Write-Host "✓ MongoDB container created and started" -ForegroundColor Green
}

Write-Host ""
Write-Host "📊 MongoDB Status:" -ForegroundColor Cyan
docker ps --filter "name=almathina-mongodb" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

Write-Host ""
Write-Host "="*60
Write-Host "🎨 Starting Admin Dashboard..." -ForegroundColor Green
Write-Host "="*60
Write-Host ""
Write-Host "📌 Admin Login: http://127.0.0.1:8000/admin/login" -ForegroundColor Cyan
Write-Host "   Username: admin" -ForegroundColor Yellow
Write-Host "   Password: admin123" -ForegroundColor Yellow
Write-Host ""
Write-Host "="*60
Write-Host ""

# Start the backend server
& ".\venv\Scripts\python.exe" ".\main_local.py"
