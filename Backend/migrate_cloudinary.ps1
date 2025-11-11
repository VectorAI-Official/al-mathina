# Cloudinary Migration - Quick Start Script
# Run this in PowerShell from the Backend directory

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  CLOUDINARY ACCOUNT MIGRATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
.\venv\Scripts\Activate.ps1

# Install required package
Write-Host "Installing required packages..." -ForegroundColor Yellow
pip install requests -q

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  STEP 1: DRY RUN (Test Mode)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will scan your database and show what would be migrated." -ForegroundColor White
Write-Host "No actual changes will be made." -ForegroundColor Green
Write-Host ""

$dryrun = Read-Host "Run dry run first? (yes/no)"

if ($dryrun -eq "yes") {
    Write-Host ""
    Write-Host "Starting dry run..." -ForegroundColor Yellow
    python migrate_cloudinary_images.py --dry-run
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Dry run complete!" -ForegroundColor Green
    Write-Host "Please review the log file before proceeding." -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $continue = Read-Host "Continue with actual migration? (yes/no)"
    
    if ($continue -ne "yes") {
        Write-Host "Migration cancelled." -ForegroundColor Yellow
        exit
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  STEP 2: REAL MIGRATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will:" -ForegroundColor Red
Write-Host "  - Download images from old Cloudinary account" -ForegroundColor White
Write-Host "  - Upload to new Cloudinary account" -ForegroundColor White
Write-Host "  - Update ALL database URLs" -ForegroundColor White
Write-Host ""
Write-Host "Make sure you have:" -ForegroundColor Yellow
Write-Host "  ✓ Created a database backup" -ForegroundColor White
Write-Host "  ✓ Set environment variables for both accounts" -ForegroundColor White
Write-Host "  ✓ Reviewed the dry run results" -ForegroundColor White
Write-Host ""

$final = Read-Host "Ready to proceed with migration? (yes/no)"

if ($final -eq "yes") {
    Write-Host ""
    Write-Host "Starting migration..." -ForegroundColor Yellow
    Write-Host ""
    python migrate_cloudinary_images.py
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  MIGRATION COMPLETE!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Check the log file for any errors" -ForegroundColor White
    Write-Host "  2. Verify images in admin dashboard" -ForegroundColor White
    Write-Host "  3. Test Flutter app image loading" -ForegroundColor White
    Write-Host "  4. Review migration_map_*.json file" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Migration cancelled." -ForegroundColor Yellow
}
