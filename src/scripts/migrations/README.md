# Scripts de Migration

Ce dossier contient les scripts de migration pour mettre à jour la base de données lors de l'ajout de nouvelles fonctionnalités.

## Utilisation

### Exécuter une migration

```bash
node src/scripts/migrations/002_add_ride_status_and_events.js
```

### Exécuter toutes les migrations

```bash
# Dans l'ordre:
node src/scripts/migrations/002_add_ride_status_and_events.js
node src/scripts/migrations/003_add_user_emergency_contact.js
node src/scripts/migrations/004_backfill_reputation.js
node src/scripts/migrations/005_backfill_vehicle_stats.js
node src/scripts/migrations/006_backfill_maintenance_reminders.js
```

## Migrations disponibles

### 002_add_ride_status_and_events.js
- Ajoute le champ `status` aux balades existantes (défaut: 'scheduled')
- Initialise `rideEvents` comme tableau vide
- Ajoute `ridingStyle` (null par défaut)
- Marque les balades passées comme 'completed'

### 003_add_user_emergency_contact.js
- Initialise `emergencyContact` et `checkInStatus` pour les utilisateurs existants
- Met `checkInStatus.isActive` à false par défaut

### 004_backfill_reputation.js
- Crée un document `Reputation` pour chaque utilisateur existant
- Calcule un score initial basé sur les balades passées et notes reçues
- Initialise les compteurs (rideCount, feedbackCount, etc.)

### 005_backfill_vehicle_stats.js
- Crée un document `VehicleStats` pour chaque véhicule actif
- Calcule les stats initiales (totalKm, totalCost, rideCount, maintenanceCount)

### 006_backfill_maintenance_reminders.js
- Crée des `MaintenanceReminder` basés sur les `MaintenanceItem` existants
- Calcule les dates d'échéance basées sur les intervalles

## Notes importantes

- ⚠️ **Toujours faire un backup de la base de données avant d'exécuter les migrations**
- Les migrations sont idempotentes (peuvent être exécutées plusieurs fois sans problème)
- Les migrations vérifient l'existence des données avant de créer de nouveaux documents






