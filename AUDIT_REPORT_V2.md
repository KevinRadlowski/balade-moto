# Rapport d'Audit de Sécurité V2 - RideTogether

**Date**: $(date)  
**Auditeur**: Staff Engineer (Sécurité + Backend + Flutter)  
**Objectif**: Durcir et stabiliser le repository sans régression

---

## 📋 Résumé Exécutif

Cet audit identifie et corrige les vulnérabilités de sécurité critiques (P0) et importantes (P1) dans le repository RideTogether.

### Statut Global
- ✅ **ÉTAPE 1**: Nettoyage sécurité - **TERMINÉ**
- ✅ **ÉTAPE 2**: Sécurisation Google Maps proxy - **TERMINÉ**
- 🔄 **ÉTAPE 3**: Durcissement uploads - **EN COURS**
- ⏳ **ÉTAPE 4**: Refactor app/server - **EN ATTENTE**
- ⏳ **ÉTAPE 5**: Centralisation erreurs - **EN ATTENTE**
- ⏳ **ÉTAPE 6**: DB index fix - **EN ATTENTE**
- ⏳ **ÉTAPE 7**: CI GitHub Actions - **EN ATTENTE**

---

## 🔍 Findings Détailés

### ÉTAPE 1 - Nettoyage Sécurité (P0) ✅

#### Finding 1.1: Secrets potentiellement exposés
**Statut**: ✅ **FIXED**

**Description**:
- Pas de `.env.example` pour documenter les variables requises
- `.gitignore` incomplet (pas de protection pour `.git/`, patterns de secrets)

**Corrections**:
- ✅ Créé `.env.example` avec template sans valeurs sensibles
- ✅ Durci `.gitignore`:
  - Ajout de patterns pour secrets (`*.secret`, `secrets/`, etc.)
  - Exclusion explicite de `.git/`
  - Exclusion stricte de `src/uploads/` avec `.gitkeep` uniquement
- ✅ Créé scripts de scan de secrets (`scripts/scan-secrets.sh` et `.ps1`)
- ✅ Créé `SECURITY.md` avec guide de rotation des secrets

**Preuve**:
- Fichier: `.env.example`
- Fichier: `.gitignore` (lignes 7-12, 53-56)
- Fichier: `SECURITY.md`
- Fichier: `scripts/scan-secrets.sh` et `.ps1`

---

#### Finding 1.2: Fichiers uploads versionnés
**Statut**: ✅ **FIXED**

**Description**:
- `src/uploads/` contient des fichiers committés (avatars, backgrounds, messages)
- Risque: exposition de données utilisateurs, consommation inutile de Git

**Corrections**:
- ✅ `.gitignore` mis à jour pour exclure strictement `src/uploads/**`
- ✅ Créé `.gitkeep` dans `src/uploads/` et sous-dossiers pour préserver la structure
- ✅ Documentation dans `SECURITY.md`

**Preuve**:
- Fichier: `.gitignore` (lignes 53-56)
- Fichiers: `src/uploads/.gitkeep`, `src/uploads/avatars/.gitkeep`, etc.

**Action requise**:
```bash
# Supprimer les fichiers uploads du tracking Git (à faire manuellement)
git rm -r --cached src/uploads/avatars/* src/uploads/backgrounds/* src/uploads/messages/*
git commit -m "security: remove uploaded files from versioning"
```

---

### ÉTAPE 2 - Sécurisation Google Maps Proxy (P0) ✅

#### Finding 2.1: Endpoints Google Maps non protégés
**Statut**: ✅ **FIXED**

**Description**:
- Routes `/directions/route`, `/geocode`, `/reverse-geocode` accessibles sans authentification
- Pas de rate limiting
- Pas de validation des entrées
- Risque: abus de quota API, coûts, DoS

**Corrections**:
- ✅ Ajout de `authMiddleware` sur les 3 routes
- ✅ Ajout de `rateLimitMiddleware(20, 60000)` (20 req/min)
- ✅ Créé `src/validators/google-maps.validator.js`:
  - `validateCalculateRoute`: validation origin/destination/waypoints (taille max 500/2000, charset)
  - `validateGeocodeAddress`: validation address (taille max 500, charset)
  - `validateReverseGeocode`: validation lat/lng (float, range -90/90, -180/180)
- ✅ Implémenté cache LRU en mémoire (`src/utils/cache.js`):
  - `routeCache`: TTL 5 min, max 50 entrées
  - `geocodeCache`: TTL 10 min, max 100 entrées
  - `reverseGeocodeCache`: TTL 10 min, max 100 entrées
- ✅ Uniformisé gestion d'erreurs: `next(err)` au lieu de `res.status(500).json()`

**Preuve**:
- Fichier: `src/routes/ride.routes.js` (lignes 23-45)
- Fichier: `src/validators/google-maps.validator.js`
- Fichier: `src/utils/cache.js`
- Fichier: `src/controllers/ride.controller.js` (calculateRoute, geocodeAddress, reverseGeocode)

**Tests recommandés**:
```bash
# Test rate limit
for i in {1..25}; do curl -H "Authorization: Bearer $TOKEN" "http://localhost:5000/api/rides/geocode?address=Paris"; done

# Test validation
curl -H "Authorization: Bearer $TOKEN" "http://localhost:5000/api/rides/geocode?address=<script>alert('xss')</script>"
```

---

### ÉTAPE 3 - Durcissement Uploads (P0) 🔄

#### Finding 3.1: Upload permissif pour type=file
**Statut**: 🔄 **EN COURS**

**Description**:
- `message-upload.middleware.js` ligne 138: `else { cb(null, true); }` accepte TOUT pour type=file
- Pas de vérification de signature (magic bytes)
- Pas d'interdiction explicite de fichiers dangereux (.html, .js, .svg, .exe, .bat, .ps1, etc.)
- Risque: upload de malware, XSS via HTML/JS, exécution de scripts

**Corrections prévues**:
- [ ] Whitelist stricte pour type=file (pdf, txt, docx, xlsx uniquement)
- [ ] Vérification de signature (magic bytes) via `file-type` ou `mmmagic`
- [ ] Interdiction explicite: .html, .js, .svg, .exe, .bat, .ps1, .sh, .php, etc.
- [ ] Taille max différente selon type (fichiers < images/vidéos)
- [ ] Appliquer même durcissement à `upload.middleware.js` et `background-upload.middleware.js`
- [ ] Tests unitaires sur fileFilter

**Fichiers concernés**:
- `src/middlewares/message-upload.middleware.js`
- `src/middlewares/upload.middleware.js`
- `src/middlewares/background-upload.middleware.js`

---

#### Finding 3.2: Exposition statique /uploads avec ACAO="*"
**Statut**: ⏳ **EN ATTENTE**

**Description**:
- `src/app.js` ligne 154: `Access-Control-Allow-Origin: *` sur `/uploads`
- Risque: CORS permissif, accès cross-origin non contrôlé

**Corrections prévues**:
- [ ] Retirer ACAO="*" ou aligner avec whitelist CORS
- [ ] Forcer `Content-Disposition: attachment` pour fichiers non-image
- [ ] Désactiver middleware debug `/uploads` en production

**Fichier concerné**:
- `src/app.js` (lignes 141-157)

---

### ÉTAPE 4 - Architecture app/server (P1) ⏳

#### Finding 4.1: Side effects au démarrage
**Statut**: ⏳ **EN ATTENTE**

**Description**:
- `src/app.js` exécute `connectDB()`, `server.listen()`, `startNotificationScheduler()` à l'import
- Impossible de tester sans démarrer le serveur
- Risque: tests non isolés, difficulté de mocking

**Corrections prévues**:
- [ ] Refactor: `src/app.js` => `createApp()` (Express + middlewares + routes)
- [ ] Créer `src/server.js`: `connectDB()` + `scheduler` + `server.listen()`
- [ ] Ne lancer `server.listen()` que si `require.main === module`
- [ ] Adapter tests pour importer `createApp()` sans side effects
- [ ] Ajouter `jest` + `supertest` en devDependencies
- [ ] Config test DB isolée (`MONGO_URI_TEST`)

**Fichiers concernés**:
- `src/app.js`
- `src/server.js` (à créer)
- `package.json`

---

### ÉTAPE 5 - Centralisation Erreurs (P1) ⏳

#### Finding 5.1: Gestion d'erreurs incohérente
**Statut**: ⏳ **EN ATTENTE**

**Description**:
- Certains controllers utilisent `res.status(500).json({ error: error.message })` au lieu de `next(err)`
- Stack traces potentiellement exposées en production
- `error.middleware.js` existe mais pas utilisé partout

**Corrections prévues**:
- [ ] Remplacer tous les `res.status(500).json()` par `next(err)` dans controllers
- [ ] Vérifier que `error.middleware.js` masque stack traces en prod
- [ ] Utiliser `utils/errors` (AppError, InternalServerError, etc.) partout

**Fichiers concernés**:
- `src/controllers/*.js` (rechercher `res.status(500)`)
- `src/middlewares/error.middleware.js` (vérifier masquage prod)

---

### ÉTAPE 6 - DB Index Fix (P1) ⏳

#### Finding 6.1: fixPseudoIndex() au démarrage
**Statut**: ⏳ **EN ATTENTE**

**Description**:
- `src/config/db.js` appelle `fixPseudoIndex()` à chaque démarrage
- Risque: ralentissement, side effects non désirés

**Corrections prévues**:
- [ ] Retirer `fixPseudoIndex()` du démarrage
- [ ] Créer script migration idempotent: `scripts/migrate-indexes.js`
- [ ] Documenter exécution dans README

**Fichiers concernés**:
- `src/config/db.js` (ligne 11)
- `scripts/migrate-indexes.js` (à créer)

---

### ÉTAPE 7 - CI GitHub Actions (P1) ⏳

#### Finding 7.1: Pas de CI/CD
**Statut**: ⏳ **EN ATTENTE**

**Description**:
- Pas de GitHub Actions
- Pas de tests automatisés
- Pas de scan de secrets automatisé

**Corrections prévues**:
- [ ] Créer `.github/workflows/ci.yml`:
  - `npm ci`
  - `npm run lint` (à ajouter eslint/prettier)
  - `npm test` (jest)
  - `npm audit` + scan OSV
  - `gitleaks` ou scan secrets
- [ ] Ajouter badges README si utile

**Fichiers concernés**:
- `.github/workflows/ci.yml` (à créer)
- `package.json` (ajouter scripts lint/test)
- `README.md` (badges)

---

## 📊 Métriques

- **Findings P0 (Critiques)**: 4
  - ✅ Fixés: 2
  - 🔄 En cours: 1
  - ⏳ En attente: 1

- **Findings P1 (Importants)**: 4
  - ⏳ En attente: 4

- **Total**: 8 findings
  - ✅ **25%** fixés
  - 🔄 **12.5%** en cours
  - ⏳ **62.5%** en attente

---

## 🎯 Prochaines Étapes

1. **Terminer ÉTAPE 3** (Durcissement uploads)
2. **ÉTAPE 4** (Refactor app/server)
3. **ÉTAPE 5** (Centralisation erreurs)
4. **ÉTAPE 6** (DB index fix)
5. **ÉTAPE 7** (CI GitHub Actions)

---

## 📝 Notes

- Tous les commits doivent être cohérents et testables
- Chaque fix P0 doit avoir au minimum une vérification automatisée
- Maintenir compatibilité API côté Flutter
- Ne jamais afficher de secrets dans les logs/commits

---

**Dernière mise à jour**: $(date)







