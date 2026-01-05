/**
 * Script pour corriger le filtre participant restant dans ride.controller.js
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
let content = fs.readFileSync(filePath, 'utf8');

// Trouver et remplacer la ligne 330-332
const lines = content.split('\n');
let found = false;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('if (participant) {') && lines[i + 1] && lines[i + 1].includes('filter.participants = participant;')) {
    // Remplacer les 3 lignes suivantes
    lines[i] = '    if (participant) {';
    lines[i + 1] = '      // Inclure les balades où l\'utilisateur est participant OU organisateur';
    lines[i + 2] = '      // Si $or existe déjà (pour visibilite), on doit utiliser $and';
    lines[i + 3] = '      const participantFilter = {';
    lines[i + 4] = '        $or: [';
    lines[i + 5] = '          { \'participants.userId\': participant },';
    lines[i + 6] = '          { organisateur: participant }';
    lines[i + 7] = '        ]';
    lines[i + 8] = '      };';
    lines[i + 9] = '      ';
    lines[i + 10] = '      if (filter.$or) {';
    lines[i + 11] = '        // Si $or existe déjà (pour visibilite), on doit utiliser $and';
    lines[i + 12] = '        filter.$and = [';
    lines[i + 13] = '          { $or: filter.$or },';
    lines[i + 14] = '          participantFilter';
    lines[i + 15] = '        ];';
    lines[i + 16] = '        delete filter.$or;';
    lines[i + 17] = '      } else {';
    lines[i + 18] = '        filter.$or = participantFilter.$or;';
    lines[i + 19] = '      }';
    lines[i + 20] = '    }';
    // Supprimer l'ancienne ligne
    lines.splice(i + 21, 1);
    found = true;
    break;
  }
}

if (found) {
  fs.writeFileSync(filePath, lines.join('\n'), 'utf8');
  console.log('✅ Filtre participant corrigé');
} else {
  console.log('⚠️  Filtre participant non trouvé - peut-être déjà corrigé');
}
