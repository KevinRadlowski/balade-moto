# Script de build pour Flutter Web avec injection de la clé API Google Maps (Windows PowerShell)
# Usage: .\scripts\build_web.ps1

# Vérifier que la clé API est définie
if (-not $env:GOOGLE_MAPS_API_KEY) {
    Write-Host "⚠️  Erreur: La variable d'environnement GOOGLE_MAPS_API_KEY n'est pas définie" -ForegroundColor Red
    Write-Host "   Définissez-la avec: `$env:GOOGLE_MAPS_API_KEY='votre-cle-api'" -ForegroundColor Yellow
    exit 1
}

# Sauvegarder le fichier original
Write-Host "🔧 Injection de la clé API Google Maps dans index.html..." -ForegroundColor Cyan
$indexHtmlPath = "web\index.html"
$backupPath = "$indexHtmlPath.bak"
Copy-Item $indexHtmlPath $backupPath

# Remplacer le placeholder
$content = Get-Content $indexHtmlPath -Raw
$content = $content -replace "GOOGLE_MAPS_API_KEY_PLACEHOLDER", $env:GOOGLE_MAPS_API_KEY
Set-Content $indexHtmlPath -Value $content -NoNewline

# Build Flutter Web
Write-Host "🏗️  Build Flutter Web..." -ForegroundColor Cyan
flutter build web

# Restaurer le fichier original (sans la clé)
Write-Host "🔒 Restauration du fichier index.html original..." -ForegroundColor Cyan
Move-Item $backupPath $indexHtmlPath -Force

Write-Host "✅ Build terminé avec succès!" -ForegroundColor Green







