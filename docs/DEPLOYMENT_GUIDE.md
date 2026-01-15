# Guide de Déploiement Production - RideTogether API

**Version** : 1.0.0  
**Date** : 2025-01-27  
**Statut** : ✅ Prêt pour production (après tests finaux)

---

## 📋 PRÉREQUIS

### Infrastructure
- [ ] Node.js 18+ installé
- [ ] MongoDB 5.0+ configuré et accessible
- [ ] Redis 6.0+ configuré et accessible (optionnel mais recommandé)
- [ ] Variables d'environnement configurées

### Services externes
- [ ] Google Maps API Key (pour directions/geocoding)
- [ ] Twilio (pour SMS OTP) - optionnel
- [ ] SMTP configuré (pour emails)

---

## 🔧 CONFIGURATION

### 1. Variables d'environnement

Créer un fichier `.env` en production avec :

```env
# === OBLIGATOIRE ===
NODE_ENV=production
MONGO_URI=mongodb://your-mongo-host:27017/ridetogether
PORT=5000
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
JWT_REFRESH_SECRET=your-super-secret-refresh-key-min-32-chars

# === CORS (OBLIGATOIRE) ===
CORS_ORIGINS=https://app.ridetogether.fr,https://www.ridetogether.fr
FRONTEND_URL=https://app.ridetogether.fr

# === REDIS (RECOMMANDÉ) ===
REDIS_URL=redis://your-redis-host:6379
REDIS_ENABLED=true

# === PAGINATION (OPTIONNEL) ===
PAGINATION_DEFAULT_LIMIT=20
PAGINATION_MAX_LIMIT=50

# === UPLOADS (OPTIONNEL) ===
UPLOAD_MAX_FILE_SIZE_IMAGE=5242880
UPLOAD_MAX_FILE_SIZE_DOCUMENT=20971520
UPLOAD_MAX_FILE_SIZE_VIDEO=52428800
UPLOAD_QUOTA_IMAGES_MAX_FILES=100
UPLOAD_QUOTA_IMAGES_MAX_SIZE_MB=500

# === GOOGLE MAPS (OPTIONNEL) ===
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# === TWILIO (OPTIONNEL) ===
TWILIO_ACCOUNT_SID=your-twilio-sid
TWILIO_AUTH_TOKEN=your-twilio-token
TWILIO_VERIFY_SERVICE_SID=your-verify-service-sid

# === SMTP (OPTIONNEL) ===
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-email@example.com
SMTP_PASS=your-password
```

### 2. Installation des dépendances

```bash
npm install --production
```

### 3. Synchronisation des index MongoDB

```bash
npm run db:indexes
```

Cette commande :
- Synchronise tous les index définis dans les modèles
- Affiche la liste des index existants
- Vérifie que les index sont correctement créés

---

## 🚀 DÉPLOIEMENT

### Option 1 : PM2 (Recommandé)

```bash
# Installation PM2
npm install -g pm2

# Démarrer l'application
pm2 start src/app.js --name ridetogether-api

# Sauvegarder la configuration
pm2 save
pm2 startup

# Monitoring
pm2 monit
```

### Option 2 : Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 5000
CMD ["node", "src/app.js"]
```

```bash
docker build -t ridetogether-api .
docker run -d --name ridetogether-api \
  -p 5000:5000 \
  --env-file .env \
  ridetogether-api
```

### Option 3 : Systemd

Créer `/etc/systemd/system/ridetogether-api.service` :

```ini
[Unit]
Description=RideTogether API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/ridetogether-api
Environment=NODE_ENV=production
ExecStart=/usr/bin/node src/app.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable ridetogether-api
sudo systemctl start ridetogether-api
sudo systemctl status ridetogether-api
```

---

## ✅ VÉRIFICATIONS POST-DÉPLOIEMENT

### 1. Santé de l'application

```bash
curl https://your-api-domain.com/health
```

Réponse attendue :
```json
{
  "status": "ok",
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### 2. CORS

```bash
curl -H "Origin: https://unauthorized-domain.com" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://your-api-domain.com/api/rides
```

Doit retourner `403 Forbidden` si l'origine n'est pas dans `CORS_ORIGINS`.

### 3. Redis

Vérifier les logs au démarrage :
```
✅ Redis: Connecté et prêt
```

Si Redis indisponible :
```
⚠️ Redis: Connexion fermée. Fallback vers memory store.
```

### 4. Index MongoDB

```bash
npm run db:indexes
```

Vérifier que tous les index sont créés sans erreur.

### 5. Rate Limiting

Tester avec plusieurs requêtes rapides :
```bash
for i in {1..10}; do
  curl https://your-api-domain.com/api/auth/login
done
```

La 6ème requête devrait être bloquée (si limite = 5).

---

## 📊 MONITORING

### Logs recommandés

- **Erreurs 500** : Logger avec stack trace (en dev) ou message générique (en prod)
- **Rate limiting** : Logger les blocages
- **Redis** : Logger les déconnexions/reconnexions
- **MongoDB** : Logger les requêtes lentes (> 100ms)

### Métriques à surveiller

- Temps de réponse moyen (< 200ms pour endpoints principaux)
- Taux d'erreur (< 1%)
- Utilisation mémoire (< 80%)
- Connexions MongoDB (pool size)
- Connexions Redis (si utilisé)

---

## 🔄 MAINTENANCE

### Mise à jour des index

Après modification des modèles Mongoose :

```bash
npm run db:indexes
```

### Rotation des logs

Configurer logrotate pour `/var/log/ridetogether-api.log` :

```
/var/log/ridetogether-api.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload ridetogether-api > /dev/null 2>&1 || true
    endscript
}
```

### Backup MongoDB

```bash
# Backup quotidien
mongodump --uri="mongodb://your-mongo-host:27017/ridetogether" \
  --out=/backup/ridetogether-$(date +%Y%m%d)
```

---

## 🚨 DÉPANNAGE

### Application ne démarre pas

1. Vérifier les variables d'environnement
2. Vérifier la connexion MongoDB
3. Vérifier les logs : `pm2 logs ridetogether-api`
4. Vérifier les ports : `netstat -tulpn | grep 5000`

### Erreurs Redis

Si Redis indisponible, l'application continue avec memory store. Pour activer Redis :

1. Vérifier que Redis est démarré : `redis-cli ping`
2. Vérifier `REDIS_URL` dans `.env`
3. Vérifier les logs de connexion

### Performance dégradée

1. Vérifier les index MongoDB : `npm run db:indexes`
2. Vérifier les requêtes lentes dans les logs
3. Vérifier l'utilisation mémoire/CPU
4. Vérifier les connexions DB (pool size)

### Erreurs CORS

1. Vérifier `CORS_ORIGINS` dans `.env`
2. Vérifier que les origines sont séparées par des virgules
3. Tester avec `curl` (voir section Vérifications)

---

## 📚 DOCUMENTATION COMPLÉMENTAIRE

- `docs/PROD_READINESS_SUMMARY.md` - Résumé des optimisations
- `docs/PROD_CHECKLIST.md` - Checklist de vérification
- `docs/CORS_TESTING.md` - Tests CORS
- `docs/REDIS_SETUP.md` - Configuration Redis
- `docs/ERROR_CODES.md` - Codes d'erreur standardisés
- `docs/REFACTOR_RIDE_CONTROLLER.md` - Architecture refactoring

---

**Support** : Voir `docs/REDIS_TROUBLESHOOTING.md` pour problèmes Redis spécifiques

