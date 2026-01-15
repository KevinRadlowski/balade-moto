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

# CORS Configuration (Production Ready)
# CORS_ORIGINS est la variable RECOMMANDÉE pour configurer les origines autorisées
# FRONTEND_URL est conservée pour compatibilité mais CORS_ORIGINS a la priorité
# 
# En développement (NODE_ENV=development):
#   - Tous les localhost/127.0.0.1/192.168.* sont automatiquement autorisés
#   - CORS_ORIGINS/FRONTEND_URL sont optionnels en dev
#
# En production (NODE_ENV=production):
#   - CORS_ORIGINS ou FRONTEND_URL sont OBLIGATOIRES
#   - Sans configuration, TOUTES les origines seront REFUSÉES (sécurité stricte)
#   - Utilisez CORS_ORIGINS="*" uniquement si nécessaire (⚠️ DÉCONSEILLÉ)
#
# Exemple développement (optionnel):
# CORS_ORIGINS=http://localhost:3000,http://localhost:5173
# FRONTEND_URL=http://localhost:3000,http://localhost:59219
#
# Exemple production (OBLIGATOIRE):
CORS_ORIGINS=https://app.ridetogether.fr,https://www.app.ridetogether.fr,https://panel.ridetogether.fr
# Ou utiliser FRONTEND_URL pour compatibilité:
# FRONTEND_URL=https://app.ridetogether.fr,https://www.app.ridetogether.fr

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

# ============================================
# Redis Configuration (Production Ready)
# ============================================
# Redis est utilisé pour le rate limiting distribué
# Si non configuré, l'application utilise un memory store (fallback)
# 
# Format de l'URL Redis:
# - Local: redis://localhost:6379
# - Avec auth: redis://:password@localhost:6379
# - Remote: redis://user:password@host:port
# - Redis Cloud: redis://default:password@host:port
#
# Exemple local:
REDIS_URL=redis://localhost:6379
REDIS_ENABLED=true

# Pour désactiver Redis (utilise memory store):
# REDIS_ENABLED=false

# ============================================
# Upload Configuration (Production Ready)
# ============================================
# Type de stockage: 'local' (par défaut) ou 's3'
STORAGE_TYPE=local

# Répertoire de base pour les uploads (si STORAGE_TYPE=local)
# UPLOAD_BASE_DIR=./uploads

# Configuration S3 (si STORAGE_TYPE=s3)
# S3_BUCKET=your-bucket-name
# S3_REGION=us-east-1
# S3_ACCESS_KEY_ID=your-access-key
# S3_SECRET_ACCESS_KEY=your-secret-key

# Limites de taille par type de fichier (en MB)
UPLOAD_MAX_SIZE_IMAGE=5
UPLOAD_MAX_SIZE_DOCUMENT=20
UPLOAD_MAX_SIZE_VIDEO=50
UPLOAD_MAX_SIZE_AUDIO=10

# Quotas par utilisateur (mensuels)
# Images
UPLOAD_QUOTA_IMAGES_PER_USER=100
UPLOAD_QUOTA_IMAGES_MB_PER_MONTH=500

# Documents
UPLOAD_QUOTA_DOCUMENTS_PER_USER=50
UPLOAD_QUOTA_DOCUMENTS_MB_PER_MONTH=200

# Vidéos
UPLOAD_QUOTA_VIDEOS_PER_USER=20
UPLOAD_QUOTA_VIDEOS_MB_PER_MONTH=1000

# Audio
UPLOAD_QUOTA_AUDIO_PER_USER=30
UPLOAD_QUOTA_AUDIO_MB_PER_MONTH=300

# Autres
UPLOAD_QUOTA_OTHER_PER_USER=50
UPLOAD_QUOTA_OTHER_MB_PER_MONTH=200
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

