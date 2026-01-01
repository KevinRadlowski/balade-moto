# Correction des erreurs 404 pour les assets Flutter Web

## Problème identifié

L'application essaie de charger les assets depuis `localhost:51135` au lieu de `192.168.1.70:8080`. Cela indique :
- Soit un service worker avec une ancienne configuration en cache
- Soit un serveur de développement Flutter (`flutter run`) qui tourne encore

## Solution complète

### 1. Arrêter tous les serveurs Flutter en cours

**Important** : Vérifiez qu'aucun `flutter run -d web` ou `flutter run` ne tourne.

```bash
# Vérifier les processus Flutter
# Sur Windows PowerShell :
Get-Process | Where-Object {$_.ProcessName -like "*flutter*" -or $_.ProcessName -like "*dart*"}

# Arrêter tous les processus Flutter si nécessaire
# Fermez tous les terminaux qui exécutent Flutter
```

### 2. Désactiver/réinitialiser le service worker dans le navigateur

**Sur Safari iPhone** :
1. Ouvrir Safari
2. Réglages > Safari > Avancé > Données de sites web
3. Trouver `192.168.1.70:8080` (ou votre IP)
4. Faire glisser vers la gauche et supprimer
5. Ou : Réglages > Safari > Effacer l'historique et les données de sites web

**Alternative - Navigation privée** :
- Utiliser Safari en navigation privée pour éviter le cache du service worker

### 3. Vérifier que vous servez le build RELEASE, pas le mode dev

**IMPORTANT** : Utilisez le build release, pas `flutter run` :

```bash
# 1. Nettoyer
cd flutter_app
flutter clean

# 2. Build en mode RELEASE
flutter build web --release

# 3. Vérifier que les fichiers existent
cd build\web
dir assets  # Doit afficher AssetManifest.bin.json
```

### 4. Servir avec http-server depuis le bon répertoire

```bash
# Vous DEVEZ être dans flutter_app\build\web
cd flutter_app\build\web

# Vérifier que vous êtes au bon endroit
dir  # Doit afficher index.html, main.dart.js, assets/, etc.

# Servir avec http-server
npx http-server -p 8080 -a 192.168.1.70 -c-1
```

**Paramètres importants** :
- `-p 8080` : Port 8080
- `-a 192.168.1.70` : Adresse IP LAN
- `-c-1` : **Désactiver le cache** (crucial pour éviter les problèmes de service worker)

### 5. Vérifier que les assets sont accessibles

**Test depuis votre navigateur (même machine)** :
- `http://localhost:8080/assets/AssetManifest.bin.json` → Doit retourner le JSON
- `http://localhost:8080/assets/FontManifest.json` → Doit retourner le JSON

**Test depuis iPhone Safari** :
- `http://192.168.1.70:8080/assets/AssetManifest.bin.json` → Doit retourner le JSON
- `http://192.168.1.70:8080/assets/FontManifest.json` → Doit retourner le JSON

### 6. Si le problème persiste : Désactiver le service worker

Modifiez temporairement `flutter_app/build/web/index.html` pour désactiver le service worker :

```html
<!-- Commenter ou supprimer cette ligne dans flutter_bootstrap.js -->
<!-- Ou modifier flutter_bootstrap.js pour ne pas charger le service worker -->
```

**Solution rapide** : Ajouter ceci dans `index.html` avant le script flutter_bootstrap.js :

```html
<script>
  // Désactiver le service worker pour le développement
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
      for(let registration of registrations) {
        registration.unregister();
      }
    });
  }
</script>
```

## Checklist de vérification

- [ ] Aucun `flutter run` ne tourne
- [ ] Build release effectué : `flutter build web --release`
- [ ] Serveur http-server lancé depuis `flutter_app\build\web`
- [ ] Paramètre `-c-1` utilisé pour désactiver le cache
- [ ] Service worker désactivé/réinitialisé dans le navigateur
- [ ] Test en navigation privée sur iPhone
- [ ] Assets accessibles directement via URL

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

## Note importante

Le port `51135` est le port du serveur de développement Flutter (DDC). Si vous voyez ce port dans les erreurs, c'est que :
1. Un `flutter run` tourne encore quelque part
2. Le service worker a mis en cache cette configuration
3. Le navigateur utilise une ancienne version en cache

**Solution** : Toujours utiliser le build release avec http-server, jamais `flutter run` pour la production.



