/**
 * Utilitaires pour la normalisation et validation du catalogue
 */

/**
 * Normalise une marque (trim, uppercase, collapse spaces)
 */
function normalizeMake(str) {
  if (!str || typeof str !== 'string') {
    return '';
  }
  return str
    .trim()
    .toUpperCase()
    .replace(/\s+/g, ' '); // Collapse multiple spaces to single space
}

/**
 * Normalise un modèle (trim, uppercase, collapse spaces)
 */
function normalizeModel(str) {
  if (!str || typeof str !== 'string') {
    return '';
  }
  return str
    .trim()
    .toUpperCase()
    .replace(/\s+/g, ' '); // Collapse multiple spaces to single space
}

/**
 * Valide une année
 */
function validateYear(year) {
  if (typeof year !== 'number' || isNaN(year)) {
    return false;
  }
  const currentYear = new Date().getFullYear();
  return year >= 1900 && year <= currentYear + 1;
}

/**
 * Valide une chaîne de caractères (make ou model)
 * Permet: A-Z0-9 space - ' . / ( ) +
 * Bloque: emojis, caractères spéciaux, etc.
 */
function validateString(str, minLength, maxLength) {
  if (!str || typeof str !== 'string') {
    return false;
  }
  
  const trimmed = str.trim();
  if (trimmed.length < minLength || trimmed.length > maxLength) {
    return false;
  }
  
  // Pattern: A-Z, 0-9, space, -, ', ., /, (, ), +
  const allowedPattern = /^[A-Z0-9\s\-'./()+]+$/;
  return allowedPattern.test(trimmed.toUpperCase());
}

/**
 * Valide une marque
 */
function validateMake(make) {
  return validateString(make, 2, 40);
}

/**
 * Valide un modèle
 */
function validateModel(model) {
  return validateString(model, 1, 80);
}

/**
 * Construit les makeBlocks à partir d'une liste d'entrées approuvées
 * Group by make, trie les modèles alpha, trie les makes alpha
 */
function buildMakeBlocks(entries) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return [];
  }
  
  // Grouper par make
  const makeMap = new Map();
  
  for (const entry of entries) {
    const make = entry.make || '';
    const model = entry.model || '';
    
    if (!make || !model) {
      continue;
    }
    
    if (!makeMap.has(make)) {
      makeMap.set(make, new Set());
    }
    
    makeMap.get(make).add(model);
  }
  
  // Convertir en array et trier
  const makeBlocks = Array.from(makeMap.entries())
    .map(([make, modelsSet]) => ({
      make,
      models: Array.from(modelsSet).sort()
    }))
    .sort((a, b) => a.make.localeCompare(b.make));
  
  return makeBlocks;
}

module.exports = {
  normalizeMake,
  normalizeModel,
  validateYear,
  validateMake,
  validateModel,
  buildMakeBlocks
};

