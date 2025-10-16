# Quick Start for Local Development
# This script starts the backend with MongoDB only (no Supabase required)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting AL-Madhina Backend (Local)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if in Backend directory
if (!(Test-Path "main_local.py")) {
    Write-Host "Error: main_local.py not found!" -ForegroundColor Red
    Write-Host "Please run this from the Backend directory" -ForegroundColor Yellow
    exit 1
}

# Activate virtual environment
Write-Host "[1/3] Activating virtual environment..." -ForegroundColor Yellow
if (Test-Path "venv\Scripts\Activate.ps1") {
    & ".\venv\Scripts\Activate.ps1"
    Write-Host "  ✓ Virtual environment activated" -ForegroundColor Green
} else {
    Write-Host "  ✗ Virtual environment not found!" -ForegroundColor Red
    Write-Host "  Run: python -m venv venv" -ForegroundColor Yellow
    exit 1
}

# Check MongoDB
Write-Host "`n[2/3] Checking MongoDB..." -ForegroundColor Yellow
$mongoService = Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue
if ($mongoService -and $mongoService.Status -eq "Running") {
    Write-Host "  ✓ MongoDB is running" -ForegroundColor Green
} else {
    Write-Host "  ✗ MongoDB is not running!" -ForegroundColor Red
    Write-Host "  Start it with: net start MongoDB" -ForegroundColor Yellow
    exit 1
}

# Start FastAPI server
Write-Host "`n[3/3] Starting FastAPI server..." -ForegroundColor Yellow
Write-Host "  Using: main_local.py (MongoDB only)" -ForegroundColor Gray
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Server will start on http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Admin Dashboard: http://127.0.0.1:8000/admin/login" -ForegroundColor Yellow
Write-Host "API Docs:        http://127.0.0.1:8000/docs`n" -ForegroundColor Yellow

# Start the server
uvicorn main_local:app --reload --host 127.0.0.1 --port 8000
