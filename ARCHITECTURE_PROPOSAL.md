# 📐 ARCHITECTURE PROPOSAL - Nouvelles Features RideTogether

## 📊 ANALYSE DE L'EXISTANT

### Structure Backend (Node.js/Express/MongoDB)

```
src/
├── models/          # Mongoose schemas (User, Ride, Vehicle, Group, Rating, Review, Message, etc.)
├── controllers/     # Logique métier (ride.controller.js, auth.controller.js, etc.)
├── routes/         # Définition des routes API
├── services/       # Services métier (email.service.js, socket.service.js, etc.)
├── middlewares/    # Auth, error handling, rate limiting, upload
├── validators/     # express-validator pour validation des inputs
├── utils/          # Utilitaires (errors.js, cache.js)
└── scripts/        # Scripts de migration
```

**Modèles existants:**
- `User`: email, pseudo, role (MEMBER/ADMIN), vehiclePreference, avatarUrl, customBackgrounds, 2FA
- `Ride`: titre, description, typeVehicule, date, heure, waypoints, organisateur, participants, likes, notes, noteMoyenne
- `Vehicle`: ownerUserId, type, make, model, year, odometerCurrentKm, photos[], externalCatalog, selectionSource
- `Group`: nom, description, visibilite, createur, membres[], bannedUsers[]
- `Rating`: note (1-5), commentaire, utilisateur, balade
- `Review`: ride, user, rating, comment
- `Message`: auteur, contenu, type, reactions[], pollData, replyToMessageId

**Patterns existants:**
- Controllers → Services → Models
- Validation via express-validator
- Error handling centralisé (utils/errors.js)
- Auth middleware (JWT)
- Rate limiting middleware
- Socket.io pour temps réel

### Structure Flutter

```
lib/
├── models/         # DTOs (User, Ride, Vehicle, Group, etc.)
├── services/       # API clients (ApiService, AuthService, GarageService, etc.)
├── repositories/   # Couche d'abstraction API (FeedbackRepository, LiveRideRepository, etc.)
├── providers/      # State management (ChangeNotifier) - FeedbackProvider, LiveRideProvider, etc.
├── screens/        # Écrans UI
├── widgets/        # Composants réutilisables
├── constants/      # AppTheme, styles
└── utils/          # Helpers (SnackBarHelper, DateHelper, etc.)
```

**State Management:**
- Provider (ChangeNotifier) pour state management
- Pattern: Repository → Provider → Screen
- ApiService centralisé avec token management

**UI/UX:**
- Material 3
- Google Fonts (Inter)
- Couleurs: Primary (#3F51B5), Secondary (#FF6F00)
- Cards avec shadows, rounded corners (16px)
- BottomNavigationBar pour navigation principale

---

## 🎯 FEATURES À IMPLÉMENTER

### A) Réputation/Confiance Participants
- Score de réputation basé sur feedbacks, ponctualité, annulations
- Badges/accomplissements (première balade, 10 balades, etc.)
- Affichage sur profil et cartes de balade

### B) Mode "Balade en cours" (Live Ride)
- Démarrer/finir une balade (organisateur)
- Écran live avec itinéraire, participants actifs, positions GPS
- Heartbeat pour détecter inactivité
- Actions rapides (pause, incident)
- Bouton urgence + flow fallback

### C) Personnalisation Avancée des Balades
- Style de conduite (calme, modéré, sportif, mixte) - **DÉJÀ IMPLÉMENTÉ**
- Warnings compatibilité (afficher sur carte, fiche détail, flow RSVP)
- Calcul de compatibilité basé sur: type véhicule, style conduite, réputation, historique commun

### D) Exploiter le Garage (Stats + Entretien)
- Statistiques véhicule: km totaux, coûts, nombre de balades, consommation
- Rappels d'entretien: intervalles (km/mois), notifications, snooze
- Prédictions d'entretien basées sur l'usage

### E) Engagement (Badges/Accomplissements)
- Système de badges: première balade, 10 balades, organisateur régulier, etc.
- Page dédiée badges dans profil
- Progression visible

### F) Sécurité & Sérénité
- Contact d'urgence (nom, téléphone, relation)
- Check-in heartbeat (détection inactivité)
- Alertes automatiques si inactivité prolongée
- Jobs backend pour monitoring

---

## 🏗️ ARCHITECTURE PROPOSÉE

### Backend - Nouveaux Modèles Mongoose

#### 1. `Reputation.js`
```javascript
{
  userId: ObjectId (ref: User, unique, index),
  score: Number (0-100, default: 50),
  rideCount: Number (default: 0),
  punctualityScore: Number (0-100, default: 50),
  cancellationRate: Number (0-100, default: 0),
  feedbackCount: Number (default: 0),
  level: String (enum: ['bronze', 'silver', 'gold', 'platinum'], default: 'bronze'),
  updatedAt: Date
}
```

#### 2. `Achievement.js`
```javascript
{
  userId: ObjectId (ref: User, index),
  type: String (enum: ['first_ride', 'ten_rides', 'organizer', 'punctual', etc.]),
  name: String,
  description: String,
  earnedAt: Date,
  progress: Number (0-100),
  target: Number
}
```

#### 3. `Feedback.js` (si pas déjà existant)
```javascript
{
  userId: ObjectId (ref: User, index),
  entityType: String (enum: ['ride', 'user']),
  entityId: ObjectId,
  type: String (enum: ['rating', 'review', 'suggestion', 'bug_report']),
  rating: Number (1-5, optional),
  comment: String (optional),
  status: String (enum: ['pending', 'approved', 'rejected'], default: 'pending'),
  createdAt: Date
}
```

#### 4. `VehicleStats.js`
```javascript
{
  vehicleId: ObjectId (ref: Vehicle, unique, index),
  totalKm: Number (default: 0),
  totalCost: Number (default: 0),
  rideCount: Number (default: 0),
  maintenanceCount: Number (default: 0),
  fuelConsumption: {
    averageLitersPer100km: Number,
    lastUpdated: Date
  },
  monthlyStats: [{
    month: String (YYYY-MM),
    km: Number,
    cost: Number,
    rides: Number
  }]
}
```

#### 5. `MaintenanceReminder.js`
```javascript
{
  userId: ObjectId (ref: User, index),
  vehicleId: ObjectId (ref: Vehicle, index),
  type: String (enum: ['oil', 'tire', 'brake', 'inspection', 'other']),
  description: String,
  intervalKm: Number,
  intervalMonths: Number,
  lastDoneKm: Number,
  lastDoneDate: Date,
  nextDueKm: Number,
  nextDueDate: Date,
  status: String (enum: ['active', 'snoozed', 'completed'], default: 'active'),
  snoozedUntil: Date (optional)
}
```

#### 6. Modifications aux modèles existants

**`Ride.js` - Ajouter:**
```javascript
{
  status: String (enum: ['scheduled', 'in_progress', 'completed', 'cancelled', 'postponed'], default: 'scheduled'),
  rideEvents: [{
    type: String (enum: ['started', 'paused', 'resumed', 'incident', 'completed', 'cancelled']),
    timestamp: Date,
    userId: ObjectId (ref: User),
    details: {
      location: { type: 'Point', coordinates: [Number] },
      description: String (optional)
    }
  }],
  ridingStyle: String (enum: ['calme', 'modere', 'sportif', 'mixte'], optional)
}
```

**`User.js` - Ajouter:**
```javascript
{
  emergencyContact: {
    name: String,
    phone: String,
    relation: String (enum: ['family', 'friend', 'colleague', 'other']),
    notes: String (optional)
  },
  checkInStatus: {
    lastHeartbeat: Date,
    isActive: Boolean (default: false),
    lastLocation: { type: 'Point', coordinates: [Number] } (optional)
  }
}
```

### Backend - Nouveaux Services

#### 1. `reputation.service.js`
- `calculateReputationScore(userId)`: Calcule le score basé sur feedbacks, ponctualité, annulations
- `updateReputationOnFeedback(userId, feedback)`: Met à jour après feedback
- `getReputationLevel(score)`: Retourne le niveau (bronze/silver/gold/platinum)

#### 2. `achievement.service.js`
- `checkAndAwardAchievements(userId, event)`: Vérifie et débloque badges
- `getUserAchievements(userId)`: Liste des badges de l'utilisateur
- `getAchievementProgress(userId, achievementType)`: Progression vers un badge

#### 3. `compatibility.service.js`
- `checkCompatibility(userId1, userId2, rideId)`: Calcule compatibilité entre 2 users pour une balade
- Retourne: `{ score: 0-100, factors: { sameVehicleType, sameRidingStyle, reputationMatch, hasRiddenTogether, commonGroups } }`

#### 4. `vehicleStats.service.js`
- `updateStatsOnRideCompletion(vehicleId, rideData)`: Met à jour stats après balade
- `getVehicleStats(vehicleId)`: Récupère stats complètes
- `predictMaintenance(vehicleId)`: Prédit prochain entretien

#### 5. `maintenanceReminder.service.js`
- `createReminder(userId, vehicleId, data)`: Crée un rappel
- `checkDueReminders()`: Vérifie rappels échus (job cron)
- `snoozeReminder(reminderId, days)`: Reporte un rappel

#### 6. `liveRide.service.js`
- `startLiveRide(rideId, userId)`: Démarre une balade live
- `sendHeartbeat(rideId, userId, location)`: Envoie heartbeat
- `reportIncident(rideId, userId, details)`: Signale un incident
- `endLiveRide(rideId, userId)`: Termine une balade

#### 7. `checkIn.service.js`
- `sendHeartbeat(userId, location)`: Envoie heartbeat utilisateur
- `checkInactivity()`: Job cron pour détecter inactivité (>30min sans heartbeat)
- `triggerInactivityAlert(userId)`: Déclenche alerte

#### 8. `emergencyContact.service.js`
- `triggerEmergencyAlert(userId, reason)`: Envoie SMS/email au contact d'urgence
- `getEmergencyContact(userId)`: Récupère contact

### Backend - Nouveaux Controllers

- `feedback.controller.js`: CRUD feedbacks
- `reputation.controller.js`: GET reputation, GET achievements
- `compatibility.controller.js`: GET compatibility check
- `vehicleStats.controller.js`: GET stats, POST update
- `maintenanceReminder.controller.js`: CRUD reminders
- `liveRide.controller.js`: POST start/pause/end/incident, GET status, POST heartbeat
- `checkIn.controller.js`: POST heartbeat, GET status
- `emergencyContact.controller.js`: CRUD contact, POST trigger alert

### Backend - Nouveaux Routes

```
/api/feedback
  POST /                    # Créer feedback
  GET /:id                  # Récupérer feedback
  PATCH /:id                # Mettre à jour
  DELETE /:id               # Supprimer

/api/reputation
  GET /:userId              # Récupérer réputation
  GET /:userId/achievements # Liste badges

/api/compatibility
  GET /check                # ?userId1=...&userId2=...&rideId=...

/api/garage
  GET /vehicle-stats/:vehicleId
  POST /vehicle-stats/:vehicleId/update
  GET /maintenance-reminders
  POST /maintenance-reminders
  PATCH /maintenance-reminders/:id
  DELETE /maintenance-reminders/:id
  POST /maintenance-reminders/:id/snooze

/api/live-rides
  POST /:rideId/start
  POST /:rideId/pause
  POST /:rideId/end
  POST /:rideId/incident
  GET /:rideId/status
  POST /:rideId/heartbeat

/api/check-in
  POST /heartbeat
  GET /status

/api/user
  GET /emergency-contact
  POST /emergency-contact
  PATCH /emergency-contact
  DELETE /emergency-contact
  POST /emergency-contact/trigger-alert
```

### Backend - Jobs Cron (node-cron)

- `checkMaintenanceReminders`: Tous les jours à 9h, vérifie rappels échus
- `checkInactivity`: Toutes les 5 minutes, vérifie inactivité utilisateurs
- `updateReputationScores`: Tous les jours à 2h, recalcule scores réputation

### Flutter - Nouveaux Modèles

- `reputation.dart`: Reputation, ReputationLevel
- `achievement.dart`: Achievement, AchievementType
- `feedback.dart`: Feedback, FeedbackType, FeedbackResponse
- `compatibility.dart`: Compatibility, CompatibilityFactors, CompatibilitySuggestion
- `vehicle_stats.dart`: VehicleStats, MaintenancePrediction, FuelConsumption, MonthlyStat
- `maintenance_reminder.dart`: MaintenanceReminder, ReminderNotification
- `live_ride.dart`: LiveRideState, RideEvent, ParticipantPosition
- `emergency_contact.dart`: EmergencyContact
- `check_in_status.dart`: CheckInStatus, CheckInLocation

### Flutter - Nouveaux Repositories

- `FeedbackRepository`: createFeedback, getFeedback, updateFeedback, deleteFeedback
- `ReputationRepository`: getReputation, getAchievements
- `CompatibilityRepository`: checkCompatibility
- `VehicleStatsRepository`: getVehicleStats, updateVehicleStats
- `MaintenanceReminderRepository`: CRUD reminders, snooze
- `LiveRideRepository`: startRide, pauseRide, endRide, reportIncident, getStatus, sendHeartbeat
- `CheckInRepository`: sendHeartbeat, getStatus
- `EmergencyContactRepository`: CRUD contact, triggerAlert

### Flutter - Nouveaux Providers

- `FeedbackProvider`: Gère état feedbacks
- `ReputationProvider`: Gère réputation et badges
- `CompatibilityProvider`: Gère compatibilité
- `VehicleStatsProvider`: Gère stats véhicule
- `MaintenanceReminderProvider`: Gère rappels entretien
- `LiveRideProvider`: Gère état balade live
- `CheckInProvider`: Gère check-in heartbeat
- `EmergencyContactProvider`: Gère contact urgence

### Flutter - Nouveaux Écrans

#### Profil
- `screens/profile/reputation_section.dart`: Bloc "Confiance" (score + badges)
- `screens/profile/badges_screen.dart`: Page complète badges
- `screens/profile/emergency_contact_screen.dart`: Gestion contact urgence

#### Garage
- `screens/garage/vehicle_stats_screen.dart`: Section stats véhicule
- `screens/garage/maintenance_reminders_screen.dart`: Liste rappels + snooze

#### Balades
- `screens/ride/live_ride_screen.dart`: Écran live avec map, participants, actions
- Intégration warnings compatibilité dans:
  - `screens/home/home_screen.dart` (cartes balade)
  - `screens/ride/ride_detail_screen.dart` (fiche détail)
  - Flow RSVP (dans `ride_detail_screen.dart`)

### Flutter - Nouveaux Widgets

- `widgets/profile/reputation_card.dart`: Carte score réputation
- `widgets/profile/badge_item.dart`: Item badge dans liste
- `widgets/rides/compatibility_warning.dart`: Warning compatibilité (déjà créé)
- `widgets/rides/riding_style_chips.dart`: Chips style conduite (déjà créé)
- `widgets/garage/stats_card.dart`: Carte stats véhicule
- `widgets/garage/maintenance_reminder_item.dart`: Item rappel entretien
- `widgets/rides/live_ride_map.dart`: Map live avec positions
- `widgets/rides/participant_position_marker.dart`: Marqueur position participant
- `widgets/safety/emergency_button.dart`: Bouton urgence
- `widgets/safety/soft_alert_banner.dart`: Bannière alerte douce (déjà créé)

---

## 📋 CHECKLIST ACCEPTANCE CRITERIA

### Backend

#### Modèles & Migrations
- [ ] Tous les nouveaux modèles Mongoose créés avec validations
- [ ] Index ajoutés sur champs fréquemment recherchés
- [ ] Scripts de migration pour données existantes (backfill)
- [ ] Champs optionnels pour compatibilité ascendante
- [ ] Tests unitaires modèles (Jest)

#### Services
- [ ] Tous les services créés avec logique métier
- [ ] Calcul réputation implémenté
- [ ] Système badges fonctionnel
- [ ] Calcul compatibilité implémenté
- [ ] Jobs cron configurés (maintenance, inactivity, reputation)
- [ ] Tests unitaires services (Jest)

#### Controllers & Routes
- [ ] Tous les controllers créés
- [ ] Routes sécurisées (auth middleware)
- [ ] Rate limiting sur endpoints critiques (alert, incident)
- [ ] Validation inputs (express-validator)
- [ ] Gestion erreurs centralisée
- [ ] Tests d'intégration controllers (Jest)

### Flutter

#### Data Layer
- [ ] Tous les modèles/DTOs créés
- [ ] Tous les repositories créés avec caching léger
- [ ] Tous les providers créés (ChangeNotifier)
- [ ] Intégration dans main.dart (MultiProvider)
- [ ] Tests unitaires repositories

#### UI Layer
- [ ] Écran badges complet
- [ ] Section réputation dans profil
- [ ] Section contact urgence dans profil
- [ ] Section stats dans garage
- [ ] Section entretien dans garage
- [ ] Écran live ride avec map
- [ ] Warnings compatibilité intégrés (carte, fiche, RSVP)
- [ ] Chips style conduite intégrés (déjà fait)
- [ ] Tests widget (2-3 écrans clés)

#### UX
- [ ] Microcopie cohérente
- [ ] Loading states partout
- [ ] Error handling avec SnackBarHelper
- [ ] Pull-to-refresh où pertinent
- [ ] Animations fluides
- [ ] Offline stability (gestion erreurs réseau)

### Intégration & Qualité

- [ ] Feature flags pour activation progressive
- [ ] Aucune breaking change
- [ ] Documentation API (Swagger)
- [ ] Documentation Flutter (README sections)
- [ ] Tests end-to-end manuels (scénarios)
- [ ] Performance: pas de régression
- [ ] Sécurité: validation inputs, rate limiting, auth

---

## 🚀 PLAN D'IMPLÉMENTATION PAR ÉTAPES

### Étape 1: Backend Data Layer (2-3h)
1. Créer modèles Mongoose (Reputation, Achievement, Feedback, VehicleStats, MaintenanceReminder)
2. Modifier modèles existants (Ride.status + rideEvents, User.emergencyContact)
3. Créer indexes
4. Créer scripts migration/backfill
5. Tests unitaires modèles

### Étape 2: Backend Services (3-4h)
1. Créer services (reputation, achievement, compatibility, vehicleStats, maintenanceReminder, liveRide, checkIn, emergencyContact)
2. Implémenter logique métier
3. Configurer jobs cron
4. Tests unitaires services

### Étape 3: Backend Controllers & Routes (2-3h)
1. Créer controllers
2. Créer routes avec validation
3. Ajouter rate limiting
4. Intégrer dans app.js
5. Tests d'intégration

### Étape 4: Flutter Data Layer (2-3h)
1. Créer modèles/DTOs
2. Créer repositories avec caching
3. Créer providers (ChangeNotifier)
4. Intégrer dans main.dart
5. Tests unitaires repositories

### Étape 5: Flutter UI - Profil (2-3h)
1. Section réputation (bloc confiance)
2. Page badges complète
3. Section contact urgence
4. Tests widget

### Étape 6: Flutter UI - Garage (2-3h)
1. Section stats véhicule
2. Section entretien (rappels + snooze)
3. Tests widget

### Étape 7: Flutter UI - Compatibilité (1-2h)
1. Intégrer warnings dans carte balade (home)
2. Intégrer warnings dans fiche détail
3. Intégrer warnings dans flow RSVP
4. Tests widget

### Étape 8: Flutter UI - Live Ride (3-4h)
1. Écran live ride avec map
2. Affichage participants actifs
3. Actions rapides (pause, incident)
4. Bouton urgence
5. Heartbeat intégration
6. Tests widget

### Étape 9: Polish & Tests (2-3h)
1. Microcopie
2. Loading/error states
3. Animations
4. Tests end-to-end manuels
5. Documentation

### Étape 10: Feature Flags & Déploiement (1h)
1. Ajouter feature flags backend
2. Ajouter feature flags Flutter
3. Documentation déploiement
4. Checklist pré-production

---

## 📝 NOTES IMPORTANTES

### Compatibilité Ascendante
- Tous les nouveaux champs sont **optionnels**
- Scripts de migration pour backfill données existantes
- Pas de breaking changes sur endpoints existants

### Performance
- Index MongoDB sur champs fréquemment recherchés
- Caching léger côté Flutter (repositories)
- Pagination pour listes longues
- Jobs cron optimisés (éviter surcharge)

### Sécurité
- Rate limiting sur endpoints critiques (alert, incident)
- Validation inputs stricte
- Auth middleware sur toutes les routes
- Pas d'exposition données sensibles (password, tokens)

### UX
- Feature flags pour activation progressive
- Offline stability (gestion erreurs réseau)
- Loading states partout
- Messages d'erreur clairs
- Microcopie cohérente

---

## 🎯 PRIORISATION

**Phase 1 (MVP):**
- Réputation basique (score + badges simples)
- Live ride (démarrer/finir + map basique)
- Compatibilité warnings (affichage basique)
- Stats véhicule (affichage basique)

**Phase 2 (Complément):**
- Rappels entretien
- Contact urgence + alertes
- Check-in heartbeat
- Badges avancés

**Phase 3 (Polish):**
- Prédictions entretien
- Animations
- Optimisations performance
- Tests complets

---

## 📚 RÉFÉRENCES

- Architecture existante: `src/`, `flutter_app/lib/`
- Patterns: Controllers → Services → Models (backend), Repository → Provider → Screen (Flutter)
- Design: Material 3, Google Fonts Inter, couleurs définies dans `AppTheme`






