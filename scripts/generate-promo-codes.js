/* eslint-disable no-console */
require('dotenv').config();
const mongoose = require('mongoose');
const promoCodeService = require('../src/services/promoCode.service');
const User = require('../src/models/User');

// Connexion à MongoDB
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides';

async function connectDB() {
  try {
    const conn = await mongoose.connect(MONGO_URI);
    console.log(`✓ MongoDB connecté : ${conn.connection.host}`);
  } catch (error) {
    console.error(`✗ Erreur de connexion MongoDB : ${error.message}`);
    process.exit(1);
  }
}

// Parser les arguments de ligne de commande
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];

    if (key.startsWith('--')) {
      const optionName = key.substring(2);
      
      // Gérer les flags booléens
      if (value === undefined || value.startsWith('--')) {
        options[optionName] = true;
        i--; // Ne pas avancer de 2 pour le prochain tour
      } else {
        options[optionName] = value;
      }
    }
  }

  return options;
}

// Afficher l'aide
function showHelp() {
  console.log(`
Usage: node scripts/generate-promo-codes.js [options]

Options:
  --type <TYPE>              Type de code (requis)
                            Valeurs: DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS, GRANT_PREMIUM_PERMANENT
  --count <NUMBER>          Nombre de codes à générer (requis, 1-100)
  --percent <NUMBER>        Pourcentage de réduction (requis si type=DISCOUNT_PERCENT, 1-100)
  --months <NUMBER>         Nombre de mois Premium (requis si type=GRANT_PREMIUM_MONTHS, >=1)
  --usageLimit <NUMBER>     Limite d'utilisation par code (défaut: 1)
  --validFrom <DATE>        Date de début de validité (format: YYYY-MM-DD)
  --validUntil <DATE>       Date de fin de validité (format: YYYY-MM-DD)
  --createdBy <USER_ID>     ID de l'admin créateur (optionnel, cherche un admin par défaut)
  --metadata <JSON>         Métadonnées au format JSON (optionnel)

Exemples:
  node scripts/generate-promo-codes.js --type GRANT_PREMIUM_MONTHS --count 10 --months 3
  node scripts/generate-promo-codes.js --type DISCOUNT_PERCENT --count 5 --percent 20 --validUntil 2026-12-31
  node scripts/generate-promo-codes.js --type GRANT_PREMIUM_PERMANENT --count 1 --usageLimit 5
`);
}

// Convertir une date string (YYYY-MM-DD) en Date
function parseDate(dateString) {
  if (!dateString) return null;
  const date = new Date(dateString);
  if (isNaN(date.getTime())) {
    throw new Error(`Date invalide: ${dateString}. Format attendu: YYYY-MM-DD`);
  }
  return date;
}

// Parser les métadonnées JSON
function parseMetadata(metadataString) {
  if (!metadataString) return {};
  try {
    return JSON.parse(metadataString);
  } catch (error) {
    throw new Error(`Métadonnées JSON invalides: ${metadataString}`);
  }
}

// Trouver un utilisateur admin pour createdBy
async function findAdminUser() {
  const admin = await User.findOne({ role: 'ADMIN' }).select('_id');
  if (!admin) {
    throw new Error('Aucun utilisateur admin trouvé. Créez d\'abord un admin.');
  }
  return admin._id;
}

// Afficher les codes dans un tableau formaté
function displayCodes(codes) {
  console.log('\n' + '='.repeat(80));
  console.log('CODES PROMOTIONNELS GÉNÉRÉS');
  console.log('='.repeat(80));
  console.log('');
  
  // En-tête du tableau
  console.log('┌─────────────────────────────┬──────────┬──────────────────────────┐');
  console.log('│ Code                        │ Préfixe  │ ID                      │');
  console.log('├─────────────────────────────┼──────────┼──────────────────────────┤');
  
  // Lignes du tableau
  codes.forEach((code, index) => {
    const codeStr = code.codePlain.padEnd(27);
    const prefixStr = code.codePrefix.padEnd(10);
    const idStr = code.id.padEnd(26);
    console.log(`│ ${codeStr} │ ${prefixStr} │ ${idStr} │`);
  });
  
  // Pied du tableau
  console.log('└─────────────────────────────┴──────────┴──────────────────────────┘');
  console.log('');
  console.log(`✓ ${codes.length} code(s) généré(s) avec succès`);
  console.log('');
  console.log('⚠️  IMPORTANT: Les codes ci-dessus ne seront affichés qu\'une seule fois.');
  console.log('   Sauvegardez-les dans un endroit sûr.');
  console.log('');
}

// Fonction principale
async function main() {
  try {
    const options = parseArgs();

    // Afficher l'aide si demandé
    if (options.help || options.h || Object.keys(options).length === 0) {
      showHelp();
      process.exit(0);
    }

    // Validation des paramètres requis
    if (!options.type) {
      console.error('✗ Erreur: --type est requis');
      showHelp();
      process.exit(1);
    }

    if (!options.count) {
      console.error('✗ Erreur: --count est requis');
      showHelp();
      process.exit(1);
    }

    const type = options.type;
    const count = parseInt(options.count, 10);

    if (!['DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'].includes(type)) {
      console.error(`✗ Erreur: Type invalide "${type}". Valeurs acceptées: DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS, GRANT_PREMIUM_PERMANENT`);
      process.exit(1);
    }

    if (isNaN(count) || count < 1 || count > 100) {
      console.error('✗ Erreur: --count doit être un nombre entre 1 et 100');
      process.exit(1);
    }

    // Validation des paramètres selon le type
    let discountPercent, premiumMonths;

    if (type === 'DISCOUNT_PERCENT') {
      if (!options.percent) {
        console.error('✗ Erreur: --percent est requis pour DISCOUNT_PERCENT');
        process.exit(1);
      }
      discountPercent = parseInt(options.percent, 10);
      if (isNaN(discountPercent) || discountPercent < 1 || discountPercent > 100) {
        console.error('✗ Erreur: --percent doit être un nombre entre 1 et 100');
        process.exit(1);
      }
    }

    if (type === 'GRANT_PREMIUM_MONTHS') {
      if (!options.months) {
        console.error('✗ Erreur: --months est requis pour GRANT_PREMIUM_MONTHS');
        process.exit(1);
      }
      premiumMonths = parseInt(options.months, 10);
      if (isNaN(premiumMonths) || premiumMonths < 1) {
        console.error('✗ Erreur: --months doit être un nombre >= 1');
        process.exit(1);
      }
    }

    // Parser les autres options
    const usageLimit = options.usageLimit ? parseInt(options.usageLimit, 10) : 1;
    const validFrom = parseDate(options.validFrom);
    const validUntil = parseDate(options.validUntil);
    const metadata = parseMetadata(options.metadata);

    // Connexion à MongoDB (doit être fait AVANT toute opération DB)
    await connectDB();

    // Trouver l'admin créateur
    let createdBy = options.createdBy;
    if (!createdBy) {
      createdBy = await findAdminUser();
      console.log(`✓ Utilisation de l'admin ID: ${createdBy}`);
    }

    // Générer les codes
    console.log(`\nGénération de ${count} code(s) de type ${type}...`);
    
    const codes = await promoCodeService.generatePromoCodes({
      type,
      count,
      discountPercent,
      premiumMonths,
      usageLimit,
      validFrom,
      validUntil,
      createdBy,
      metadata
    });

    // Afficher les codes
    displayCodes(codes);

    // Fermer la connexion MongoDB
    await mongoose.connection.close();
    console.log('✓ Connexion MongoDB fermée');
    
    process.exit(0);
  } catch (error) {
    console.error(`\n✗ Erreur: ${error.message}`);
    if (error.stack && process.env.NODE_ENV === 'development') {
      console.error(error.stack);
    }
    
    // Fermer la connexion en cas d'erreur
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
    }
    
    process.exit(1);
  }
}

// Exécuter le script
main();

