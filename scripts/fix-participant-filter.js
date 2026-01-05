/**
 * Script pour corriger le filtre participant dans ride.controller.js
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
let content = fs.readFileSync(filePath, 'utf8');

// Correction 1: Dans la recherche géospatiale
content = content.replace(
  /if \(participant\) \{\s*filter\.participants = participant;\s*\}/g,
  `if (participant) {
          // Inclure les balades où l'utilisateur est participant OU organisateur
          const participantFilter = {
            $or: [
              { 'participants.userId': participant },
              { organisateur: participant }
            ]
          };
          // Fusionner avec le filtre existant
          if (filter.$and) {
            filter.$and.push(participantFilter);
          } else {
            filter.$and = [participantFilter];
          }
        }`
);

// Correction 2: Dans la recherche classique
content = content.replace(
  /if \(participant\) \{\s*filter\.participants = participant;\s*\}/g,
  `if (participant) {
      // Inclure les balades où l'utilisateur est participant OU organisateur
      // Si $or existe déjà (pour visibilite), on doit utiliser $and
      const participantFilter = {
        $or: [
          { 'participants.userId': participant },
          { organisateur: participant }
        ]
      };
      
      if (filter.$or) {
        // Si $or existe déjà (pour visibilite), on doit utiliser $and
        filter.$and = [
          { $or: filter.$or },
          participantFilter
        ];
        delete filter.$or;
      } else {
        filter.$or = participantFilter.$or;
      }
    }`
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ Filtre participant corrigé');
