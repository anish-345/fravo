# PowerShell Helper Script for Firebase CLI & FlutterFire Configuration
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Fravo - Firebase & FlutterFire Setup CLI      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Firebase CLI
Write-Host "[1/3] Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if ($null -eq $firebaseCmd) {
    Write-Host "❌ Firebase CLI not found. Please install via: npm install -g firebase-tools" -ForegroundColor Red
} else {
    $fbVersion = firebase --version
    Write-Host "✅ Firebase CLI Version: $fbVersion" -ForegroundColor Green
}

# 2. Check FlutterFire CLI
Write-Host ""
Write-Host "[2/3] Checking FlutterFire CLI..." -ForegroundColor Yellow
$flutterfireCmd = Get-Command flutterfire -ErrorAction SilentlyContinue
if ($null -eq $flutterfireCmd) {
    Write-Host "⚠️ Global 'flutterfire' command not in PATH. Activating flutterfire_cli..." -ForegroundColor Yellow
    dart pub global activate flutterfire_cli
} else {
    Write-Host "✅ FlutterFire CLI is ready." -ForegroundColor Green
}

# 3. Prompt for configuration
Write-Host ""
Write-Host "[3/3] Running 'flutterfire configure' to update lib/firebase_options.dart..." -ForegroundColor Yellow
Write-Host "Make sure you are logged in using 'firebase login' before proceeding." -ForegroundColor Cyan
Write-Host ""

dart pub global run flutterfire_cli:flutterfire configure --project=fravo-app

Write-Host ""
Write-Host "Done! If successful, lib/firebase_options.dart has been configured with your live Firebase Project." -ForegroundColor Green
