const axios = require('axios');
const CatalogCache = require('../models/CatalogCache');

const CARAPI_BASE_URL = process.env.CARAPI_BASE_URL || 'https://www.carapi.app/api';
const REQUEST_TIMEOUT = 5000; // 5 secondes
const MAX_RETRIES = 1;

/**
 * Service pour interagir avec l'API CarAPI.app
 * - CarAPI.app pour les voitures
 * - CarAPI.app PowerSports pour les motos
 */
class CarApiService {
  /**
   * Effectue une requête HTTP avec retry
   * @throws {Error} Erreur avec status 502 si CarAPI renvoie 404
   */
  async _makeRequest(url, params = {}, retries = MAX_RETRIES) {
    try {
      console.log('[CarAPI] Appel:', { url, params });
      const response = await axios.get(url, {
        params,
        timeout: REQUEST_TIMEOUT,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      });
      
      console.log('[CarAPI] Réponse:', { 
        url, 
        status: response.status, 
        dataType: typeof response.data,
        hasCollection: !!(response.data?.collection),
        hasData: !!(response.data?.data),
        isArray: Array.isArray(response.data)
      });
      
      return response.data;
    } catch (error) {
      if (retries > 0 && (error.code === 'ECONNRESET' || error.code === 'ETIMEDOUT' || !error.response)) {
        console.warn('[CarAPI] Retry request:', {
          url,
          retriesLeft: retries - 1,
          errorCode: error.code
        });
        await new Promise(resolve => setTimeout(resolve, 500));
        return this._makeRequest(url, params, retries - 1);
      }
      
      // Gérer les erreurs CarAPI proprement
      if (error.response) {
        const status = error.response.status;
        console.error('[CarAPI] Request failed:', {
          url,
          status,
          statusText: error.response.statusText,
          errorCode: error.code
        });
        
        // Si 404, transformer en 502 (Bad Gateway) avec message clair
        if (status === 404) {
          const cleanError = new Error('CarAPI endpoint not found (Power Sports). Check CarAPI baseUrl and path.');
          cleanError.status = 502;
          cleanError.isCarApiError = true;
          throw cleanError;
        }
        
        // Pour les autres erreurs HTTP, créer une erreur avec le status
        const httpError = new Error(error.response.data?.message || `CarAPI returned ${status}`);
        httpError.status = status;
        httpError.isCarApiError = true;
        throw httpError;
      }
      
      // Erreur réseau/timeout
      console.error('[CarAPI] Network error:', {
        url,
        errorCode: error.code,
        message: error.message
      });
      throw error;
    }
  }

  /**
   * Normalise les données de marque depuis CarAPI
   * IMPORTANT: id doit être un entier (number), pas une string
   */
  _normalizeMake(item) {
    const id = item.id || item.make_id || item.makeId;
    const idNumber = typeof id === 'number' ? id : (typeof id === 'string' ? parseInt(id, 10) : null);
    
    return {
      id: idNumber,
      name: String(item.name || item.make_name || item.makeName || item.make || '')
    };
  }

  /**
   * Normalise les données de modèle depuis CarAPI
   * IMPORTANT: id et makeId doivent être des entiers (number), pas des strings
   */
  _normalizeModel(item, makeName, makeId) {
    const id = item.id || item.model_id || item.modelId;
    const idNumber = typeof id === 'number' ? id : (typeof id === 'string' ? parseInt(id, 10) : null);
    
    const itemMakeId = item.make_id || item.makeId || makeId;
    const makeIdNumber = typeof itemMakeId === 'number' ? itemMakeId : 
                         (typeof itemMakeId === 'string' ? parseInt(itemMakeId, 10) : 
                          (makeId ? (typeof makeId === 'number' ? makeId : parseInt(makeId, 10)) : null));
    
    return {
      id: idNumber,
      name: String(item.name || item.model_name || item.modelName || item.model || ''),
      makeName: makeName || String(item.make || item.make_name || ''),
      makeId: makeIdNumber
    };
  }

  /**
   * Récupère les marques de voitures pour une année
   * @param {number} year - Année
   * @returns {Promise<Array>} Liste des marques [{ id, name }]
   */
  async fetchCarMakes(year) {
    const cacheKey = CatalogCache.generateKey('carapi', 'voiture', 'makes', year.toString());
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarAPI.app endpoint pour les marques de voitures
          const url = `${CARAPI_BASE_URL}/makes`;
          const data = await this._makeRequest(url, { year });
          
          if (!data || !Array.isArray(data)) {
            console.warn('[CarAPI] Pas de résultats pour fetchCarMakes', { year });
            return [];
          }

          const makes = data
            .map(item => this._normalizeMake(item))
            .filter(make => make.id != null && make.name)
            .sort((a, b) => a.name.localeCompare(b.name));

          console.log('[CarAPI] fetchCarMakes:', { year, count: makes.length });
          return makes;
        } catch (error) {
          console.error('[CarAPI] Erreur fetchCarMakes:', { year, error: error.message });
          throw error;
        }
      },
      24 * 7 // Cache 7 jours
    );
  }

  /**
   * Récupère les modèles de voitures pour une marque et une année
   * @param {number} year - Année
   * @param {string} makeId - ID de la marque
   * @param {string} makeName - Nom de la marque (fallback)
   * @returns {Promise<Array>} Liste des modèles [{ id, name, makeName }]
   */
  async fetchCarModels(year, makeId, makeName = '') {
    const cacheKey = CatalogCache.generateKey('carapi', 'voiture', 'models', year.toString(), makeId);
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarAPI.app endpoint pour les modèles de voitures
          const url = `${CARAPI_BASE_URL}/models`;
          const data = await this._makeRequest(url, { 
            year,
            make_id: makeId 
          });
          
          if (!data || !Array.isArray(data)) {
            console.warn('[CarAPI] Pas de résultats pour fetchCarModels', { year, makeId });
            return [];
          }

          const models = data
            .map(item => this._normalizeModel(item, makeName))
            .filter(model => model.id != null && model.name)
            .sort((a, b) => a.name.localeCompare(b.name));

          console.log('[CarAPI] fetchCarModels:', { year, makeId, count: models.length });
          return models;
        } catch (error) {
          console.error('[CarAPI] Erreur fetchCarModels:', { year, makeId, error: error.message });
          throw error;
        }
      },
      24 * 7 // Cache 7 jours
    );
  }

  /**
   * Récupère les marques de motos pour une année
   * Utilise l'endpoint CarAPI Power Sports: /api/makes/street-motorcycles
   * @param {number} year - Année
   * @returns {Promise<Array>} Liste des marques [{ id: number, name: string }]
   */
  async fetchMotoMakes(year) {
    const cacheKey = CatalogCache.generateKey('carapi', 'moto', 'makes', year.toString());
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarAPI.app Power Sports endpoint pour les marques de motos (Street Motorcycles)
          const url = `${CARAPI_BASE_URL}/makes/street-motorcycles`;
          const allMakes = [];
          let page = 1;
          let hasMore = true;
          
          while (hasMore) {
            const params = {
              sort: 'name',
              direction: 'asc',
              year: year,
              page: page
            };
            
            console.log('[CarAPI] fetchMotoMakes - Appel page', page, { url, params });
            const data = await this._makeRequest(url, params);
            
            // CarAPI renvoie { collection: {...}, data: [...] }
            if (data && data.collection && Array.isArray(data.data)) {
              const makes = data.data
                .map(item => this._normalizeMake(item))
                .filter(make => make.id != null && make.name);
              
              allMakes.push(...makes);
              
              // Vérifier s'il y a d'autres pages
              const totalPages = data.collection?.pages || 1;
              hasMore = page < totalPages;
              page++;
              
              console.log('[CarAPI] fetchMotoMakes - Page', page - 1, ':', {
                items: makes.length,
                total: allMakes.length,
                totalPages,
                hasMore
              });
            } else if (Array.isArray(data)) {
              // Fallback: si CarAPI renvoie directement un tableau
              const makes = data
                .map(item => this._normalizeMake(item))
                .filter(make => make.id != null && make.name);
              allMakes.push(...makes);
              hasMore = false;
            } else {
              console.warn('[CarAPI] Format de réponse inattendu pour fetchMotoMakes', { 
                year, 
                dataType: typeof data,
                hasCollection: !!(data?.collection),
                hasData: !!(data?.data)
              });
              hasMore = false;
            }
          }

          // Dédupliquer par id et trier
          const uniqueMakes = Array.from(
            new Map(allMakes.map(make => [make.id, make])).values()
          ).sort((a, b) => a.name.localeCompare(b.name));

          console.log('[CarAPI] fetchMotoMakes final:', { 
            year, 
            totalPages: page - 1,
            totalItems: allMakes.length,
            uniqueCount: uniqueMakes.length 
          });
          
          return uniqueMakes;
        } catch (error) {
          console.error('[CarAPI] Erreur fetchMotoMakes:', { 
            year, 
            error: error.message,
            status: error.status,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
          });
          throw error;
        }
      },
      24 * 7 // Cache 7 jours
    );
  }

  /**
   * Récupère les modèles de motos pour une marque et une année
   * Utilise l'endpoint CarAPI Power Sports: /api/models/street-motorcycles
   * @param {number} year - Année
   * @param {number} makeId - ID de la marque (entier)
   * @param {string} makeName - Nom de la marque (fallback)
   * @returns {Promise<Array>} Liste des modèles [{ id: number, name: string, makeName: string, makeId: number }]
   */
  async fetchMotoModels(year, makeId, makeName = '') {
    // S'assurer que makeId est un entier
    const makeIdInt = typeof makeId === 'number' ? makeId : parseInt(String(makeId), 10);
    if (isNaN(makeIdInt) || makeIdInt <= 0) {
      throw new Error(`makeId invalide: ${makeId} (doit être un entier positif)`);
    }
    
    const cacheKey = CatalogCache.generateKey('carapi', 'moto', 'models', year.toString(), makeIdInt.toString());
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarAPI.app Power Sports endpoint pour les modèles de motos (Street Motorcycles)
          const url = `${CARAPI_BASE_URL}/models/street-motorcycles`;
          const allModels = [];
          let page = 1;
          let hasMore = true;
          
          while (hasMore) {
            const params = {
              sort: 'name',
              direction: 'asc',
              year: year,
              make_id: makeIdInt,
              page: page
            };
            
            console.log('[CarAPI] fetchMotoModels - Appel page', page, { url, params });
            const data = await this._makeRequest(url, params);
            
            // CarAPI renvoie { collection: {...}, data: [...] }
            if (data && data.collection && Array.isArray(data.data)) {
              const models = data.data
                .map(item => this._normalizeModel(item, makeName, makeIdInt))
                .filter(model => model.id != null && model.name);
              
              allModels.push(...models);
              
              // Vérifier s'il y a d'autres pages
              const totalPages = data.collection?.pages || 1;
              hasMore = page < totalPages;
              page++;
              
              console.log('[CarAPI] fetchMotoModels - Page', page - 1, ':', {
                items: models.length,
                total: allModels.length,
                totalPages,
                hasMore
              });
            } else if (Array.isArray(data)) {
              // Fallback: si CarAPI renvoie directement un tableau
              const models = data
                .map(item => this._normalizeModel(item, makeName, makeIdInt))
                .filter(model => model.id != null && model.name);
              allModels.push(...models);
              hasMore = false;
            } else {
              console.warn('[CarAPI] Format de réponse inattendu pour fetchMotoModels', { 
                year, 
                makeId: makeIdInt,
                dataType: typeof data,
                hasCollection: !!(data?.collection),
                hasData: !!(data?.data)
              });
              hasMore = false;
            }
          }

          // Dédupliquer par id et trier
          const uniqueModels = Array.from(
            new Map(allModels.map(model => [model.id, model])).values()
          ).sort((a, b) => a.name.localeCompare(b.name));

          console.log('[CarAPI] fetchMotoModels final:', { 
            year, 
            makeId: makeIdInt,
            totalPages: page - 1,
            totalItems: allModels.length,
            uniqueCount: uniqueModels.length 
          });
          
          return uniqueModels;
        } catch (error) {
          console.error('[CarAPI] Erreur fetchMotoModels:', { 
            year, 
            makeId: makeIdInt,
            error: error.message,
            status: error.status,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
          });
          throw error;
        }
      },
      24 * 7 // Cache 7 jours
    );
  }
}

module.exports = new CarApiService();

