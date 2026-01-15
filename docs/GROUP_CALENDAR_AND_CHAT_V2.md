# Group Calendar & Chat V2 - Design Document

**Date** : 2025-01-27  
**Version** : 1.0  
**Auteur** : Lead Engineer

---

## 📋 TABLE DES MATIÈRES

1. [Audit du code existant](#audit)
2. [Schémas de base de données](#schemas)
3. [Contrats API](#api-contracts)
4. [Events Socket.io](#socket-events)
5. [Matrice de permissions](#permissions)
6. [Flux UX](#ux-flows)
7. [Plan de migration](#migration)

---

## 🔍 AUDIT DU CODE EXISTANT {#audit}

### Modèles existants

#### Group Model (`src/models/Group.js`)
- ✅ **Membres avec rôles** : `membres[]` avec `role: 'admin' | 'moderateur' | 'membre'`
- ✅ **Créateur** : `createur` (ObjectId ref User)
- ✅ **Bannis** : `bannedUsers[]` avec `bannedBy`, `reason`, `bannedAt`
- ✅ **Méthodes** : `isMember()`, `isAdmin()`, `isModerator()`, `getUserRole()`, `getUserPermissions()`
- ❌ **Manque** : Pas de champ `groupId` dans Ride (à ajouter)

#### Message Model (`src/models/Message.js`)
- ✅ **Reply** : `replyToMessageId` (ObjectId ref Message)
- ✅ **Pinned** : `pinned` (boolean), `pinnedAt` (Date), `pinnedBy` (ObjectId ref User)
- ✅ **Mentions** : `mentions[]` (array ObjectId ref User) - **DÉJÀ PRÉSENT**
- ✅ **Poll** : `pollData` avec question, options, votes
- ✅ **Média** : `metadata` avec url, mimeType, size, fileName
- ❌ **Manque** : `parentMessageId` pour threads (utiliser `replyToMessageId` ou ajouter ?)
- ❌ **Manque** : `threadRootId`, `threadReplyCount` (denormalized)

#### Ride Model (`src/models/Ride.js`)
- ❌ **Manque** : `groupId` (ObjectId ref Group) - **À AJOUTER**
- ✅ **Date/Heure** : `date` (Date), `heure` (String)
- ✅ **Lieux** : `lieuDepart`, `lieuArrivee`
- ✅ **Status** : `status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'postponed'`

#### Notification Model (`src/models/Notification.js`)
- ✅ **Structure** : `user`, `type`, `title`, `message`, `metadata`, `read`, `readAt`
- ❌ **Manque** : Types pour mentions (`message_mention`), reports (`message_reported`)

### Socket.io Events existants

**Events côté serveur (écoutés)** :
- `join-ride-room` / `leave-ride-room`
- `join-group-room` / `leave-group-room`
- `send-group-message` / `send-ride-message`
- `edit-message`
- `delete-message`
- `toggle-reaction`
- `vote-poll`

**Events côté client (émis)** :
- `new-message` (avec `message` object)
- `previous-messages` (avec `messages[]`)
- `message-sent` (confirmation)
- `error` (erreurs)

### Flutter UI existante

- ✅ `group_chat_screen_v2.dart` : Chat groupe avec Socket.io
- ✅ `group_detail_screen.dart` : Détail groupe
- ✅ `chat_input.dart` : Input avec support reply
- ✅ `message_extended.dart` : Modèle message complet

---

## 🗄️ SCHÉMAS DE BASE DE DONNÉES {#schemas}

### 1. Extensions Message (rétrocompatibles)

```javascript
// Message Schema - Ajouts (tous optionnels pour rétrocompatibilité)
{
  // Threads (utiliser replyToMessageId existant OU ajouter parentMessageId)
  parentMessageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  threadRootId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  threadReplyCount: {
    type: Number,
    default: 0,
    min: 0
  },
  
  // Mentions (DÉJÀ PRÉSENT - juste documenter le format)
  mentions: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    username: {
      type: String, // Denormalized pour performance
      required: true
    }
  }],
  
  // Pinned (DÉJÀ PRÉSENT)
  pinned: Boolean,
  pinnedAt: Date,
  pinnedBy: ObjectId ref User
}
```

**Index à ajouter** :
```javascript
messageSchema.index({ idGroupe: 1, parentMessageId: 1, date: -1 }); // Threads
messageSchema.index({ idGroupe: 1, pinned: -1, pinnedAt: -1 }); // Pins
messageSchema.index({ idGroupe: 1, 'mentions.userId': 1 }); // Mentions
messageSchema.index({ idGroupe: 1, date: -1, type: 1 }); // Search
messageSchema.index({ idGroupe: 1, 'metadata.url': 1, date: -1 }); // Search media
messageSchema.index({ idGroupe: 1, 'pollData.question': 1, date: -1 }); // Search polls
// Index texte (MongoDB Text Search)
messageSchema.index({ contenu: 'text' }); // Text search
```

### 2. Nouveau modèle : GroupMute

```javascript
const groupMuteSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  mutedUntil: {
    type: Date,
    required: true,
    index: true
  },
  reason: {
    type: String,
    trim: true,
    maxlength: [500, 'La raison ne peut pas dépasser 500 caractères']
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index compound pour vérification rapide
groupMuteSchema.index({ groupId: 1, userId: 1, mutedUntil: 1 });
```

### 3. Nouveau modèle : MessageReport

```javascript
const messageReportSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  messageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    required: true,
    index: true
  },
  reporterId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  reasonCode: {
    type: String,
    enum: ['SPAM', 'HARASSMENT', 'HATE', 'NUDITY', 'OTHER'],
    required: true
  },
  reasonText: {
    type: String,
    trim: true,
    maxlength: [500, 'Le texte ne peut pas dépasser 500 caractères']
  },
  status: {
    type: String,
    enum: ['open', 'reviewed', 'resolved', 'dismissed'],
    default: 'open',
    index: true
  },
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  reviewedAt: {
    type: Date,
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index compound pour éviter doublons
messageReportSchema.index({ groupId: 1, messageId: 1, reporterId: 1 }, { unique: true });
messageReportSchema.index({ groupId: 1, status: 1, createdAt: -1 });
```

### 4. Nouveau modèle : GroupModerationLog

```javascript
const groupModerationLogSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  action: {
    type: String,
    enum: ['mute', 'unmute', 'pin', 'unpin', 'report', 'ban', 'unban'],
    required: true,
    index: true
  },
  targetUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
    index: true
  },
  messageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  meta: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: true
});

groupModerationLogSchema.index({ groupId: 1, createdAt: -1 });
```

### 5. Extension Ride : Ajout groupId

```javascript
// Ride Schema - Ajout (optionnel pour rétrocompatibilité)
{
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    default: null,
    index: true
  }
}
```

**Index à ajouter** :
```javascript
rideSchema.index({ groupId: 1, date: 1 }); // Calendar queries
rideSchema.index({ groupId: 1, status: 1, date: 1 }); // Filtered calendar
```

### 6. Extension Notification : Nouveaux types

```javascript
// Notification Schema - Ajout types
type: {
  enum: [
    // ... existants ...
    'message_mention',      // Nouveau
    'message_reported',     // Nouveau (pour mods)
    'group_member_muted',   // Nouveau (optionnel)
  ]
}
```

---

## 🔌 CONTRATS API {#api-contracts}

### PHASE 1 : Group Calendar

#### GET /api/groups/:groupId/rides
**Description** : Liste des balades d'un groupe dans une période

**Query Parameters** :
- `from` (required) : ISO date string (ex: `2025-01-01T00:00:00Z`)
- `to` (required) : ISO date string (ex: `2025-01-31T23:59:59Z`)
- `view` (optional) : `'month' | 'week' | 'agenda'` (pour optimisation)

**Response 200** :
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "rideId": "507f1f77bcf86cd799439011",
        "title": "Balade côte",
        "startAt": "2025-01-15T09:00:00Z",
        "endAt": "2025-01-15T12:00:00Z",
        "status": "scheduled",
        "departureName": "Paris",
        "arrivalName": "Lyon",
        "organizer": {
          "id": "507f1f77bcf86cd799439012",
          "pseudo": "JohnDoe"
        },
        "visibility": "publique"
      }
    ],
    "meta": {
      "total": 5,
      "from": "2025-01-01T00:00:00Z",
      "to": "2025-01-31T23:59:59Z"
    }
  }
}
```

**Permissions** :
- Membre du groupe OU créateur
- Si groupe privé : 403 si non membre
- Si groupe public : rides visibles selon `ride.visibility`

#### GET /api/groups/:groupId/calendar.ics
**Description** : Export ICS des balades du groupe

**Query Parameters** :
- `from` (required) : ISO date string
- `to` (required) : ISO date string

**Response 200** :
- Content-Type: `text/calendar; charset=utf-8`
- Content-Disposition: `attachment; filename="ridetogether-{groupId}.ics"`
- Body: Fichier ICS valide

**Exemple ICS** :
```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//RideTogether//Group Calendar//FR
BEGIN:VEVENT
UID:ridetogether-507f1f77bcf86cd799439011@ridetogether
DTSTART:20250115T090000Z
DTEND:20250115T120000Z
SUMMARY:RideTogether: Balade côte
DESCRIPTION:Lien: https://app.ridetogether.fr/rides/507f1f77bcf86cd799439011
LOCATION:Départ: Paris / Arrivée: Lyon
END:VEVENT
END:VCALENDAR
```

**Permissions** : Identique à `/rides`

### PHASE 2 : Mentions

#### GET /api/groups/:groupId/members/suggest
**Description** : Suggestions de membres pour autocomplete mentions

**Query Parameters** :
- `q` (required) : String de recherche (min 1 caractère)

**Response 200** :
```json
{
  "success": true,
  "data": {
    "members": [
      {
        "userId": "507f1f77bcf86cd799439012",
        "username": "johndoe",
        "displayName": "John Doe",
        "avatarUrl": "https://..."
      }
    ]
  }
}
```

**Permissions** : Membre du groupe

**Note** : Le parsing des mentions se fait côté serveur lors de `POST /api/messages` (pas de nouvel endpoint)

### PHASE 3 : Threads

#### GET /api/groups/:groupId/messages
**Modification** : Ajouter query param `parentMessageId`

**Query Parameters** :
- `parentMessageId` (optional) :
  - `null` ou absent : messages principaux (pas de parent)
  - `{messageId}` : réponses à ce message (thread)

**Response 200** : Identique à l'existant, mais filtré par `parentMessageId`

#### GET /api/groups/:groupId/messages/:messageId/thread
**Description** : Récupère le thread complet (root + replies)

**Response 200** :
```json
{
  "success": true,
  "data": {
    "root": { /* Message */ },
    "replies": [ /* Messages[] */ ]
  }
}
```

**Permissions** : Membre du groupe

#### POST /api/groups/:groupId/messages
**Modification** : Ajouter `parentMessageId` dans le body

**Body** :
```json
{
  "text": "Réponse dans le thread",
  "parentMessageId": "507f1f77bcf86cd799439013",
  "attachments": [],
  "poll": null
}
```

### PHASE 4 : Pins

#### POST /api/groups/:groupId/messages/:messageId/pin
**Description** : Épingler un message

**Response 200** :
```json
{
  "success": true,
  "data": {
    "message": { /* Message avec pinned=true */ }
  }
}
```

**Permissions** : Owner/Admin/Mod uniquement

#### POST /api/groups/:groupId/messages/:messageId/unpin
**Description** : Désépingler un message

**Permissions** : Owner/Admin/Mod uniquement

#### GET /api/groups/:groupId/messages/pins
**Description** : Liste des messages épinglés

**Response 200** :
```json
{
  "success": true,
  "data": {
    "pins": [ /* Messages[] triés par pinnedAt desc */ ]
  }
}
```

**Permissions** : Membre du groupe

### PHASE 5 : Recherche

#### GET /api/groups/:groupId/messages/search
**Description** : Recherche avancée de messages

**Query Parameters** :
- `q` (optional) : Texte de recherche
- `media` (optional) : `true | false` (filtre médias)
- `poll` (optional) : `true | false` (filtre sondages)
- `from` (optional) : ISO date (début période)
- `to` (optional) : ISO date (fin période)
- `cursor` (optional) : Pagination cursor
- `limit` (optional) : Nombre de résultats (default: 20, max: 50)

**Response 200** :
```json
{
  "success": true,
  "data": {
    "items": [ /* Messages[] */ ],
    "pageInfo": {
      "nextCursor": "2025-01-15T10:30:00Z",
      "hasNextPage": true
    }
  }
}
```

**Permissions** : Membre du groupe

### PHASE 6 : Modération

#### POST /api/groups/:groupId/messages/:messageId/report
**Description** : Signaler un message

**Body** :
```json
{
  "reasonCode": "SPAM",
  "reasonText": "Message répétitif"
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "report": { /* MessageReport */ },
    "message": "Signalement créé"
  }
}
```

**Permissions** : Membre du groupe (sauf si déjà reporté)

#### POST /api/groups/:groupId/members/:userId/mute
**Description** : Muter un utilisateur

**Body** :
```json
{
  "durationMinutes": 60,
  "reason": "Spam répété"
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "mute": { /* GroupMute */ }
  }
}
```

**Permissions** : Owner/Admin/Mod uniquement

#### POST /api/groups/:groupId/members/:userId/unmute
**Description** : Dé-muter un utilisateur

**Permissions** : Owner/Admin/Mod uniquement

#### GET /api/groups/:groupId/mutes
**Description** : Liste des utilisateurs mutés

**Response 200** :
```json
{
  "success": true,
  "data": {
    "mutes": [ /* GroupMute[] */ ]
  }
}
```

**Permissions** : Owner/Admin/Mod uniquement

---

## 📡 EVENTS SOCKET.IO {#socket-events}

### Events existants (à conserver)

- `new-message` : Nouveau message (inclure `parentMessageId` si thread)
- `message-sent` : Confirmation envoi
- `previous-messages` : Messages initiaux
- `error` : Erreurs

### Nouveaux events (à ajouter)

#### Threads
- `thread:reply:new` (optionnel) : Nouvelle réponse dans un thread
  ```json
  {
    "message": { /* Message */ },
    "threadRootId": "507f1f77bcf86cd799439013",
    "threadReplyCount": 5
  }
  ```

#### Pins
- `message:pinned` : Message épinglé
  ```json
  {
    "messageId": "507f1f77bcf86cd799439013",
    "pinnedBy": { /* User */ },
    "pinnedAt": "2025-01-15T10:00:00Z"
  }
  ```
- `message:unpinned` : Message désépinglé
  ```json
  {
    "messageId": "507f1f77bcf86cd799439013"
  }
  ```

#### Mentions
- `message:mention` : Notification mention (si push activé)
  ```json
  {
    "messageId": "507f1f77bcf86cd799439013",
    "groupId": "507f1f77bcf86cd799439014",
    "mentionedBy": { /* User */ }
  }
  ```

#### Modération
- `user:muted` : Utilisateur muté
  ```json
  {
    "groupId": "507f1f77bcf86cd799439014",
    "userId": "507f1f77bcf86cd799439015",
    "mutedUntil": "2025-01-15T11:00:00Z",
    "reason": "Spam"
  }
  ```
- `user:unmuted` : Utilisateur dé-muté
- `message:reported` : Message signalé (pour mods seulement)
  ```json
  {
    "groupId": "507f1f77bcf86cd799439014",
    "messageId": "507f1f77bcf86cd799439013",
    "reporterId": "507f1f77bcf86cd799439015",
    "reasonCode": "SPAM"
  }
  ```

---

## 🔐 MATRICE DE PERMISSIONS {#permissions}

| Action | Owner | Admin | Mod | Member |
|--------|-------|-------|-----|--------|
| **Calendar** |
| Voir calendrier | ✅ | ✅ | ✅ | ✅ |
| Exporter ICS | ✅ | ✅ | ✅ | ✅ |
| **Chat** |
| Envoyer message | ✅ | ✅ | ✅ | ✅* |
| Éditer message (own) | ✅ | ✅ | ✅ | ✅ |
| Supprimer message (own) | ✅ | ✅ | ✅ | ✅ |
| **Mentions** |
| Mentionner | ✅ | ✅ | ✅ | ✅ |
| **Threads** |
| Répondre | ✅ | ✅ | ✅ | ✅* |
| **Pins** |
| Épingler | ✅ | ✅ | ✅ | ❌ |
| Désépingler | ✅ | ✅ | ✅ | ❌ |
| Voir pins | ✅ | ✅ | ✅ | ✅ |
| **Recherche** |
| Rechercher | ✅ | ✅ | ✅ | ✅ |
| **Modération** |
| Signaler message | ✅ | ✅ | ✅ | ✅ |
| Muter utilisateur | ✅ | ✅ | ✅ | ❌ |
| Dé-muter utilisateur | ✅ | ✅ | ✅ | ❌ |
| Voir mutes | ✅ | ✅ | ✅ | ❌ |
| Voir reports | ✅ | ✅ | ✅ | ❌ |

* : Sauf si utilisateur muté

**Règles spéciales** :
- Utilisateur muté : peut lire, ne peut pas envoyer
- Utilisateur banni : ne peut pas accéder au groupe
- Message signalé : visible par mods/admins pour review

---

## 🎨 FLUX UX {#ux-flows}

### PHASE 1 : Group Calendar

**Écran** : `GroupDetailScreen` → Onglet "Calendrier"

**Flux** :
1. User ouvre groupe → onglet "Calendrier"
2. Vue mois par défaut (tableau calendrier)
3. Tap date → Bottom sheet avec liste rides du jour
4. Tap ride → Navigation vers `RideDetailScreen`
5. Bouton "Exporter ICS" → Share sheet / Download

**Composants Flutter** :
- `GroupCalendarScreen` : Vue calendrier
- `GroupCalendarService` : API calls
- `GroupCalendarRideItem` : Modèle

### PHASE 2 : Mentions

**Flux** :
1. User tape "@" dans input chat
2. Autocomplete apparaît (debounce 250ms)
3. User sélectionne membre → "@username " inséré
4. Envoi message → Backend parse mentions
5. Notifications créées pour mentionnés
6. Dans bubble : mentions stylisées (tappable → profil)

**Composants Flutter** :
- `MentionAutocomplete` : Widget autocomplete
- `MentionTextSpan` : Stylisation mentions dans texte

### PHASE 3 : Threads

**Flux** :
1. User long-press message → Menu "Répondre"
2. Bottom sheet "Thread" s'ouvre :
   - En haut : message root
   - Liste replies (scrollable)
   - Input en bas
3. User répond → Message ajouté au thread
4. Dans timeline principale : badge "X réponses" si `threadReplyCount > 0`
5. Tap badge → Ouvre thread

**Composants Flutter** :
- `ThreadScreen` : Écran thread
- `ThreadReplyWidget` : Widget reply dans timeline

### PHASE 4 : Pins

**Flux** :
1. App bar chat : Icône "📌" (pins)
2. Tap → Écran "Messages épinglés"
3. Long-press message → Menu "Épingler" (si mod)
4. Message épinglé → Socket event → UI update
5. Optionnel : Bandeau en haut du chat avec dernier pin

**Composants Flutter** :
- `PinnedMessagesScreen` : Liste pins
- `PinnedBanner` : Bandeau pin (optionnel)

### PHASE 5 : Recherche

**Flux** :
1. App bar chat : Icône "🔍" (recherche)
2. Tap → Écran "Recherche"
3. Input texte + filtres (chips) : Médias, Sondages, Période
4. Résultats affichés (liste messages)
5. Tap résultat → "Aller au message" → Scroll vers message dans timeline

**Composants Flutter** :
- `ChatSearchScreen` : Écran recherche
- `SearchFilters` : Widget filtres

### PHASE 6 : Modération

**Flux Report** :
1. Long-press message → Menu "Signaler"
2. Modal : Sélection raison + texte optionnel
3. Confirmation → Toast "Signalement envoyé"
4. Mods reçoivent notification

**Flux Mute** :
1. Mod ouvre profil membre → Action "Mute"
2. Picker durée : 10m, 1h, 24h, 7j, custom
3. Raison optionnelle
4. Confirmation → User muté
5. Si user muté : Input désactivé + message "Vous êtes muet jusqu'au..."

**Composants Flutter** :
- `ReportMessageDialog` : Modal report
- `MuteUserDialog` : Modal mute
- `MutedBanner` : Bandeau si user muté

---

## 🔄 PLAN DE MIGRATION {#migration}

### Étape 1 : Préparation (rétrocompatible)

1. **Ajouter `groupId` à Ride** (optionnel, default null)
   - Migration script : `tools/migrate-ride-groupId.js`
   - Logique : Si ride créé depuis groupe, associer `groupId`

2. **Ajouter champs threads à Message** (optionnels)
   - `parentMessageId` : Utiliser `replyToMessageId` existant OU ajouter nouveau champ
   - `threadRootId` : Calculé au runtime si absent
   - `threadReplyCount` : Calculé au runtime si absent

3. **Créer nouveaux modèles** :
   - `GroupMute`
   - `MessageReport`
   - `GroupModerationLog`

### Étape 2 : Index

1. Créer index MongoDB pour performance
2. Index texte pour recherche (si pas déjà fait)

### Étape 3 : Backfill (optionnel)

1. Calculer `threadReplyCount` pour messages existants
2. Calculer `threadRootId` pour replies existantes

### Scripts de migration

**`tools/migrate-ride-groupId.js`** :
```javascript
// Associer rides à groupes si créés depuis groupe
// (nécessite logique métier pour déterminer association)
```

**`tools/migrate-thread-counts.js`** :
```javascript
// Calculer threadReplyCount pour messages existants
const messages = await Message.find({ replyToMessageId: { $exists: true } });
for (const msg of messages) {
  const count = await Message.countDocuments({ 
    parentMessageId: msg.replyToMessageId 
  });
  await Message.updateOne(
    { _id: msg.replyToMessageId },
    { $set: { threadReplyCount: count } }
  );
}
```

---

## ✅ CHECKLIST IMPLÉMENTATION

### Backend
- [ ] PHASE 1 : Calendar endpoints + ICS export
- [ ] PHASE 2 : Mention parsing + suggestions API
- [ ] PHASE 3 : Thread endpoints + socket events
- [ ] PHASE 4 : Pin endpoints + socket events
- [ ] PHASE 5 : Search endpoint + indexes
- [ ] PHASE 6 : Report + Mute endpoints + enforcement

### Frontend
- [ ] PHASE 1 : Calendar screen + ICS export
- [ ] PHASE 2 : Mention autocomplete + styling
- [ ] PHASE 3 : Thread screen + UI
- [ ] PHASE 4 : Pins screen + actions
- [ ] PHASE 5 : Search screen + filters
- [ ] PHASE 6 : Report + Mute dialogs

### Tests
- [ ] Backend : Supertest pour chaque endpoint
- [ ] Frontend : QA checklist pour chaque feature
- [ ] Integration : Socket events + permissions

---

**Dernière mise à jour** : 2025-01-27

