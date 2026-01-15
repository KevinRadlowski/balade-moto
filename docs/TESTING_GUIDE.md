# Guide de Tests - RideTogether API

**Date** : 2025-01-27  
**Framework** : Jest + Supertest

---

## 📋 STRUCTURE DES TESTS

```
tests/
├── services/
│   ├── ride.service.test.js      ✅ Tests unitaires ride.service
│   ├── planQuota.service.test.js ✅ Tests existants
│   └── ...
├── integration/
│   └── ride.routes.test.js       ✅ Tests d'intégration routes rides
└── ...
```

---

## 🧪 TESTS UNITAIRES

### Tests pour `ride.service.js`

**Fichier** : `tests/services/ride.service.test.js`

**Méthodes testées** :
- ✅ `getRideById()` - Récupération avec vérification d'accès
- ✅ `createRide()` - Création avec validation
- ✅ `joinRide()` - Rejoindre une balade
- ✅ `leaveRide()` - Quitter une balade
- ✅ `likeRide()` - Like une balade
- ✅ `buildRideFilters()` - Construction de filtres

**Mocking** :
- `rideRepository` - Mocké pour éviter les appels DB réels
- `enrichRidesWithLikes` - Mocké
- `subscriptionService` - Mocké
- `premiumConfig` - Mocké

**Exemple** :
```javascript
describe('getRideById', () => {
  it('devrait retourner une balade existante et accessible', async () => {
    rideRepository.findById.mockResolvedValue(mockRide);
    const result = await rideService.getRideById(rideId, user);
    expect(result).toBeDefined();
  });
});
```

---

## 🔗 TESTS D'INTÉGRATION

### Tests pour routes rides

**Fichier** : `tests/integration/ride.routes.test.js`

**Endpoints testés** :
- ✅ `GET /api/rides` - Liste avec pagination
- ✅ `GET /api/rides/:id` - Détail d'une balade
- ✅ `POST /api/rides` - Création
- ✅ `PUT /api/rides/:id` - Mise à jour
- ✅ `DELETE /api/rides/:id` - Suppression

**Setup** :
- Base de données de test : `mongodb://localhost:27017/ridetogether_test`
- Utilisateur de test créé avec token JWT
- Nettoyage automatique après chaque test

**Exemple** :
```javascript
describe('GET /api/rides', () => {
  it('devrait retourner une liste de balades avec pagination', async () => {
    const response = await request(app)
      .get('/api/rides')
      .set('Authorization', `Bearer ${authToken}`)
      .query({ page: 1, limit: 10 })
      .expect(200);
    
    expect(response.body.data.pagination).toBeDefined();
  });
});
```

---

## 🚀 EXÉCUTION DES TESTS

### Tous les tests
```bash
npm test
```

### Tests en mode watch
```bash
npm run test:watch
```

### Tests pour CI/CD
```bash
npm run test:ci
```

### Tests spécifiques
```bash
# Tests unitaires seulement
npm test -- tests/services

# Tests d'intégration seulement
npm test -- tests/integration

# Un fichier spécifique
npm test -- tests/services/ride.service.test.js
```

---

## 📊 COVERAGE

### Configuration

Le coverage est configuré dans `jest.config.js` :
- **Seuil minimum** : 70% (branches, functions, lines, statements)
- **Fichiers exclus** : `node_modules/`, `tests/`, `src/app.js`, `src/config/`

### Voir le coverage
```bash
npm test -- --coverage
```

Le rapport est généré dans `coverage/` :
- `coverage/lcov-report/index.html` - Rapport HTML
- `coverage/lcov.info` - Format LCOV

---

## 🔧 CONFIGURATION

### Variables d'environnement pour tests

Créer un fichier `.env.test` (optionnel) :
```env
NODE_ENV=test
MONGO_URI=mongodb://localhost:27017/ridetogether_test
JWT_SECRET=test-secret-key
REDIS_ENABLED=false
```

### Base de données de test

Les tests d'intégration utilisent une DB séparée :
- **URI** : `mongodb://localhost:27017/ridetogether_test`
- **Nettoyage** : Automatique après chaque test
- **Isolation** : Chaque test démarre avec une DB propre

---

## 📝 BONNES PRATIQUES

### Tests unitaires
1. **Mock toutes les dépendances** (DB, services externes)
2. **Teste un comportement à la fois**
3. **Nomme les tests clairement** : "devrait [comportement attendu]"
4. **Utilise `beforeEach`** pour réinitialiser les mocks

### Tests d'intégration
1. **Utilise une DB de test séparée**
2. **Nettoie après chaque test** (`afterEach` ou `beforeEach`)
3. **Crée des données de test réalistes**
4. **Teste les cas d'erreur** (404, 403, 400)

### Structure AAA
```javascript
it('devrait créer une balade', async () => {
  // Arrange - Préparer les données
  const rideData = { titre: 'Test', ... };
  
  // Act - Exécuter l'action
  const result = await rideService.createRide(rideData, user);
  
  // Assert - Vérifier le résultat
  expect(result.titre).toBe('Test');
});
```

---

## 🐛 DÉPANNAGE

### Erreur "Cannot find module"
```bash
npm install --save-dev jest supertest
```

### Erreur de connexion MongoDB
- Vérifier que MongoDB est démarré
- Vérifier `MONGO_URI` dans `.env.test`

### Tests qui échouent aléatoirement
- Vérifier l'isolation des tests (nettoyage DB)
- Vérifier les mocks (réinitialisation dans `beforeEach`)

### Coverage trop bas
- Ajouter des tests pour les branches non couvertes
- Vérifier les fichiers exclus dans `jest.config.js`

---

## 📚 RESSOURCES

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest Documentation](https://github.com/visionmedia/supertest)
- `jest.config.js` - Configuration Jest
- `tests/services/ride.service.test.js` - Exemple tests unitaires
- `tests/integration/ride.routes.test.js` - Exemple tests d'intégration

---

**Dernière mise à jour** : 2025-01-27

