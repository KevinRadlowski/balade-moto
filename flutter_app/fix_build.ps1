# Script de correction du build Flutter Web sur Windows
# Usage: .\fix_build.ps1

Write-Host "=== ÉTAPE A: Diagnostic et correction de l'erreur d'écriture ===" -ForegroundColor Cyan

# 1. Vérifier et supprimer le dossier build
Write-Host "`n1. Nettoyage du dossier build..." -ForegroundColor Yellow
if (Test-Path "build") {
    try {
        Remove-Item -Path "build" -Recurse -Force
        Write-Host "   ✓ Dossier build supprimé" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Erreur lors de la suppression: $_" -ForegroundColor Red
        Write-Host "   → Vérifiez que aucun processus ne verrouille le dossier" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "   ✓ Dossier build n'existe pas" -ForegroundColor Green
}

# 2. Flutter clean
Write-Host "`n2. Exécution de flutter clean..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ flutter clean terminé" -ForegroundColor Green
} else {
    Write-Host "   ✗ flutter clean a échoué" -ForegroundColor Red
    exit 1
}

# 3. Flutter pub get
Write-Host "`n3. Exécution de flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ flutter pub get terminé" -ForegroundColor Green
} else {
    Write-Host "   ✗ flutter pub get a échoué" -ForegroundColor Red
    exit 1
}

# 4. Vérifier Windows Defender Controlled Folder Access
Write-Host "`n4. Vérification de Windows Defender..." -ForegroundColor Yellow
Write-Host "   → Vérifiez manuellement dans:" -ForegroundColor Cyan
Write-Host "     Paramètres Windows > Confidentialité et sécurité > Sécurité Windows" -ForegroundColor Cyan
Write-Host "     > Protection contre les virus et menaces > Gérer les paramètres" -ForegroundColor Cyan
Write-Host "     > Accès contrôlé aux dossiers" -ForegroundColor Cyan
Write-Host "   → Désactivez temporairement OU ajoutez une exclusion pour:" -ForegroundColor Yellow
Write-Host "     - Ce dossier du projet" -ForegroundColor Yellow
Write-Host "     - Le dossier Flutter SDK (si nécessaire)" -ForegroundColor Yellow

# 5. Tentative de build avec renderer HTML (évite les shaders)
Write-Host "`n5. Tentative de build avec renderer HTML (évite les shaders)..." -ForegroundColor Yellow
flutter build web --release --web-renderer html
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Build réussi avec renderer HTML!" -ForegroundColor Green
    Write-Host "`n=== BUILD RÉUSSI ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "   ✗ Build avec renderer HTML a échoué" -ForegroundColor Red
}

# 6. Si HTML échoue, essayer CanvasKit avec chemin court
Write-Host "`n6. Le problème peut venir du chemin avec espaces/accents." -ForegroundColor Yellow
Write-Host "   → Solution recommandée: Déplacer le projet vers un chemin court sans espaces" -ForegroundColor Cyan
Write-Host "   → Exemple: C:\dev\balades_moto\flutter_app" -ForegroundColor Cyan
Write-Host "   → OU: D:\dev\balades_moto\flutter_app" -ForegroundColor Cyan

Write-Host "`n=== ÉTAPE A TERMINÉE ===" -ForegroundColor Cyan

