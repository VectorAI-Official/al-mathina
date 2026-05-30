# Quick Deploy Script for Vercel Email Webhook

Write-Host "`n🚀 AL-Madhina Email Webhook Deployment`n" -ForegroundColor Cyan

# Step 1: Check if Vercel CLI is installed
Write-Host "📦 Step 1: Checking Vercel CLI..." -ForegroundColor Yellow
if (!(Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Vercel CLI not found. Installing..." -ForegroundColor Red
    npm install -g vercel
} else {
    Write-Host "✅ Vercel CLI found`n" -ForegroundColor Green
}

# Step 2: Navigate to webhook directory
Set-Location -Path "email-webhook"
Write-Host "📁 Step 2: In email-webhook directory`n" -ForegroundColor Yellow

# Step 3: Generate API Secret
Write-Host "🔐 Step 3: Generating API Secret..." -ForegroundColor Yellow
$apiSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
Write-Host "✅ Generated API Secret: $apiSecret" -ForegroundColor Green
Write-Host "⚠️  SAVE THIS SECRET - You'll need it for Render!`n" -ForegroundColor Yellow

# Step 4: Deploy to Vercel
Write-Host "🚀 Step 4: Deploying to Vercel..." -ForegroundColor Yellow
Write-Host "When prompted, accept defaults and create new project.`n" -ForegroundColor Cyan
vercel deploy --prod

Write-Host "`n✅ Deployment complete!`n" -ForegroundColor Green

# Step 5: Instructions
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "*" * 60 -ForegroundColor Cyan
Write-Host "📋 NEXT STEPS:`n" -ForegroundColor Cyan

Write-Host "1️⃣  Go to Vercel Dashboard: https://vercel.com/dashboard" -ForegroundColor White
Write-Host "2️⃣  Click your project → Settings → Environment Variables" -ForegroundColor White
Write-Host "3️⃣  Add these 3 variables:`n" -ForegroundColor White

Write-Host "   SMTP_USER = almathina64@gmail.com" -ForegroundColor Yellow
Write-Host "   SMTP_PASSWORD = cgpj fbdz srve oqhn" -ForegroundColor Yellow
Write-Host "   API_SECRET = $apiSecret`n" -ForegroundColor Yellow

Write-Host "4️⃣  Redeploy: " -NoNewline -ForegroundColor White
Write-Host "vercel deploy --prod`n" -ForegroundColor Green

Write-Host "5️⃣  Note your Vercel URL (shown above)" -ForegroundColor White
Write-Host "6️⃣  Add to Render environment:`n" -ForegroundColor White

Write-Host "   EMAIL_WEBHOOK_URL = https://YOUR_VERCEL_URL/api/send-email" -ForegroundColor Yellow
Write-Host "   EMAIL_WEBHOOK_SECRET = $apiSecret" -ForegroundColor Yellow
Write-Host "   ADMIN_EMAIL = faizalbashafaizalbasha07@gmail.com,sathishsuba2208@gmail.com,abuarsath30@gmail.com`n" -ForegroundColor Yellow

Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "*" * 60 -ForegroundColor Cyan
Write-Host ""
