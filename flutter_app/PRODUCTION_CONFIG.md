# Configuration pour la production

## Configuration de l'URL de l'API

L'URL de l'API backend doit être configurée via une variable d'environnement Dart lors du build.

### Pour le build Web

```bash
flutter build web --dart-define=API_BASE_URL=https://api.ridetogether.fr
```

### Pour le build Android

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.ridetogether.fr
```

ou pour un bundle :

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://api.ridetogether.fr
```

### Pour le build iOS

```bash
flutter build ios --dart-define=API_BASE_URL=https://api.ridetogether.fr
```

### Pour le développement local

Par défaut, l'application utilise `http://localhost:5000`. Vous pouvez aussi spécifier une URL différente :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.70:5000
```

## Variables d'environnement disponibles

- `API_BASE_URL` : URL de base de l'API backend (ex: `https://api.ridetogether.fr`)
- `GOOGLE_MAPS_API_KEY` : Clé API Google Maps (requis)

## Exemple de build complet pour la production

```bash
# Build Web
flutter build web \
  --dart-define=API_BASE_URL=https://api.ridetogether.fr \
  --dart-define=GOOGLE_MAPS_API_KEY=votre-cle-google-maps

# Build Android
flutter build apk \
  --dart-define=API_BASE_URL=https://api.ridetogether.fr \
  --dart-define=GOOGLE_MAPS_API_KEY=votre-cle-google-maps
```

## Vérification

Après le build, vérifiez que l'application utilise bien l'URL de production en inspectant les requêtes réseau dans les DevTools du navigateur ou en vérifiant les logs de l'application.

