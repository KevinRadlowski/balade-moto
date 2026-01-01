# Application Flutter - Balades Moto

Application mobile Flutter pour gérer et participer aux balades moto.

## Prérequis

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / Xcode (pour les émulateurs)
- Backend Express.js en cours d'exécution

## Installation

1. Installer les dépendances :
```bash
cd flutter_app
flutter pub get
```

2. Configurer l'URL de l'API dans `lib/config/api_config.dart` :
```dart
static const String apiBaseUrl = 'http://192.168.56.1:5000';
// ou votre IP Wi-Fi locale (ex: 'http://192.168.1.70:5000')
```

**⚠️ Important pour Flutter Web depuis un autre appareil (iPhone, etc.) :**
- Ne pas utiliser `localhost:5000` car cela ne fonctionnera pas depuis un autre appareil
- Utiliser l'IP locale de votre PC (trouvez-la avec `ipconfig` sur Windows ou `ifconfig` sur Mac/Linux)
- Exemple : si votre PC a l'IP `192.168.56.1`, utilisez `http://192.168.56.1:5000`

## Structure du projet

```
lib/
├── main.dart                 # Point d'entrée
├── models/                   # Modèles de données
│   ├── user.dart
│   └── ride.dart
├── services/                 # Services (API, Auth, Storage)
│   ├── api_service.dart
│   └── auth_service.dart
├── screens/                  # Écrans de l'application
│   ├── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   └── ride/
│       ├── ride_detail_screen.dart
│       └── filters_sheet.dart
└── widgets/                  # Widgets réutilisables (à créer)
```

## Fonctionnalités

- ✅ Authentification (login/register) avec validation
- ✅ Stockage sécurisé des tokens JWT
- ✅ Liste des balades à venir avec cards
- ✅ Détails d'une balade
- ✅ Actions : Participer, Aimer, Noter
- ✅ Filtres : type de véhicule, date, recherche
- ⏳ Filtres avancés : rayon, lieu (Google Maps) - À implémenter

## Lancement

```bash
flutter run
```

## Notes

- Les filtres par rayon et lieu (Google Maps) nécessitent une clé API Google Maps
- Pour activer Google Maps, ajoutez votre clé API dans `android/app/src/main/AndroidManifest.xml` et `ios/Runner/AppDelegate.swift`



