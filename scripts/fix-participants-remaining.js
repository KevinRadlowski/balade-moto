/**
 * Script pour corriger les occurrences restantes de participants
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../src/controllers/ride.controller.js');
let content = fs.readFileSync(filePath, 'utf8');

// Correction pour participants: [req.user._id] -> participants: [{ userId: req.user._id }]
content = content.replace(
  /participants:\s*\[req\.user\._id\]/g,
  "participants: [{ userId: req.user._id }]"
);

// Correction pour { participants: req.user._id } dans $or
content = content.replace(
  /\{\s*participants:\s*req\.user\._id\s*\}/g,
  "{ 'participants.userId': req.user._id }"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ Corrections appliquées');
