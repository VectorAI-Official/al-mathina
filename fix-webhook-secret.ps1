# Generate new API secret
$newSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

Write-Host "`n" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "🔐 NEW API SECRET GENERATED" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "`nNew Secret (COPY THIS):`n" -ForegroundColor Yellow
Write-Host $newSecret -ForegroundColor White -BackgroundColor Black
Write-Host "`n" -ForegroundColor Cyan

Write-Host "📋 STEPS TO FIX:`n" -ForegroundColor Cyan

Write-Host "1️⃣  GO TO VERCEL" -ForegroundColor Green
Write-Host "   URL: https://vercel.com/dashboard`n" -ForegroundColor White

Write-Host "2️⃣  OPEN PROJECT" -ForegroundColor Green
Write-Host "   Click: al-mathina-email`n" -ForegroundColor White

Write-Host "3️⃣  GO TO SETTINGS" -ForegroundColor Green
Write-Host "   Click: Settings (left sidebar)`n" -ForegroundColor White

Write-Host "4️⃣  ENVIRONMENT VARIABLES" -ForegroundColor Green
Write-Host "   Click: Environment Variables`n" -ForegroundColor White

Write-Host "5️⃣  UPDATE API_SECRET" -ForegroundColor Green
Write-Host "   Find: API_SECRET`n" -ForegroundColor White

Write-Host "6️⃣  EDIT THE VALUE" -ForegroundColor Green
Write-Host "   Click: Edit (pencil icon)`n" -ForegroundColor White

Write-Host "7️⃣  PASTE NEW SECRET" -ForegroundColor Green
Write-Host "   Delete old value`n" -ForegroundColor White
Write-Host "   Paste this:$newSecret`n" -ForegroundColor Yellow

Write-Host "8️⃣  SAVE" -ForegroundColor Green
Write-Host "   Click: Save button`n" -ForegroundColor White

Write-Host "9️⃣  REDEPLOY" -ForegroundColor Green
Write-Host "   Go to: Deployments tab`n" -ForegroundColor White
Write-Host "   Click: ··· (three dots) on latest`n" -ForegroundColor White
Write-Host "   Click: Redeploy`n" -ForegroundColor White
Write-Host "   Wait: 30-60 seconds for completion`n" -ForegroundColor White

Write-Host "🔟 UPDATE RENDER" -ForegroundColor Green
Write-Host "   Go to: Render Dashboard`n" -ForegroundColor White
Write-Host "   Click: al-mathina service`n" -ForegroundColor White
Write-Host "   Click: Environment`n" -ForegroundColor White
Write-Host "   Find: EMAIL_WEBHOOK_SECRET`n" -ForegroundColor White
Write-Host "   Update with:$newSecret`n" -ForegroundColor Yellow
Write-Host "   Click: Save Changes`n" -ForegroundColor White

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "✅ AFTER BOTH DEPLOYMENTS COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "`nRun this test command:`n" -ForegroundColor Cyan

Write-Host "`$headers = @{" -ForegroundColor White
Write-Host "    'Content-Type' = 'application/json'" -ForegroundColor White
Write-Host "    'x-api-key' = '$newSecret'" -ForegroundColor Yellow
Write-Host "}`n" -ForegroundColor White

Write-Host "`$body = @{" -ForegroundColor White
Write-Host "    to = @('faizalbashafaizalbasha07@gmail.com')" -ForegroundColor White
Write-Host "    subject = 'Test Email'" -ForegroundColor White
Write-Host "    html = '<h1>Test</h1>'" -ForegroundColor White
Write-Host "} | ConvertTo-Json`n" -ForegroundColor White

Write-Host "Invoke-RestMethod -Uri 'https://al-mathina-email.vercel.app/api/send-email' -Method POST -Headers `$headers -Body `$body`n" -ForegroundColor Green

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
