/**
 * Configuration email normalisée
 * 
 * Supporte deux formats de variables d'environnement :
 * - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM (format préféré)
 * - EMAIL_HOST, EMAIL_PORT, EMAIL_USER, EMAIL_PASS, EMAIL_FROM (alias pour compatibilité)
 */

/**
 * Récupère une variable d'environnement avec fallback sur alias
 * @param {string} primaryKey - Clé principale (ex: 'SMTP_HOST')
 * @param {string} aliasKey - Clé d'alias (ex: 'EMAIL_HOST')
 * @param {string} defaultValue - Valeur par défaut
 * @returns {string} Valeur de la variable
 */
function getEnvVar(primaryKey, aliasKey, defaultValue = null) {
  return process.env[primaryKey] || process.env[aliasKey] || defaultValue;
}

/**
 * Configuration email normalisée
 */
const emailConfig = {
  host: getEnvVar('SMTP_HOST', 'EMAIL_HOST', 'smtp.gmail.com'),
  port: parseInt(getEnvVar('SMTP_PORT', 'EMAIL_PORT', '587'), 10),
  user: getEnvVar('SMTP_USER', 'EMAIL_USER'),
  pass: getEnvVar('SMTP_PASS', 'EMAIL_PASS'),
  from: getEnvVar('SMTP_FROM', 'EMAIL_FROM')
};

/**
 * Vérifie si l'email est configuré
 * @returns {boolean} true si configuré, false sinon
 */
function isEmailConfigured() {
  return !!(emailConfig.user && emailConfig.pass);
}

/**
 * Log un warning unique si l'email n'est pas configuré
 */
let emailWarningLogged = false;
function logEmailWarningIfNeeded() {
  if (!isEmailConfigured() && !emailWarningLogged) {
    console.warn('⚠️  Email non configuré. Les emails ne pourront pas être envoyés.');
    console.warn('   Variables requises: SMTP_USER (ou EMAIL_USER) et SMTP_PASS (ou EMAIL_PASS)');
    emailWarningLogged = true;
  }
}

module.exports = {
  emailConfig,
  isEmailConfigured,
  logEmailWarningIfNeeded
};














