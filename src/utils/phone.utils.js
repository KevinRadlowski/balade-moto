/**
 * Utilitaires pour la normalisation et validation des numéros de téléphone
 */

/**
 * Normalise un numéro de téléphone au format E.164
 * @param {string} input - Numéro de téléphone à normaliser
 * @returns {string|null} - Numéro normalisé en E.164 ou null si invalide
 */
function normalizePhoneE164(input) {
  if (!input || typeof input !== 'string') {
    return null;
  }

  // Retirer espaces, tirets, parenthèses, points
  let cleaned = input.trim()
    .replace(/\s+/g, '')
    .replace(/-/g, '')
    .replace(/\(/g, '')
    .replace(/\)/g, '')
    .replace(/\./g, '');

  // Si commence par 0 (format français), remplacer par +33
  if (cleaned.startsWith('0')) {
    cleaned = '+33' + cleaned.substring(1);
  }

  // Si ne commence pas par +, ajouter +
  if (!cleaned.startsWith('+')) {
    cleaned = '+' + cleaned;
  }

  // Vérifier le format E.164: + suivi de 1-3 chiffres (indicatif), puis 4-14 chiffres
  // Longueur totale: 8 à 16 caractères (incluant le +)
  if (!/^\+[1-9]\d{1,14}$/.test(cleaned)) {
    return null;
  }

  // Vérifier longueur minimale et maximale
  if (cleaned.length < 8 || cleaned.length > 16) {
    return null;
  }

  return cleaned;
}

/**
 * Valide qu'un numéro est au format E.164
 * @param {string} phone - Numéro à valider
 * @returns {boolean}
 */
function isValidE164(phone) {
  if (!phone || typeof phone !== 'string') {
    return false;
  }
  return /^\+[1-9]\d{1,14}$/.test(phone) && phone.length >= 8 && phone.length <= 16;
}

module.exports = {
  normalizePhoneE164,
  isValidE164
};
