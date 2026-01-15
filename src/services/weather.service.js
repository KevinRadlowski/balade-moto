/**
 * Weather Service - Service principal pour la gestion de la météo
 * 
 * Gère le cache, les appels au provider, et la logique météo
 */

const { OpenWeatherProvider } = require('./weather.provider');
const redis = require('../config/redis');
const { BadRequestError } = require('../utils/errors');

// Cache mémoire (fallback si Redis indisponible)
const memoryCache = new Map();
const CACHE_TTL_MS = (parseInt(process.env.WEATHER_CACHE_TTL) || 1800) * 1000; // 30 min par défaut

class WeatherService {
  constructor() {
    const apiKey = process.env.WEATHER_API_KEY;
    const apiUrl = process.env.WEATHER_API_URL || 'https://api.openweathermap.org/data/2.5';
    
    this.provider = new OpenWeatherProvider(apiKey, apiUrl);
    this.cacheEnabled = process.env.WEATHER_CACHE_ENABLED !== 'false';
    this.isConfigured = !!(apiKey && apiKey !== 'your-openweather-api-key' && apiKey.trim() !== '');
    
    // Seuils pour les alertes (configurables via env)
    this.rainThreshold = parseFloat(process.env.WEATHER_RAIN_THRESHOLD) || 60; // %
    this.windThreshold = parseFloat(process.env.WEATHER_WIND_THRESHOLD) || 45; // km/h
    this.frostThreshold = parseFloat(process.env.WEATHER_FROST_THRESHOLD) || 0; // °C
    
    if (!this.isConfigured) {
      console.warn('⚠️  [WeatherService] WEATHER_API_KEY non configurée. Le service météo ne fonctionnera pas.');
      console.warn('   Pour activer la météo, ajoutez WEATHER_API_KEY dans votre fichier .env');
      console.warn('   Obtenez une clé gratuite sur https://openweathermap.org/api');
    }
  }

  /**
   * Génère une clé de cache pour une position et une date/heure
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @param {Date} dateTime - Date/heure
   * @returns {string} Clé de cache
   */
  _getCacheKey(lat, lng, dateTime) {
    // Arrondir la date/heure à l'heure la plus proche pour le cache
    const roundedDate = new Date(dateTime);
    roundedDate.setMinutes(0, 0, 0);
    const dateHour = roundedDate.toISOString().split('T')[0] + 'T' + roundedDate.getHours().toString().padStart(2, '0') + ':00:00Z';
    
    // Arrondir les coordonnées à 2 décimales (environ 1km de précision)
    const roundedLat = Math.round(lat * 100) / 100;
    const roundedLng = Math.round(lng * 100) / 100;
    
    return `forecast:${roundedLat}:${roundedLng}:${dateHour}`;
  }

  /**
   * Récupère les prévisions depuis le cache
   * @param {string} cacheKey - Clé de cache
   * @returns {Promise<object|null>} Prévisions en cache ou null
   */
  async _getFromCache(cacheKey) {
    if (!this.cacheEnabled) {
      return null;
    }

    try {
      // Essayer Redis d'abord
      if (redis.client && redis.client.isReady) {
        const cached = await redis.client.get(cacheKey);
        if (cached) {
          return JSON.parse(cached);
        }
      }
    } catch (error) {
      console.warn('[WeatherService] Erreur cache Redis, fallback mémoire:', error.message);
    }

    // Fallback mémoire
    const cached = memoryCache.get(cacheKey);
    if (cached) {
      const { data, expiresAt } = cached;
      if (expiresAt > Date.now()) {
        return data;
      } else {
        memoryCache.delete(cacheKey);
      }
    }

    return null;
  }

  /**
   * Met en cache les prévisions
   * @param {string} cacheKey - Clé de cache
   * @param {object} forecast - Prévisions à mettre en cache
   */
  async _setCache(cacheKey, forecast) {
    if (!this.cacheEnabled) {
      return;
    }

    const ttlSeconds = Math.floor(CACHE_TTL_MS / 1000);
    const data = JSON.stringify(forecast);

    try {
      // Essayer Redis d'abord
      if (redis.client && redis.client.isReady) {
        await redis.client.setEx(cacheKey, ttlSeconds, data);
        return;
      }
    } catch (error) {
      console.warn('[WeatherService] Erreur cache Redis, fallback mémoire:', error.message);
    }

    // Fallback mémoire
    memoryCache.set(cacheKey, {
      data: forecast,
      expiresAt: Date.now() + CACHE_TTL_MS,
    });

    // Nettoyer le cache mémoire périodiquement (garder max 1000 entrées)
    if (memoryCache.size > 1000) {
      const entries = Array.from(memoryCache.entries());
      entries.sort((a, b) => a[1].expiresAt - b[1].expiresAt);
      const toDelete = entries.slice(0, entries.length - 1000);
      toDelete.forEach(([key]) => memoryCache.delete(key));
    }
  }

  /**
   * Récupère les prévisions météo pour une position et une date/heure
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @param {Date} dateTime - Date/heure cible
   * @returns {Promise<object>} Prévisions normalisées
   */
  async getForecast(lat, lng, dateTime) {
    if (!lat || !lng || !dateTime) {
      throw new BadRequestError('Latitude, longitude et date/heure sont requis');
    }

    // Si le service n'est pas configuré, retourner null immédiatement
    if (!this.isConfigured) {
      return null;
    }

    // Vérifier le cache
    const cacheKey = this._getCacheKey(lat, lng, dateTime);
    const cached = await this._getFromCache(cacheKey);
    if (cached) {
      return cached;
    }

    // Appel au provider
    try {
      const forecast = await this.provider.getForecast(lat, lng, dateTime);
      
      // Mettre en cache
      await this._setCache(cacheKey, forecast);
      
      return forecast;
    } catch (error) {
      // Si la clé API n'est pas configurée, retourner null au lieu de throw
      if (error.message && error.message.includes('WEATHER_API_KEY')) {
        console.warn('[WeatherService] Clé API météo non configurée. Retour null.');
        return null;
      }
      console.error('[WeatherService] Erreur lors de la récupération des prévisions:', error);
      throw error;
    }
  }

  /**
   * Récupère la météo pour une balade (départ et arrivée)
   * @param {object} ride - Objet Ride
   * @returns {Promise<object>} Météo départ et arrivée
   */
  async getRideWeather(ride) {
    if (!ride) {
      throw new BadRequestError('Balade requise');
    }

    // Déterminer les coordonnées de départ et d'arrivée
    let departureLat, departureLng, arrivalLat, arrivalLng;

    if (ride.waypoints && ride.waypoints.length > 0) {
      // Utiliser les waypoints si disponibles
      const sortedWaypoints = [...ride.waypoints].sort((a, b) => a.order - b.order);
      const departure = sortedWaypoints[0];
      const arrival = sortedWaypoints[sortedWaypoints.length - 1];

      if (departure.coordinates && departure.coordinates.coordinates) {
        departureLng = departure.coordinates.coordinates[0];
        departureLat = departure.coordinates.coordinates[1];
      }

      if (arrival.coordinates && arrival.coordinates.coordinates) {
        arrivalLng = arrival.coordinates.coordinates[0];
        arrivalLat = arrival.coordinates.coordinates[1];
      }
    }

    // Fallback sur lieuDepart/lieuArrivee si waypoints non disponibles
    if (!departureLat || !departureLng) {
      if (ride.lieuDepart && typeof ride.lieuDepart === 'object') {
        if (ride.lieuDepart.coordinates) {
          departureLng = ride.lieuDepart.coordinates[0];
          departureLat = ride.lieuDepart.coordinates[1];
        } else if (ride.lieuDepart.latitude && ride.lieuDepart.longitude) {
          departureLat = ride.lieuDepart.latitude;
          departureLng = ride.lieuDepart.longitude;
        }
      }
    }

    if (!arrivalLat || !arrivalLng) {
      if (ride.lieuArrivee && typeof ride.lieuArrivee === 'object') {
        if (ride.lieuArrivee.coordinates) {
          arrivalLng = ride.lieuArrivee.coordinates[0];
          arrivalLat = ride.lieuArrivee.coordinates[1];
        } else if (ride.lieuArrivee.latitude && ride.lieuArrivee.longitude) {
          arrivalLat = ride.lieuArrivee.latitude;
          arrivalLng = ride.lieuArrivee.longitude;
        }
      }
    }

    if (!departureLat || !departureLng) {
      throw new BadRequestError('Impossible de déterminer les coordonnées de départ');
    }

    if (!arrivalLat || !arrivalLng) {
      throw new BadRequestError('Impossible de déterminer les coordonnées d\'arrivée');
    }

    // Construire la date/heure de départ
    const departureDateTime = new Date(ride.date);
    const [hours, minutes] = ride.heure.split(':').map(Number);
    departureDateTime.setHours(hours, minutes, 0, 0);

    // Estimer l'heure d'arrivée (départ + durée estimée si disponible, sinon +2h par défaut)
    const arrivalDateTime = new Date(departureDateTime);
    if (ride.estimatedDuration) {
      // Si estimatedDuration est en minutes
      const durationMinutes = typeof ride.estimatedDuration === 'number' 
        ? ride.estimatedDuration 
        : parseInt(ride.estimatedDuration) || 120; // 2h par défaut
      arrivalDateTime.setMinutes(arrivalDateTime.getMinutes() + durationMinutes);
    } else {
      arrivalDateTime.setHours(arrivalDateTime.getHours() + 2); // 2h par défaut
    }

    // Récupérer les prévisions
    const [departureForecast, arrivalForecast] = await Promise.all([
      this.getForecast(departureLat, departureLng, departureDateTime),
      this.getForecast(arrivalLat, arrivalLng, arrivalDateTime),
    ]);

    // Si les prévisions sont null (clé API non configurée), retourner null
    if (!departureForecast || !arrivalForecast) {
      return null;
    }

    // Générer les alertes
    const alerts = [];
    if (this.isBadWeather(departureForecast)) {
      alerts.push({
        type: 'departure',
        severity: 'warning',
        message: this._generateAlertMessage(departureForecast),
      });
    }
    if (this.isBadWeather(arrivalForecast)) {
      alerts.push({
        type: 'arrival',
        severity: 'warning',
        message: this._generateAlertMessage(arrivalForecast),
      });
    }

    return {
      departure: departureForecast,
      arrival: arrivalForecast,
      alerts,
    };
  }

  /**
   * Détermine si les conditions météo sont défavorables
   * @param {object} forecast - Prévisions normalisées
   * @returns {boolean} true si conditions défavorables
   */
  isBadWeather(forecast) {
    if (!forecast) {
      return false;
    }

    return (
      (forecast.precipitationProb >= this.rainThreshold) ||
      (forecast.windSpeed >= this.windThreshold) ||
      (forecast.temperature !== null && forecast.temperature < this.frostThreshold)
    );
  }

  /**
   * Génère un message d'alerte basé sur les prévisions
   * @param {object} forecast - Prévisions normalisées
   * @returns {string} Message d'alerte
   */
  _generateAlertMessage(forecast) {
    const messages = [];

    if (forecast.precipitationProb >= this.rainThreshold) {
      messages.push(`Pluie prévue (${forecast.precipitationProb.toFixed(0)}%)`);
    }

    if (forecast.windSpeed >= this.windThreshold) {
      messages.push(`Vent fort prévu (${forecast.windSpeed.toFixed(0)} km/h)`);
    }

    if (forecast.temperature !== null && forecast.temperature < this.frostThreshold) {
      messages.push(`Température très basse (${forecast.temperature.toFixed(0)}°C)`);
    }

    return messages.join(', ') || 'Conditions météo défavorables';
  }
}

// Singleton
const weatherService = new WeatherService();

module.exports = weatherService;

