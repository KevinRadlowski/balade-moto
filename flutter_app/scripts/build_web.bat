@echo off
REM Script de build pour Flutter Web avec injection de la clé API Google Maps (Windows CMD)
REM Usage: scripts\build_web.bat

REM Vérifier que la clé API est définie
if "%GOOGLE_MAPS_API_KEY%"=="" (
    echo ⚠️  Erreur: La variable d'environnement GOOGLE_MAPS_API_KEY n'est pas définie
    echo    Définissez-la avec: set GOOGLE_MAPS_API_KEY=votre-cle-api
    exit /b 1
)

REM Sauvegarder le fichier original
echo 🔧 Injection de la clé API Google Maps dans index.html...
copy web\index.html web\index.html.bak >nul

REM Remplacer le placeholder (nécessite PowerShell ou un outil de remplacement)
powershell -Command "(Get-Content web\index.html) -replace 'GOOGLE_MAPS_API_KEY_PLACEHOLDER', '%GOOGLE_MAPS_API_KEY%' | Set-Content web\index.html"

REM Build Flutter Web
echo 🏗️  Build Flutter Web...
flutter build web

REM Restaurer le fichier original (sans la clé)
echo 🔒 Restauration du fichier index.html original...
move /Y web\index.html.bak web\index.html >nul

echo ✅ Build terminé avec succès!










