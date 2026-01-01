# Guide de correction du build Flutter Web sur Windows

## Problème identifié
- **Erreur principale** : `ShaderCompilerException` - Impossible d'écrire les fichiers shaders
- **Cause probable** : Chemin du projet contenant des espaces et caractères non-ASCII (`Développement`)
- **Warnings secondaires** : `file_picker:* inline implementation` et `FlutterLoader.loadEntrypoint deprecated`

---

## ✅ ÉTAPE A : Correction de l'erreur d'écriture des shaders

### Solution 1 : Nettoyage complet (à essayer en premier)

```powershell
# Depuis le dossier flutter_app
cd flutter_app

# 1. Supprimer le dossier build
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue

# 2. Nettoyer Flutter
flutter clean

# 3. Récupérer les dépendances
flutter pub get

# 4. Tenter le build
flutter build web --release --no-wasm-dry-run
```

### Solution 2 : Vérifier Windows Defender (si Solution 1 échoue)

1. Ouvrir **Paramètres Windows** > **Confidentialité et sécurité** > **Sécurité Windows**
2. Cliquer sur **Protection contre les virus et menaces**
3. Cliquer sur **Gérer les paramètres** (sous Paramètres de protection contre les virus et menaces)
4. Scroller jusqu'à **Accès contrôlé aux dossiers**
5. Cliquer sur **Gérer l'accès contrôlé aux dossiers**
6. **Option A** : Désactiver temporairement l'accès contrôlé
7. **Option B** : Ajouter une exclusion pour :
   - `D:\Users\kevin\Desktop\Développement\Projets\Balades Moto\flutter_app`
   - Ou mieux : `D:\Users\kevin\Desktop\Développement\Projets\Balades Moto`

### Solution 3 : Déplacer le projet (RECOMMANDÉ si Solutions 1-2 échouent)

Le problème vient probablement du chemin avec espaces et caractères accentués. **Solution la plus fiable** :

```powershell
# 1. Créer un nouveau dossier avec chemin court ASCII
New-Item -ItemType Directory -Path "C:\dev\balades_moto" -Force

# 2. Copier le projet (sans le dossier build)
robocopy "D:\Users\kevin\Desktop\Développement\Projets\Balades Moto" "C:\dev\balades_moto" /E /XD build node_modules .dart_tool

# 3. Aller dans le nouveau dossier
cd C:\dev\balades_moto\flutter_app

# 4. Nettoyer et build
flutter clean
flutter pub get
flutter build web --release --no-wasm-dry-run
```

**Note** : Après le déplacement, mettez à jour :
- Les chemins dans votre IDE (VS Code, Android Studio)
- Les raccourcis/scripts qui pointent vers l'ancien chemin
- Les variables d'environnement si nécessaire

---

## ✅ ÉTAPE B : Correction des warnings file_picker

### Modifications dans `pubspec.yaml`

**Avant** :
```yaml
file_picker: ^6.1.1
```

**Après** :
```yaml
file_picker: ^8.1.2
```

### Commandes à exécuter

```powershell
cd flutter_app
flutter pub upgrade file_picker
flutter pub get
```

### Vérification

Les warnings `file_picker:* inline implementation` devraient disparaître. Si ils persistent :
- C'est un warning connu du package, non bloquant
- Le build fonctionnera quand même
- Attendre une mise à jour du package file_picker

---

## ✅ ÉTAPE C : Correction du warning FlutterLoader

### Modifications dans `web/index.html`

**Avant** (déprécié) :
```html
<script>
  window.addEventListener('load', function(ev) {
    if (typeof _flutter !== 'undefined' && _flutter.loader) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: null,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    }
  });
</script>
```

**Après** (moderne) :
```html
<script>
  window.addEventListener('load', function(ev) {
    _flutter.loader.load({
      serviceWorkerSettings: {
        serviceWorkerVersion: null,
      },
    }).then(function(engineInitializer) {
      return engineInitializer.initializeEngine();
    }).then(function(appRunner) {
      return appRunner.runApp();
    });
  });
</script>
```

**Changements** :
- `loadEntrypoint()` → `load()`
- `serviceWorker` → `serviceWorkerSettings`
- `onEntrypointLoaded` callback → chaînage de Promises avec `.then()`

---

## 📋 Checklist d'exécution

### Priorité 1 : Résoudre l'erreur de build

- [ ] Exécuter `flutter clean` et `flutter pub get`
- [ ] Vérifier Windows Defender (désactiver ou ajouter exclusion)
- [ ] Si échec : Déplacer le projet vers `C:\dev\balades_moto` (chemin ASCII)
- [ ] Relancer `flutter build web --release --no-wasm-dry-run`
- [ ] Confirmer que le build réussit

### Priorité 2 : Corriger les warnings (après build réussi)

- [ ] Mettre à jour `file_picker` à `^8.1.2` dans `pubspec.yaml`
- [ ] Exécuter `flutter pub upgrade file_picker` et `flutter pub get`
- [ ] Modifier `web/index.html` pour utiliser `FlutterLoader.load()`
- [ ] Vérifier que le build fonctionne toujours après modifications

---

## 🔍 Diagnostic supplémentaire

Si le problème persiste après toutes ces étapes :

1. **Vérifier les processus verrouillants** :
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -like "*flutter*" -or $_.ProcessName -like "*dart*" } | Stop-Process -Force
   ```

2. **Vérifier les permissions du dossier** :
   ```powershell
   icacls "D:\Users\kevin\Desktop\Développement\Projets\Balades Moto\flutter_app"
   ```

3. **Vérifier l'espace disque** :
   ```powershell
   Get-PSDrive C | Select-Object Used,Free
   ```

4. **Vérifier la version Flutter** :
   ```powershell
   flutter --version
   flutter doctor -v
   ```

---

## 📝 Résumé des modifications

### Fichiers modifiés :

1. **`pubspec.yaml`** :
   - `file_picker: ^6.1.1` → `file_picker: ^8.1.2`

2. **`web/index.html`** :
   - Remplacement de `loadEntrypoint()` par `load()`
   - Modernisation de l'initialisation Flutter

### Commandes à exécuter (dans l'ordre) :

```powershell
# Depuis flutter_app
cd flutter_app

# Nettoyage
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
flutter clean
flutter pub get

# Mise à jour file_picker
flutter pub upgrade file_picker

# Build
flutter build web --release --no-wasm-dry-run
```

---

## ✅ Résultat attendu

- ✅ Build web réussi sans erreur `ShaderCompilerException`
- ✅ Warnings `file_picker:*` réduits ou éliminés
- ✅ Warning `FlutterLoader.loadEntrypoint deprecated` éliminé
- ✅ Application web fonctionnelle dans `build/web/`

