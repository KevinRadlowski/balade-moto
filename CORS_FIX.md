# Correction CORS et Accès Réseau

## Modifications apportées

### 1. Configuration Express (src/app.js)

#### Écoute sur toutes les interfaces réseau
- Le serveur écoute maintenant sur `0.0.0.0` au lieu de `localhost`
- Accessible depuis n'importe quel appareil sur le réseau local

#### Configuration CORS améliorée
- Autorise explicitement `http://192.168.56.1:8080` et autres IPs réseau courantes
- Gère correctement les requêtes preflight OPTIONS
- Headers autorisés : `Content-Type`, `Authorization`, `X-Requested-With`

#### Endpoint de santé
- Nouveau endpoint `/health` pour tester l'accès depuis un autre appareil

### 2. Configuration Flutter (flutter_app/lib/config/api_config.dart)

Fichier centralisé pour la configuration de l'URL de l'API :
- `apiBaseUrl` : URL de base (par défaut : `http://192.168.56.1:5000`)
- `apiUrl` : URL complète pour les endpoints API
- `getFileUrl()` : Fonction helper pour construire les URLs de fichiers

### 3. Remplacement de localhost:5000

Tous les `http://localhost:5000` ont été remplacés par `ApiConfig` dans :
- `api_service.dart`
- `socket_service.dart`
- `chat_service.dart`
- Tous les fichiers screens (home, profile, groups, etc.)
- Tous les widgets (message_bubble, etc.)

## Instructions d'utilisation

### Côté Backend (Node.js)

1. **Trouver votre IP locale** :
   ```bash
   # Windows
   ipconfig
   # Cherchez "Adresse IPv4" (ex: 192.168.56.1)
   
   # Mac/Linux
   ifconfig
   # ou
   ip addr
   ```

2. **Démarrer le serveur** :
   ```bash
   npm start
   # ou
   npm run dev
   ```

3. **Vérifier l'accès** :
   - Depuis votre machine : `http://localhost:5000/health`
   - Depuis l'iPhone : `http://VOTRE_IP:5000/health`
   - Exemple : `http://192.168.56.1:5000/health`

### Côté Flutter

1. **Modifier l'URL de l'API** dans `flutter_app/lib/config/api_config.dart` :
   ```dart
   static const String apiBaseUrl = 'http://VOTRE_IP:5000';
   ```
   Remplacez `VOTRE_IP` par votre IP locale (ex: `192.168.56.1`)

2. **Rebuild l'application** :
   ```bash
   cd flutter_app
   flutter pub get
   flutter build web
   ```

3. **Servir l'application** :
   ```bash
   # Depuis flutter_app/build/web
   python -m http.server 8080 --bind 0.0.0.0
   # ou
   npx http-server -p 8080 -a 0.0.0.0
   ```

## Pourquoi localhost ne fonctionne pas depuis l'iPhone ?

`localhost` (ou `127.0.0.1`) fait référence à la machine locale elle-même. Quand vous accédez depuis un iPhone :
- L'iPhone essaie de se connecter à **son propre** localhost (l'iPhone lui-même)
- Pas à votre ordinateur de développement
- Il faut donc utiliser l'IP locale de votre machine sur le réseau

## Test de connexion

1. **Depuis l'iPhone**, ouvrez un navigateur et allez sur :
   ```
   http://VOTRE_IP:5000/health
   ```
   Vous devriez voir :
   ```json
   {
     "success": true,
     "message": "API accessible",
     "timestamp": "...",
     "origin": "..."
   }
   ```

2. **Depuis l'application Flutter Web** :
   - Ouvrez `http://VOTRE_IP:8080` sur l'iPhone
   - L'application devrait maintenant pouvoir se connecter à l'API

## Variables d'environnement (optionnel)

Vous pouvez aussi configurer via `.env` :
```env
PORT=5000
HOST=0.0.0.0
FRONTEND_URL=http://192.168.56.1:8080,http://localhost:8080
NODE_ENV=development
```

## Dépannage

### Erreur CORS persistante
- Vérifiez que l'IP dans `api_config.dart` correspond à votre IP locale
- Vérifiez que le serveur écoute bien sur `0.0.0.0` (regardez les logs au démarrage)
- Vérifiez que le firewall Windows/Mac autorise les connexions sur le port 5000

### Impossible de se connecter depuis l'iPhone
- Vérifiez que l'iPhone et votre PC sont sur le même réseau Wi-Fi
- Vérifiez que le firewall n'bloque pas le port 5000
- Testez d'abord avec `/health` dans le navigateur de l'iPhone

### L'application Flutter ne se charge pas
- Vérifiez que le serveur web Flutter écoute sur `0.0.0.0` (pas `localhost`)
- Utilisez `--bind 0.0.0.0` ou `-a 0.0.0.0` selon votre serveur



