# Configuration des variables d'environnement

## Clé API Google Maps

La clé API Google Maps est maintenant requise pour l'application Flutter.

### Configuration

#### Option 1 : Via la ligne de commande (recommandé pour le développement)

```bash
# Linux/Mac
export GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'
flutter run

# Windows PowerShell
$env:GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'
flutter run

# Windows CMD
set GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps
flutter run
```

#### Option 2 : Via --dart-define (recommandé pour CI/CD)

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps
flutter build web --dart-define=GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps
```

#### Option 3 : Configuration dans l'IDE

**VS Code** : Créez un fichier `.vscode/launch.json` :
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps"
      ]
    }
  ]
}
```

**Android Studio / IntelliJ** : 
1. Run → Edit Configurations
2. Ajoutez dans "Additional run args" : `--dart-define=GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps`

### Obtenir une clé API Google Maps

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
2. Créez un projet ou sélectionnez un projet existant
3. Activez les APIs nécessaires :
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API
   - Places API
4. Créez une clé API
5. Configurez les restrictions (domaines, IPs, etc.) pour la sécurité

### Sécurité

⚠️ **Important** : Ne commitez jamais votre clé API dans Git !

- La clé est maintenant requise au runtime (pas de valeur par défaut)
- Configurez les restrictions dans Google Cloud Console
- Limitez les quotas par jour
- Utilisez des clés différentes pour dev/staging/prod





