# Plans d'abonnement FREE vs PREMIUM

## Vue d'ensemble

L'application propose deux plans d'abonnement :
- **FREE** : Plan gratuit avec limitations sur la création de ressources
- **PREMIUM** : Plan payant avec fonctionnalités illimitées

**Important** : Les limites s'appliquent uniquement à la **CRÉATION** de ressources, pas à la **PARTICIPATION**.
- Un utilisateur FREE peut participer à autant de balades/groupes qu'il veut
- Un utilisateur FREE peut voir toutes les balades/groupes publics
- Les limites s'appliquent uniquement lors de la création de nouvelles ressources

## Tableau comparatif des limites

| Fonctionnalité | Plan FREE | Plan PREMIUM |
|----------------|-----------|--------------|
| **Véhicules** |
| Nombre total de véhicules | 2 | Illimité |
| Nombre de motos | 1 | Illimité |
| Nombre de voitures | 1 | Illimité |
| Photos totales (tous véhicules) | 12 | Illimité |
| **Groupes** |
| Groupes privés créés | 1 | Illimité |
| Groupes publics créés | Illimité | Illimité |
| Participation aux groupes | Illimité | Illimité |
| **Balades** |
| Balades privées créées par mois | 2 | Illimité |
| Balades publiques créées | Illimité | Illimité |
| Participation aux balades | Illimité | Illimité |

## Endpoints concernés

Les endpoints suivants vérifient les limites du plan :

### Garage (Véhicules)

- **`POST /api/garage/vehicles`** : Création d'un véhicule
  - Vérifie `maxVehiclesTotal` (2 pour FREE)
  - Vérifie `maxVehiclesByType` (1 moto et 1 voiture pour FREE)

- **`POST /api/garage/vehicles/:id/photos`** : Ajout de photos à un véhicule
  - Vérifie `maxPhotosTotal` (12 photos au total pour FREE)

### Groupes

- **`POST /api/groups`** : Création d'un groupe
  - Vérifie `maxPrivateGroupsCreated` (1 groupe privé pour FREE)
  - Les groupes publics ne sont pas limités

### Balades

- **`POST /api/rides`** : Création d'une balade
  - Vérifie `maxPrivateRidesCreatedPerMonth` (2 balades privées par mois pour FREE)
  - Les balades publiques ne sont pas limitées

### Informations du plan

- **`GET /api/users/me/plan`** : Récupération des informations du plan de l'utilisateur
  - Retourne le plan actuel, les limites et l'utilisation actuelle

## Structure des erreurs PLAN_LIMIT

Lorsqu'un utilisateur FREE tente de créer une ressource au-delà de sa limite, l'API renvoie une erreur standardisée avec le code HTTP **403 Forbidden**.

### Format de la réponse

```json
{
  "success": false,
  "code": "PLAN_LIMIT",
  "message": "Limite atteinte : vous ne pouvez créer que {limit} {resourceName} avec le plan gratuit (actuellement {current}). Passez à Premium pour créer un nombre illimité de {resourceName}.",
  "details": {
    "limit": 2,
    "current": 2,
    "remaining": 0,
    "plan": "FREE"
  }
}
```

### Propriétés de l'erreur

- **`success`** (boolean) : Toujours `false` pour les erreurs
- **`code`** (string) : Toujours `"PLAN_LIMIT"` pour les erreurs de quota
- **`message`** (string) : Message d'erreur explicite en français
- **`details`** (object) : Détails de la limite
  - **`limit`** (number) : La valeur de la limite pour le plan FREE
  - **`current`** (number) : Le nombre actuel de ressources créées
  - **`remaining`** (number) : Le nombre de ressources restantes (max(0, limit - current))
  - **`plan`** (string) : Le plan de l'utilisateur (`"FREE"` ou `"PREMIUM"`)

### Exemples d'erreurs

#### Limite de véhicules atteinte

```json
{
  "success": false,
  "code": "PLAN_LIMIT",
  "message": "Limite atteinte : vous ne pouvez créer que 2 véhicule(s) avec le plan gratuit (actuellement 2). Passez à Premium pour créer un nombre illimité de véhicule(s).",
  "details": {
    "limit": 2,
    "current": 2,
    "remaining": 0,
    "plan": "FREE"
  }
}
```

#### Limite de photos atteinte

```json
{
  "success": false,
  "code": "PLAN_LIMIT",
  "message": "Limite atteinte : vous ne pouvez avoir que 12 photo(s) avec le plan gratuit (actuellement 12). Passez à Premium pour un nombre illimité de photo(s).",
  "details": {
    "limit": 12,
    "current": 12,
    "remaining": 0,
    "plan": "FREE"
  }
}
```

#### Limite de balades privées par mois atteinte

```json
{
  "success": false,
  "code": "PLAN_LIMIT",
  "message": "Limite atteinte : vous ne pouvez créer que 2 balade(s) privée(s) par mois avec le plan gratuit (actuellement 2). Passez à Premium pour créer un nombre illimité de balade(s) privée(s) par mois.",
  "details": {
    "limit": 2,
    "current": 2,
    "remaining": 0,
    "plan": "FREE"
  }
}
```

#### Limite de groupes privés atteinte

```json
{
  "success": false,
  "code": "PLAN_LIMIT",
  "message": "Limite atteinte : vous ne pouvez créer que 1 groupe(s) privé(s) avec le plan gratuit (actuellement 1). Passez à Premium pour créer un nombre illimité de groupe(s) privé(s).",
  "details": {
    "limit": 1,
    "current": 1,
    "remaining": 0,
    "plan": "FREE"
  }
}
```

## Gestion côté client

Lors de la réception d'une erreur `PLAN_LIMIT`, le client peut :

1. Afficher le message d'erreur à l'utilisateur
2. Utiliser les informations de `details` pour afficher un message personnalisé
3. Proposer un lien vers la page d'upgrade vers Premium
4. Afficher la progression (ex: "2/2 véhicules utilisés")

## Configuration

Les limites sont définies dans `src/config/premium.config.js` :

```javascript
const FREE_LIMITS = {
  maxVehiclesTotal: 2,
  maxVehiclesByType: {
    moto: 1,
    voiture: 1,
  },
  maxPrivateGroupsCreated: 1,
  maxPrivateRidesCreatedPerMonth: 2,
  maxPhotosTotal: 12,
};

const PREMIUM_LIMITS = {
  unlimited: true,
};
```

## Notes techniques

- Le middleware `subscriptionMiddleware` normalise automatiquement l'état de l'abonnement à chaque requête
- Les vérifications de quota sont effectuées dans les contrôleurs avant la création de la ressource
- Les erreurs `PLAN_LIMIT` sont générées via la fonction utilitaire `createPlanLimitError()` dans `src/utils/errors.js`
- Le middleware d'erreur global (`error.middleware.js`) formate automatiquement les erreurs `PLAN_LIMIT` avec la structure standardisée
