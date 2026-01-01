# Variables d'environnement requises

Créez un fichier `.env` à la racine du projet avec les variables suivantes :

```env
# Configuration MongoDB
MONGO_URI=mongodb://localhost:27017/balades-moto

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-in-production-min-32-chars
JWT_REFRESH_SECRET=your-super-secret-refresh-key-change-in-production-min-32-chars

# Server Configuration
PORT=5000
NODE_ENV=development
BASE_URL=http://localhost:5000

# Frontend URLs (séparées par des virgules pour plusieurs origines)
# En développement (NODE_ENV=development), tous les ports localhost sont automatiquement autorisés
# En production, vous DEVEZ spécifier toutes les URLs autorisées
# Exemple dev (optionnel, car localhost autorisé automatiquement):
FRONTEND_URL=http://localhost:3000,http://localhost:59219
# Exemple production (OBLIGATOIRE):
# FRONTEND_URL=https://votre-domaine.com,https://www.votre-domaine.com

# Google Maps API (OBLIGATOIRE - pas de valeur par défaut)
GOOGLE_MAPS_API_KEY=your-google-maps-api-key-here

# Email Configuration (pour vérification email)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_FROM=noreply@balades-moto.com

# Redis (optionnel, pour cache et rate limiting distribué)
# REDIS_HOST=localhost
# REDIS_PORT=6379
# REDIS_PASSWORD=
```

## Notes importantes

- **GOOGLE_MAPS_API_KEY** : OBLIGATOIRE. L'application ne démarrera pas sans cette clé.
- **FRONTEND_URL** : Peut contenir plusieurs URLs séparées par des virgules pour autoriser plusieurs origines (ex: dev, staging, prod).
- **JWT_SECRET** : Utilisez des clés fortes en production (minimum 32 caractères, générées aléatoirement).

