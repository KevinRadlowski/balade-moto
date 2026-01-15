# Codes d'erreur standardisés - API RideTogether

Ce document liste tous les codes d'erreur standardisés utilisés par l'API.

## Format de réponse d'erreur

Toutes les erreurs suivent ce format :

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Message d'erreur lisible",
    "details": {
      // Détails optionnels (seulement si pertinents)
    }
  },
  "errors": [
    // Erreurs de validation (seulement pour VALIDATION_ERROR)
    {
      "field": "email",
      "message": "Email invalide",
      "value": "invalid-email"
    }
  ],
  "debug": {
    // Seulement en développement
    "stack": "...",
    "name": "ErrorName",
    "statusCode": 400
  }
}
```

## Codes d'erreur

### 400 - Bad Request

| Code | Description | Détails |
|------|-------------|---------|
| `BAD_REQUEST` | Requête invalide | - |
| `VALIDATION_ERROR` | Erreur de validation | `errors`: Array d'erreurs par champ |
| `FILE_TOO_LARGE` | Fichier trop volumineux | `multerCode`, `field` |
| `TOO_MANY_FILES` | Trop de fichiers | `multerCode`, `field` |
| `UNEXPECTED_FIELD` | Champ de fichier inattendu | `multerCode`, `field` |
| `UPLOAD_ERROR` | Erreur lors de l'upload | `multerCode`, `field` |

### 401 - Unauthorized

| Code | Description | Détails |
|------|-------------|---------|
| `UNAUTHORIZED` | Non autorisé | - |
| `INVALID_TOKEN` | Token JWT invalide | - |
| `TOKEN_EXPIRED` | Token JWT expiré | - |

### 403 - Forbidden

| Code | Description | Détails |
|------|-------------|---------|
| `FORBIDDEN` | Accès interdit | - |
| `PLAN_LIMIT` | Limite de plan atteinte | `limit`, `current`, `remaining`, `plan`, `limitKey` |
| `CORS_ERROR` | Origine non autorisée | `origin` (dev seulement) |

### 404 - Not Found

| Code | Description | Détails |
|------|-------------|---------|
| `NOT_FOUND` | Ressource non trouvée | - |

### 409 - Conflict

| Code | Description | Détails |
|------|-------------|---------|
| `CONFLICT` | Conflit (ex: duplication) | `field`, `value`, `duplicate: true` |

### 422 - Unprocessable Entity

| Code | Description | Détails |
|------|-------------|---------|
| `VALIDATION_ERROR` | Erreur de validation (alternative) | `errors`: Array |

### 429 - Too Many Requests

| Code | Description | Détails |
|------|-------------|---------|
| `RATE_LIMIT_EXCEEDED` | Trop de requêtes | `retryAfter`: secondes |

### 500 - Internal Server Error

| Code | Description | Détails |
|------|-------------|---------|
| `INTERNAL_SERVER_ERROR` | Erreur interne du serveur | `originalError` (dev seulement) |

### 503 - Service Unavailable

| Code | Description | Détails |
|------|-------------|---------|
| `SERVICE_UNAVAILABLE` | Service indisponible | - |

## Mapping des erreurs Mongoose

Les erreurs Mongoose sont automatiquement mappées :

| Erreur Mongoose | Code API | Status Code |
|-----------------|----------|-------------|
| `ValidationError` | `VALIDATION_ERROR` | 400 |
| `CastError` | `BAD_REQUEST` | 400 |
| `MongoServerError` (code 11000) | `CONFLICT` | 409 |
| `MongoServerError` (autre) | `INTERNAL_SERVER_ERROR` | 500 |

## Exemples

### Erreur de validation

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Erreur de validation"
  },
  "errors": [
    {
      "field": "email",
      "message": "Email invalide",
      "value": "invalid"
    },
    {
      "field": "password",
      "message": "Le mot de passe doit contenir au moins 8 caractères",
      "value": "short"
    }
  ]
}
```

### Erreur de limite de plan

```json
{
  "success": false,
  "error": {
    "code": "PLAN_LIMIT",
    "message": "Vous avez atteint votre limite de 5 véhicules avec le plan Standard...",
    "details": {
      "limit": 5,
      "current": 5,
      "remaining": 0,
      "plan": "FREE",
      "limitKey": "maxVehiclesTotal"
    }
  }
}
```

### Erreur de duplication

```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "pseudo déjà utilisé(e): john_doe",
    "details": {
      "field": "pseudo",
      "value": "john_doe",
      "duplicate": true
    }
  }
}
```

### Erreur interne (production)

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "Erreur interne du serveur"
  }
}
```

### Erreur interne (développement)

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "Erreur interne du serveur",
    "details": {
      "originalError": "ErrorName"
    }
  },
  "debug": {
    "stack": "Error: ...\n    at ...",
    "name": "ErrorName",
    "statusCode": 500,
    "isOperational": false
  }
}
```

## Utilisation dans le code

### Créer une erreur personnalisée

```javascript
const { BadRequestError, NotFoundError } = require('../utils/errors');

// Erreur simple
throw new BadRequestError('Email invalide');

// Erreur avec détails
throw new BadRequestError('Email invalide', { field: 'email', value: 'invalid' });

// Erreur de ressource non trouvée
throw new NotFoundError('Utilisateur');
```

### Gérer les erreurs Mongoose

Les erreurs Mongoose sont automatiquement mappées par le middleware d'erreur. Pas besoin de code supplémentaire.

### Codes personnalisés

Pour créer une erreur avec un code personnalisé :

```javascript
const { AppError } = require('../utils/errors');

throw new AppError(
  'Service indisponible',
  503,
  'SERVICE_UNAVAILABLE',
  { service: 'payment', reason: 'maintenance' }
);
```

## Migration depuis l'ancien format

### Avant

```javascript
res.status(400).json({
  success: false,
  message: 'Erreur de validation',
  error: err.message
});
```

### Après

```javascript
const { ValidationError } = require('../utils/errors');
throw new ValidationError('Erreur de validation', errors);
```

Le middleware d'erreur s'occupe automatiquement du format de réponse.

