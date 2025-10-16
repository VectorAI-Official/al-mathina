# AL-Madhina Backend - Quick Start Script
# Run this script to start all backend services

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AL-Madhina Wholesale Backend Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if running in Backend directory
$currentDir = Split-Path -Leaf (Get-Location)
if ($currentDir -ne "Backend") {
    Write-Host "Error: Please run this script from the Backend directory" -ForegroundColor Red
    Write-Host "cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" -ForegroundColor Yellow
    exit 1
}

# Step 1: Check Python
Write-Host "[1/6] Checking Python installation..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Python found: $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Python not found. Please install Python 3.9+" -ForegroundColor Red
    exit 1
}

# Step 2: Check/Create Virtual Environment
Write-Host "`n[2/6] Setting up Python virtual environment..." -ForegroundColor Yellow
if (Test-Path "venv") {
    Write-Host "  ✓ Virtual environment exists" -ForegroundColor Green
} else {
    Write-Host "  Creating virtual environment..." -ForegroundColor Gray
    python -m venv venv
    Write-Host "  ✓ Virtual environment created" -ForegroundColor Green
}

# Step 3: Activate venv and install dependencies
Write-Host "`n[3/6] Installing Python dependencies..." -ForegroundColor Yellow
& ".\venv\Scripts\Activate.ps1"
pip install -q -r requirements.txt
Write-Host "  ✓ Dependencies installed" -ForegroundColor Green

# Step 4: Check .env file
Write-Host "`n[4/6] Checking environment configuration..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "  ✓ .env file exists" -ForegroundColor Green
} else {
    Write-Host "  Creating .env from template..." -ForegroundColor Gray
    Copy-Item ".env.example" ".env"
    Write-Host "  ✓ .env file created (review and update if needed)" -ForegroundColor Green
}

# Step 5: Check Docker services
Write-Host "`n[5/6] Checking database services..." -ForegroundColor Yellow

# Check MongoDB
$mongoRunning = docker ps --format "{{.Names}}" | Select-String -Pattern "mongo-local"
if ($mongoRunning) {
    Write-Host "  ✓ MongoDB is running" -ForegroundColor Green
} else {
    Write-Host "  Starting MongoDB..." -ForegroundColor Gray
    $mongoExists = docker ps -a --format "{{.Names}}" | Select-String -Pattern "mongo-local"
    if ($mongoExists) {
        docker start mongo-local | Out-Null
    } else {
        docker run --name mongo-local -p 27017:27017 -d mongo:latest | Out-Null
    }
    Start-Sleep -Seconds 2
    Write-Host "  ✓ MongoDB started" -ForegroundColor Green
}

# Check Supabase
Write-Host "  Checking Supabase..." -ForegroundColor Gray
$supabaseStatus = supabase status 2>&1
if ($supabaseStatus -like "*supabase local development*") {
    Write-Host "  ✓ Supabase is running" -ForegroundColor Green
} else {
    Write-Host "  Starting Supabase (this may take a minute)..." -ForegroundColor Gray
    if (Test-Path "supabase") {
        supabase start | Out-Null
    } else {
        supabase init | Out-Null
        supabase start | Out-Null
    }
    Write-Host "  ✓ Supabase started" -ForegroundColor Green
}

# Step 6: Ready to start FastAPI
Write-Host "`n[6/6] Setup complete!" -ForegroundColor Green
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Backend services are ready!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "To start the FastAPI server, run:" -ForegroundColor Yellow
Write-Host "  uvicorn main:app --reload`n" -ForegroundColor White

Write-Host "Quick links:" -ForegroundColor Yellow
Write-Host "  • API Docs:      http://127.0.0.1:8000/docs" -ForegroundColor Gray
Write-Host "  • Health Check:  http://127.0.0.1:8000/health" -ForegroundColor Gray
Write-Host "  • Supabase UI:   http://127.0.0.1:54323" -ForegroundColor Gray

Write-Host "`nPress any key to start the FastAPI server now, or Ctrl+C to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host "`nStarting FastAPI server...`n" -ForegroundColor Green
uvicorn main:app --reload --host 127.0.0.1 --port 8000
