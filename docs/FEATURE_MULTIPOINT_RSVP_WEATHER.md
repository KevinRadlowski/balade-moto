# Feature: Multi-point Waypoints, RSVP Intelligent, Météo & Annulation

**Date** : 2025-01-27  
**Auteur** : Lead Engineer  
**Statut** : Design Phase

---

## 📋 RÉSUMÉ

Implémentation de 4 features majeures pour RideTogether :
1. **Waypoints multi-points avancés** : Types (FUEL, COFFEE, DANGER, VIEWPOINT) + contraintes
2. **Annulation / Report** : Motifs + notifications + reprogrammation
3. **Météo intégrée** : Affichage départ/arrivée + alertes (Premium 24h avant)
4. **RSVP intelligent** : États (GOING, NOT_GOING, INTERESTED, LATE, WEATHER_OK) + synthèse organisateur

---

## 🗄️ SCHÉMAS DB

### 1. Ride Model - Extensions Waypoints

**État actuel** :
```javascript
waypoints: [{
  type: { type: String, enum: ['depart', 'checkpoint', 'arrivee'] },
  address: String,
  coordinates: { type: 'Point', coordinates: [lng, lat] },
  order: Number
}]
```

**Nouveau schéma (rétrocompatible)** :
```javascript
waypoints: [{
  _id: mongoose.Schema.Types.ObjectId, // Auto-généré
  type: {
    type: String,
    enum: ['depart', 'checkpoint', 'arrivee', 'fuel', 'coffee', 'danger', 'viewpoint'],
    required: true
  },
  address: String,
  coordinates: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number] // [lng, lat]
  },
  order: Number,
  // NOUVEAUX CHAMPS
  waypointType: {
    type: String,
    enum: ['normal', 'fuel', 'coffee', 'danger', 'viewpoint'],
    default: 'normal'
  },
  isMandatoryStop: {
    type: Boolean,
    default: false
  },
  note: {
    type: String,
    maxlength: 500,
    default: null
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}]
```

**Migration** :
- Les waypoints existants auront `waypointType: 'normal'` par défaut
- Script de migration : `tools/migrate-waypoints.js` (idempotent)

---

### 2. Ride Model - Extensions Annulation/Report

**État actuel** :
```javascript
status: {
  type: String,
  enum: ['scheduled', 'in_progress', 'completed', 'cancelled', 'postponed'],
  default: 'scheduled'
}
```

**Nouveau schéma (ajouts)** :
```javascript
// Annulation
cancellation: {
  cancelledAt: Date,
  cancelledBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  cancelReasonCode: {
    type: String,
    enum: ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'],
    default: null
  },
  cancelReasonText: {
    type: String,
    maxlength: 500,
    default: null
  }
},
// Report/Reprogrammation
postponement: {
  postponedAt: Date,
  postponedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  postponeReasonCode: {
    type: String,
    enum: ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'],
    default: null
  },
  postponeReasonText: {
    type: String,
    maxlength: 500,
    default: null
  },
  originalRideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null
  },
  reprogrammedToRideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null
  }
}
```

**Migration** :
- Les rides existantes auront `cancellation: null` et `postponement: null`
- Pas de migration nécessaire (champs optionnels)

---

### 3. Ride Model - Extensions RSVP

**État actuel** :
```javascript
participants: [{
  userId: ObjectId,
  vehicleId: ObjectId,
  arrivalTime: Date,
  isOnTime: Boolean,
  validatedBy: ObjectId,
  validatedAt: Date
}]
```

**Nouveau schéma (ajouts)** :
```javascript
participants: [{
  userId: ObjectId,
  vehicleId: ObjectId,
  arrivalTime: Date,
  isOnTime: Boolean,
  validatedBy: ObjectId,
  validatedAt: Date,
  // NOUVEAUX CHAMPS RSVP
  rsvpStatus: {
    type: String,
    enum: ['going', 'not_going', 'interested', 'late', 'weather_ok'],
    default: 'going' // Pour participants existants
  },
  rsvpUpdatedAt: {
    type: Date,
    default: Date.now
  },
  lateEtaMinutes: {
    type: Number,
    min: 5,
    max: 180,
    default: null
  },
  rsvpNote: {
    type: String,
    maxlength: 200,
    default: null
  }
}]
```

**Migration** :
- Participants existants : `rsvpStatus: 'going'` par défaut
- Invitations/pendingRequests : `rsvpStatus: 'interested'` par défaut (si pas encore accepté)
- Script : `tools/migrate-rsvp.js`

---

### 4. DangerReport Model (nouveau)

**Collection séparée pour crowdsourcing** :
```javascript
const dangerReportSchema = new mongoose.Schema({
  rideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: true,
    index: true
  },
  reportedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number] // [lng, lat]
  },
  description: {
    type: String,
    maxlength: 500,
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'promoted'],
    default: 'pending'
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  approvedAt: {
    type: Date,
    default: null
  },
  promotedToWaypointId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null
  }
}, { timestamps: true });

// Index pour éviter doublons (même user, même zone)
dangerReportSchema.index({ rideId: 1, reportedBy: 1, location: '2dsphere' }, { unique: false });
dangerReportSchema.index({ rideId: 1, status: 1 });
```

---

### 5. User Model - Extensions Météo

**Ajout préférences météo** :
```javascript
preferences: {
  // ... existants
  weatherAlertsEnabled: {
    type: Boolean,
    default: false
  }
}
```

**Migration** :
- Tous les users : `weatherAlertsEnabled: false` par défaut
- Seuls les premium peuvent activer (vérification côté service)

---

## 🔌 CONTRATS API

### Waypoints

#### POST /api/rides/:id/waypoints
**Ajouter/Modifier un waypoint**
```json
{
  "waypoint": {
    "type": "checkpoint",
    "waypointType": "fuel",
    "address": "Station Total",
    "coordinates": { "type": "Point", "coordinates": [2.3522, 48.8566] },
    "order": 1,
    "isMandatoryStop": true,
    "note": "Plein d'essence obligatoire"
  }
}
```

**Réponse** :
```json
{
  "success": true,
  "data": {
    "ride": { ... },
    "waypoint": { ... }
  }
}
```

#### DELETE /api/rides/:id/waypoints/:waypointId
**Supprimer un waypoint**

#### POST /api/rides/:id/waypoints/danger-report
**Signaler un danger (crowdsourcing)**
```json
{
  "location": { "type": "Point", "coordinates": [2.3522, 48.8566] },
  "description": "Gravillons sur la route"
}
```

**Réponse** :
```json
{
  "success": true,
  "data": {
    "report": { ... },
    "message": "Signalement en attente de validation"
  }
}
```

#### GET /api/rides/:id/waypoint-summary
**Synthèse des waypoints**
```json
{
  "success": true,
  "data": {
    "mandatoryStopsCount": 2,
    "dangerCount": 1,
    "fuelStopsCount": 1,
    "coffeeStopsCount": 2,
    "viewpointCount": 1
  }
}
```

---

### Annulation/Report

#### POST /api/rides/:id/cancel
**Annuler une balade**
```json
{
  "reasonCode": "WEATHER",
  "reasonText": "Pluie forte prévue"
}
```

**Réponse** :
```json
{
  "success": true,
  "message": "Balade annulée. Tous les participants ont été notifiés.",
  "data": {
    "ride": { ... }
  }
}
```

#### POST /api/rides/:id/postpone
**Reporter une balade**
```json
{
  "reasonCode": "MECHANICAL",
  "reasonText": "Problème mécanique",
  "newDateTime": "2025-02-15T10:00:00Z" // Optionnel
}
```

#### POST /api/rides/:id/reschedule
**Reprogrammer (dupliquer)**
```json
{
  "newDateTime": "2025-02-15T10:00:00Z",
  "keepVisibility": true,
  "keepParticipants": false
}
```

**Réponse** :
```json
{
  "success": true,
  "message": "Balade reprogrammée",
  "data": {
    "originalRide": { ... },
    "newRide": { ... }
  }
}
```

---

### Météo

#### GET /api/rides/:id/weather
**Récupérer météo départ/arrivée**
```json
{
  "success": true,
  "data": {
    "departure": {
      "temperature": 15,
      "windSpeed": 20,
      "windDirection": "NW",
      "precipitationProb": 30,
      "conditions": "partiellement nuageux",
      "alerts": []
    },
    "arrival": {
      "temperature": 18,
      "windSpeed": 15,
      "precipitationProb": 10,
      "conditions": "ensoleillé"
    },
    "alerts": [
      {
        "type": "RAIN",
        "severity": "moderate",
        "message": "Pluie modérée prévue"
      }
    ]
  }
}
```

#### PUT /api/users/me/preferences
**Activer/désactiver alertes météo (Premium)**
```json
{
  "weatherAlertsEnabled": true
}
```

---

### RSVP

#### PUT /api/rides/:id/rsvp
**Changer statut RSVP**
```json
{
  "status": "late",
  "lateEtaMinutes": 20,
  "note": "Je serai en retard de 20 minutes"
}
```

**Réponse** :
```json
{
  "success": true,
  "message": "Statut RSVP mis à jour",
  "data": {
    "ride": { ... },
    "rsvpStatus": "late"
  }
}
```

#### GET /api/rides/:id/rsvp-summary
**Synthèse RSVP (organisateur uniquement)**
```json
{
  "success": true,
  "data": {
    "counts": {
      "going": 5,
      "not_going": 2,
      "interested": 3,
      "late": 1,
      "weather_ok": 2
    },
    "lateList": [
      {
        "userId": "...",
        "user": { "firstName": "John", "pseudo": "john" },
        "etaMinutes": 20
      }
    ],
    "weatherOkList": [
      {
        "userId": "...",
        "user": { "firstName": "Jane", "pseudo": "jane" }
      }
    ],
    "pendingRequestsCount": 2,
    "maxParticipants": 10,
    "spotsLeft": 3
  }
}
```

---

## 🔄 STRATÉGIE DE MIGRATION

### Waypoints
1. **Script** : `tools/migrate-waypoints.js`
2. **Logique** :
   - Parcourir toutes les rides
   - Pour chaque waypoint existant :
     - Si `waypointType` absent → `'normal'`
     - Si `isMandatoryStop` absent → `false`
     - Si `createdBy` absent → `organisateur` de la ride
3. **Idempotent** : Peut être exécuté plusieurs fois
4. **Rollback** : Non nécessaire (champs optionnels)

### RSVP
1. **Script** : `tools/migrate-rsvp.js`
2. **Logique** :
   - Participants existants → `rsvpStatus: 'going'`
   - Invitations pending → `rsvpStatus: 'interested'`
   - `rsvpUpdatedAt: createdAt` ou `Date.now()`
3. **Idempotent** : Oui
4. **Rollback** : Non nécessaire

---

## 🎨 SCÉNARIOS UX

### 1. Créer une balade avec waypoints typés

**Flutter - Écran création** :
1. User ajoute un point sur la carte
2. Bottom sheet s'ouvre :
   - Sélection type : Normal / Pause carburant / Pause café / Danger / Point de vue
   - Toggle "Arrêt obligatoire"
   - Champ "Note (optionnel)"
   - Bouton "Ajouter"
3. Sur la carte : markers colorés selon type
4. Badge "!" si arrêt obligatoire

### 2. Détail balade - Waypoints

**Section "Points de passage"** :
- Liste avec icônes (⛽ 🍵 ⚠️ 🏔️)
- Badge "Obligatoire" si `isMandatoryStop`
- Note affichée si présente
- Filtre : "Voir uniquement dangers / arrêts obligatoires"

### 3. Annuler/Reporter

**Menu organisateur** :
- "Annuler" → Modal motif + texte → Confirme → Badge "Annulée"
- "Reporter" → Modal motif + date/heure optionnelle
- "Reprogrammer" → Date picker → Crée nouvelle ride → Navigue vers nouvelle

### 4. Météo

**Section météo** :
- Départ : Température, vent, pluie, icône
- Arrivée : Idem
- Alertes : Badges (Pluie forte / Vent fort)
- Bouton "Rafraîchir" (cooldown UI)

**Profil Premium** :
- Toggle "Alerte météo 24h avant"
- Si non premium : CTA "Passer Premium"

### 5. RSVP

**Actions** :
- "Je participe" → `going`
- "Je ne participe pas" → `not_going`
- "Je suis intéressé" → `interested`
- "Je viens en retard" → Picker minutes → `late`
- "Je viens si météo OK" → `weather_ok`

**Synthèse organisateur** :
- Chips avec compteurs
- Liste "En retard" avec ETA
- Liste "Si météo OK"

---

## ✅ TESTS ATTENDUS

### Backend
- [ ] Création ride avec ancien format waypoints → normalisation
- [ ] Création ride avec nouveau format → persistance
- [ ] Danger report → création, rate limit, duplication check
- [ ] Cancel ride → statut + meta + notifications
- [ ] Reschedule → nouvelle ride créée, old ride updated
- [ ] RSVP transitions → interested → going, late → going
- [ ] Weather endpoint → cache hit/miss
- [ ] Scheduler météo → sélection rides, premium filter

### Frontend (Flutter)
- [ ] Créer balade : ajouter points typés + mandatory
- [ ] Détail balade : afficher liste points + badges + map
- [ ] Cancel/reschedule : UI badges + redirections
- [ ] Météo : affichage + toggle premium
- [ ] RSVP : tous boutons + état persistant

---

## 📝 NOTES TECHNIQUES

### Rétrocompatibilité
- Tous les nouveaux champs sont **optionnels**
- Les endpoints acceptent ancien ET nouveau format
- Migration soft (runtime + script)

### Performance
- Cache météo : Redis ou mémoire (TTL 30 min)
- Index MongoDB : `rideId + status` pour danger reports
- Pagination : Waypoints list (si > 50)

### Sécurité
- Rate limit danger reports : 5 par heure par user
- Duplication check : même zone (rayon 100m) dans 1h
- Validation organisateur : Seul l'organisateur peut approuver danger reports

---

---

## 📦 ENUMS & CONVENTIONS

### RideWaypointType
```javascript
enum: ['normal', 'fuel', 'coffee', 'danger', 'viewpoint']
```

### RideWaypointConstraint
- `isMandatoryStop` : Boolean
- `note` : String (optionnel, max 500 chars)

### RSVP Status
```javascript
enum: ['going', 'not_going', 'interested', 'late', 'weather_ok']
```

### RideStatus (existant, confirmé)
```javascript
enum: ['scheduled', 'in_progress', 'completed', 'cancelled', 'postponed']
```

### CancelReasonCode
```javascript
enum: ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER']
```

---

**Dernière mise à jour** : 2025-01-27

