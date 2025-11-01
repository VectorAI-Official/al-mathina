#!/usr/bin/env pwsh
# 🧪 Quick Test Script - Verify Docker & Backend Setup

param(
    [Parameter(Mandatory=$false)]
    [switch]$Full
)

function Write-Header {
    param([string]$Message)
    Write-Host "`n╔" + ("═" * 78) + "╗" -ForegroundColor Cyan
    Write-Host "║ $Message$((" " * (76 - $Message.Length))) ║" -ForegroundColor Cyan
    Write-Host "╚" + ("═" * 78) + "╝" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "  ⏳ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ️  $Message" -ForegroundColor Cyan
}

Write-Header "🧪 AL-MADHINA Setup Verification Test"

# Test 1: Docker Installation
Write-Step "Test 1: Checking Docker installation..."
try {
    $dockerVersion = docker --version
    Write-Success "Docker installed: $dockerVersion"
} catch {
    Write-Error "Docker not found. Install from: https://www.docker.com/products/docker-desktop"
    exit 1
}

# Test 2: Docker Daemon
Write-Step "Test 2: Checking Docker daemon..."
try {
    docker info > $null 2>&1
    Write-Success "Docker daemon running"
} catch {
    Write-Error "Docker daemon not running. Start Docker Desktop."
    exit 1
}

# Test 3: Docker Compose
Write-Step "Test 3: Checking Docker Compose..."
try {
    $composeVersion = docker-compose --version
    Write-Success "Docker Compose installed: $composeVersion"
} catch {
    Write-Error "Docker Compose not found. Install Docker Desktop (includes Compose)."
    exit 1
}

# Test 4: Project Structure
Write-Step "Test 4: Checking project structure..."
$structureOK = $true

$checks = @(
    @{ Path = "Backend"; Name = "Backend directory" },
    @{ Path = "Backend\docker-compose.yml"; Name = "docker-compose.yml" },
    @{ Path = "Backend\Dockerfile"; Name = "Dockerfile" },
    @{ Path = "Backend\.env.production"; Name = ".env.production" },
    @{ Path = "Backend\requirements.txt"; Name = "requirements.txt" },
    @{ Path = "Backend\main_production.py"; Name = "main_production.py" },
    @{ Path = "flutter_preview"; Name = "Flutter app directory" }
)

foreach ($check in $checks) {
    if (Test-Path $check.Path) {
        Write-Success "Found: $($check.Name)"
    } else {
        Write-Error "Missing: $($check.Name) at $($check.Path)"
        $structureOK = $false
    }
}

if (-not $structureOK) {
    Write-Error "Project structure incomplete. Run from repository root."
    exit 1
}

# Test 5: Scripts
Write-Step "Test 5: Checking automation scripts..."
$scriptsOK = $true

$scripts = @(
    @{ Path = "docker_backend.ps1"; Name = "docker_backend.ps1" },
    @{ Path = "dev_launcher.ps1"; Name = "dev_launcher.ps1" }
)

foreach ($script in $scripts) {
    if (Test-Path $script.Path) {
        Write-Success "Found: $($script.Name)"
    } else {
        Write-Error "Missing: $($script.Name)"
        $scriptsOK = $false
    }
}

# Test 6: Documentation
Write-Step "Test 6: Checking documentation..."
$docsOK = $true

$docs = @(
    "DOCKER_LOCALHOST_SETUP.md",
    "DOCKER_LOCALHOST_COMPLETE.md",
    "LOGS_QUICK_START.md",
    "LOGS_VISUAL_REFERENCE.md",
    "MOBILE_VIEW_LOGGING_GUIDE.md"
)

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-Success "Found: $doc"
    } else {
        Write-Error "Missing: $doc"
        $docsOK = $false
    }
}

# Test 7: Environment file
Write-Step "Test 7: Checking environment configuration..."
if (Test-Path "Backend\.env.production") {
    $envContent = Get-Content "Backend\.env.production"
    
    if ($envContent -match "MONGO_URI") {
        Write-Success "MONGO_URI configured"
    } else {
        Write-Error "MONGO_URI not found in .env.production"
    }
    
    if ($envContent -match "CLOUDINARY_CLOUD_NAME") {
        Write-Success "Cloudinary configured"
    } else {
        Write-Error "Cloudinary not configured"
    }
} else {
    Write-Error ".env.production not found"
}

# Summary
Write-Header "✨ Test Summary"

$allPassed = $structureOK -and $scriptsOK -and $docsOK

if ($allPassed) {
    Write-Success "All checks passed! ✨"
    Write-Info ""
    Write-Info "Next steps:"
    Write-Info "1. Start backend: .\dev_launcher.ps1"
    Write-Info "2. Open admin:   http://localhost:8000/admin"
    Write-Info "3. Login:        admin / admin123"
    Write-Info "4. Start Flutter: flutter run -d chrome"
    Write-Info ""
    Write-Info "For detailed setup: see DOCKER_LOCALHOST_SETUP.md"
} else {
    Write-Error "Some checks failed. Please fix the issues above."
    exit 1
}

Write-Host "`n"

# Optional full test (start backend)
if ($Full) {
    Write-Header "Running Full Startup Test"
    
    Write-Step "Starting Docker backend..."
    Set-Location "Backend"
    
    # Check if already running
    $running = docker-compose ps --services --filter "status=running" 2>/dev/null
    if ($running) {
        Write-Info "Backend already running, skipping startup test"
        Write-Success "Backend is running on http://localhost:8000"
    } else {
        Write-Step "Building image and starting container (this may take a minute)..."
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Containers started"
            
            Write-Step "Waiting for backend health check..."
            $maxAttempts = 30
            $attempts = 0
            
            while ($attempts -lt $maxAttempts) {
                try {
                    $response = curl -s -f "http://localhost:8000/health" 2>/dev/null
                    if ($response) {
                        Write-Success "Backend health check passed! ✅"
                        Write-Info "Backend ready at http://localhost:8000"
                        Write-Info "API Docs at http://localhost:8000/docs"
                        break
                    }
                } catch { }
                
                $attempts++
                Write-Host "." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            
            if ($attempts -ge $maxAttempts) {
                Write-Error "Backend health check timeout"
                Write-Info "View logs: docker-compose logs"
            }
        } else {
            Write-Error "Failed to start containers"
            exit 1
        }
    }
    
    Write-Header "Full Test Complete! 🎉"
}

Write-Host ""
Write-Host "✨ You're ready to develop! Use: .\dev_launcher.ps1" -ForegroundColor Green
Write-Host ""
