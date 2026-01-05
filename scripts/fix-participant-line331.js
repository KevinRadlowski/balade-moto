/**
 * Script pour corriger le filtre participant à la ligne 331
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
const content = fs.readFileSync(filePath, 'utf8');

// Remplacer la ligne problématique
const newContent = content.replace(
  /(\s+if \(participant\) \{\s+filter\.participants = participant;\s+\})/,
  `    if (participant) {
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

fs.writeFileSync(filePath, newContent, 'utf8');
console.log('✅ Filtre participant ligne 331 corrigé');
