# ⚠️ Sécurité - Clés API

## Clé API Google Maps

La clé API Google Maps est maintenant sécurisée dans les fichiers suivants :

### Android
- **Fichier** : `flutter_app/android/local.properties`
- **Variable** : `GOOGLE_MAPS_API_KEY`
- **Statut** : ✅ Sécurisé (dans `.gitignore`)

### Flutter (Dart)
- **Fichier** : `flutter_app/lib/config/api_config.dart`
- **Variable** : `ApiConfig.googleMapsApiKey`
- **Statut** : ⚠️ **ATTENTION** - La clé est encore en dur dans le code
- **Recommandation** : Utiliser une variable d'environnement au build ou migrer vers un proxy backend

### Web
- **Fichier** : `flutter_app/web/index.html`
- **Statut** : ✅ Sécurisé - Utilise un placeholder remplacé au build
- **Scripts de build** :
  - Linux/Mac : `flutter_app/scripts/build_web.sh`
  - Windows PowerShell : `flutter_app/scripts/build_web.ps1`
  - Windows CMD : `flutter_app/scripts/build_web.bat`
- **Usage** :
  ```bash
  # Linux/Mac
  export GOOGLE_MAPS_API_KEY='votre-cle-api'
  ./flutter_app/scripts/build_web.sh
  
  # Windows PowerShell
  $env:GOOGLE_MAPS_API_KEY='votre-cle-api'
  .\flutter_app\scripts\build_web.ps1
  
  # Windows CMD
  set GOOGLE_MAPS_API_KEY=votre-cle-api
  flutter_app\scripts\build_web.bat
  ```

## Actions à faire

1. ✅ **Android** : Clé déplacée dans `local.properties` (déjà fait)
2. ⚠️ **Flutter** : Remplacer la clé en dur par une variable d'environnement
3. ⚠️ **Web** : Injecter la clé au build depuis une variable d'environnement

## Pour obtenir une nouvelle clé API

Si la clé actuelle a été compromise :
1. Allez sur [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
2. Créez une nouvelle clé API
3. Configurez les restrictions (domaines, IPs, etc.)
4. Remplacez l'ancienne clé dans `local.properties` et `api_config.dart`

## Note importante

⚠️ **La clé API Google Maps côté client peut être exposée** car elle est visible dans le code compilé. Pour une sécurité maximale :
- Utilisez les restrictions de clé API dans Google Cloud Console
- Limitez les quotas par jour
- Considérez l'utilisation d'un proxy backend pour les requêtes sensibles

