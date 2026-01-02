# Scripts de build et développement

## Scripts pour Flutter Web

### Scripts de développement (`run_web_dev.*`)

Ces scripts permettent de lancer l'application Flutter Web en mode développement avec injection automatique de la clé API Google Maps.

**Utilisation** :

#### Linux / macOS
```bash
export GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'
cd flutter_app
chmod +x scripts/run_web_dev.sh
./scripts/run_web_dev.sh
```

#### Windows PowerShell
```powershell
$env:GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'
cd flutter_app
.\scripts\run_web_dev.ps1
```

#### Windows CMD
```cmd
set GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps
cd flutter_app
scripts\run_web_dev.bat
```

### Scripts de build (`build_web.*`)

Ces scripts permettent de builder l'application Flutter Web en injectant automatiquement la clé API Google Maps depuis une variable d'environnement.

### Prérequis

1. Définir la variable d'environnement `GOOGLE_MAPS_API_KEY` avec votre clé API Google Maps
2. Avoir Flutter installé et configuré

### Utilisation

#### Linux / macOS

```bash
# Définir la variable d'environnement
export GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'

# Exécuter le script
cd flutter_app
chmod +x scripts/build_web.sh
./scripts/build_web.sh
```

#### Windows PowerShell

```powershell
# Définir la variable d'environnement
$env:GOOGLE_MAPS_API_KEY='votre-cle-api-google-maps'

# Exécuter le script
cd flutter_app
.\scripts\build_web.ps1
```

#### Windows CMD

```cmd
# Définir la variable d'environnement
set GOOGLE_MAPS_API_KEY=votre-cle-api-google-maps

# Exécuter le script
cd flutter_app
scripts\build_web.bat
```

### Fonctionnement

1. Le script vérifie que la variable `GOOGLE_MAPS_API_KEY` est définie
2. Il remplace le placeholder `GOOGLE_MAPS_API_KEY_PLACEHOLDER` dans `web/index.html` par la vraie clé
3. Il exécute `flutter build web`
4. Il restaure le fichier `index.html` original (sans la clé) pour éviter de commiter la clé

### Sécurité

- ✅ La clé n'est jamais commitée dans Git
- ✅ Le fichier `index.html` est restauré après le build
- ✅ Les fichiers `.bak` sont ignorés par Git
- ⚠️ La clé sera visible dans le build final (normal pour les clés API côté client)

### Note importante

Le build final (`build/web/index.html`) contiendra la clé API. C'est normal car les clés API Google Maps côté client sont toujours visibles dans le code compilé. Pour sécuriser davantage :

1. Configurez les restrictions de clé API dans [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
2. Limitez les quotas par jour
3. Restreignez la clé à des domaines/IP spécifiques

