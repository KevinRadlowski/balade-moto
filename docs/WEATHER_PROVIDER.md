# Weather Provider - Configuration & Stratégie

**Date** : 2025-01-27  
**Provider choisi** : OpenWeatherMap API

---

## 🌤️ FOURNISSEUR MÉTÉO

### OpenWeatherMap API

**Raison du choix** :
- ✅ API gratuite généreuse (1000 appels/jour gratuit)
- ✅ Documentation complète
- ✅ Prévisions jusqu'à 5 jours
- ✅ Alertes météo intégrées
- ✅ Support international (France inclus)
- ✅ Pas de limite géographique stricte

**Alternative considérée** : Météo France API
- ❌ Plus complexe à intégrer
- ❌ Limites plus strictes
- ✅ Plus précis pour la France

**Décision** : OpenWeatherMap pour la simplicité et la scalabilité.

---

## 🔌 ENDPOINTS UTILISÉS

### 1. Current Weather + Forecast

**Endpoint** : `https://api.openweathermap.org/data/2.5/forecast`

**Paramètres** :
- `lat` : Latitude
- `lon` : Longitude
- `appid` : API Key
- `units` : `metric` (Celsius, km/h)
- `lang` : `fr` (français)

**Réponse** :
```json
{
  "list": [
    {
      "dt": 1706284800,
      "main": {
        "temp": 15.5,
        "feels_like": 14.2,
        "pressure": 1013,
        "humidity": 65
      },
      "weather": [{
        "id": 800,
        "main": "Clear",
        "description": "ciel dégagé",
        "icon": "01d"
      }],
      "wind": {
        "speed": 5.2, // m/s → convertir en km/h
        "deg": 270
      },
      "rain": {
        "3h": 0.5 // mm de pluie (3h)
      },
      "dt_txt": "2025-01-27 12:00:00"
    }
  ]
}
```

**Utilisation** :
- Trouver le forecast le plus proche de la date/heure de la balade
- Extraire : temp, wind, precipitation, conditions

---

### 2. Weather Alerts (si disponible)

**Endpoint** : `https://api.openweathermap.org/data/2.5/onecall` (payant)  
**OU** : Analyser les conditions pour générer des alertes custom

**Stratégie** : Générer des alertes custom basées sur :
- `precipitationProb >= 60%` → Alerte PLUIE
- `windSpeed >= 45 km/h` → Alerte VENT
- `temperature < 0°C` → Alerte GEL (optionnel)

---

## 📊 LIMITES & QUOTAS

### Plan Gratuit (Free Tier)
- **1000 appels/jour**
- **60 appels/minute**
- **Pas de limite mensuelle**

### Calcul d'utilisation

**Scénario** :
- 100 balades/jour avec météo
- 1 appel par balade (départ + arrivée dans même forecast)
- **Total** : ~100 appels/jour ✅ (sous la limite)

**Avec cache** :
- Cache TTL : 30 minutes
- Si même zone (rayon 10km) → réutilisation
- **Réduction** : ~50% d'appels économisés

### Plan Payant (si nécessaire)
- **One Call API 3.0** : $40/mois
- 1000 appels/jour inclus
- Alertes météo intégrées
- **Décision** : Commencer avec Free Tier, upgrade si nécessaire

---

## 💾 CACHE & STRATÉGIE ANTI-SPAM

### Stratégie de Cache

**Clé de cache** :
```
forecast:{lat}:{lng}:{dateHour}
```

**Exemple** :
```
forecast:48.8566:2.3522:2025-01-27T10:00:00Z
```

**TTL** :
- **30 minutes** (configurable via `WEATHER_CACHE_TTL`)
- Raison : Météo change peu en 30 min, économise les appels API

**Storage** :
- **Redis** (si disponible) : `SETEX forecast:... 1800 {json}`
- **Fallback mémoire** : Map en mémoire (perdu au restart)

### Implémentation

```javascript
// src/services/weather.service.js
const cacheKey = `forecast:${lat}:${lng}:${dateHour}`;

// 1. Vérifier cache
const cached = await redis.get(cacheKey);
if (cached) {
  return JSON.parse(cached);
}

// 2. Appel API
const forecast = await fetchOpenWeather(lat, lng, dateTime);

// 3. Mettre en cache
await redis.setex(cacheKey, 1800, JSON.stringify(forecast));

return forecast;
```

---

## 🚨 ALERTES MÉTÉO

### Règles de Détection

**Fonction** : `isBadWeather(forecast)`

```javascript
function isBadWeather(forecast) {
  const rainThreshold = parseFloat(process.env.WEATHER_RAIN_THRESHOLD) || 60; // %
  const windThreshold = parseFloat(process.env.WEATHER_WIND_THRESHOLD) || 45; // km/h
  
  return (
    forecast.precipitationProb >= rainThreshold ||
    forecast.windSpeed >= windThreshold ||
    forecast.hasSevereAlert // Si provider supporte
  );
}
```

### Types d'Alertes

1. **RAIN** : Pluie forte prévue (`precipitationProb >= 60%`)
2. **WIND** : Vent fort prévu (`windSpeed >= 45 km/h`)
3. **FROST** : Gel prévu (`temperature < 0°C`) - Optionnel
4. **SEVERE** : Alerte sévère du provider (si disponible)

---

## ⏰ SCHEDULER - ALERTES 24H AVANT

### Job Cron

**Fréquence** : Toutes les heures

**Logique** :
```javascript
// 1. Trouver rides dans 24h ± 1h
const now = new Date();
const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
const in25h = new Date(now.getTime() + 25 * 60 * 60 * 1000);

const rides = await Ride.find({
  status: 'scheduled',
  date: { $gte: in24h, $lte: in25h }
});

// 2. Pour chaque ride
for (const ride of rides) {
  const forecast = await getWeatherForecast(ride);
  
  if (isBadWeather(forecast)) {
    // 3. Notifier organisateur (toujours)
    await notifyOrganizer(ride, forecast);
    
    // 4. Notifier participants PREMIUM (si opt-in)
    const premiumParticipants = await getPremiumParticipants(ride);
    for (const participant of premiumParticipants) {
      if (participant.preferences.weatherAlertsEnabled) {
        await notifyParticipant(participant, ride, forecast);
      }
    }
  }
}
```

### Prévention Doublons

**Modèle** : `NotificationSent` (existant)
- Ajouter champ `type: 'weather_alert'`
- Index : `{ rideId: 1, userId: 1, type: 1 }`
- Vérifier avant envoi

---

## 🔧 CONFIGURATION

### Variables d'Environnement

```env
# OpenWeatherMap API
WEATHER_API_KEY=your-openweather-api-key
WEATHER_API_URL=https://api.openweathermap.org/data/2.5

# Cache
WEATHER_CACHE_TTL=1800 # 30 minutes (secondes)
WEATHER_CACHE_ENABLED=true

# Alertes
WEATHER_RAIN_THRESHOLD=60 # % probabilité pluie
WEATHER_WIND_THRESHOLD=45 # km/h
WEATHER_FROST_THRESHOLD=0 # °C (optionnel)

# Scheduler
WEATHER_ALERT_ENABLED=true
WEATHER_ALERT_HOURS_BEFORE=24
```

### .env.example

Ajouter dans `ENV_VARIABLES.md` :
```markdown
# Weather Service (OpenWeatherMap)
WEATHER_API_KEY=your-openweather-api-key
WEATHER_CACHE_TTL=1800
WEATHER_RAIN_THRESHOLD=60
WEATHER_WIND_THRESHOLD=45
```

---

## 📝 IMPLÉMENTATION

### Structure des Fichiers

```
src/
├── services/
│   ├── weather.service.js      # Service principal
│   └── weather.provider.js     # Interface provider (OpenWeather)
├── models/
│   └── (pas de nouveau modèle, utilise NotificationSent)
└── scripts/
    └── weather-alert.job.js    # Cron job alertes
```

### WeatherService Interface

```javascript
class WeatherService {
  async getForecast(lat, lng, dateTime) {
    // 1. Vérifier cache
    // 2. Appel API si nécessaire
    // 3. Mettre en cache
    // 4. Retourner format normalisé
  }
  
  async getRideWeather(rideId) {
    // Récupère météo départ + arrivée
  }
  
  isBadWeather(forecast) {
    // Détecte conditions défavorables
  }
}
```

---

## 🧪 TESTS

### Unitaires
- [ ] `getForecast()` : Cache hit/miss
- [ ] `isBadWeather()` : Détection correcte
- [ ] `getRideWeather()` : Départ + arrivée

### Intégration
- [ ] Endpoint `/api/rides/:id/weather` : Réponse correcte
- [ ] Scheduler : Sélection rides, premium filter, notifications

### Mock
- [ ] Mock OpenWeather API (pour tests sans clé)

---

## 🔄 FALLBACK & ERREURS

### Si API indisponible
- Retourner `null` ou erreur gracieuse
- Logger l'erreur
- Ne pas bloquer l'application

### Si quota dépassé
- Logger l'erreur
- Retourner message : "Service météo temporairement indisponible"
- Considérer upgrade plan

### Si cache Redis indisponible
- Fallback mémoire (Map)
- Warning log
- Continuer fonctionnement

---

## 📚 RESSOURCES

- [OpenWeatherMap API Docs](https://openweathermap.org/api)
- [Forecast API](https://openweathermap.org/forecast5)
- [One Call API 3.0](https://openweathermap.org/api/one-call-3) (payant)

---

**Dernière mise à jour** : 2025-01-27

