# 🔧 Solution rapide pour corriger l'erreur InvalidKeyMapError

## Problème
L'erreur `InvalidKeyMapError` apparaît car la clé API Google Maps n'est pas injectée dans `web/index.html` en mode développement.

## Solution rapide (pour tester immédiatement)

### Option 1 : Utiliser le script de développement (recommandé)

```bash
# Windows PowerShell
$env:GOOGLE_MAPS_API_KEY='AIzaSyCi6gk88a0y91dRMBpSxpuCHl24tt4fXFo'
cd flutter_app
.\scripts\run_web_dev.ps1
```

### Option 2 : Remplacer temporairement dans index.html

1. Ouvrez `flutter_app/web/index.html`
2. Remplacez `GOOGLE_MAPS_API_KEY_PLACEHOLDER` par votre clé API
3. Lancez `flutter run -d chrome`
4. ⚠️ **IMPORTANT** : Remettez `GOOGLE_MAPS_API_KEY_PLACEHOLDER` avant de commiter !

## Solution pour Android

La clé est déjà dans `android/local.properties`, donc Android devrait fonctionner. Si ce n'est pas le cas :

1. Vérifiez que `android/local.properties` contient :
   ```
   GOOGLE_MAPS_API_KEY=AIzaSyCi6gk88a0y91dRMBpSxpuCHl24tt4fXFo
   ```

2. Rebuild l'app :
   ```bash
   cd flutter_app
   flutter clean
   flutter pub get
   flutter run
   ```

## Solution pour Flutter/Dart (code)

Si vous utilisez `ApiConfig.googleMapsApiKey` dans votre code Dart, lancez avec :

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyCi6gk88a0y91dRMBpSxpuCHl24tt4fXFo
```

## Vérification

Après avoir appliqué la solution, Google Maps devrait se charger correctement sans l'erreur `InvalidKeyMapError`.









