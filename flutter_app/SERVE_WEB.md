# Comment servir Flutter Web correctement

## Problème : Erreur 404 pour AssetManifest.bin.json

Cette erreur survient quand le serveur http-server ne sert pas correctement les fichiers depuis le bon répertoire.

## Solution

### 1. S'assurer d'être dans le bon répertoire

```bash
cd flutter_app\build\web
```

### 2. Vérifier que les fichiers existent

Vous devriez voir :
- `assets/AssetManifest.bin.json`
- `assets/AssetManifest.bin`
- `main.dart.js`
- `flutter_bootstrap.js`
- `index.html`

### 3. Servir avec http-server

**Option A - Sur l'IP LAN spécifique (recommandé pour iPhone) :**
```bash
npx http-server -p 8080 -a 192.168.1.70 -c-1
```

**Option B - Sur toutes les interfaces :**
```bash
npx http-server -p 8080 -a 0.0.0.0 -c-1
```

**Option C - Avec cache désactivé (pour le développement) :**
```bash
npx http-server -p 8080 -a 192.168.1.70 -c-1 --cors
```

### Paramètres importants :
- `-p 8080` : Port 8080
- `-a 192.168.1.70` : Adresse IP (ou `0.0.0.0` pour toutes les interfaces)
- `-c-1` : Désactiver le cache (important pour le développement)
- `--cors` : Activer CORS (optionnel, mais peut aider)

### 4. Vérifier que le serveur fonctionne

Depuis votre navigateur (même machine) :
- `http://localhost:8080` doit charger l'application
- `http://localhost:8080/assets/AssetManifest.bin.json` doit retourner le fichier JSON

Depuis l'iPhone :
- `http://192.168.1.70:8080` doit charger l'application
- `http://192.168.1.70:8080/assets/AssetManifest.bin.json` doit retourner le fichier JSON

## Alternative : Utiliser Python HTTP Server

Si http-server ne fonctionne pas correctement :

```bash
cd flutter_app\build\web
python -m http.server 8080 --bind 192.168.1.70
```

Ou avec Python 3 :
```bash
python3 -m http.server 8080 --bind 192.168.1.70
```

## Dépannage

### Erreur 404 pour assets/AssetManifest.bin.json

1. **Vérifier le répertoire de travail** :
   ```bash
   # Vous devez être dans flutter_app\build\web
   pwd  # ou cd sur Windows
   ls assets  # ou dir assets sur Windows
   ```

2. **Vérifier que le build est complet** :
   ```bash
   cd flutter_app
   flutter build web --release
   ```

3. **Vérifier les permissions** :
   - Assurez-vous que le serveur peut lire les fichiers
   - Sur Windows, vérifiez les permissions du dossier

4. **Tester avec un autre serveur** :
   - Essayez Python HTTP Server (voir ci-dessus)
   - Ou utilisez `serve` : `npx serve -p 8080 -l 192.168.1.70`

### Erreur CORS pour localhost:51135

Cette erreur est normale si vous utilisez Flutter dev server (hot reload). La configuration CORS a été mise à jour pour autoriser tous les ports localhost en développement.

Si l'erreur persiste :
1. Vérifiez que `NODE_ENV=development` (ou non défini)
2. Redémarrez le serveur Express



