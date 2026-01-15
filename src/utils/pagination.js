/**
 * Module utilitaire pour la pagination standardisée
 * 
 * Supporte deux modes :
 * 1. Cursor-based (recommandé pour performance) : utilise _id ou createdAt + _id
 * 2. Offset-based (fallback) : utilise page + limit
 * 
 * Toutes les limites sont strictement bornées pour éviter les surcharges.
 */

/**
 * Parse et valide les paramètres de pagination depuis req.query
 * @param {object} query - req.query
 * @param {object} options - Options de configuration
 * @returns {object} Paramètres de pagination normalisés
 */
function parsePaginationParams(query, options = {}) {
  const {
    defaultLimit = 20,
    maxLimit = 50,
    minLimit = 1,
    cursorField = '_id', // Champ utilisé pour le cursor (peut être '_id' ou 'createdAt')
    cursorValue = null, // Cursor fourni (base64 encodé)
    preferCursor = true // Préférer cursor-based si possible
  } = options;

  // Récupérer les paramètres
  const cursor = query.cursor || cursorValue;
  const page = parseInt(query.page) || null;
  const limit = Math.min(
    Math.max(parseInt(query.limit) || defaultLimit, minLimit),
    maxLimit
  );

  // Décider du mode de pagination
  const useCursor = preferCursor && cursor !== null && cursor !== undefined;

  return {
    mode: useCursor ? 'cursor' : 'offset',
    cursor: useCursor ? decodeCursor(cursor) : null,
    page: useCursor ? null : (page || 1),
    limit,
    sortField: cursorField
  };
}

/**
 * Décode un cursor base64 en objet utilisable pour la requête
 * @param {string} cursorBase64 - Cursor encodé en base64
 * @returns {object|null} Objet avec _id et/ou createdAt, ou null si invalide
 */
function decodeCursor(cursorBase64) {
  if (!cursorBase64) return null;
  
  try {
    const decoded = Buffer.from(cursorBase64, 'base64').toString('utf-8');
    const parsed = JSON.parse(decoded);
    
    // Valider la structure
    if (parsed._id || parsed.createdAt) {
      return parsed;
    }
    
    return null;
  } catch (error) {
    // Cursor invalide, ignorer
    return null;
  }
}

/**
 * Encode un objet en cursor base64
 * @param {object} data - Objet à encoder (doit contenir _id et/ou createdAt)
 * @returns {string} Cursor encodé en base64
 */
function encodeCursor(data) {
  if (!data || (!data._id && !data.createdAt)) {
    return null;
  }
  
  const toEncode = {
    _id: data._id?.toString() || data._id,
    createdAt: data.createdAt ? new Date(data.createdAt).toISOString() : null
  };
  
  // Nettoyer les valeurs null
  Object.keys(toEncode).forEach(key => {
    if (toEncode[key] === null) delete toEncode[key];
  });
  
  return Buffer.from(JSON.stringify(toEncode)).toString('base64');
}

/**
 * Construit un filtre MongoDB pour la pagination cursor-based
 * @param {object} cursor - Cursor décodé
 * @param {string} sortField - Champ utilisé pour le tri ('_id' ou 'createdAt')
 * @param {number} sortOrder - Ordre de tri (1 pour asc, -1 pour desc)
 * @returns {object} Filtre MongoDB
 */
function buildCursorFilter(cursor, sortField = '_id', sortOrder = -1) {
  if (!cursor) return {};
  
  const filter = {};
  
  if (sortField === '_id') {
    // Pour _id, on utilise $lt ou $gt selon l'ordre
    if (cursor._id) {
      filter._id = sortOrder === -1 ? { $lt: cursor._id } : { $gt: cursor._id };
    }
  } else if (sortField === 'createdAt') {
    // Pour createdAt, on peut combiner avec _id pour garantir l'unicité
    if (cursor.createdAt) {
      const dateFilter = sortOrder === -1 
        ? { $lt: new Date(cursor.createdAt) }
        : { $gt: new Date(cursor.createdAt) };
      
      // Si on a aussi _id, l'utiliser pour plus de précision
      if (cursor._id) {
        filter.$or = [
          { createdAt: dateFilter },
          { 
            createdAt: new Date(cursor.createdAt),
            _id: sortOrder === -1 ? { $lt: cursor._id } : { $gt: cursor._id }
          }
        ];
      } else {
        filter.createdAt = dateFilter;
      }
    }
  }
  
  return filter;
}

/**
 * Construit la réponse de pagination standardisée
 * @param {Array} items - Items de la page actuelle
 * @param {object} paginationParams - Paramètres de pagination utilisés
 * @param {number} total - Nombre total d'items (optionnel, pour offset-based)
 * @param {boolean} hasMore - Indique s'il y a plus d'items (pour cursor-based)
 * @returns {object} Réponse de pagination
 */
function buildPaginationResponse(items, paginationParams, total = null, hasMore = false) {
  const { mode, limit, cursor, page } = paginationParams;
  
  // Déterminer le nextCursor si cursor-based
  let nextCursor = null;
  if (mode === 'cursor' && items.length > 0) {
    const lastItem = items[items.length - 1];
    nextCursor = encodeCursor({
      _id: lastItem._id || lastItem.id,
      createdAt: lastItem.createdAt || lastItem.date
    });
  }
  
  // Construire la réponse
  const response = {
    items,
    pageInfo: {
      mode,
      limit,
      ...(mode === 'cursor' ? {
        nextCursor,
        hasNextPage: hasMore || (items.length === limit && nextCursor !== null)
      } : {
        page: page || 1,
        total: total || items.length,
        totalPages: total ? Math.ceil(total / limit) : 1,
        hasNextPage: total ? (page * limit < total) : false
      })
    }
  };
  
  return response;
}

/**
 * Construit les headers HTTP pour la pagination (compatibilité avec format existant)
 * @param {object} paginationInfo - Informations de pagination
 * @returns {object} Headers à ajouter à la réponse
 */
function buildPaginationHeaders(paginationInfo) {
  const headers = {};
  
  if (paginationInfo.nextCursor) {
    headers['X-Next-Cursor'] = paginationInfo.nextCursor;
  }
  
  if (paginationInfo.hasNextPage !== undefined) {
    headers['X-Has-Next-Page'] = paginationInfo.hasNextPage.toString();
  }
  
  return headers;
}

/**
 * Helper pour appliquer la pagination à une requête Mongoose
 * @param {object} query - Requête Mongoose
 * @param {object} paginationParams - Paramètres de pagination
 * @param {object} sortOptions - Options de tri { field: string, order: number }
 * @returns {object} Requête modifiée avec pagination appliquée
 */
function applyPaginationToQuery(query, paginationParams, sortOptions = { field: '_id', order: -1 }) {
  const { mode, cursor, page, limit, sortField } = paginationParams;
  
  // Appliquer le tri
  const sort = {};
  sort[sortOptions.field || sortField] = sortOptions.order || -1;
  query.sort(sort);
  
  // Appliquer la pagination
  if (mode === 'cursor') {
    // Cursor-based
    if (cursor) {
      const cursorFilter = buildCursorFilter(cursor, sortOptions.field || sortField, sortOptions.order || -1);
      Object.assign(query.getQuery(), cursorFilter);
    }
    query.limit(limit + 1); // +1 pour détecter s'il y a plus d'items
  } else {
    // Offset-based
    const skip = (page - 1) * limit;
    query.skip(skip).limit(limit);
  }
  
  return query;
}

/**
 * Traite les résultats après pagination cursor-based
 * @param {Array} results - Résultats de la requête (avec +1 item si hasMore)
 * @param {number} limit - Limite demandée
 * @returns {object} { items, hasMore }
 */
function processCursorResults(results, limit) {
  const hasMore = results.length > limit;
  const items = hasMore ? results.slice(0, limit) : results;
  
  return { items, hasMore };
}

/**
 * Valide et normalise les paramètres de pagination offset-based
 * @param {number|string} page - Numéro de page
 * @param {number|string} limit - Limite par page
 * @returns {object} { validatedPage, validatedLimit }
 */
function validatePaginationParams(page, limit) {
  const DEFAULT_LIMIT = parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20;
  const MAX_LIMIT = parseInt(process.env.PAGINATION_MAX_LIMIT) || 50;
  
  const validatedPage = Math.max(1, parseInt(page) || 1);
  const validatedLimit = Math.min(Math.max(parseInt(limit) || DEFAULT_LIMIT, 1), MAX_LIMIT);
  
  return { validatedPage, validatedLimit };
}

module.exports = {
  parsePaginationParams,
  decodeCursor,
  encodeCursor,
  buildCursorFilter,
  buildPaginationResponse,
  buildPaginationHeaders,
  applyPaginationToQuery,
  processCursorResults,
  validatePaginationParams,
  DEFAULT_LIMIT: parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20,
  MAX_LIMIT: parseInt(process.env.PAGINATION_MAX_LIMIT) || 50
};

