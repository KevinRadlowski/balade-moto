@echo off
REM Script pour lancer Flutter Web en mode développement avec injection de la clé API (Windows CMD)
REM Usage: scripts\run_web_dev.bat

REM Vérifier que la clé API est définie
if "%GOOGLE_MAPS_API_KEY%"=="" (
    echo ⚠️  Erreur: La variable d'environnement GOOGLE_MAPS_API_KEY n'est pas définie
    echo    Définissez-la avec: set GOOGLE_MAPS_API_KEY=votre-cle-api
    exit /b 1
)

REM Sauvegarder le fichier original
echo 🔧 Injection de la clé API Google Maps dans index.html...
copy web\index.html web\index.html.bak >nul

REM Remplacer le placeholder (nécessite PowerShell)
powershell -Command "(Get-Content web\index.html) -replace 'GOOGLE_MAPS_API_KEY_PLACEHOLDER', '%GOOGLE_MAPS_API_KEY%' | Set-Content web\index.html"

REM Lancer Flutter en mode développement
echo 🚀 Lancement de Flutter Web en mode développement...
flutter run -d chrome

REM Restaurer le fichier original (sans la clé) après la fermeture
echo 🔒 Restauration du fichier index.html original...
move /Y web\index.html.bak web\index.html >nul

echo ✅ Terminé!




