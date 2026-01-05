/**
 * Script de test de connexion SMTP
 * 
 * Usage: node scripts/test-smtp.js
 * 
 * Teste la connexion au serveur SMTP configuré dans .env
 */

require('dotenv').config();
const nodemailer = require('nodemailer');

// Récupérer la configuration
function getEnvVar(primaryKey, aliasKey, defaultValue = null) {
  return process.env[primaryKey] || process.env[aliasKey] || defaultValue;
}

const emailConfig = {
  host: getEnvVar('SMTP_HOST', 'EMAIL_HOST', 'smtp.gmail.com'),
  port: parseInt(getEnvVar('SMTP_PORT', 'EMAIL_PORT', '587'), 10),
  user: getEnvVar('SMTP_USER', 'EMAIL_USER'),
  pass: getEnvVar('SMTP_PASS', 'EMAIL_PASS'),
  from: getEnvVar('SMTP_FROM', 'EMAIL_FROM')
};

console.log('🔍 Test de connexion SMTP\n');
console.log('Configuration:');
console.log(`  Host: ${emailConfig.host}`);
console.log(`  Port: ${emailConfig.port}`);
console.log(`  User: ${emailConfig.user ? emailConfig.user.substring(0, 5) + '...' : 'NON DÉFINI'}`);
console.log(`  Pass: ${emailConfig.pass ? '***' : 'NON DÉFINI'}`);
console.log(`  From: ${emailConfig.from || 'NON DÉFINI'}`);
console.log('');

if (!emailConfig.user || !emailConfig.pass) {
  console.error('❌ Erreur: SMTP_USER et SMTP_PASS doivent être définis dans .env');
  process.exit(1);
}

// Tester les deux ports courants
const portsToTest = emailConfig.port === 465 ? [465, 587] : [587, 465];

async function testConnection(port) {
  const isSecure = port === 465;
  
  console.log(`\n📡 Test du port ${port} (${isSecure ? 'SSL' : 'TLS'})...`);
  
  const transporter = nodemailer.createTransport({
    host: emailConfig.host,
    port: port,
    secure: isSecure,
    auth: {
      user: emailConfig.user,
      pass: emailConfig.pass
    },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 10000,
    requireTLS: !isSecure,
    tls: {
      rejectUnauthorized: false,
      minVersion: 'TLSv1.2'
    }
  });

  try {
    await transporter.verify();
    console.log(`✅ Connexion réussie sur le port ${port}!`);
    return true;
  } catch (error) {
    console.log(`❌ Échec sur le port ${port}:`);
    console.log(`   Erreur: ${error.message}`);
    console.log(`   Code: ${error.code}`);
    return false;
  }
}

async function runTests() {
  for (const port of portsToTest) {
    const success = await testConnection(port);
    if (success) {
      console.log(`\n✅ Recommandation: Utilisez le port ${port} dans votre .env`);
      console.log(`   SMTP_PORT=${port}`);
      process.exit(0);
    }
  }
  
  console.log('\n❌ Aucun port n\'a fonctionné. Vérifiez:');
  console.log('   1. Que votre firewall/autorouteur autorise les connexions sortantes');
  console.log('   2. Que vous utilisez un "App Password" pour Gmail');
  console.log('   3. Que votre connexion internet fonctionne');
  console.log('   4. Que les identifiants sont corrects dans .env');
  process.exit(1);
}

runTests();
