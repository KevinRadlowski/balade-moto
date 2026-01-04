#!/bin/bash
# Script de scan de secrets dans le repository
# Utilise gitleaks si disponible, sinon fait un scan basique

set -e

echo "🔍 Scan de secrets dans le repository..."

# Vérifier si gitleaks est installé
if command -v gitleaks &> /dev/null; then
    echo "✅ Utilisation de gitleaks..."
    gitleaks detect --source . --verbose --no-banner
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Aucun secret détecté"
    else
        echo "❌ Secrets potentiels détectés !"
        exit 1
    fi
else
    echo "⚠️  gitleaks non installé, scan basique..."
    echo "💡 Installez gitleaks: https://github.com/gitleaks/gitleaks"
    
    # Scan basique pour les patterns évidents
    PATTERNS=(
        "JWT_SECRET="
        "JWT_REFRESH_SECRET="
        "GOOGLE_MAPS_API_KEY="
        "EMAIL_PASS="
        "MONGO_URI=mongodb.*://.*:.*@"
        "password.*=.*[a-zA-Z0-9]{20,}"
        "secret.*=.*[a-zA-Z0-9]{20,}"
        "api[_-]?key.*=.*[a-zA-Z0-9]{20,}"
    )
    
    FOUND_SECRETS=0
    
    for pattern in "${PATTERNS[@]}"; do
        if grep -r -i --exclude-dir=node_modules --exclude-dir=.git --exclude="*.example" "$pattern" . 2>/dev/null; then
            echo "⚠️  Pattern suspect trouvé: $pattern"
            FOUND_SECRETS=1
        fi
    done
    
    if [ $FOUND_SECRETS -eq 0 ]; then
        echo "✅ Aucun pattern suspect détecté (scan basique)"
    else
        echo "❌ Patterns suspects détectés ! Vérifiez manuellement."
        exit 1
    fi
fi

echo "✅ Scan terminé"




