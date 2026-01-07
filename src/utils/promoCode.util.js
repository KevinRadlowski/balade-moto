const crypto = require('crypto');

/**
 * Génère un code promotionnel au format RT-XXXX-XXXX-XXXX
 * @returns {string} Code promotionnel (ex: RT-A3B2-C4D1-E5F6)
 */
function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclut I, O, 0, 1 pour éviter confusion
  const segments = [4, 4, 4]; // Format: RT-XXXX-XXXX-XXXX (3 segments de 4 caractères)
  
  let code = 'RT-';
  
  for (let i = 0; i < segments.length; i++) {
    for (let j = 0; j < segments[i]; j++) {
      const randomIndex = crypto.randomInt(0, chars.length);
      code += chars[randomIndex];
    }
    if (i < segments.length - 1) {
      code += '-';
    }
  }
  
  return code;
}

/**
 * Hash un code promotionnel avec SHA-256
 * @param {string} code - Code promotionnel en clair
 * @returns {string} Hash SHA-256 en hexadécimal
 */
function hashCode(code) {
  if (!code || typeof code !== 'string') {
    throw new Error('Le code doit être une chaîne non vide');
  }
  
  // Normaliser le code (uppercase, trim)
  const normalizedCode = code.trim().toUpperCase();
  
  return crypto.createHash('sha256').update(normalizedCode).digest('hex');
}

/**
 * Extrait le préfixe d'un code (4 premiers caractères après "RT-")
 * @param {string} code - Code promotionnel
 * @returns {string} Préfixe (ex: "A3B2")
 */
function extractPrefix(code) {
  if (!code || typeof code !== 'string') {
    return null;
  }
  
  const normalizedCode = code.trim().toUpperCase();
  
  // Format attendu: RT-XXXX-XXXX-XXXX
  const match = normalizedCode.match(/^RT-([A-Z0-9]{4})/);
  if (match) {
    return match[1];
  }
  
  // Fallback: prendre les 4 premiers caractères après "RT-"
  const withoutPrefix = normalizedCode.replace(/^RT-?/, '');
  return withoutPrefix.substring(0, 4) || null;
}

/**
 * Compare un code en clair avec un hash stocké (comparaison sécurisée)
 * @param {string} plainCode - Code en clair saisi par l'utilisateur
 * @param {string} storedHash - Hash stocké en base
 * @returns {boolean} true si les codes correspondent
 */
function compareCode(plainCode, storedHash) {
  if (!plainCode || !storedHash) {
    return false;
  }
  
  const computedHash = hashCode(plainCode);
  
  // Vérifier que les deux hashs ont la même longueur (SHA-256 = 64 caractères hex)
  if (computedHash.length !== storedHash.length) {
    return false;
  }
  
  // Comparaison sécurisée pour éviter les attaques par timing
  try {
    return crypto.timingSafeEqual(
      Buffer.from(computedHash, 'hex'),
      Buffer.from(storedHash, 'hex')
    );
  } catch (error) {
    // En cas d'erreur (buffers de longueur différente), retourner false
    return false;
  }
}

module.exports = {
  generateCode,
  hashCode,
  extractPrefix,
  compareCode
};

