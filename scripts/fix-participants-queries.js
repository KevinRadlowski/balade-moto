/**
 * Script pour corriger les requêtes MongoDB qui utilisent participants
 * 
 * Ce script corrige :
 * - { participants: userId } -> { 'participants.userId': userId }
 * - filter.participants = participant -> filter['participants.userId'] = participant
 * - localField: 'participants' -> localField: 'participants.userId' (dans les aggregations)
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
let content = fs.readFileSync(filePath, 'utf8');

// Correction pour les filtres dans $or
content = content.replace(
  /\{\s*participants:\s*req\.user\._id\s*\}/g,
  "{ 'participants.userId': req.user._id }"
);

content = content.replace(
  /\{\s*participants:\s*participant\s*\}/g,
  "{ 'participants.userId': participant }"
);

// Correction pour filter.participants = participant
content = content.replace(
  /filter\.participants\s*=\s*participant;/g,
  "filter['participants.userId'] = participant;"
);

// Correction pour les aggregations $lookup
content = content.replace(
  /localField:\s*['"]participants['"]/g,
  "localField: 'participants.userId'"
);

// Sauvegarder
fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ Corrections des requêtes MongoDB appliquées avec succès');
