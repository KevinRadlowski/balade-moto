# Checklist QA - Group Calendar & Advanced Chat

## PHASE 1 - Group Calendar

### Backend API
- [ ] `GET /api/groups/:groupId/rides` retourne les balades dans la période demandée
- [ ] `GET /api/groups/:groupId/rides` respecte les permissions (membres seulement pour groupes privés)
- [ ] `GET /api/groups/:groupId/calendar.ics` génère un fichier ICS valide
- [ ] Le fichier ICS contient les UID stables pour chaque balade
- [ ] Le fichier ICS contient les informations complètes (titre, dates, lieu, description)
- [ ] L'export ICS fonctionne avec le token en query parameter

### Frontend Flutter
- [ ] L'écran calendrier s'affiche dans l'onglet "Calendrier" du groupe
- [ ] La vue mois affiche les badges sur les jours avec balades
- [ ] Le tap sur une date affiche la liste des balades du jour
- [ ] Le tap sur une balade ouvre le détail de la balade
- [ ] Le bouton "Exporter ICS" ouvre le fichier dans l'app calendrier
- [ ] Les balades créées depuis un groupe sont automatiquement associées
- [ ] Les balades sélectionnées depuis un groupe sont associées au groupe
- [ ] La suppression d'un message de balade retire la balade du calendrier

---

## PHASE 2 - Mentions @pseudo

### Backend API
- [ ] `GET /api/groups/:groupId/members/suggest?q=...` retourne des suggestions
- [ ] Les suggestions sont filtrées par pseudo/nom
- [ ] Les mentions sont parsées correctement dans les messages
- [ ] Les notifications sont créées pour chaque utilisateur mentionné
- [ ] Un utilisateur ne reçoit pas de notification s'il se mentionne lui-même

### Frontend Flutter
- [ ] L'autocomplete s'affiche quand on tape "@" dans le champ de message
- [ ] La liste des suggestions se met à jour avec debounce
- [ ] La sélection d'un utilisateur insère "@username " dans le texte
- [ ] Les mentions sont affichées en surbrillance dans les messages
- [ ] Les mentions sont tappables (placeholder pour navigation profil)

---

## PHASE 3 - Threads

### Backend API
- [ ] `POST /api/messages` avec `parentMessageId` crée une réponse dans un thread
- [ ] Le `threadRootId` est correctement déterminé
- [ ] Le `threadReplyCount` est incrémenté sur le message racine
- [ ] `GET /api/messages/:messageId/thread` retourne le message racine et les réponses
- [ ] `GET /api/messages` avec `parentMessageId=null` retourne uniquement les messages principaux

### Frontend Flutter
- [ ] Le bouton "Répondre" ouvre le thread
- [ ] L'écran Thread affiche le message racine en haut
- [ ] Les réponses sont affichées en dessous du message racine
- [ ] Le compteur "X réponses" s'affiche sur les messages avec réponses
- [ ] Le tap sur le compteur ouvre le thread
- [ ] Les nouveaux messages dans un thread sont reçus en temps réel

---

## PHASE 4 - Pin Message

### Backend API
- [ ] `POST /api/messages/:messageId/pin` épingler un message (admin/mod seulement)
- [ ] `POST /api/messages/:messageId/pin` désépingler un message
- [ ] `GET /api/groups/:groupId/messages/pins` retourne les messages épinglés
- [ ] L'événement Socket.io `message-pinned` est émis

### Frontend Flutter
- [ ] Le menu contextuel affiche "Épingler" ou "Désépingler" selon l'état
- [ ] Seuls les mods peuvent voir l'option pin
- [ ] L'icône pin dans le header ouvre l'écran des messages épinglés
- [ ] L'écran des messages épinglés affiche tous les pins triés par date
- [ ] Les messages épinglés apparaissent en haut de la timeline
- [ ] Les mises à jour de pin sont reçues en temps réel

---

## PHASE 5 - Recherche avancée

### Backend API
- [ ] `GET /api/groups/:groupId/messages/search?q=...` recherche par texte
- [ ] `GET /api/groups/:groupId/messages/search?media=true` filtre les médias
- [ ] `GET /api/groups/:groupId/messages/search?poll=true` filtre les sondages
- [ ] `GET /api/groups/:groupId/messages/search?from=...&to=...` filtre par période
- [ ] La pagination cursor fonctionne correctement

### Frontend Flutter
- [ ] L'écran de recherche s'ouvre depuis le header
- [ ] Le champ de recherche déclenche la recherche avec debounce
- [ ] Les filtres (Médias, Sondages, Période) fonctionnent
- [ ] Le sélecteur de période ouvre un date range picker
- [ ] Les résultats s'affichent dans une liste
- [ ] Le tap sur un résultat retourne le messageId
- [ ] Le bouton "Charger plus" charge la page suivante

---

## PHASE 6 - Modération

### Backend API
- [ ] `POST /api/groups/:groupId/messages/:messageId/report` crée un report
- [ ] Un utilisateur ne peut pas reporter son propre message
- [ ] Un utilisateur ne peut reporter qu'une fois le même message
- [ ] Les mods/admins reçoivent une notification lors d'un report
- [ ] `POST /api/groups/:groupId/members/:userId/mute` mute un utilisateur (admin/mod)
- [ ] `POST /api/groups/:groupId/members/:userId/unmute` démuté un utilisateur
- [ ] `GET /api/groups/:groupId/mutes` retourne les utilisateurs mutés (admin/mod)
- [ ] Les utilisateurs mutés ne peuvent pas envoyer de messages (HTTP)
- [ ] Les utilisateurs mutés ne peuvent pas envoyer de messages (Socket.io)
- [ ] L'erreur retournée contient la date de fin du mute

### Frontend Flutter
- [ ] L'option "Signaler" apparaît dans le menu contextuel (pas pour ses propres messages)
- [ ] L'écran de signalement affiche les raisons prédéfinies
- [ ] Le champ texte optionnel apparaît pour "Autre"
- [ ] La soumission du report affiche un message de confirmation
- [ ] L'utilisateur muté voit un message d'erreur s'il essaie d'envoyer un message
- [ ] Le message d'erreur affiche la date de fin du mute

---

## Tests de régression

- [ ] Les messages existants continuent de fonctionner
- [ ] Les groupes existants continuent de fonctionner
- [ ] Les balades existantes continuent de fonctionner
- [ ] Les notifications existantes continuent de fonctionner
- [ ] Les Socket.io events existants continuent de fonctionner
- [ ] Aucune erreur de linter
- [ ] Aucune erreur de compilation Flutter

---

## Performance

- [ ] La recherche de messages est rapide (< 500ms)
- [ ] L'autocomplete des mentions est rapide (< 300ms)
- [ ] Le chargement du calendrier est rapide (< 1s)
- [ ] L'export ICS est rapide (< 2s pour 100 balades)

---

## Sécurité

- [ ] Les permissions sont correctement vérifiées pour toutes les routes
- [ ] Les utilisateurs non membres ne peuvent pas accéder aux groupes privés
- [ ] Seuls les mods peuvent muter/pin
- [ ] Les utilisateurs ne peuvent pas signaler leurs propres messages
- [ ] Les utilisateurs mutés ne peuvent pas contourner le mute

