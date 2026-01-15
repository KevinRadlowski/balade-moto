# Résumé des corrections CORS, Email et Logs

## Fichiers modifiés

### 1. Nouveaux fichiers créés

#### `src/config/cors.js` (NOUVEAU)
- Module centralisé pour la configuration CORS
- Fonctions : `buildCorsOptions()`, `getAllowedOrigins()`, `getCorsInfo()`
- Support de `FRONTEND_URL="*"` pour autoriser toutes les origines
- Support de `FRONTEND_URL="url1,url2"` pour une liste d'origines
- Fallback automatique si `FRONTEND_URL` est vide

#### `src/config/email.js` (NOUVEAU)
- Module centralisé pour la configuration email
- Support des variables `SMTP_*` (préférées) et `EMAIL_*` (alias)
- Fonction `isEmailConfigured()` pour vérifier la configuration
- Warning unique si email non configuré

### 2. Fichiers modifiés

#### `src/app.js`
- **CORS** : Utilise maintenant `src/config/cors.js`
- **Logs** : Nettoyés pour la production (pas de logs LAN/localhost/iPhone)
- **Health endpoint** : Mis à jour pour retourner `{status: "ok", ...}`
- **OPTIONS** : Gestion globale avec `app.options('*', cors(corsOptions))`

#### `src/services/email.service.js`
- Utilise maintenant `src/config/email.js`
- Support des variables `SMTP_*` et `EMAIL_*` (alias)
- Warning unique au lieu de multiples warnings

#### `src/services/socket.service.js`
- Utilise maintenant `src/config/cors.js` pour la cohérence
- Même logique CORS que l'API HTTP

#### `src/models/Vehicle.js`
- **Correction** : Retiré `index: true` de `ownerUserId` (ligne 8)
- L'index composé `{ ownerUserId: 1, active: 1 }` couvre déjà ce cas

#### `src/models/VehicleDocument.js`
- **Correction** : Retiré `index: true` de `ownerUserId` (ligne 14)
- L'index explicite `vehicleDocumentSchema.index({ ownerUserId: 1 })` couvre déjà ce cas

## Configuration CORS

### Variables d'environnement

#### `FRONTEND_URL="*"`
Autorise toutes les origines (mode dev/démo)

#### `FRONTEND_URL="https://app.ridetogether.fr,https://www.app.ridetogether.fr"`
Autorise uniquement ces URLs

#### `FRONTEND_URL` vide ou non défini
Utilise les fallbacks par défaut :
- Dev : `http://localhost:8080`, `http://192.168.1.70:8080`, etc.
- Prod : `http://localhost:3000`, `http://localhost:59219`, `https://app.ridetogether.fr`, `https://www.app.ridetogether.fr`

### Comportement

- **Sans origin** (curl, Postman, apps mobiles) : ✅ Autorisé
- **Localhost en dev** : ✅ Tous les ports autorisés automatiquement
- **Production** : ✅ Seulement les origines dans la whitelist

## Configuration Email

### Variables d'environnement supportées

#### Format préféré (SMTP_*)
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=noreply@ridetogether.fr
```

#### Format alias (EMAIL_*) - Compatibilité
```env
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_FROM=noreply@ridetogether.fr
```

### Priorité
1. Variables `SMTP_*` (si définies)
2. Variables `EMAIL_*` (fallback)
3. Valeurs par défaut (host: smtp.gmail.com, port: 587)

## Tests manuels

### 1. Test CORS - OPTIONS preflight

```bash
# Test depuis app.ridetogether.fr
curl -X OPTIONS https://api.ridetogether.fr/api/auth/login \
  -H "Origin: https://app.ridetogether.fr" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization" \
  -v

# Attendu : 204 No Content avec headers CORS
```

### 2. Test CORS - Requête réelle

```bash
# Test POST depuis app.ridetogether.fr
curl -X POST https://api.ridetogether.fr/api/auth/login \
  -H "Origin: https://app.ridetogether.fr" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}' \
  -v

# Attendu : Pas d'erreur CORS, réponse 401 ou 200 selon les credentials
```

### 3. Test Health endpoint

```bash
curl https://api.ridetogether.fr/health

# Attendu : {"status":"ok","timestamp":"...","uptime":123.45,"environment":"production"}
```

### 4. Test CORS avec FRONTEND_URL="*"

```bash
# Définir FRONTEND_URL="*" dans Render
# Puis tester avec n'importe quelle origine
curl -X OPTIONS https://api.ridetogether.fr/api/auth/login \
  -H "Origin: https://example.com" \
  -v

# Attendu : 204 No Content (toutes origines autorisées)
```

### 5. Test Email configuration

```bash
# Vérifier les logs au démarrage
# Si email configuré : "✅ Serveur email prêt à envoyer des messages"
# Si email non configuré : "⚠️  Email non configuré. Les emails ne pourront pas être envoyés."
```

## Vérifications post-déploiement

1. ✅ Les logs ne montrent plus "CORS blocked for origin: https://app.ridetogether.fr"
2. ✅ Les requêtes OPTIONS retournent 204 avec les bons headers
3. ✅ Le warning Mongoose "Duplicate schema index" a disparu
4. ✅ Les logs de démarrage sont propres en production (pas de LAN/localhost)
5. ✅ L'endpoint `/health` retourne `{status: "ok", ...}`
6. ✅ Le warning email n'apparaît qu'une seule fois au démarrage

## Notes importantes

- **CORS avec credentials** : Le middleware CORS est configuré avec `credentials: true`, donc on ne peut pas utiliser `origin: '*'`. C'est pourquoi on utilise une fonction `origin` qui vérifie la whitelist.
- **Socket.io** : Utilise la même logique CORS que l'API HTTP pour la cohérence.
- **Index Mongoose** : Les warnings de duplication sont corrigés en retirant les `index: true` redondants dans les schémas.














