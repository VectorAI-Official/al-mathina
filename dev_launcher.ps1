#!/usr/bin/env pwsh
# 🚀 AL-MADHINA COMPLETE DEVELOPMENT LAUNCHER
# Automatically starts backend (Docker), admin dashboard, and Flutter preview

param(
    [Parameter(Mandatory=$false)]
    [switch]$Backend,
    
    [Parameter(Mandatory=$false)]
    [switch]$Admin,
    
    [Parameter(Mandatory=$false)]
    [switch]$Flutter,
    
    [Parameter(Mandatory=$false)]
    [switch]$All
)

$RootPath = $PSScriptRoot
$BackendPath = "$RootPath\go-backend"
$FlutterPath = "$RootPath\flutter_preview"

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host "╔" + ("═" * 78) + "╗" -ForegroundColor Cyan
    Write-Host "║ $Message$((" " * (76 - $Message.Length))) ║" -ForegroundColor Cyan
    Write-Host "╚" + ("═" * 78) + "╝" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Show-Menu {
    Write-Header "AL-MADHINA Development Setup"
    Write-Host "`n"
    Write-Host "What would you like to start?`n" -ForegroundColor Yellow
    Write-Host "  1) Backend (Docker) Only"
    Write-Host "  2) Backend + Admin Dashboard"
    Write-Host "  3) Backend + Flutter Preview"
    Write-Host "  4) Everything (Backend + Admin + Flutter)" -ForegroundColor Green
    Write-Host "  5) Exit"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-5)"
    return $choice
}

function Start-Backend {
    Write-Header "🐳 Starting Docker Backend"
    
    Write-Info "Starting Docker containers..."
    Set-Location $BackendPath
    
    # Check if already running
    $running = docker-compose ps --services --filter "status=running" 2>/dev/null
    if ($running) {
        Write-Success "Backend already running on http://localhost:9000"
        return $true
    }
    
    # Start Docker
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Docker"
        return $false
    }
    
    # Wait for health check
    Write-Info "Waiting for backend to be ready (30 seconds)..."
    $maxAttempts = 30
    $attempts = 0
    
    while ($attempts -lt $maxAttempts) {
        try {
            $response = curl -s -f "http://localhost:9000/health" 2>/dev/null
            if ($response) {
                Write-Success "Backend is ready! ✨"
                Write-Info "URL: http://localhost:9000"
                Write-Info "API Docs: http://localhost:9000/docs"
                return $true
            }
        }
        catch { }
        
        $attempts++
        Write-Host "." -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    Write-Error "Backend failed to start. Check logs with: docker-compose logs"
    return $false
}

function Start-AdminDashboard {
    Write-Header "📊 Opening Admin Dashboard"
    
    Write-Info "Opening http://localhost:9000/admin in browser..."
    Start-Process "http://localhost:9000/admin"
    
    Write-Info "Login credentials:"
    Write-Info "  Username: admin"
    Write-Info "  Password: admin123"
    
    Write-Success "Admin dashboard opened in default browser"
}

function Start-FlutterPreview {
    Write-Header "📱 Starting Flutter Preview"
    
    Write-Info "Changing to flutter_preview directory..."
    Set-Location $FlutterPath
    
    Write-Info "Launching Flutter on Chrome..."
    Write-Info "(This will open a new Chrome window)"
    
    flutter run -d chrome
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Flutter preview"
        return $false
    }
    
    Write-Success "Flutter preview started!"
    return $true
}

function Show-URLs {
    Write-Host "`n"
    Write-Header "📌 Important URLs & Commands"
    
    Write-Host "`n  📍 Endpoints:" -ForegroundColor Yellow
    Write-Host "     Backend:        http://localhost:9000"
    Write-Host "     Admin Dashboard: http://localhost:9000/admin"
    Write-Host "     API Docs:        http://localhost:9000/docs"
    Write-Host "     Health Check:    http://localhost:9000/health"
    
    Write-Host "`n  🔐 Admin Login:" -ForegroundColor Yellow
    Write-Host "     Username: admin"
    Write-Host "     Password: admin123"
    
    Write-Host "`n  📝 Useful Commands:" -ForegroundColor Yellow
    Write-Host "     View logs:       docker-compose -f go-backend/docker-compose.yml logs -f"
    Write-Host "     Stop backend:    docker-compose -f go-backend/docker-compose.yml down"
    Write-Host "     Rebuild:         docker-compose -f go-backend/docker-compose.yml build --no-cache"
    
    Write-Host "`n  🐛 Debugging:" -ForegroundColor Yellow
    Write-Host "     Press F12 in browser for DevTools"
    Write-Host "     Check Console tab for logs (colored output)"
    Write-Host "     Reference: LOGS_VISUAL_REFERENCE.md"
    
    Write-Host "`n  📚 Documentation:" -ForegroundColor Yellow
    Write-Host "     Docker Setup:        DOCKER_LOCALHOST_SETUP.md"
    Write-Host "     Logging Guide:       LOGS_QUICK_START.md"
    Write-Host "     Visual Reference:    LOGS_VISUAL_REFERENCE.md"
    Write-Host "     Mobile View Debug:   MOBILE_VIEW_LOGGING_GUIDE.md"
    
    Write-Host "`n"
}

function Wait-For-User {
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main execution
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                   🚀 AL-MADHINA DEVELOPMENT ENVIRONMENT 🚀                      ║" -ForegroundColor Cyan
Write-Host "║                                                                                ║" -ForegroundColor Cyan
Write-Host "║  This script will help you start the development environment for testing      ║" -ForegroundColor Cyan
Write-Host "║  the Flutter app with a local backend connected to cloud databases.           ║" -ForegroundColor Cyan
Write-Host "║                                                                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Determine what to start
$startBackend = $false
$startAdmin = $false
$startFlutter = $false

if ($All) {
    $startBackend = $true
    $startAdmin = $true
    $startFlutter = $true
}
elseif ($Backend) {
    $startBackend = $true
}
elseif ($Admin) {
    $startBackend = $true
    $startAdmin = $true
}
elseif ($Flutter) {
    $startBackend = $true
    $startFlutter = $true
}
else {
    # Interactive menu
    $choice = Show-Menu
    
    switch ($choice) {
        "1" { $startBackend = $true }
        "2" { $startBackend = $true; $startAdmin = $true }
        "3" { $startBackend = $true; $startFlutter = $true }
        "4" { $startBackend = $true; $startAdmin = $true; $startFlutter = $true }
        "5" { exit 0 }
        default { Write-Error "Invalid choice"; exit 1 }
    }
}

# Start components
if ($startBackend) {
    if (-not (Start-Backend)) {
        Write-Error "Failed to start backend. Exiting."
        exit 1
    }
    Start-Sleep -Seconds 2
}

if ($startAdmin) {
    Start-AdminDashboard
    Start-Sleep -Seconds 2
}

if ($startFlutter) {
    Start-FlutterPreview
}

# Show summary
Show-URLs

Write-Header "All Systems Ready! 🎉"
Write-Host ""
Write-Host "Your development environment is running!" -ForegroundColor Green
Write-Host ""
Write-Host "  ✅ Backend (Docker):     http://localhost:9000" -ForegroundColor Green
if ($startAdmin) {
    Write-Host "  ✅ Admin Dashboard:      http://localhost:9000/admin" -ForegroundColor Green
}
if ($startFlutter) {
    Write-Host "  ✅ Flutter Preview:      Chrome window" -ForegroundColor Green
}

Write-Host ""
Write-Host "📖 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Open http://localhost:9000/admin and log in"
Write-Host "  2. Press F12 to open DevTools and check Console logs"
Write-Host "  3. Use LOGS_VISUAL_REFERENCE.md to understand the logs"
Write-Host "  4. Make changes in Admin, watch Flutter app update"
Write-Host "  5. Monitor console logs for debugging"
Write-Host ""

if (-not $startFlutter) {
    Write-Host "To also run Flutter Preview, use: .\dev_launcher.ps1 -All" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Happy coding! 🎨✨" -ForegroundColor Green
Write-Host ""
