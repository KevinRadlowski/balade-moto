# Garage API Documentation

## Vue d'ensemble

L'API Garage permet de gérer les véhicules, les relevés kilométriques et les maintenances pour chaque utilisateur. Toutes les routes nécessitent une authentification JWT.

## Variables d'environnement

Ajoutez ces variables dans votre fichier `.env` :

```env
# Fenêtres de rappel pour les maintenances (optionnel, valeurs par défaut)
MAINTENANCE_UPCOMING_KM_WINDOW=500      # Kilomètres avant la date d'échéance pour marquer comme "UPCOMING"
MAINTENANCE_UPCOMING_DAYS_WINDOW=30     # Jours avant la date d'échéance pour marquer comme "UPCOMING"
```

## Endpoints

### Véhicules

#### POST `/api/garage/vehicles`
Créer un nouveau véhicule.

**Body:**
```json
{
  "name": "Ma moto",
  "brand": "Yamaha",
  "model": "MT-07",
  "year": 2020,
  "type": "moto",
  "color": "Noir",
  "odometerCurrentKm": 5000,
  "purchaseDate": "2020-01-15",
  "description": "Ma première moto"
}
```

#### GET `/api/garage/vehicles`
Liste paginée des véhicules de l'utilisateur.

**Query params:**
- `page` (optionnel, défaut: 1)
- `limit` (optionnel, défaut: 20, max: 100)
- `type` (optionnel: "moto" ou "voiture")

#### GET `/api/garage/vehicles/:id`
Détails d'un véhicule spécifique.

#### PATCH `/api/garage/vehicles/:id`
Mettre à jour un véhicule.

#### DELETE `/api/garage/vehicles/:id`
Supprimer un véhicule (soft delete: `active = false`).

### Odomètre

#### POST `/api/garage/vehicles/:id/odometer`
Ajouter une entrée odomètre. Met automatiquement à jour `vehicle.odometerCurrentKm` si le nouveau kilométrage est supérieur.

**Body:**
```json
{
  "km": 5500,
  "date": "2024-01-20",
  "notes": "Relevé après balade"
}
```

#### GET `/api/garage/vehicles/:id/odometer`
Liste paginée des entrées odomètre pour un véhicule.

**Query params:**
- `page` (optionnel, défaut: 1)
- `limit` (optionnel, défaut: 20, max: 100)

### Maintenance

#### POST `/api/garage/vehicles/:id/maintenance/items`
Créer un élément de maintenance récurrent.

**Body:**
```json
{
  "type": "vidange",
  "name": "Vidange moteur",
  "description": "Vidange complète avec filtre",
  "intervalKm": 5000,
  "intervalDays": 180,
  "lastDoneAtKm": 5000,
  "lastDoneAtDate": "2024-01-01",
  "cost": 50,
  "notes": "Utiliser huile 10W40",
  "parts": [
    {
      "name": "Huile moteur",
      "reference": "H10W40-5L",
      "price": 30
    }
  ]
}
```

**Types de maintenance disponibles:**
- `vidange`
- `filtre_huile`
- `filtre_air`
- `filtre_essence`
- `bougies`
- `freins`
- `pneus`
- `batterie`
- `chaines`
- `liquide_refroidissement`
- `liquide_freins`
- `revision`
- `autre`

#### GET `/api/garage/vehicles/:id/maintenance/dashboard`
Dashboard de maintenance avec statuts calculés.

**Réponse:**
```json
{
  "success": true,
  "data": {
    "vehicle": {
      "_id": "...",
      "name": "Ma moto",
      "odometerCurrentKm": 5500
    },
    "dashboard": {
      "due": [...],      // Éléments DUE (échéance dépassée)
      "upcoming": [...],  // Éléments UPCOMING (échéance proche)
      "ok": [...]         // Éléments OK
    },
    "summary": {
      "total": 10,
      "due": 2,
      "upcoming": 3,
      "ok": 5
    }
  }
}
```

**Statuts:**
- **DUE**: `dueAtKm <= odometerCurrentKm` OU `dueAtDate <= today`
- **UPCOMING**: Dans la fenêtre configurable (défaut: 500km ou 30 jours avant échéance)
- **OK**: Aucune échéance proche

#### PATCH `/api/garage/vehicles/:id/maintenance/items/:itemId`
Mettre à jour un élément de maintenance.

#### DELETE `/api/garage/vehicles/:id/maintenance/items/:itemId`
Supprimer un élément de maintenance (soft delete: `active = false`).

#### POST `/api/garage/vehicles/:id/maintenance/logs`
Créer un log de maintenance. Si `maintenanceItem` est fourni, marque automatiquement l'élément comme fait et recalcule les échéances.

**Body:**
```json
{
  "maintenanceItem": "60f1b2c3d4e5f6a7b8c9d0e1",  // Optionnel
  "type": "vidange",
  "description": "Vidange effectuée",
  "date": "2024-01-20",
  "km": 5500,
  "cost": 50,
  "notes": "Tout s'est bien passé",
  "parts": [...]
}
```

#### GET `/api/garage/vehicles/:id/maintenance/logs`
Liste paginée des logs de maintenance pour un véhicule.

**Query params:**
- `page` (optionnel, défaut: 1)
- `limit` (optionnel, défaut: 20, max: 100)

## Règles métier

1. **Ownership**: Toutes les ressources (véhicules, odomètres, maintenances) appartiennent à un utilisateur. Seul le propriétaire peut les gérer.

2. **Kilométrage**: 
   - Quand une entrée odomètre est ajoutée avec `km > vehicle.odometerCurrentKm`, le véhicule est automatiquement mis à jour.
   - Le kilométrage ne peut pas diminuer.

3. **Maintenance**:
   - Quand un log de maintenance est créé avec un `maintenanceItem`, l'élément est automatiquement marqué comme fait (`lastDoneAtKm` et `lastDoneAtDate` mis à jour).
   - Les échéances (`dueAtKm` et `dueAtDate`) sont recalculées automatiquement.

4. **Dashboard**:
   - Les statuts sont calculés en temps réel basés sur le kilométrage actuel du véhicule et la date du jour.
   - Les fenêtres de rappel sont configurables via les variables d'environnement.

## Codes de réponse

- `200`: Succès
- `201`: Créé avec succès
- `400`: Erreur de validation
- `401`: Non authentifié
- `403`: Accès interdit (pas propriétaire)
- `404`: Ressource non trouvée
- `500`: Erreur serveur

## Swagger

La documentation Swagger est disponible à `/api-docs` (si configuré) et inclut tous les endpoints Garage avec leurs schémas de validation.







