# Correction Flutter Web - Erreur localhost:5000

## Problème
L'application Flutter Web essaie toujours de se connecter à `localhost:5000` au lieu de `192.168.1.70:5000` depuis l'iPhone.

## Solution

### 1. Vérifier la configuration
Le fichier `flutter_app/lib/config/api_config.dart` doit contenir :
```dart
static const String apiBaseUrl = 'http://192.168.1.70:5000';
```

### 2. Rebuild l'application Flutter Web
```bash
cd flutter_app
flutter clean
flutter pub get
flutter build web --release
```

### 3. Redémarrer le serveur http-server
Arrêtez l'ancien serveur (Ctrl+C) et redémarrez-le :
```bash
cd flutter_app\build\web
npx http-server -p 8080 -a 192.168.1.70
```

### 4. Vider le cache du navigateur Safari sur iPhone
**Important** : Safari sur iPhone cache les fichiers JavaScript. Vous devez vider le cache :

**Option 1 - Navigation privée (recommandé pour tester) :**
- Ouvrir Safari en navigation privée
- Aller sur `http://192.168.1.70:8080`

**Option 2 - Vider le cache :**
- Réglages > Safari > Effacer l'historique et les données de sites web
- Ou : Réglages > Safari > Avancé > Données de sites web > Supprimer tout

**Option 3 - Forcer le rechargement :**
- Maintenir le bouton de rechargement dans Safari
- Choisir "Recharger sans le contenu en cache"

### 5. Vérifier dans les logs
Si l'erreur persiste, vérifiez dans la console du navigateur (si accessible) ou dans les logs serveur que :
- L'URL utilisée est bien `http://192.168.1.70:5000/api/auth/login`
- Pas `http://localhost:5000/api/auth/login`

## Vérification rapide

1. **Vérifier le fichier source** :
   ```bash
   # Dans flutter_app/lib/config/api_config.dart
   # Doit contenir : static const String apiBaseUrl = 'http://192.168.1.70:5000';
   ```

2. **Vérifier le build** :
   ```bash
   # Le build doit être récent (après le changement de api_config.dart)
   ```

3. **Tester l'API directement** :
   - Depuis l'iPhone Safari : `http://192.168.1.70:5000/health`
   - Doit retourner un JSON avec `"success": true`

4. **Tester le front** :
   - Depuis l'iPhone Safari : `http://192.168.1.70:8080`
   - L'application doit se charger

## Si le problème persiste

1. **Vérifier que le serveur http-server sert bien les nouveaux fichiers** :
   - Arrêter complètement le serveur
   - Redémarrer avec la commande exacte
   - Vérifier que les fichiers dans `build/web` sont à jour

2. **Vérifier les logs serveur Express** :
   - Vous devriez voir les requêtes arriver avec l'origine `http://192.168.1.70:8080`
   - Si vous voyez `localhost:8080`, c'est que le cache du navigateur n'a pas été vidé

3. **Test en navigation privée** :
   - C'est le moyen le plus sûr de tester sans cache

## Commandes complètes

```bash
# 1. Nettoyer et rebuilder
cd C:\dev\balades_moto\flutter_app
flutter clean
flutter pub get
flutter build web --release

# 2. Servir le front
cd build\web
npx http-server -p 8080 -a 192.168.1.70

# 3. Dans un autre terminal, démarrer le backend
cd C:\dev\balades_moto
npm start
```



