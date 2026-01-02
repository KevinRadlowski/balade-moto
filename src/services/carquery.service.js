const axios = require('axios');
const crypto = require('crypto');
const CatalogCache = require('../models/CatalogCache');

const CARQUERY_BASE_URL = process.env.CARQUERY_BASE_URL || 'https://www.carqueryapi.com/api/0.3';
const REQUEST_TIMEOUT = 5000; // 5 secondes
const MAX_RETRIES = 1;

// Liste des marques de motos connues (normalisées en minuscules pour comparaison)
// Note: Certaines marques comme Honda, Suzuki, Yamaha, BMW produisent aussi des voitures,
// mais on les inclut dans la liste des motos car elles sont très connues pour leurs motos
const MOTORCYCLE_BRANDS = new Set([
  // Marques principales de motos
  'aprilia', 'benelli', 'bmw', 'brough superior', 'buell', 'bultaco', 'cagiva',
  'can-am', 'derbi', 'ducati', 'gas gas', 'gasgas', 'harley-davidson', 'honda',
  'husqvarna', 'indian', 'kawasaki', 'ktm', 'laverda', 'moto guzzi', 'mv agusta',
  'norton', 'royal enfield', 'suzuki', 'triumph', 'vespa', 'victory', 'yamaha', 'zero',
  // Marques historiques et moins connues
  'agusta', 'aermacchi', 'a.j.s.', 'ariel', 'bimota', 'brough', 'bsa',
  'ccm', 'cimatti', 'cossack', 'cz', 'dkw', 'dot', 'douglas', 'dragon',
  'emc', 'enfield', 'excelsior', 'fantic', 'f.b.mondial', 'garelli', 'gilera',
  'guzzi', 'hercules', 'humber', 'italjet', 'jawa', 'keeway', 'lambretta',
  'lml', 'maico', 'matchless', 'minarelli', 'mondial', 'montesa', 'moto morini',
  'osca', 'ossa', 'panther', 'peugeot', 'piaggio', 'puch', 'rieju', 'sachs',
  'scott', 'sherco', 'simson', 'sunbeam', 'swm', 'sym', 'voxan', 'zundapp',
  'beta', 'husaberg', 'tm', 'vertemati', 'cf moto', 'cfmoto', 'lifan', 'loncin',
  'zongshen', 'qjmotor', 'mvagusta', 'moto morini'
].map(b => b.toLowerCase().trim()));

/**
 * Service pour interagir avec l'API CarQuery
 */
class CarQueryService {
  /**
   * Génère un ID déterministe à partir d'une chaîne
   * @param {string} str - Chaîne à hasher
   * @returns {string} Hash MD5 (hex)
   */
  _generateId(str) {
    return crypto.createHash('md5').update(str.toLowerCase().trim()).digest('hex').substring(0, 8);
  }

  /**
   * Effectue une requête HTTP avec retry
   * @param {string} url - URL à appeler
   * @param {object} params - Paramètres de requête
   * @param {number} retries - Nombre de tentatives restantes
   * @returns {Promise<object>} Réponse de l'API
   */
  async _makeRequest(url, params = {}, retries = MAX_RETRIES) {
    try {
      // Forcer le format JSON (pas JSONP) - ne pas passer callback du tout
      const queryParams = {
        ...params
        // Ne pas passer callback pour forcer JSON pur
      };
      
      console.log('[CarQuery] _makeRequest:', { url, params: queryParams });
      
      const response = await axios.get(url, {
        params: queryParams,
        timeout: REQUEST_TIMEOUT,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        responseType: 'json' // Forcer Axios à parser le JSON automatiquement
      });
      
      // Axios devrait parser automatiquement, mais vérifier quand même
      let data = response.data;
      const originalDataType = typeof data;
      
      if (typeof data === 'string') {
        // Nettoyer la réponse si c'est du JSONP
        let jsonString = data.trim();
        if (jsonString.startsWith('callback(') || jsonString.startsWith('jQuery')) {
          // Extraire le JSON du wrapper JSONP
          const jsonMatch = jsonString.match(/\(({.*})\)/);
          if (jsonMatch && jsonMatch[1]) {
            jsonString = jsonMatch[1];
          }
        }
        
        try {
          data = JSON.parse(jsonString);
        } catch (parseError) {
          console.error('[CarQuery] Erreur parsing JSON:', {
            error: parseError.message,
            originalDataType,
            dataPreview: jsonString.substring(0, 200),
            fullData: jsonString
          });
          throw new Error('Réponse CarQuery invalide (JSON non parsable)');
        }
      }
      
      console.log('[CarQuery] _makeRequest response:', {
        status: response.status,
        statusText: response.statusText,
        originalDataType,
        parsedDataType: typeof data,
        hasMakes: !!(data?.Makes),
        hasModels: !!(data?.Models),
        makesType: data?.Makes ? (Array.isArray(data.Makes) ? 'array' : typeof data.Makes) : 'null',
        modelsType: data?.Models ? (Array.isArray(data.Models) ? 'array' : typeof data.Models) : 'null',
        makesCount: Array.isArray(data?.Makes) ? data.Makes.length : (data?.Makes && typeof data.Makes === 'object' ? Object.keys(data.Makes).length : 0),
        modelsCount: Array.isArray(data?.Models) ? data.Models.length : (data?.Models && typeof data.Models === 'object' ? Object.keys(data.Models).length : 0),
        dataKeys: data && typeof data === 'object' ? Object.keys(data).slice(0, 10) : []
      });
      
      return data;
    } catch (error) {
      if (retries > 0 && (error.code === 'ECONNRESET' || error.code === 'ETIMEDOUT' || !error.response)) {
        console.warn('[CarQuery] Retry request:', {
          endpoint: url.split('/').pop(),
          retriesLeft: retries - 1,
          errorCode: error.code
        });
        await new Promise(resolve => setTimeout(resolve, 500));
        return this._makeRequest(url, params, retries - 1);
      }
      
      const errorInfo = {
        endpoint: url.split('/').pop(),
        status: error.response?.status,
        errorCode: error.code
      };
      
      if (process.env.NODE_ENV === 'development') {
        errorInfo.message = error.message;
      }
      
      console.error('[CarQuery] Request failed:', errorInfo);
      throw error;
    }
  }

  /**
   * Normalise un nom (trim, uppercase pour comparaison)
   * @param {string} name - Nom à normaliser
   * @returns {string} Nom normalisé
   */
  _normalizeName(name) {
    if (!name || typeof name !== 'string') return '';
    return name.trim();
  }

  /**
   * Récupère toutes les marques disponibles
   * Note: CarQuery ne gère pas les types "moto/voiture" comme vPIC
   * On retourne toutes les marques pour compatibilité avec l'API existante
   * @param {string} vehicleType - Type de véhicule ('moto' ou 'voiture') - ignoré pour l'instant
   * @returns {Promise<Array>} Liste des marques normalisées [{ makeId, makeName }]
   */
  async getMakesForVehicleType(vehicleType) {
    // CarQuery ne supporte pas le filtrage par type, on ignore le paramètre pour l'instant
    // mais on le garde dans la signature pour compatibilité
    console.log('[CarQuery] getMakesForVehicleType appelé avec type:', vehicleType, '(ignoré)');

    const cacheKey = CatalogCache.generateKey('makes', vehicleType);
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarQuery API: https://www.carqueryapi.com/api/0.3/?cmd=getMakes
          // CarQuery API attend l'URL avec le slash final
          const url = `${CARQUERY_BASE_URL}/`;
          console.log('[CarQuery] URL complète:', url);
          const data = await this._makeRequest(url, {
            cmd: 'getMakes'
          });
          
          console.log('[CarQuery] getMakes - données brutes:', {
            hasData: !!data,
            dataType: typeof data,
            dataKeys: data && typeof data === 'object' ? Object.keys(data) : [],
            makesExists: !!(data?.Makes),
            makesType: data?.Makes ? (Array.isArray(data.Makes) ? 'array' : typeof data.Makes) : 'null',
            sampleData: data ? JSON.stringify(data).substring(0, 500) : 'null'
          });
          
          if (!data || !data.Makes) {
            console.warn('[CarQuery] Pas de résultats pour getMakes', {
              data: data ? JSON.stringify(data).substring(0, 200) : 'null'
            });
            return [];
          }

          const makesMap = new Map();
          
          // CarQuery retourne un objet avec des clés numériques ou un tableau
          // Si c'est un objet, convertir en tableau
          let makesArray = [];
          if (Array.isArray(data.Makes)) {
            makesArray = data.Makes;
          } else if (data.Makes && typeof data.Makes === 'object') {
            makesArray = Object.values(data.Makes);
          }
          
          makesArray.forEach(item => {
            const makeName = this._normalizeName(item.make_name || item.make_display || item.make);
            
            if (makeName) {
              // Générer un ID déterministe à partir du nom
              const makeId = this._generateId(makeName);
              
              // Dédupliquer par makeId
              if (!makesMap.has(makeId)) {
                makesMap.set(makeId, {
                  makeId: makeId,
                  makeName: makeName
                });
              }
            }
          });
          
          console.log('[CarQuery] Total marques collectées avant filtrage:', {
            vehicleType,
            totalMakes: makesMap.size,
            makes: Array.from(makesMap.values()).slice(0, 5).map(m => m.makeName)
          });
          
          // Filtrer par type de véhicule si nécessaire
          let filteredMakes = Array.from(makesMap.values());
          
          if (vehicleType === 'moto') {
            // Pour les motos, ne garder que les marques de motos connues
            filteredMakes = filteredMakes.filter(make => {
              const makeNameLower = make.makeName.toLowerCase().trim();
              return MOTORCYCLE_BRANDS.has(makeNameLower);
            });
            console.log('[CarQuery] Filtrage motos:', {
              avant: makesMap.size,
              apres: filteredMakes.length,
              marquesFiltrees: filteredMakes.slice(0, 10).map(m => m.makeName)
            });
          } else if (vehicleType === 'voiture') {
            // Pour les voitures, exclure les marques de motos
            filteredMakes = filteredMakes.filter(make => {
              const makeNameLower = make.makeName.toLowerCase().trim();
              return !MOTORCYCLE_BRANDS.has(makeNameLower);
            });
            console.log('[CarQuery] Filtrage voitures:', {
              avant: makesMap.size,
              apres: filteredMakes.length
            });
          }
          
          // Trier par nom de marque
          return filteredMakes
            .sort((a, b) => a.makeName.localeCompare(b.makeName));
        } catch (error) {
          console.error('[CarQuery] Erreur getMakesForVehicleType:', {
            vehicleType,
            error: error.message,
            hasResponse: !!error.response,
            status: error.response?.status
          });
          throw error;
        }
      },
      24 * 7 // Cache pendant 7 jours
    );
  }

  /**
   * Récupère les modèles pour une marque, une année et un type de véhicule
   * @param {string} makeNameOrId - Nom de la marque
   * @param {number} year - Année du véhicule
   * @param {string} vehicleType - Type de véhicule ('moto' ou 'voiture') - ignoré pour l'instant
   * @returns {Promise<Array>} Liste des modèles normalisés [{ modelId, modelName, makeId, makeName }]
   */
  async getModelsForMakeYearAndType(makeNameOrId, year, vehicleType) {
    // CarQuery ne supporte pas le filtrage par type, on ignore le paramètre pour l'instant
    console.log('[CarQuery] getModelsForMakeYearAndType appelé:', {
      make: makeNameOrId,
      year,
      type: vehicleType,
      note: '(type ignoré par CarQuery)'
    });

    const cacheKey = CatalogCache.generateKey('models', makeNameOrId, year.toString(), vehicleType);
    
    return await CatalogCache.getOrSet(
      cacheKey,
      async () => {
        try {
          // CarQuery API attend l'URL avec le slash final
          const url = `${CARQUERY_BASE_URL}/`;
          console.log('[CarQuery] URL complète pour models:', url);
          const data = await this._makeRequest(url, {
            cmd: 'getModels',
            make: makeNameOrId,
            year: year
          });
          
          if (!data || !data.Models) {
            console.log('[CarQuery] Aucun modèle trouvé pour:', {
              make: makeNameOrId,
              year
            });
            return [];
          }

          const modelsMap = new Map();
          const makeName = this._normalizeName(makeNameOrId);
          const makeId = this._generateId(makeName);
          
          // CarQuery retourne un objet avec des clés numériques ou un tableau
          // Si c'est un objet, convertir en tableau
          let modelsArray = [];
          if (Array.isArray(data.Models)) {
            modelsArray = data.Models;
          } else if (data.Models && typeof data.Models === 'object') {
            modelsArray = Object.values(data.Models);
          }
          
          modelsArray.forEach(item => {
            const modelName = this._normalizeName(
              item.model_name || 
              item.model_display || 
              item.model ||
              item.model_make_display
            );
            
            if (modelName) {
              // Générer un ID déterministe à partir du nom
              const modelId = this._generateId(`${makeName}_${modelName}`);
              
              // Dédupliquer par modelId
              if (!modelsMap.has(modelId)) {
                modelsMap.set(modelId, {
                  modelId: modelId,
                  modelName: modelName,
                  makeId: makeId,
                  makeName: makeName
                });
              }
            }
          });
          
          console.log('[CarQuery] Total modèles collectés:', {
            make: makeNameOrId,
            year,
            totalModels: modelsMap.size
          });
          
          // Trier par nom de modèle
          return Array.from(modelsMap.values())
            .sort((a, b) => a.modelName.localeCompare(b.modelName));
        } catch (error) {
          // Si c'est une erreur 404 ou similaire, retourner un tableau vide
          if (error.response?.status === 404 || error.response?.status === 400) {
            console.log('[CarQuery] Aucun modèle trouvé (erreur 404/400):', {
              make: makeNameOrId,
              year
            });
            return [];
          }
          
          console.error('[CarQuery] Erreur getModelsForMakeYearAndType:', {
            make: makeNameOrId,
            year,
            error: error.message,
            status: error.response?.status
          });
          throw error;
        }
      },
      24 * 7 // Cache pendant 7 jours
    );
  }
}

module.exports = new CarQueryService();

