# Script de scan de secrets dans le repository (PowerShell)
# Utilise gitleaks si disponible, sinon fait un scan basique

Write-Host "🔍 Scan de secrets dans le repository..." -ForegroundColor Cyan

# Vérifier si gitleaks est installé
$gitleaksPath = Get-Command gitleaks -ErrorAction SilentlyContinue

if ($gitleaksPath) {
    Write-Host "✅ Utilisation de gitleaks..." -ForegroundColor Green
    gitleaks detect --source . --verbose --no-banner
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "✅ Aucun secret détecté" -ForegroundColor Green
    } else {
        Write-Host "❌ Secrets potentiels détectés !" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️  gitleaks non installé, scan basique..." -ForegroundColor Yellow
    Write-Host "💡 Installez gitleaks: https://github.com/gitleaks/gitleaks" -ForegroundColor Yellow
    
    # Scan basique pour les patterns évidents
    $patterns = @(
        "JWT_SECRET=",
        "JWT_REFRESH_SECRET=",
        "GOOGLE_MAPS_API_KEY=",
        "EMAIL_PASS=",
        "MONGO_URI=mongodb.*://.*:.*@",
        "password.*=.*[a-zA-Z0-9]{20,}",
        "secret.*=.*[a-zA-Z0-9]{20,}",
        "api[_-]?key.*=.*[a-zA-Z0-9]{20,}"
    )
    
    $foundSecrets = $false
    
    foreach ($pattern in $patterns) {
        $results = Get-ChildItem -Recurse -File -Exclude node_modules,.git,*.example | 
            Select-String -Pattern $pattern -CaseSensitive:$false -ErrorAction SilentlyContinue
        
        if ($results) {
            Write-Host "⚠️  Pattern suspect trouvé: $pattern" -ForegroundColor Yellow
            $foundSecrets = $true
        }
    }
    
    if (-not $foundSecrets) {
        Write-Host "✅ Aucun pattern suspect détecté (scan basique)" -ForegroundColor Green
    } else {
        Write-Host "❌ Patterns suspects détectés ! Vérifiez manuellement." -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Scan terminé" -ForegroundColor Green










