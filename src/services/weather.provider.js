/**
 * Weather Provider Interface - OpenWeatherMap Implementation
 * 
 * Interface pour les providers météo (permettant de changer facilement de provider)
 */

const axios = require('axios');

class WeatherProvider {
  /**
   * Récupère les prévisions météo pour une position et une date/heure
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @param {Date} dateTime - Date/heure pour laquelle obtenir la prévision
   * @returns {Promise<object>} Prévisions normalisées
   */
  async getForecast(lat, lng, dateTime) {
    throw new Error('getForecast must be implemented by subclass');
  }
}

/**
 * Implémentation OpenWeatherMap
 */
class OpenWeatherProvider extends WeatherProvider {
  constructor(apiKey, apiUrl = 'https://api.openweathermap.org/data/2.5') {
    super();
    this.apiKey = apiKey;
    this.apiUrl = apiUrl;
    
    if (!apiKey) {
      console.warn('[WeatherProvider] WEATHER_API_KEY non configurée. Le service météo ne fonctionnera pas.');
    }
  }

  /**
   * Récupère les prévisions météo depuis OpenWeatherMap
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @param {Date} dateTime - Date/heure cible
   * @returns {Promise<object>} Prévisions normalisées
   */
  async getForecast(lat, lng, dateTime) {
    if (!this.apiKey || this.apiKey === 'your-openweather-api-key') {
      throw new Error('WEATHER_API_KEY non configurée ou invalide');
    }

    try {
      // Appel à l'API Forecast (5 jours, 3h par 3h)
      const response = await axios.get(`${this.apiUrl}/forecast`, {
        params: {
          lat,
          lon: lng,
          appid: this.apiKey,
          units: 'metric', // Celsius, km/h
          lang: 'fr', // Français
        },
        timeout: 10000, // 10 secondes timeout
      });

      if (response.status !== 200 || !response.data || !response.data.list) {
        throw new Error('Réponse invalide de l\'API OpenWeatherMap');
      }

      // Trouver la prévision la plus proche de la date/heure cible
      const targetTimestamp = dateTime.getTime();
      let closestForecast = null;
      let minDiff = Infinity;

      for (const item of response.data.list) {
        const forecastTime = new Date(item.dt * 1000).getTime();
        const diff = Math.abs(forecastTime - targetTimestamp);
        
        if (diff < minDiff) {
          minDiff = diff;
          closestForecast = item;
        }
      }

      if (!closestForecast) {
        throw new Error('Aucune prévision trouvée pour cette date');
      }

      // Normaliser les données
      return this._normalizeForecast(closestForecast);
    } catch (error) {
      if (error.response) {
        // Erreur API
        const status = error.response.status;
        const message = error.response.data?.message || error.message;
        
        if (status === 401) {
          throw new Error('Clé API OpenWeatherMap invalide');
        } else if (status === 429) {
          throw new Error('Quota OpenWeatherMap dépassé. Veuillez réessayer plus tard.');
        } else {
          throw new Error(`Erreur API OpenWeatherMap (${status}): ${message}`);
        }
      } else if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
        throw new Error('Timeout lors de l\'appel à l\'API météo');
      } else {
        throw error;
      }
    }
  }

  /**
   * Normalise les données OpenWeatherMap vers un format standard
   * @param {object} forecastItem - Item de prévision OpenWeatherMap
   * @returns {object} Prévisions normalisées
   */
  _normalizeForecast(forecastItem) {
    const main = forecastItem.main || {};
    const weather = forecastItem.weather?.[0] || {};
    const wind = forecastItem.wind || {};
    const rain = forecastItem.rain || {};
    const clouds = forecastItem.clouds || {};

    // Calculer la probabilité de précipitation
    // OpenWeatherMap ne fournit pas directement la probabilité, on l'estime
    // Si rain.3h > 0, on considère qu'il y a de la pluie
    // On peut aussi utiliser clouds.all comme indicateur
    let precipitationProb = 0;
    if (rain['3h'] && rain['3h'] > 0) {
      precipitationProb = Math.min(100, (rain['3h'] / 5) * 100); // Estimation basée sur mm/3h
    } else if (clouds.all > 80) {
      precipitationProb = 30; // Nuages épais = risque de pluie
    } else if (clouds.all > 50) {
      precipitationProb = 15; // Nuages moyens = faible risque
    }

    // Convertir la vitesse du vent de m/s à km/h
    const windSpeedKmh = wind.speed ? (wind.speed * 3.6) : 0;

    return {
      temperature: main.temp || null,
      feelsLike: main.feels_like || null,
      humidity: main.humidity || null,
      pressure: main.pressure || null,
      windSpeed: windSpeedKmh, // km/h
      windDirection: wind.deg || null,
      precipitationProb, // %
      precipitationAmount: rain['3h'] || 0, // mm
      conditions: weather.main || 'Unknown',
      description: weather.description || '',
      icon: weather.icon || null,
      clouds: clouds.all || 0, // %
      visibility: forecastItem.visibility ? (forecastItem.visibility / 1000) : null, // km
      timestamp: new Date(forecastItem.dt * 1000),
      alerts: [], // OpenWeatherMap Free tier ne fournit pas d'alertes
    };
  }
}

module.exports = {
  WeatherProvider,
  OpenWeatherProvider,
};

