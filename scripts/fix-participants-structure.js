/**
 * Script pour corriger la structure des participants dans ride.controller.js
 * 
 * Ce script corrige toutes les occurrences de :
 * - participants.some(p => p.toString()) -> participants.some(p => p.userId && p.userId.toString())
 * - participants.filter(p => p.toString()) -> participants.filter(p => !p.userId || p.userId.toString())
 * - .populate('participants') -> .populate('participants.userId')
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
let content = fs.readFileSync(filePath, 'utf8');

// Corrections pour participants.some() avec p.toString() ou p._id
content = content.replace(
  /participants\.some\(\s*p\s*=>\s*p\._id\.toString\(\)\s*===/g,
  'participants.some(p => p.userId && p.userId.toString() ==='
);

content = content.replace(
  /participants\.some\(\s*p\s*=>\s*p\.toString\(\)\s*===/g,
  'participants.some(p => p.userId && p.userId.toString() ==='
);

// Corrections pour participants.filter()
content = content.replace(
  /participants\.filter\(\s*p\s*=>\s*p\.toString\(\)\s*!==/g,
  'participants.filter(p => !p.userId || p.userId.toString() !=='
);

// Corrections pour .populate('participants') -> .populate('participants.userId')
// Mais seulement si ce n'est pas déjà participants.userId
content = content.replace(
  /\.populate\(['"]participants['"],\s*['"]firstName lastName pseudo['"]\)/g,
  ".populate('participants.userId', 'firstName lastName pseudo')"
);

content = content.replace(
  /await\s+ride\.populate\(['"]participants['"],\s*['"]firstName lastName pseudo['"]\)/g,
  "await ride.populate('participants.userId', 'firstName lastName pseudo')"
);

// Sauvegarder
fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ Corrections appliquées avec succès');
