# Plan de Préparation Production - RideTogether API

**Date**: 2025-01-27  
**Objectif**: Rendre l'API prête pour 500-1000 utilisateurs sans casser les features existantes  
**Approche**: Modifications incrémentales, rétrocompatibles, testables

---

## 📊 ÉTAPE 0 - DIAGNOSTIC COMPLET

### 1. Endpoints de Listing Identifiés

#### Rides
- `GET /rides` - Liste des balades (filtres: typeVehicule, visibilite, dateDebut, dateFin, organisateur, participant, search, lat/lng/rayon)
  - **Fichier**: `src/controllers/ride.controller.js:198`
  - **Pagination**: ✅ Oui (page, limit) mais inconsistante
  - **Problème**: N+1 sur likes (ligne 666-682)
  - **Problème**: Tri en mémoire après récupération (ligne 629-644)
  - **Problème**: `limit * 2` pour compenser filtrage (inefficace)

- `GET /rides/past` - Balades passées
  - **Fichier**: `src/controllers/ride.controller.js:542`
  - **Pagination**: ✅ Oui (page, limit)
  - **Problème**: N+1 sur likes (ligne 666-682)

- `GET /rides/my-past` - Mes balades passées
  - **Fichier**: `src/controllers/ride.controller.js` (à vérifier)
  - **Pagination**: ✅ Oui

#### Groups
- `GET /groups` - Liste des groupes
  - **Fichier**: `src/controllers/group.controller.js:221`
  - **Pagination**: ✅ Oui (page, limit, max 50)
  - **Utilise**: Aggregation pipeline (bon)
  - **Pas de N+1 visible**

#### Messages
- `GET /messages/:conversationId/:type` - Messages d'une conversation
  - **Fichier**: `src/controllers/message.controller.js:7`
  - **Pagination**: ✅ Cursor-based (bon)
  - **Utilise**: `.lean()` (bon)
  - **Populate**: auteur, replyToMessageId, pinnedBy (acceptable)

#### Admin
- `GET /admin/rides` - Liste admin des balades
  - **Fichier**: `src/controllers/admin.rides.controller.js`
  - **Pagination**: À vérifier

- `GET /admin/groups` - Liste admin des groupes
  - **Fichier**: `src/controllers/admin.groups.controller.js`
  - **Pagination**: À vérifier

- `GET /admin/users` - Liste admin des utilisateurs
  - **Fichier**: `src/controllers/admin.users.controller.js`
  - **Pagination**: À vérifier

### 2. Problèmes N+1 Identifiés

#### ✅ RÉSOLU - ride.controller.js (était: 666-682)
**Avant**:
```javascript
const ridesWithLikes = await Promise.all(
  paginatedRides.map(async (ride) => {
    const totalLikes = await Like.countLikesByRide(ride._id); // N requêtes
    const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id); // N requêtes
    // ...
  })
);
```
**Après**:
```javascript
const rideStats = require('../utils/rideStats');
let ridesWithLikes = await rideStats.enrichRidesWithLikes(paginatedRides, req.user._id);
```
**Impact**: Réduction de 40+ requêtes DB à 2 requêtes pour 20 rides  
**Solution appliquée**: ✅ Méthodes batch dans `Like.js` + utilitaire `rideStats.js`

#### 🟡 MOYEN - ride.controller.js:184-185
```javascript
await ride.populate('organisateur', '...');
await ride.populate('participants.userId', '...');
```
**Impact**: Acceptable pour un seul ride, mais à optimiser si répété

#### 🟡 MOYEN - group.controller.js:115-116
```javascript
await group.populate('createur', '...');
await group.populate('membres.userId', '...');
```
**Impact**: Acceptable pour un seul groupe

### 3. Pagination Actuelle

#### Format existant
- **Rides**: `{ rides: [...], pagination: { page, limit, total, pages } }`
- **Groups**: `{ groups: [...], pagination: { page, limit, total, pages } }`
- **Messages**: `{ messages: [...], nextCursor, hasMore }` (cursor-based ✅)

#### Problèmes
- Pas de limite max stricte (sauf groups: max 50)
- `limit * 2` dans rides pour compenser filtrage (inefficace)
- Tri en mémoire après récupération (rides past)

### 4. CORS Actuel

#### Express CORS
- **Fichier**: `src/config/cors.js`
- **Configuration**: ✅ Whitelist via `FRONTEND_URL`
- **Problème**: En dev, autorise tous les localhost (OK pour dev)
- **Production**: Utilise fallback si `FRONTEND_URL` vide (⚠️ à sécuriser)

#### Socket.io CORS
- **Fichier**: `src/services/socket.service.js:12-46`
- **Configuration**: ✅ Utilise `getAllowedOrigins()` (cohérent)
- **Problème**: Même logique que Express (bon), mais à valider strictement en prod

### 5. Uploads Actuels

#### Routes d'upload identifiées
- `POST /user/upload-avatar` - Avatar utilisateur
  - **Middleware**: `src/middlewares/upload.middleware.js`
  - **Stockage**: Local (`uploads/avatars/`)
  - **Validation**: ✅ Magic bytes (file-type)
  - **Taille max**: 5MB
  - **Nom**: `userId-timestamp.ext` (✅ random)

- `POST /user/upload-background` - Background personnalisé
  - **Middleware**: `src/middlewares/background-upload.middleware.js`
  - **Stockage**: Local (`uploads/backgrounds/`)

- `POST /messages/:conversationId/:type/upload` - Fichiers messages
  - **Middleware**: `src/middlewares/message-upload.middleware.js`
  - **Stockage**: Local (`uploads/messages/`)

- `POST /garage/vehicles/:id/documents` - Documents véhicules
  - **Middleware**: `src/middlewares/vehicle-document-upload.middleware.js`
  - **Stockage**: Local (`uploads/vehicle-documents/`)

#### Problèmes
- ❌ Pas de quotas par utilisateur
- ❌ Pas d'abstraction StorageProvider (S3-ready)
- ✅ Validation magic bytes (bon)
- ✅ Noms random (bon)

### 6. Rate Limiting Actuel

#### Middleware identifiés
- `src/middlewares/rateLimit.middleware.js` - Rate limit mémoire (géospatial)
  - **Store**: Map en mémoire
  - **Problème**: ❌ Pas de Redis, perdu au redémarrage

- `src/middlewares/otpRateLimit.middleware.js` - Rate limit OTP
  - **À vérifier**: Store utilisé

#### Routes protégées
- `/auth/login` - À vérifier
- `/auth/register` - À vérifier
- `/auth/otp` - ✅ Rate limit OTP
- `/uploads/*` - ❌ Pas de rate limit visible
- `/password/reset` - À vérifier

### 7. Structure Controllers

#### ride.controller.js
- **Taille**: ~4000 lignes (⚠️ très volumineux)
- **Fonctions**: ~30+ exports
- **Problème**: Logique métier mélangée avec accès DB
- **Refactor nécessaire**: ✅ Oui (priorité haute)

#### group.controller.js
- **Taille**: ~1600 lignes
- **Fonctions**: ~15+ exports
- **État**: Acceptable mais pourrait être mieux structuré

#### message.controller.js
- **Taille**: ~900 lignes
- **Fonctions**: ~10+ exports
- **État**: Acceptable

### 8. Index MongoDB Actuels

#### Ride
- ✅ `organisateur: 1`
- ✅ `date: 1`
- ✅ `typeVehicule: 1`
- ✅ `visibilite: 1`
- ✅ `localisation: '2dsphere'`
- ✅ `status: 1, date: 1` (compound)
- ✅ `participants: 1`
- **Manque**: Index compound pour requêtes fréquentes (ex: `typeVehicule + date + visibilite`)

#### Group
- ✅ `createur: 1`
- ✅ `visibilite: 1`
- ✅ `membres.userId: 1`
- ✅ `location.geo: '2dsphere'` (sparse)
- **Manque**: Index sur `createdAt` pour tri

#### Message
- ✅ `idBalade: 1, date: -1` (compound)
- ✅ `idGroupe: 1, date: -1` (compound)
- ✅ `auteur: 1`
- **État**: ✅ Bon

#### Like
- ✅ `balade: 1, dateLike: -1`
- ✅ `utilisateur: 1, balade: 1` (unique)
- **État**: ✅ Bon

#### Rating
- ✅ `balade: 1, dateNote: -1`
- ✅ `utilisateur: 1, balade: 1` (unique)
- **État**: ✅ Bon

### 9. Gestion d'Erreurs Actuelle

#### Middleware
- **Fichier**: `src/middlewares/error.middleware.js`
- **État**: ✅ Bonne base
- **Problème**: Stack trace en dev (OK), mais message générique en prod (✅ bon)
- **Manque**: Codes d'erreur standardisés (ex: `INVALID_INPUT`, `NOT_FOUND`)

#### AppError
- **Fichier**: `src/utils/errors.js`
- **État**: ✅ Existe déjà
- **Utilisation**: Partielle (à généraliser)

---

## 📋 FICHIERS À MODIFIER

### Étape 1 - Index Mongo
- `src/models/Ride.js` - Ajouter index compound
- `src/models/Group.js` - Ajouter index createdAt
- `tools/ensure-indexes.js` - **NOUVEAU** - Script de vérification
- `package.json` - Ajouter script `db:indexes`

### Étape 2 - Pagination
- `src/utils/pagination.js` - **NOUVEAU** - Module utilitaire
- `src/controllers/ride.controller.js` - Standardiser pagination
- `src/controllers/group.controller.js` - Vérifier pagination
- `src/controllers/message.controller.js` - Déjà cursor-based (✅)
- `src/controllers/admin.*.controller.js` - Ajouter pagination si manquante

### Étape 3 - Réduction N+1 ✅ TERMINÉE
- `src/models/Like.js` - ✅ Ajout méthodes batch (`countLikesByRides`, `hasUserLikedRides`)
- `src/utils/rideStats.js` - ✅ **NOUVEAU** - Utilitaires pour enrichir rides avec stats en batch
- `src/controllers/ride.controller.js` - ✅ Remplacé N+1 dans:
  - `getRides()` (ligne ~526)
  - `getPastRides()` (ligne ~694)
  - `getMyPastRides()` (ligne ~879)
  - `getRidesNearby()` (ligne ~1142)
  - `getRideById()` (ligne ~1231)
- **Impact**: Réduction de 40+ requêtes DB à 2-3 requêtes pour 20 rides
- **Note**: Utilisation de `.lean()` déjà présente dans plusieurs endroits (✅)

### Étape 4 - CORS ✅ TERMINÉE
- `src/config/cors.js` - ✅ Renforcé whitelist prod (refuse si non configuré)
  - Utilise `CORS_ORIGINS` en priorité, `FRONTEND_URL` en fallback
  - Production sans config : refuse toutes les origines (sécurité stricte)
  - Développement : autorise localhost/127.0.0.1/192.168.* automatiquement
- `src/services/socket.service.js` - ✅ Même logique CORS stricte appliquée
- `ENV_VARIABLES.md` - ✅ Documenté `CORS_ORIGINS`
- `docs/CORS_TESTING.md` - ✅ **NOUVEAU** - Documentation complète avec exemples curl

### Étape 5 - Uploads ✅ TERMINÉE
- `src/models/UploadUsage.js` - ✅ **NOUVEAU** - Modèle pour suivre les quotas par utilisateur
- `src/services/storage.provider.js` - ✅ **NOUVEAU** - Abstraction StorageProvider
  - `LocalStorageProvider` : Implémentation complète pour stockage local
  - `S3StorageProvider` : Stub prêt pour implémentation future
  - Structure de dossiers: `category/userId/YYYY/MM/DD/randomName.ext`
  - Noms de fichiers randomisés avec `crypto.randomBytes`
- `src/services/upload.quota.service.js` - ✅ **NOUVEAU** - Service de gestion des quotas
  - Vérification avant upload
  - Enregistrement après upload
  - Limites configurables par type (image, document, video, audio)
- `src/middlewares/upload-secure.middleware.js` - ✅ **NOUVEAU** - Middleware d'exemple
  - Utilise StorageProvider et quotas
  - Validation magic bytes (déjà présent dans les autres middlewares)
  - Prêt pour migration progressive
- **Note**: Les middlewares existants continuent de fonctionner. Le nouveau middleware peut être adopté progressivement.

### Étape 6 - Rate Limiting Redis ✅ TERMINÉE
- `src/config/redis.js` - ✅ **NOUVEAU** - Configuration Redis avec fail-open
  - Connexion avec ioredis
  - Retry strategy avec délai exponentiel
  - Fallback automatique vers memory store si Redis indisponible
  - Logs détaillés des événements Redis
- `src/middlewares/redis-rate-limit.store.js` - ✅ **NOUVEAU** - Store Redis pour express-rate-limit
  - Implémente l'interface store de express-rate-limit
  - Fail-open vers MemoryStore si Redis indisponible
  - Préfixes pour organiser les clés (otp:send:, auth:login:, etc.)
- `src/middlewares/otpRateLimit.middleware.js` - ✅ Migré vers Redis
  - Tous les limiters utilisent maintenant Redis store
  - Préfixes: `otp:send:`, `otp:verify:`, `auth:register:`, `auth:login:`
- `src/middlewares/rateLimit.middleware.js` - ✅ Migré vers express-rate-limit + Redis
  - Remplace l'ancien système Map en mémoire
  - Compatible avec l'API existante (rateLimitMiddleware(maxRequests, windowMs))
  - Utilise Redis avec fail-open
- `src/middlewares/uploadRateLimit.middleware.js` - ✅ **NOUVEAU** - Rate limits pour uploads
  - Avatar: 10 uploads/15min
  - Messages: 20 uploads/15min
  - Véhicules: 15 uploads/15min
  - Documents: 10 uploads/15min
  - Background: 5 uploads/15min
- `src/app.js` - ✅ Initialisation Redis au démarrage
- **Note**: ioredis doit être installé (`npm install ioredis`) pour utiliser Redis. Sinon, fallback automatique vers memory store.

### Étape 7 - Normalisation Erreurs ✅ TERMINÉE
- `src/utils/errors.js` - ✅ Enrichi AppError avec codes et détails
  - Ajout paramètres `code` et `details` à AppError
  - Génération automatique de codes par défaut selon statusCode
  - Fonction `mapMongooseError()` pour mapper erreurs Mongoose
  - Toutes les classes d'erreur supportent maintenant codes et détails
- `src/middlewares/error.middleware.js` - ✅ Amélioré pour standardiser toutes les erreurs
  - Format standardisé : `{ error: { code, message, details? } }`
  - Mapping automatique des erreurs Mongoose (ValidationError, CastError, duplicate key)
  - Mapping des erreurs JWT (JsonWebTokenError, TokenExpiredError)
  - Mapping des erreurs Multer (LIMIT_FILE_SIZE, etc.)
  - Mapping des erreurs CORS et rate limiting
  - Production : pas de stack trace, message générique pour erreurs internes
  - Development : stack trace et détails complets
  - Logging structuré en production
- `src/controllers/social-auth.controller.js` - ✅ Remplacé `throw new Error` par AppError
- `src/controllers/phoneOtp.controller.js` - ✅ Remplacé `throw new Error` par AppError
- `docs/ERROR_CODES.md` - ✅ **NOUVEAU** - Documentation complète des codes d'erreur

### Étape 8 - Refactor ride.controller
- `src/repositories/ride.repository.js` - **NOUVEAU**
- `src/services/ride.service.js` - **NOUVEAU**
- `src/controllers/ride.controller.js` - Réduire à parsing/validation/response

---

## ⚠️ RISQUES (Breaking Changes Potentiels)

### Risques Faibles
1. **Index MongoDB**: Aucun (ajout uniquement)
2. **Pagination**: Risque faible si on garde format existant + ajoute headers
3. **CORS**: Risque moyen si whitelist trop stricte (mitigé par env)

### Risques Moyens
4. **N+1 fixes**: Risque faible (changement interne, réponse identique)
5. **Rate limiting Redis**: Risque faible (fail-open vers memory store)
6. **Uploads quotas**: Risque faible (ajout de limites, pas de suppression)

### Risques Élevés
7. **Refactor ride.controller**: ⚠️ **RISQUE MOYEN**
   - **Mitigation**: Tests unitaires + intégration avant déploiement
   - **Stratégie**: Refactor progressif, fonction par fonction

---

## 🧪 STRATÉGIE DE TEST

### Tests Unitaires
- `src/services/ride.service.test.js` - Logique métier
- `src/repositories/ride.repository.test.js` - Accès DB
- `src/utils/pagination.test.js` - Utilitaires pagination

### Tests Intégration
- `tests/controllers/ride.controller.test.js` - Routes rides
- `tests/controllers/group.controller.test.js` - Routes groups
- `tests/middlewares/rateLimit.test.js` - Rate limiting

### Tests Manuels (Checklist Flutter)
- ✅ Accueil: Liste rides charge correctement
- ✅ Balades: Pagination fonctionne (scroll infini)
- ✅ Détail: Ride detail charge avec stats
- ✅ Groupes: Liste groupes + pagination
- ✅ Chat: Messages chargent avec cursor
- ✅ Upload: Avatar upload fonctionne
- ✅ Auth: Login/register rate limit OK

---

## 📝 NOTES IMPORTANTES

### Compatibilité Frontend Flutter
- **Format réponse rides**: `{ rides: [...], pagination: {...} }` → **CONSERVER**
- **Format réponse groups**: `{ groups: [...], pagination: {...} }` → **CONSERVER**
- **Format réponse messages**: `{ messages: [...], nextCursor, hasMore }` → **CONSERVER**

### Variables Env à Ajouter
```env
# CORS
CORS_ORIGINS=https://ridetogether.app,https://panel.ridetogether.app,http://localhost:3000,http://localhost:5173

# Redis
REDIS_URL=redis://localhost:6379
REDIS_ENABLED=true

# Pagination
PAGINATION_MAX_LIMIT=50
PAGINATION_DEFAULT_LIMIT=20

# Uploads
UPLOAD_MAX_SIZE_IMAGE=5242880  # 5MB
UPLOAD_MAX_SIZE_DOCUMENT=20971520  # 20MB
UPLOAD_QUOTA_IMAGES_PER_USER=100
UPLOAD_QUOTA_MB_PER_MONTH=500
```

---

## ✅ PROCHAINES ÉTAPES

1. **ÉTAPE 1** - Index Mongo ✅ **TERMINÉE**
2. **ÉTAPE 2** - Pagination ✅ **TERMINÉE**
3. **ÉTAPE 3** - N+1 fixes ✅ **TERMINÉE**
4. **ÉTAPE 4** - CORS ✅ **TERMINÉE**
5. **ÉTAPE 5** - Uploads sécurisés ✅ **TERMINÉE**
6. **ÉTAPE 6** - Rate limiting Redis ✅ **TERMINÉE**
7. **ÉTAPE 7** - Normalisation erreurs ✅ **TERMINÉE**
8. **ÉTAPE 8** - Refactor ride.controller ✅ **EN COURS** (Fonctions principales terminées)
9. **ÉTAPE 9** - Tests et Vérification Finale ⏭️ **SUIVANTE**

**Voir `docs/PROD_READINESS_SUMMARY.md` pour le résumé complet**
5. **ÉTAPE 5** - Uploads (risque faible, sécurité)
6. **ÉTAPE 6** - Rate limiting Redis (risque faible, scalabilité)
7. **ÉTAPE 7** - Normalisation erreurs (risque faible, qualité)
8. **ÉTAPE 8** - Refactor ride.controller (risque moyen, maintenabilité)

---

**Statut**: ✅ Diagnostic complet - Prêt pour implémentation

