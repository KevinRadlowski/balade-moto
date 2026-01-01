# 🗺️ PLAN DE REFACTORISATION - Balades Moto
**Objectif** : Préparer pour 500-1000 utilisateurs  
**Approche** : Par phases, sans casser l'existant

---

## 📅 ROADMAP GLOBALE

```
Phase 1 (Critique) : 5-7 jours  → Sécurité + Bugs critiques
Phase 2 (Structure) : 8-10 jours → Architecture + Qualité code
Phase 3 (Performance) : 6-8 jours → Scalabilité + Optimisations
Phase 4 (Tests) : 5-7 jours → Socle de tests minimal
Phase 5 (Production) : 3-4 jours → Hardening + Monitoring
─────────────────────────────────────────────────────────
TOTAL : 27-36 jours
```

---

## 🔴 PHASE 1 : CORRECTIFS CRITIQUES (5-7 jours)

### Objectifs
- Sécuriser l'application (pas de vulnérabilités critiques)
- Corriger les bugs qui peuvent causer des crashes
- Mettre en place les bases de sécurité

### Tâches

#### 1.1 Sécurité immédiate (Jour 1)
**Fichiers** : `src/app.js`, `src/controllers/ride.controller.js`, `src/services/socket.service.js`

- [ ] **1.1.1** Supprimer clé API Google Maps en dur
  - Fichier : `src/controllers/ride.controller.js:1400, 1483, 1643`
  - Action : Remplacer par `process.env.GOOGLE_MAPS_API_KEY` avec vérification
  - Risque : Aucun (fail fast si manquant)
  - Rollback : Git revert

- [ ] **1.1.2** Configurer CORS restrictif
  - Fichier : `src/app.js:29`
  - Action : 
    ```javascript
    app.use(cors({
      origin: process.env.FRONTEND_URL?.split(',') || ['http://localhost:3000'],
      credentials: true
    }));
    ```
  - Risque : Faible (tester avec frontend)
  - Rollback : Git revert

- [ ] **1.1.3** Ajouter helmet.js
  - Fichier : `src/app.js`
  - Action : `npm install helmet`, ajouter après `app.use(cors())`
  - Risque : Aucun
  - Rollback : Git revert

- [ ] **1.1.4** Créer `.env.example`
  - Fichier : `.env.example` (nouveau)
  - Action : Lister toutes les variables nécessaires
  - Risque : Aucun
  - Rollback : Supprimer fichier

**Résumé** : Sécurité de base en place, CORS sécurisé, headers de sécurité

---

#### 1.2 Validation centralisée (Jour 2-3)
**Fichiers** : `src/middlewares/validation.middleware.js` (nouveau), tous les controllers

- [ ] **1.2.1** Installer express-validator
  - Action : `npm install express-validator`

- [ ] **1.2.2** Créer middleware de validation
  - Fichier : `src/middlewares/validation.middleware.js`
  - Action : Créer wrapper pour express-validator

- [ ] **1.2.3** Créer schemas de validation
  - Fichier : `src/validators/` (nouveau dossier)
  - Schemas :
    - `ride.validator.js` : createRide, updateRide
    - `auth.validator.js` : register, login
    - `user.validator.js` : updateProfile
    - `message.validator.js` : sendMessage
  - Action : Extraire validation des controllers

- [ ] **1.2.4** Appliquer validation aux routes critiques
  - Fichiers : `src/routes/*.routes.js`
  - Priorité : auth, rides, messages
  - Risque : Moyen (changer comportement)
  - Rollback : Git revert, tests manuels

**Résumé** : Validation centralisée, moins de bugs, sécurité renforcée

---

#### 1.3 Gestion d'erreurs centralisée (Jour 3-4)
**Fichiers** : `src/middlewares/error.middleware.js` (nouveau), `src/utils/errors.js` (nouveau)

- [ ] **1.3.1** Créer classes d'erreur personnalisées
  - Fichier : `src/utils/errors.js`
  - Classes :
    - `AppError` (base)
    - `ValidationError` (400)
    - `UnauthorizedError` (401)
    - `NotFoundError` (404)
    - `ConflictError` (409)
    - `InternalServerError` (500)

- [ ] **1.3.2** Créer middleware d'erreur global
  - Fichier : `src/middlewares/error.middleware.js`
  - Action : Remplacer try/catch dans controllers
  - Format réponse standardisé

- [ ] **1.3.3** Masquer détails en production
  - Fichier : `src/middlewares/error.middleware.js`
  - Action : Ne pas exposer stack traces, chemins fichiers

- [ ] **1.3.4** Refactorer controllers progressivement
  - Fichiers : `src/controllers/*.controller.js`
  - Action : Remplacer try/catch par throw AppError
  - Priorité : auth, rides, messages
  - Risque : Moyen (changer format erreurs)
  - Rollback : Git revert par controller

**Résumé** : Erreurs cohérentes, pas de fuite d'infos, plus facile à déboguer

---

#### 1.4 Uploads sécurisés (Jour 4-5)
**Fichiers** : `src/middlewares/upload.middleware.js`, `src/middlewares/message-upload.middleware.js`

- [ ] **1.4.1** Validation par magic bytes
  - Action : Utiliser `file-type` ou `mmmagic`
  - Vérifier réel type de fichier (pas juste extension)

- [ ] **1.4.2** Limites strictes par type
  - Images : 5MB
  - Vidéos : 50MB
  - Audio : 10MB
  - Documents : 20MB

- [ ] **1.4.3** Noms de fichiers aléatoires
  - Action : UUID v4 au lieu de timestamp
  - Stocker mapping dans DB si besoin

- [ ] **1.4.4** Sanitization noms de fichiers
  - Action : Nettoyer caractères spéciaux, paths

**Résumé** : Uploads sécurisés, moins de risques malware

---

#### 1.5 Rate limiting amélioré (Jour 5)
**Fichiers** : `src/middlewares/rateLimit.middleware.js`

- [ ] **1.5.1** Installer express-rate-limit
  - Action : `npm install express-rate-limit`

- [ ] **1.5.2** Créer middlewares de rate limiting
  - Auth : 5 req/min
  - API générale : 100 req/min
  - Upload : 10 req/min
  - Géospatial : 20 req/min

- [ ] **1.5.3** Appliquer aux routes critiques
  - Fichiers : `src/routes/*.routes.js`
  - Priorité : auth, upload, géospatial

**Résumé** : Protection contre brute force, DoS

---

#### 1.6 Tests critiques (Jour 6-7)
**Fichiers** : `tests/` (nouveau)

- [ ] **1.6.1** Tests d'intégration auth
  - Register, login, refresh token
  - Fichier : `tests/auth.integration.test.js`

- [ ] **1.6.2** Tests validation
  - Tester schemas de validation
  - Fichier : `tests/validation.test.js`

- [ ] **1.6.3** Tests uploads
  - Types de fichiers, tailles
  - Fichier : `tests/upload.test.js`

**Résumé** : Confiance pour continuer refacto

---

### Livrables Phase 1
- ✅ Application sécurisée (pas de vulnérabilités critiques)
- ✅ Validation centralisée
- ✅ Gestion d'erreurs cohérente
- ✅ Uploads sécurisés
- ✅ Rate limiting
- ✅ Tests critiques

### Risques Phase 1
- **Changement format erreurs** : Frontend peut casser
  - Mitigation : Tester frontend après chaque changement
- **Validation plus stricte** : Peut rejeter données valides
  - Mitigation : Tests, rollback si besoin

---

## 🏗️ PHASE 2 : REFACTO STRUCTUREL (8-10 jours)

### Objectifs
- Séparer responsabilités (Controller/Service/Repository)
- Réduire duplication
- Améliorer maintenabilité

### Tâches

#### 2.1 Refactorer ride.controller (Jour 1-3)
**Fichier** : `src/controllers/ride.controller.js` (1700 lignes → ~300 lignes)

- [ ] **2.1.1** Créer service layer
  - Fichier : `src/services/ride.service.js` (nouveau)
  - Extraire logique métier :
    - `createRide()`
    - `getRides()`
    - `getPastRides()`
    - `calculateRoute()`
    - `geocodeAddress()`

- [ ] **2.1.2** Créer repository layer
  - Fichier : `src/repositories/ride.repository.js` (nouveau)
  - Extraire requêtes DB :
    - `findRides(filter, pagination)`
    - `findRideById(id)`
    - `createRide(data)`
    - `updateRide(id, data)`

- [ ] **2.1.3** Refactorer controller
  - Fichier : `src/controllers/ride.controller.js`
  - Controller devient mince :
    - Validation (via middleware)
    - Appel service
    - Retour réponse

- [ ] **2.1.4** Tests unitaires service
  - Fichier : `tests/services/ride.service.test.js`
  - Mock repository

**Résumé** : Controller allégé, logique testable, réutilisable

---

#### 2.2 Appliquer pattern aux autres controllers (Jour 4-6)
**Fichiers** : Tous les controllers

- [ ] **2.2.1** Auth controller
  - Service : `src/services/auth.service.js`
  - Repository : `src/repositories/user.repository.js`

- [ ] **2.2.2** Message controller
  - Service : `src/services/message.service.js`
  - Repository : `src/repositories/message.repository.js`

- [ ] **2.2.3** Group controller
  - Service : `src/services/group.service.js`
  - Repository : `src/repositories/group.repository.js`

**Résumé** : Architecture cohérente partout

---

#### 2.3 Extraire utilitaires (Jour 7)
**Fichiers** : `src/utils/` (nouveau)

- [ ] **2.3.1** Date utils
  - Fichier : `src/utils/date.utils.js`
  - Fonctions : `toUTC()`, `combineDateAndTime()`, etc.

- [ ] **2.3.2** URL utils
  - Fichier : `src/utils/url.utils.js`
  - Fonction : `buildFileUrl()`, `buildApiUrl()`

- [ ] **2.3.3** Validation utils
  - Fichier : `src/utils/validation.utils.js`
  - Fonctions réutilisables

**Résumé** : Moins de duplication

---

#### 2.4 Linting & Formatting (Jour 8)
**Fichiers** : Configuration

- [ ] **2.4.1** Installer ESLint + Prettier
  - Action : `npm install --save-dev eslint prettier eslint-config-prettier`

- [ ] **2.4.2** Configurer ESLint
  - Fichier : `.eslintrc.js`
  - Règles : Airbnb base + custom

- [ ] **2.4.3** Configurer Prettier
  - Fichier : `.prettierrc`

- [ ] **2.4.4** Linter tout le code
  - Action : `npm run lint -- --fix`

- [ ] **2.4.5** Pre-commit hooks (optionnel)
  - Action : `npm install --save-dev husky lint-staged`

**Résumé** : Code cohérent, moins d'erreurs

---

### Livrables Phase 2
- ✅ Architecture propre (Controller/Service/Repository)
- ✅ Code DRY (moins de duplication)
- ✅ Code linté et formaté
- ✅ Tests unitaires services

### Risques Phase 2
- **Refacto peut introduire bugs** : Mitigation = tests
- **Changements nombreux** : Mitigation = commits atomiques, rollback facile

---

## ⚡ PHASE 3 : PERFORMANCE & SCALABILITÉ (6-8 jours)

### Objectifs
- Optimiser requêtes DB
- Ajouter pagination standardisée
- Préparer pour 1000 users

### Tâches

#### 3.1 Optimiser requêtes N+1 (Jour 1-2)
**Fichiers** : `src/services/ride.service.js`, etc.

- [ ] **3.1.1** Identifier requêtes N+1
  - Audit : Compter requêtes par endpoint
  - Outil : MongoDB profiler

- [ ] **3.1.2** Utiliser aggregation pipelines
  - Fichier : `src/repositories/ride.repository.js`
  - Exemple : `getRidesWithLikes()` avec `$lookup`

- [ ] **3.1.3** Batch queries
  - Exemple : `Like.countLikesByRides(rideIds)` au lieu de N appels

**Résumé** : 10x moins de requêtes DB

---

#### 3.2 Index DB (Jour 2-3)
**Fichiers** : `src/models/*.js`

- [ ] **3.2.1** Auditer index existants
  - Action : `db.collection.getIndexes()`

- [ ] **3.2.2** Ajouter index manquants
  - Ride : `date`, `typeVehicule`, `organisateur`, `participants`
  - Message : `idGroupe`, `idBalade`, `createdAt`
  - User : `email` (déjà unique), `pseudo` (déjà unique)

- [ ] **3.2.3** Index géospatial
  - Vérifier : `localisation` (2dsphere)

- [ ] **3.2.4** Script de migration
  - Fichier : `scripts/create-indexes.js`
  - Action : Créer index en production

**Résumé** : Requêtes 10-100x plus rapides

---

#### 3.3 Pagination standardisée (Jour 3-4)
**Fichiers** : `src/utils/pagination.utils.js` (nouveau), services

- [ ] **3.3.1** Créer utilitaire pagination
  - Fichier : `src/utils/pagination.utils.js`
  - Fonctions : `parsePagination()`, `buildPaginationResponse()`

- [ ] **3.3.2** Appliquer partout
  - Limite max : 100
  - Default : 20
  - Format réponse standardisé

**Résumé** : Pagination cohérente, moins de données chargées

---

#### 3.4 Logging structuré (Jour 4-5)
**Fichiers** : `src/utils/logger.js` (nouveau), tous les fichiers

- [ ] **3.4.1** Installer Winston
  - Action : `npm install winston`

- [ ] **3.4.2** Configurer logger
  - Fichier : `src/utils/logger.js`
  - Niveaux : error, warn, info, debug
  - Format : JSON en production

- [ ] **3.4.3** Middleware requestId
  - Fichier : `src/middlewares/requestId.middleware.js`
  - Ajouter requestId à chaque requête

- [ ] **3.4.4** Remplacer console.log
  - Action : Remplacer progressivement
  - Priorité : Controllers, services

**Résumé** : Logs structurés, facile à déboguer

---

#### 3.5 Cache (optionnel, Jour 6-7)
**Fichiers** : `src/services/cache.service.js` (nouveau)

- [ ] **3.5.1** Installer Redis client
  - Action : `npm install ioredis` (ou utiliser mémoire pour dev)

- [ ] **3.5.2** Service de cache
  - Fichier : `src/services/cache.service.js`
  - Méthodes : `get()`, `set()`, `del()`

- [ ] **3.5.3** Cache données fréquentes
  - Rides populaires (TTL 5 min)
  - User profiles (TTL 10 min)

**Résumé** : Moins de charge DB

---

### Livrables Phase 3
- ✅ Requêtes optimisées (pas de N+1)
- ✅ Index DB complets
- ✅ Pagination standardisée
- ✅ Logging structuré
- ✅ Cache (optionnel)

### Risques Phase 3
- **Index peuvent ralentir écritures** : Mitigation = index background
- **Cache peut servir données obsolètes** : Mitigation = TTL appropriés

---

## 🧪 PHASE 4 : TESTS & QUALITÉ (5-7 jours)

### Objectifs
- Socle de tests minimal (60% coverage)
- Pipeline CI/CD basique
- Confiance pour itérer

### Tâches

#### 4.1 Tests unitaires services (Jour 1-3)
**Fichiers** : `tests/services/`

- [ ] **4.1.1** Tests auth.service
  - Register, login, refresh token
  - Mocks : User repository

- [ ] **4.1.2** Tests ride.service
  - Create, get, filter
  - Mocks : Ride repository, Google Maps API

- [ ] **4.1.3** Tests message.service
  - Send, delete, restore
  - Mocks : Message repository

**Résumé** : Services testés

---

#### 4.2 Tests d'intégration API (Jour 3-5)
**Fichiers** : `tests/integration/`

- [ ] **4.2.1** Setup test DB
  - Fichier : `tests/setup.js`
  - Action : MongoDB en mémoire ou test DB

- [ ] **4.2.2** Tests endpoints critiques
  - Auth : register, login
  - Rides : create, list, join
  - Messages : send, list

**Résumé** : API testée end-to-end

---

#### 4.3 Coverage & CI (Jour 5-7)
**Fichiers** : Configuration

- [ ] **4.3.1** Configurer coverage
  - Action : `jest --coverage`
  - Objectif : 60% minimum

- [ ] **4.3.2** GitHub Actions (ou équivalent)
  - Fichier : `.github/workflows/ci.yml`
  - Actions : Lint, test, build

**Résumé** : CI/CD basique

---

### Livrables Phase 4
- ✅ Tests unitaires (services)
- ✅ Tests d'intégration (API)
- ✅ Coverage 60%+
- ✅ CI/CD basique

---

## 🚀 PHASE 5 : DURCISSEMENT PRODUCTION (3-4 jours)

### Objectifs
- Health checks
- Monitoring basique
- Documentation déploiement

### Tâches

#### 5.1 Health checks (Jour 1)
**Fichiers** : `src/routes/health.routes.js` (nouveau)

- [ ] **5.1.1** Endpoint `/health`
  - Action : Retourne 200 si serveur OK

- [ ] **5.1.2** Endpoint `/ready`
  - Action : Vérifie DB, retourne 200 si prêt

**Résumé** : Kubernetes/load balancer peuvent vérifier santé

---

#### 5.2 Docker (Jour 2-3)
**Fichiers** : `Dockerfile`, `docker-compose.yml`

- [ ] **5.2.1** Dockerfile
  - Multi-stage build
  - Non-root user

- [ ] **5.2.2** docker-compose.yml
  - App + MongoDB + Redis (optionnel)

**Résumé** : Déploiement reproductible

---

#### 5.3 Documentation (Jour 3-4)
**Fichiers** : `README.md`, `DEPLOYMENT.md`

- [ ] **5.3.1** README complet
  - Setup, env vars, run, test

- [ ] **5.3.2** Guide déploiement
  - Fichier : `DEPLOYMENT.md`
  - Steps : Build, deploy, migrate

**Résumé** : Onboarding facile

---

### Livrables Phase 5
- ✅ Health checks
- ✅ Docker
- ✅ Documentation complète

---

## 📊 MÉTRIQUES DE SUCCÈS

### Avant refacto
- ❌ 0% tests
- ❌ CORS "*"
- ❌ Clé API exposée
- ❌ Controllers 1700 lignes
- ❌ Requêtes N+1
- ❌ Pas d'index DB

### Après refacto
- ✅ 60%+ tests
- ✅ CORS restrictif
- ✅ Pas de secrets exposés
- ✅ Controllers <300 lignes
- ✅ Pas de N+1
- ✅ Index DB complets
- ✅ Logging structuré
- ✅ Health checks
- ✅ Docker
- ✅ Documentation

---

## 🎯 PRIORISATION POUR 500-1000 USERS

**Minimum viable pour production** :
- Phase 1 complète (sécurité)
- Phase 3.1, 3.2, 3.3 (performance)
- Phase 4.1, 4.2 (tests critiques)
- Phase 5.1 (health checks)

**Temps estimé** : 15-20 jours

**Recommandation** : Faire Phase 1 + Phase 3 critiques + Phase 4 minimal, puis itérer.

