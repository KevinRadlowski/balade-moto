# Instructions de rebuild Flutter Web

## Commandes à exécuter (dans l'ordre)

```powershell
# 1. Aller dans le dossier flutter_app
cd flutter_app

# 2. Nettoyer le build précédent
flutter clean

# 3. Récupérer les dépendances
flutter pub get

# 4. Build web en mode release
flutter build web --release
```

## Vérification du serveur

Assurez-vous que votre serveur sur `http://192.168.1.70:8080` sert bien les fichiers suivants :

- ✅ `/flutter_bootstrap.js` (généré par Flutter)
- ✅ `/flutter.js` (généré par Flutter)
- ✅ `/main.dart.js` (généré par Flutter)
- ✅ `/assets/` (dossier avec les assets)
- ✅ `/manifest.json` (copié depuis web/)
- ✅ `/canvaskit/` (dossier avec les fichiers CanvasKit)

### Si vous utilisez un serveur HTTP simple

Exemple avec Python :
```powershell
cd flutter_app\build\web
python -m http.server 8080 --bind 192.168.1.70
```

Exemple avec Node.js (http-server) :
```powershell
cd flutter_app\build\web
npx http-server -p 8080 -a 192.168.1.70
```

## Résultat attendu

Après le rebuild et le redémarrage du serveur :
- ✅ L'erreur `FlutterLoader.load requires _flutter.buildConfig to be set` devrait disparaître
- ✅ L'erreur `favicon.png 404` devrait disparaître (ou être remplacée par une erreur sur `icons/Icon-192.png` si les icônes ne sont pas présentes)
- ✅ L'application Flutter devrait se charger correctement

## Note sur ERR_BLOCKED_BY_CLIENT

L'erreur `ERR_BLOCKED_BY_CLIENT` est typiquement causée par :
- Une extension de navigateur (AdBlock, uBlock Origin, Brave Shields, etc.)
- Pour la désactiver : ajoutez `192.168.1.70` aux exceptions de votre extension
- Cette erreur n'est **pas** causée par le code de l'application



