# Performance Test: FastAPI vs Go Backend - Orders API
# Tests response time and memory usage for /api/admin/orders endpoint

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "   AL-Madhina Backend Performance Test" -ForegroundColor Cyan
Write-Host "   Endpoint: /api/admin/orders" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$iterations = 10
$fastApiPort = 8000
$goPort = 9000

# Function to measure API response time
function Measure-ApiPerformance {
    param(
        [string]$Url,
        [string]$Name,
        [int]$Iterations
    )
    
    Write-Host "`nTesting $Name..." -ForegroundColor Yellow
    Write-Host "URL: $Url" -ForegroundColor Gray
    
    $times = @()
    $orderCounts = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        try {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
            $sw.Stop()
            
            $json = $response.Content | ConvertFrom-Json
            $orderCount = if ($json.orders) { $json.orders.Count } else { $json.Count }
            
            $times += $sw.Elapsed.TotalMilliseconds
            $orderCounts += $orderCount
            
            Write-Host "  [$i/$Iterations] ${sw.Elapsed.TotalMilliseconds}ms - $orderCount orders" -ForegroundColor Gray
        }
        catch {
            Write-Host "  [$i/$Iterations] FAILED: $_" -ForegroundColor Red
        }
        
        Start-Sleep -Milliseconds 100  # Brief pause between requests
    }
    
    if ($times.Count -gt 0) {
        $avg = ($times | Measure-Object -Average).Average
        $min = ($times | Measure-Object -Minimum).Minimum
        $max = ($times | Measure-Object -Maximum).Maximum
        $median = ($times | Sort-Object)[[Math]::Floor($times.Count / 2)]
        
        return @{
            Average = $avg
            Min = $min
            Max = $max
            Median = $median
            OrderCount = $orderCounts[0]
            SuccessRate = ($times.Count / $Iterations) * 100
        }
    }
    
    return $null
}

# Function to get process memory usage
function Get-ProcessMemory {
    param([string]$ProcessName)
    
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($process) {
        return [Math]::Round($process.WorkingSet64 / 1MB, 2)
    }
    return 0
}

# Warmup requests
Write-Host "Warming up backends..." -ForegroundColor Yellow
try { Invoke-WebRequest -Uri "http://127.0.0.1:$fastApiPort/api/admin/orders" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch {}
try { Invoke-WebRequest -Uri "http://127.0.0.1:$goPort/api/admin/orders" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch {}
Start-Sleep -Seconds 2

# Get initial memory usage
Write-Host "`nMeasuring baseline memory usage..." -ForegroundColor Yellow

$pythonMemBefore = Get-ProcessMemory "python"
$uvicornMemBefore = Get-ProcessMemory "uvicorn"
$fastApiMem = if ($pythonMemBefore -gt 0) { $pythonMemBefore } else { $uvicornMemBefore }

$dockerProcess = Get-Process | Where-Object { $_.Name -like "*docker*" -or $_.ProcessName -like "*com.docker*" }
$goContainerMem = 0
try {
    $containerStats = docker stats almathina-go-backend --no-stream --format "{{.MemUsage}}" 2>$null
    if ($containerStats -match '(\d+\.?\d*)MiB') {
        $goContainerMem = [decimal]$matches[1]
    }
    elseif ($containerStats -match '(\d+\.?\d*)GiB') {
        $goContainerMem = [decimal]$matches[1] * 1024
    }
}
catch {
    Write-Host "  Could not measure Go container memory" -ForegroundColor Gray
}

Write-Host "  FastAPI (Python): ${fastApiMem} MB" -ForegroundColor Gray
Write-Host "  Go (Docker Container): ${goContainerMem} MB" -ForegroundColor Gray

# Test FastAPI
$fastApiResults = Measure-ApiPerformance -Url "http://127.0.0.1:$fastApiPort/api/admin/orders" -Name "FastAPI (Python) - Port $fastApiPort" -Iterations $iterations

# Test Go Backend
$goResults = Measure-ApiPerformance -Url "http://127.0.0.1:$goPort/api/admin/orders" -Name "Go Backend - Port $goPort" -Iterations $iterations

# Get final memory usage
Start-Sleep -Seconds 2
$fastApiMemAfter = if ((Get-ProcessMemory "python") -gt 0) { Get-ProcessMemory "python" } else { Get-ProcessMemory "uvicorn" }
try {
    $containerStatsAfter = docker stats almathina-go-backend --no-stream --format "{{.MemUsage}}" 2>$null
    if ($containerStatsAfter -match '(\d+\.?\d*)MiB') {
        $goContainerMemAfter = [decimal]$matches[1]
    }
    elseif ($containerStatsAfter -match '(\d+\.?\d*)GiB') {
        $goContainerMemAfter = [decimal]$matches[1] * 1024
    }
}
catch {
    $goContainerMemAfter = $goContainerMem
}

# Display Results
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "             RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

Write-Host "FastAPI (Python) - Port $fastApiPort" -ForegroundColor Green
Write-Host "  Response Time:" -ForegroundColor White
Write-Host "    Average: $([Math]::Round($fastApiResults.Average, 2)) ms" -ForegroundColor White
Write-Host "    Median:  $([Math]::Round($fastApiResults.Median, 2)) ms" -ForegroundColor White
Write-Host "    Min:     $([Math]::Round($fastApiResults.Min, 2)) ms" -ForegroundColor White
Write-Host "    Max:     $([Math]::Round($fastApiResults.Max, 2)) ms" -ForegroundColor White
Write-Host "  Memory Usage: ${fastApiMemAfter} MB" -ForegroundColor White
Write-Host "  Orders Returned: $($fastApiResults.OrderCount)" -ForegroundColor White
Write-Host "  Success Rate: $($fastApiResults.SuccessRate)%`n" -ForegroundColor White

Write-Host "Go Backend - Port $goPort" -ForegroundColor Green
Write-Host "  Response Time:" -ForegroundColor White
Write-Host "    Average: $([Math]::Round($goResults.Average, 2)) ms" -ForegroundColor White
Write-Host "    Median:  $([Math]::Round($goResults.Median, 2)) ms" -ForegroundColor White
Write-Host "    Min:     $([Math]::Round($goResults.Min, 2)) ms" -ForegroundColor White
Write-Host "    Max:     $([Math]::Round($goResults.Max, 2)) ms" -ForegroundColor White
Write-Host "  Memory Usage: ${goContainerMemAfter} MB" -ForegroundColor White
Write-Host "  Orders Returned: $($goResults.OrderCount)" -ForegroundColor White
Write-Host "  Success Rate: $($goResults.SuccessRate)%`n" -ForegroundColor White

# Calculate winner
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "             COMPARISON" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$speedDiff = $fastApiResults.Average - $goResults.Average
$speedWinner = if ($speedDiff -gt 0) { "Go" } else { "FastAPI" }
$speedPct = [Math]::Abs([Math]::Round(($speedDiff / $fastApiResults.Average) * 100, 1))

Write-Host "Speed Winner: $speedWinner" -ForegroundColor Yellow
if ($speedDiff -gt 0) {
    Write-Host "  Go is ${speedPct}% faster ($([Math]::Abs([Math]::Round($speedDiff, 2))) ms faster)" -ForegroundColor Green
} else {
    Write-Host "  FastAPI is ${speedPct}% faster ($([Math]::Abs([Math]::Round($speedDiff, 2))) ms faster)" -ForegroundColor Green
}

$memDiff = $fastApiMemAfter - $goContainerMemAfter
$memWinner = if ($memDiff -gt 0) { "Go" } else { "FastAPI" }

Write-Host "`nMemory Winner: $memWinner" -ForegroundColor Yellow
if ($memDiff -gt 0) {
    Write-Host "  Go uses $([Math]::Round($memDiff, 2)) MB less memory" -ForegroundColor Green
} else {
    Write-Host "  FastAPI uses $([Math]::Round([Math]::Abs($memDiff), 2)) MB less memory" -ForegroundColor Green
}

Write-Host "`n============================================`n" -ForegroundColor Cyan
