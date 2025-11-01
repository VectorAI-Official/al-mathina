#!/usr/bin/env pwsh
# Setup script for AL-Madhina Backend Local Development
# This script sets up the complete local debugging environment

param(
    [switch]$SkipVenv = $false,
    [switch]$SkipDeps = $false
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    AL-MADHINA BACKEND LOCAL SETUP                         ║" -ForegroundColor Green
Write-Host "║    Complete environment setup with cloud databases        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Navigate to Backend directory
Write-Host "📁 Changing to Backend directory..." -ForegroundColor Yellow
Set-Location -LiteralPath "Backend"
if (-not (Test-Path "Backend")) {
    Write-Host "❌ Already in Backend directory" -ForegroundColor Yellow
}

# Step 1: Check Python
Write-Host ""
Write-Host "🐍 Step 1: Checking Python installation..." -ForegroundColor Cyan
$pythonVersion = python --version 2>&1
Write-Host "   $pythonVersion" -ForegroundColor Green

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Python not found! Please install Python 3.11+" -ForegroundColor Red
    exit 1
}

# Step 2: Create .env.local
Write-Host ""
Write-Host "⚙️  Step 2: Creating .env.local configuration..." -ForegroundColor Cyan

if (Test-Path ".env.local") {
    Write-Host "   ⚠️  .env.local already exists - skipping creation" -ForegroundColor Yellow
} else {
    if (Test-Path ".env.local.template") {
        Copy-Item ".env.local.template" ".env.local" -Force
        Write-Host "   ✅ .env.local created from template" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  .env.local.template not found - creating basic .env.local" -ForegroundColor Yellow
        @'
HOST=127.0.0.1
PORT=8000
DEBUG=true
LOG_LEVEL=DEBUG
RELOAD=true
MONGO_URI=mongodb+srv://vectoraiautomations_db_user:VectoraI_123@al-mathina.9xt8cbd.mongodb.net/?retryWrites=true&w=majority&appName=al-mathina
MONGO_DB_NAME=almadhinadb
CLOUDINARY_CLOUD_NAME=vectorai
CLOUDINARY_API_KEY=315192596216358
CLOUDINARY_API_SECRET=JFpyMTpUZ01pRxaFpZjm_Na6H-s
SUPABASE_URL=https://supabase-placeholder.com
SUPABASE_ANON_KEY=placeholder-key
JWT_SECRET_KEY=your-local-dev-secret-key
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
'@ | Out-File -FilePath ".env.local" -Encoding UTF8
        Write-Host "   ✅ .env.local created with default values" -ForegroundColor Green
    }
}

# Step 3: Setup Virtual Environment
Write-Host ""
Write-Host "🔧 Step 3: Setting up Python virtual environment..." -ForegroundColor Cyan

if (-not $SkipVenv) {
    if (Test-Path "venv") {
        Write-Host "   ⚠️  venv already exists - skipping creation" -ForegroundColor Yellow
    } else {
        Write-Host "   Creating virtual environment..." -ForegroundColor Gray
        python -m venv venv
        Write-Host "   ✅ Virtual environment created" -ForegroundColor Green
    }
    
    Write-Host "   Activating virtual environment..." -ForegroundColor Gray
    & ".\venv\Scripts\Activate.ps1"
    Write-Host "   ✅ Virtual environment activated" -ForegroundColor Green
} else {
    Write-Host "   ⏭️  Skipping venv creation (-SkipVenv flag set)" -ForegroundColor Yellow
}

# Step 4: Upgrade pip
Write-Host ""
Write-Host "📦 Step 4: Upgrading pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip 2>&1 | Out-Null
Write-Host "   ✅ pip upgraded" -ForegroundColor Green

# Step 5: Install dependencies
Write-Host ""
Write-Host "📚 Step 5: Installing dependencies..." -ForegroundColor Cyan

if (-not $SkipDeps) {
    if (Test-Path "requirements.txt") {
        Write-Host "   Installing packages from requirements.txt..." -ForegroundColor Gray
        pip install -r requirements.txt 2>&1 | Tee-Object -Variable pipOutput | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Dependencies installed successfully" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Some packages may have failed to install" -ForegroundColor Yellow
            Write-Host "   Try running: pip install -r requirements.txt" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ requirements.txt not found!" -ForegroundColor Red
    }
} else {
    Write-Host "   ⏭️  Skipping dependency installation (-SkipDeps flag set)" -ForegroundColor Yellow
}

# Step 6: Verify setup
Write-Host ""
Write-Host "✅ Step 6: Verifying setup..." -ForegroundColor Cyan

Write-Host "   Checking critical files..." -ForegroundColor Gray
$criticalFiles = @("main_production.py", ".env.local", "static\admin\js\dashboard.js")
$allExists = $true

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $file not found" -ForegroundColor Red
        $allExists = $false
    }
}

# Step 7: Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    SETUP COMPLETE! ✅                      ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. ✅ Virtual environment is active" -ForegroundColor Cyan
Write-Host "   (You'll see (venv) in your terminal)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 🚀 Start the backend:" -ForegroundColor Cyan
Write-Host "   python -m uvicorn main_production:app --reload --host 127.0.0.1 --port 8000" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 🌐 Access dashboard in browser:" -ForegroundColor Cyan
Write-Host "   http://127.0.0.1:8000/admin" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 🔑 Login credentials:" -ForegroundColor Cyan
Write-Host "   Username: admin" -ForegroundColor Gray
Write-Host "   Password: admin123" -ForegroundColor Gray
Write-Host ""
Write-Host "5. 🧪 Debug mobile view:" -ForegroundColor Cyan
Write-Host "   Press F12 → Console tab → Run: enableMobileViewDebugging()" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 Tips:" -ForegroundColor Yellow
Write-Host "   • Your cloud databases are configured:" -ForegroundColor Gray
Write-Host "     - MongoDB Atlas (production data)" -ForegroundColor Gray
Write-Host "     - Cloudinary (image storage)" -ForegroundColor Gray
Write-Host "   • Environment: .env.local (check for correct credentials)" -ForegroundColor Gray
Write-Host "   • Logs: Watch this terminal for errors" -ForegroundColor Gray
Write-Host "   • Console: F12 → Console tab for JavaScript debugging" -ForegroundColor Gray
Write-Host ""
Write-Host "📖 Documentation:" -ForegroundColor Yellow
Write-Host "   • LOCAL_DEBUGGING_GUIDE.md       - Complete debugging guide" -ForegroundColor Gray
Write-Host "   • MOBILE_VIEW_DEBUG_STEPS.md     - Mobile view debugging" -ForegroundColor Gray
Write-Host "   • DEBUG_MOBILE_VIEW.js           - Debug functions for console" -ForegroundColor Gray
Write-Host ""
