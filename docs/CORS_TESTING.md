# Tests CORS - Documentation

Ce document explique comment tester la configuration CORS de l'API RideTogether.

## Configuration

### Variables d'environnement

- `CORS_ORIGINS` (recommandé) : Liste d'origines autorisées séparées par des virgules
- `FRONTEND_URL` (compatibilité) : Utilisé si `CORS_ORIGINS` n'est pas défini
- `NODE_ENV` : `development` (flexible) ou `production` (strict)
- `DEBUG_CORS` : `true` pour activer les logs détaillés

### Comportement selon l'environnement

#### Développement (`NODE_ENV=development`)
- ✅ Autorise automatiquement tous les `localhost`, `127.0.0.1`, `192.168.*`
- ✅ Autorise les requêtes sans origin (apps natives, Postman, curl)
- ⚠️ `CORS_ORIGINS` est optionnel

#### Production (`NODE_ENV=production`)
- ✅ Utilise strictement `CORS_ORIGINS` ou `FRONTEND_URL`
- ❌ **REFUSE toutes les origines** si aucune configuration n'est fournie
- ⚠️ `CORS_ORIGINS="*"` autorise toutes les origines (déconseillé)

## Tests avec curl

### 1. Test d'une origine autorisée

```bash
# Avec une origine autorisée
curl -X GET http://localhost:5000/api/rides \
  -H "Origin: https://app.ridetogether.fr" \
  -H "Content-Type: application/json" \
  -v
```

**Résultat attendu** :
- Status: `200 OK`
- Headers: `Access-Control-Allow-Origin: https://app.ridetogether.fr`

### 2. Test d'une origine non autorisée

```bash
# Avec une origine non autorisée
curl -X GET http://localhost:5000/api/rides \
  -H "Origin: https://evil.com" \
  -H "Content-Type: application/json" \
  -v
```

**Résultat attendu** :
- Status: `403 Forbidden` ou erreur CORS
- Message: `CORS: Origin https://evil.com is not allowed`

### 3. Test sans origin (app native, Postman)

```bash
# Sans header Origin (app native, Postman, curl)
curl -X GET http://localhost:5000/api/rides \
  -H "Content-Type: application/json" \
  -v
```

**Résultat attendu** :
- Status: `200 OK`
- ✅ Autorisé (requêtes sans origin sont acceptées)

### 4. Test OPTIONS (preflight)

```bash
# Requête preflight CORS
curl -X OPTIONS http://localhost:5000/api/rides \
  -H "Origin: https://app.ridetogether.fr" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  -v
```

**Résultat attendu** :
- Status: `204 No Content`
- Headers:
  - `Access-Control-Allow-Origin: https://app.ridetogether.fr`
  - `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS`
  - `Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With`
  - `Access-Control-Allow-Credentials: true`

### 5. Test en production sans configuration

```bash
# Simuler production sans CORS_ORIGINS
NODE_ENV=production CORS_ORIGINS= \
curl -X GET http://localhost:5000/api/rides \
  -H "Origin: https://app.ridetogether.fr" \
  -H "Content-Type: application/json" \
  -v
```

**Résultat attendu** :
- Status: `403 Forbidden` ou erreur CORS
- Message: `CORS: Origin https://app.ridetogether.fr is not allowed. Aucune origine configurée en production.`

## Tests avec Postman

1. **Créer une requête GET** vers `http://localhost:5000/api/rides`
2. **Dans l'onglet Headers**, ajouter :
   - `Origin: https://app.ridetogether.fr` (ou une origine non autorisée pour tester le rejet)
3. **Envoyer la requête**
4. **Vérifier les headers de réponse** :
   - `Access-Control-Allow-Origin` doit correspondre à l'origine envoyée si autorisée
   - Sinon, erreur 403

## Tests Socket.io

Socket.io utilise la même logique CORS que Express.

### Test avec un client WebSocket

```javascript
// Client JavaScript (dans la console du navigateur)
const socket = io('http://localhost:5000', {
  transports: ['websocket'],
  withCredentials: true
});

socket.on('connect', () => {
  console.log('✅ Connecté');
});

socket.on('connect_error', (error) => {
  console.error('❌ Erreur de connexion:', error.message);
  // Si CORS: "Not allowed by CORS" ou "Socket.io CORS: Origin ... is not allowed"
});
```

### Test avec wscat (CLI)

```bash
# Installer wscat: npm install -g wscat

# Test connexion
wscat -c ws://localhost:5000 -H "Origin: https://app.ridetogether.fr"
```

## Vérification des logs

### Activer les logs détaillés

```bash
DEBUG_CORS=true npm start
```

### Logs attendus

#### Origine autorisée
```
✅ CORS: Origin dans whitelist: https://app.ridetogether.fr
```

#### Origine refusée
```
🚫 CORS blocked for origin: https://evil.com
   NODE_ENV: production
   isDevelopment: false
   Allowed origins: [ 'https://app.ridetogether.fr' ]
```

#### Production sans config
```
❌ CORS: Aucune origine configurée en production. CORS_ORIGINS ou FRONTEND_URL requis.
   Exemple: CORS_ORIGINS=https://app.ridetogether.fr,https://www.app.ridetogether.fr
```

## Checklist de déploiement production

- [ ] `NODE_ENV=production` est défini
- [ ] `CORS_ORIGINS` est configuré avec toutes les origines autorisées
- [ ] Tester avec curl chaque origine autorisée
- [ ] Tester avec curl une origine non autorisée (doit être refusée)
- [ ] Vérifier les logs avec `DEBUG_CORS=true`
- [ ] Tester Socket.io avec les mêmes origines
- [ ] Documenter les origines autorisées pour l'équipe

## Exemples de configuration

### Développement local
```env
NODE_ENV=development
# CORS_ORIGINS optionnel, localhost autorisé automatiquement
```

### Production single domain
```env
NODE_ENV=production
CORS_ORIGINS=https://app.ridetogether.fr
```

### Production multiple domains
```env
NODE_ENV=production
CORS_ORIGINS=https://app.ridetogether.fr,https://www.app.ridetogether.fr,https://panel.ridetogether.fr
```

### Production avec sous-domaines wildcard (non supporté directement)
```env
NODE_ENV=production
# Il faut lister chaque sous-domaine explicitement:
CORS_ORIGINS=https://app.ridetogether.fr,https://api.ridetogether.fr,https://panel.ridetogether.fr
```

## Dépannage

### Problème: Toutes les origines sont refusées en production

**Cause**: `CORS_ORIGINS` ou `FRONTEND_URL` non configuré

**Solution**: Ajouter `CORS_ORIGINS=https://votre-domaine.com` dans `.env`

### Problème: Une origine autorisée est refusée

**Causes possibles**:
1. Typo dans `CORS_ORIGINS` (espaces, http vs https)
2. Port manquant (ex: `http://localhost` au lieu de `http://localhost:3000`)
3. Trailing slash (ex: `https://app.ridetogether.fr/` au lieu de `https://app.ridetogether.fr`)

**Solution**: Vérifier exactement l'origine envoyée dans les logs avec `DEBUG_CORS=true`

### Problème: Socket.io ne se connecte pas

**Cause**: Même logique CORS que Express, vérifier que l'origine est dans `CORS_ORIGINS`

**Solution**: Vérifier les logs Socket.io avec `DEBUG_CORS=true`

