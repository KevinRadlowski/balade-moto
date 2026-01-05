#!/bin/bash
# Script pour lancer Flutter Web en mode développement avec injection de la clé API
# Usage: ./scripts/run_web_dev.sh

set -e

# Vérifier que la clé API est définie
if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    echo "⚠️  Erreur: La variable d'environnement GOOGLE_MAPS_API_KEY n'est pas définie"
    echo "   Définissez-la avec: export GOOGLE_MAPS_API_KEY='votre-cle-api'"
    exit 1
fi

# Remplacer le placeholder dans index.html
echo "🔧 Injection de la clé API Google Maps dans index.html..."
sed -i.bak "s/GOOGLE_MAPS_API_KEY_PLACEHOLDER/$GOOGLE_MAPS_API_KEY/g" web/index.html

# Lancer Flutter en mode développement
echo "🚀 Lancement de Flutter Web en mode développement..."
flutter run -d chrome

# Restaurer le fichier original (sans la clé) après la fermeture
echo "🔒 Restauration du fichier index.html original..."
mv web/index.html.bak web/index.html






