# Live Ride & Safety - Documentation

## Vue d'ensemble

Le mode "Balade en cours" (Live Ride) permet de suivre une balade en temps réel avec :
- Suivi GPS des participants
- Heartbeat automatique pour détecter l'inactivité
- Actions rapides (pause, incident, fin)
- Système d'alerte d'urgence
- Notifications douces pour les alertes système

## Architecture

### Backend

#### Endpoints API

- `POST /api/live-rides/:id/start` - Démarrer une balade en direct
- `POST /api/live-rides/:id/pause` - Mettre en pause
- `POST /api/live-rides/:id/end` - Terminer la balade
- `POST /api/live-rides/:id/incident` - Signaler un incident
- `GET /api/live-rides/:id/status` - Obtenir l'état actuel
- `POST /api/live-rides/:id/heartbeat` - Envoyer un heartbeat
- `POST /api/user/emergency-contact/alert` - Déclencher une alerte d'urgence
- `POST /api/check-in/heartbeat` - Heartbeat de check-in général

#### Jobs Backend

1. **Détection d'inactivité** (`src/services/notification.service.js`)
   - Vérifie les heartbeats toutes les 2 minutes
   - Envoie une alerte si aucun heartbeat depuis 3 minutes
   - Notifie le contact d'urgence si inactivité > 5 minutes

2. **Vérification des alertes d'urgence**
   - Traite les alertes déclenchées
   - Envoie des notifications push/email
   - Met à jour le statut de la balade

### Frontend (Flutter)

#### Providers

- `LiveRideProvider` - Gestion de l'état de la balade en cours
- `EmergencyContactProvider` - Gestion du contact d'urgence
- `CheckInProvider` - Gestion du check-in et heartbeat

#### Écrans

- `LiveRideScreen` - Écran principal de la balade en cours
  - Carte avec itinéraire et participants
  - Actions rapides (pause, incident, fin)
  - Bouton urgence
  - Indicateur de heartbeat actif

#### Composants

- `SoftAlertBanner` - Bannière d'alerte douce (non bloquante)

## Fonctionnalités

### 1. Démarrer une balade

**Organisateur uniquement**

1. Dans l'écran de détail de la balade, l'organisateur voit le bouton "Démarrer la balade"
2. Au clic, la balade passe en statut `in_progress`
3. L'écran Live Ride s'ouvre automatiquement
4. Le heartbeat commence automatiquement

### 2. Heartbeat automatique

- **Fréquence** : Toutes les 30 secondes
- **Données envoyées** : Position GPS (si disponible)
- **Détection d'inactivité** : Si aucun heartbeat depuis 3 minutes, alerte envoyée

### 3. Actions rapides

#### Pause (Organisateur)
- Met la balade en pause
- Les participants restent connectés
- Le heartbeat continue

#### Incident
- Types disponibles :
  - Panne mécanique
  - Accident
  - Perdu
  - Autre
- Enregistre la position et l'heure
- Notifie les autres participants

#### Terminer
- Met fin à la balade
- Change le statut à `completed`
- Arrête le heartbeat
- Retourne à l'écran de détail

### 4. Alerte d'urgence

#### Déclenchement
1. L'utilisateur appuie sur le bouton "URGENCE"
2. Vérification du contact d'urgence configuré
3. Confirmation requise (double validation)
4. Envoi de l'alerte :
   - Au contact d'urgence (email + SMS si configuré)
   - Aux autres participants
   - Enregistrement comme incident

#### Fallback
Si le contact d'urgence n'est pas configuré :
- Affichage d'un message
- Proposition de redirection vers le profil
- L'alerte ne peut pas être déclenchée

### 5. Alertes système (Soft Alerts)

Les alertes système sont affichées via `SoftAlertBanner` :
- **Info** : Informations générales (bleu)
- **Warning** : Avertissements (orange)
- **Error** : Erreurs (rouge)
- **Success** : Confirmations (vert)

Exemples :
- "Heartbeat perdu - Reconnexion en cours..."
- "Alerte d'urgence reçue d'un participant"
- "Balade mise en pause par l'organisateur"

## Scénario de test manuel bout en bout

### Prérequis

1. Deux comptes utilisateur (A = organisateur, B = participant)
2. Contact d'urgence configuré pour A
3. Une balade créée par A avec B comme participant
4. Date de la balade = aujourd'hui

### Test 1 : Démarrer une balade

1. **Compte A (Organisateur)**
   - Ouvrir l'écran de détail de la balade
   - Vérifier que le bouton "Démarrer la balade" est visible
   - Cliquer sur "Démarrer la balade"
   - ✅ L'écran Live Ride s'ouvre
   - ✅ L'indicateur "Actif" apparaît en haut à droite
   - ✅ La carte affiche l'itinéraire
   - ✅ Les actions rapides sont visibles en bas

2. **Compte B (Participant)**
   - Ouvrir l'écran de détail de la balade
   - ✅ Le bouton "Rejoindre la balade en cours" est visible
   - Cliquer sur "Rejoindre la balade en cours"
   - ✅ L'écran Live Ride s'ouvre
   - ✅ L'indicateur "Actif" apparaît

### Test 2 : Heartbeat et suivi GPS

1. **Compte A**
   - Dans l'écran Live Ride, attendre 30 secondes
   - ✅ Vérifier dans les logs backend que les heartbeats sont reçus
   - Se déplacer (simuler avec un émulateur ou un vrai déplacement)
   - ✅ La position est mise à jour toutes les 30 secondes

2. **Compte B**
   - Dans l'écran Live Ride, vérifier la carte
   - ✅ Les positions des participants actifs sont visibles (marqueurs orange)

### Test 3 : Actions rapides

1. **Pause**
   - Compte A : Cliquer sur "Pause"
   - ✅ Le statut passe à "En pause"
   - ✅ Le heartbeat continue
   - ✅ Compte B voit une notification "Balade mise en pause"

2. **Incident**
   - Compte A : Cliquer sur "Incident"
   - Sélectionner "Panne mécanique"
   - ✅ L'incident est enregistré
   - ✅ Compte B voit une notification "Incident signalé"

3. **Terminer**
   - Compte A : Cliquer sur "Terminer"
   - Confirmer
   - ✅ La balade se termine
   - ✅ Retour à l'écran de détail
   - ✅ Le statut est "completed"

### Test 4 : Alerte d'urgence

1. **Préparation**
   - Compte A : Vérifier que le contact d'urgence est configuré dans le profil

2. **Déclenchement**
   - Compte A : Dans l'écran Live Ride, cliquer sur "URGENCE"
   - ✅ Un dialogue de confirmation apparaît
   - Confirmer
   - ✅ L'alerte est envoyée
   - ✅ Un message de succès s'affiche

3. **Vérification**
   - ✅ Vérifier dans les logs backend que l'alerte a été traitée
   - ✅ Vérifier que le contact d'urgence a reçu un email (si configuré)
   - ✅ Compte B voit une notification "Alerte d'urgence déclenchée"

### Test 5 : Détection d'inactivité

1. **Simulation d'inactivité**
   - Compte A : Démarrer une balade
   - Arrêter l'app (kill process) ou désactiver le réseau
   - Attendre 3 minutes

2. **Vérification**
   - ✅ Vérifier dans les logs backend que l'inactivité est détectée
   - ✅ Une alerte est envoyée au contact d'urgence
   - ✅ Les autres participants sont notifiés

### Test 6 : Fallback contact d'urgence

1. **Compte A**
   - Retirer le contact d'urgence du profil
   - Démarrer une balade
   - Cliquer sur "URGENCE"

2. **Vérification**
   - ✅ Un message indique que le contact d'urgence n'est pas configuré
   - ✅ Proposition de redirection vers le profil
   - ✅ L'alerte ne peut pas être déclenchée

### Test 7 : Reconnexion après perte de connexion

1. **Compte A**
   - Démarrer une balade
   - Désactiver le réseau WiFi/mobile
   - Attendre 1 minute
   - Réactiver le réseau

2. **Vérification**
   - ✅ Le heartbeat reprend automatiquement
   - ✅ Une alerte douce peut apparaître "Reconnexion réussie"
   - ✅ La position est mise à jour

## Points d'attention

### Performance

- Le heartbeat toutes les 30 secondes peut consommer de la batterie
- Considérer une fréquence adaptative selon l'état de la balade
- Mettre en pause le heartbeat si l'app est en arrière-plan

### Sécurité

- Les positions GPS sont sensibles : ne pas les logger en clair
- Vérifier les permissions de localisation avant d'envoyer des heartbeats
- Limiter le nombre de participants actifs pour éviter la surcharge

### UX

- Toujours afficher un indicateur visuel du statut (actif/en pause)
- Fournir un feedback immédiat pour toutes les actions
- Gérer gracieusement les erreurs réseau

## Troubleshooting

### Le heartbeat ne fonctionne pas

1. Vérifier les permissions de localisation
2. Vérifier la connexion réseau
3. Vérifier les logs backend pour les erreurs API

### L'alerte d'urgence n'est pas envoyée

1. Vérifier que le contact d'urgence est configuré
2. Vérifier les logs backend
3. Vérifier la configuration email/SMS

### Les participants ne voient pas les positions

1. Vérifier que les heartbeats sont bien envoyés
2. Vérifier que le statut de la balade est `in_progress`
3. Vérifier les permissions de lecture de la balade

## Améliorations futures

- [ ] Mode économie d'énergie (heartbeat moins fréquent)
- [ ] Historique des positions
- [ ] Partage de position avec contacts externes
- [ ] Intégration avec services d'urgence (112)
- [ ] Mode offline avec synchronisation différée







