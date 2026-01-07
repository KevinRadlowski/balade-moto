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

# Twilio Configuration (pour envoi de SMS OTP)
# Pour recevoir de VRAIS SMS, vous devez configurer Twilio :
# 1. Créez un compte sur https://www.twilio.com
# 2. Récupérez votre Account SID et Auth Token depuis le dashboard
# 3. Créez un Verify Service dans Twilio Console
# 4. Ajoutez ces variables dans votre .env :
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_VERIFY_SERVICE_SID=your-twilio-verify-service-sid

# IMPORTANT : Si ces variables ne sont pas configurées, l'OTP sera simulé en développement
# Pour désactiver la simulation même en développement, ne définissez PAS SKIP_SMS_VERIFICATION
# SKIP_SMS_VERIFICATION=true  # Ne définissez PAS cette variable si vous voulez recevoir de vrais SMS

# Redis (optionnel, pour cache et rate limiting distribué)
# REDIS_HOST=localhost
# REDIS_PORT=6379
# REDIS_PASSWORD=
```

## Notes importantes

- **GOOGLE_MAPS_API_KEY** : OBLIGATOIRE. L'application ne démarrera pas sans cette clé.
- **FRONTEND_URL** : Peut contenir plusieurs URLs séparées par des virgules pour autoriser plusieurs origines (ex: dev, staging, prod).
- **JWT_SECRET** : Utilisez des clés fortes en production (minimum 32 caractères, générées aléatoirement).
- **TWILIO Configuration** : 
  - Pour recevoir de **vrais SMS OTP**, vous devez configurer les 3 variables Twilio (Account SID, Auth Token, Verify Service SID).
  - Si Twilio n'est pas configuré, l'OTP sera simulé en mode développement (message dans la console).
  - **Ne définissez PAS** `SKIP_SMS_VERIFICATION=true` si vous voulez recevoir de vrais SMS.
  - Guide Twilio : https://www.twilio.com/docs/verify/quickstart

