#!/usr/bin/env pwsh
# 🐳 Docker Backend Quick Start Script
# Automatically sets up and runs Docker for local development

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('start', 'stop', 'rebuild', 'logs', 'clean', 'status')]
    [string]$Action = 'start'
)

$BackendPath = "$PSScriptRoot\go-backend"
$ScriptName = "docker_backend.ps1"

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host "╔" + ("═" * 78) + "╗" -ForegroundColor Cyan
    Write-Host "║ $Message$((" " * (76 - $Message.Length))) ║" -ForegroundColor Cyan
    Write-Host "╚" + ("═" * 78) + "╝" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message, [string]$Status = "⏳")
    Write-Host "$Status  $Message" -ForegroundColor Blue
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

function Check-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Docker
    Write-Step "Checking Docker installation..."
    try {
        $dockerVersion = docker --version
        Write-Success "Docker found: $dockerVersion"
    }
    catch {
        Write-Error "Docker not found. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        exit 1
    }
    
    # Check Docker running
    Write-Step "Checking if Docker daemon is running..."
    try {
        docker info > $null 2>&1
        Write-Success "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }
    
    # Check .env exists
    Write-Step "Checking environment configuration..."
    if (Test-Path "$BackendPath\.env") {
        Write-Success "Environment file found (.env)"
    }
    else {
        Write-Error ".env not found in go-backend folder"
        exit 1
    }
}

function Docker-Start {
    Write-Header "Starting Docker Backend"
    
    # Check prerequisites
    Check-Prerequisites
    
    # Navigate to Backend
    Set-Location $BackendPath
    Write-Step "Changed directory to: $BackendPath"
    
    # Check if containers already running
    $running = docker-compose ps --services --filter "status=running" 2>/dev/null
    if ($running) {
        Write-Info "Containers already running. Use 'docker_backend.ps1 stop' to stop them."
        Docker-Status
        exit 0
    }
    
    # Build image
    Write-Step "Building Docker image (this may take a few minutes)..."
    docker-compose build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed"
        exit 1
    }
    Write-Success "Docker image built successfully"
    
    # Start containers
    Write-Step "Starting containers..."
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start containers"
        exit 1
    }
    Write-Success "Containers started"
    
    # Wait for health check
    Write-Step "Waiting for backend to be ready (this takes ~30 seconds)..."
    $maxAttempts = 30
    $attempts = 0
    while ($attempts -lt $maxAttempts) {
        try {
            $response = curl -s -f "http://localhost:9000/health" 2>/dev/null
            if ($response) {
                Write-Success "Backend is healthy and running!"
                break
            }
        }
        catch { }
        
        $attempts++
        Write-Host "." -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    if ($attempts -ge $maxAttempts) {
        Write-Error "Backend failed to start. Check logs with: docker-compose logs"
        exit 1
    }
    
    Docker-Status
    
    Write-Header "Backend Ready! 🚀"
    Write-Info "Backend URL: http://localhost:9000"
    Write-Info "Admin Dashboard: http://localhost:9000/admin"
    Write-Info "API Documentation: http://localhost:9000/docs"
    Write-Info "Health Check: http://localhost:9000/health"
    Write-Info ""
    Write-Info "View logs: $ScriptName logs"
    Write-Info "Stop backend: $ScriptName stop"
    Write-Info "Rebuild: $ScriptName rebuild"
}

function Docker-Stop {
    Write-Header "Stopping Docker Backend"
    
    Set-Location $BackendPath
    
    $running = docker-compose ps --services --filter "status=running" 2>/dev/null
    if (-not $running) {
        Write-Info "No containers currently running"
        exit 0
    }
    
    Write-Step "Stopping containers..."
    docker-compose down
    Write-Success "Containers stopped"
}

function Docker-Rebuild {
    Write-Header "Rebuilding Docker Backend"
    
    Set-Location $BackendPath
    
    Write-Step "Stopping existing containers..."
    docker-compose down
    Write-Success "Stopped"
    
    Write-Step "Building fresh image..."
    docker-compose build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
        exit 1
    }
    Write-Success "Image rebuilt"
    
    Write-Step "Starting containers..."
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start containers"
        exit 1
    }
    Write-Success "Containers started"
    
    Write-Step "Waiting for backend to be ready..."
    Start-Sleep -Seconds 10
    
    Docker-Status
    Write-Success "Rebuild complete!"
}

function Docker-Logs {
    Set-Location $BackendPath
    Write-Header "Backend Logs (Press Ctrl+C to exit)"
    docker-compose logs -f
}

function Docker-Clean {
    Write-Header "Cleaning Up Docker Resources"
    
    Set-Location $BackendPath
    
    Write-Step "Stopping containers..."
    docker-compose down
    Write-Success "Containers stopped"
    
    Write-Step "Removing containers and images..."
    docker-compose down --volumes
    Write-Success "Cleaned up"
    
    Write-Step "Pruning unused images..."
    docker image prune -f
    Write-Success "Pruned"
    
    Write-Success "Docker cleanup complete"
}

function Docker-Status {
    Set-Location $BackendPath
    Write-Header "Container Status"
    
    $ps = docker-compose ps
    Write-Host $ps -ForegroundColor Gray
    
    try {
        $health = curl -s -f "http://localhost:9000/health" 2>/dev/null
        if ($health) {
            Write-Success "Backend health check: OK ✅"
        }
        else {
            Write-Error "Backend health check: FAILED"
        }
    }
    catch {
        Write-Error "Backend health check: FAILED (cannot connect)"
    }
}

# Main execution
try {
    switch ($Action) {
        'start' { Docker-Start }
        'stop' { Docker-Stop }
        'rebuild' { Docker-Rebuild }
        'logs' { Docker-Logs }
        'clean' { Docker-Clean }
        'status' { Docker-Status }
        default { Write-Error "Unknown action: $Action"; exit 1 }
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
