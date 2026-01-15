/// Modèle pour les données météo
class WeatherForecast {
  final double? temperature;
  final double? feelsLike;
  final int? humidity;
  final int? pressure;
  final double windSpeed; // km/h
  final int? windDirection;
  final double precipitationProb; // %
  final double precipitationAmount; // mm
  final String conditions;
  final String description;
  final String? icon;
  final int clouds; // %
  final double? visibility; // km
  final DateTime timestamp;
  final List<WeatherAlert> alerts;

  WeatherForecast({
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.pressure,
    required this.windSpeed,
    this.windDirection,
    required this.precipitationProb,
    required this.precipitationAmount,
    required this.conditions,
    required this.description,
    this.icon,
    required this.clouds,
    this.visibility,
    required this.timestamp,
    this.alerts = const [],
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      temperature: json['temperature']?.toDouble(),
      feelsLike: json['feelsLike']?.toDouble(),
      humidity: json['humidity']?.toInt(),
      pressure: json['pressure']?.toInt(),
      windSpeed: (json['windSpeed'] ?? 0).toDouble(),
      windDirection: json['windDirection']?.toInt(),
      precipitationProb: (json['precipitationProb'] ?? 0).toDouble(),
      precipitationAmount: (json['precipitationAmount'] ?? 0).toDouble(),
      conditions: json['conditions'] ?? 'Unknown',
      description: json['description'] ?? '',
      icon: json['icon'],
      clouds: json['clouds'] ?? 0,
      visibility: json['visibility']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      alerts: json['alerts'] != null
          ? (json['alerts'] as List)
              .map((a) => WeatherAlert.fromJson(a))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'pressure': pressure,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'precipitationProb': precipitationProb,
      'precipitationAmount': precipitationAmount,
      'conditions': conditions,
      'description': description,
      'icon': icon,
      'clouds': clouds,
      'visibility': visibility,
      'timestamp': timestamp.toIso8601String(),
      'alerts': alerts.map((a) => a.toJson()).toList(),
    };
  }

  /// Retourne l'icône météo basée sur les conditions
  String getWeatherIcon() {
    if (icon != null) {
      return icon!;
    }
    // Fallback basé sur les conditions
    switch (conditions.toLowerCase()) {
      case 'clear':
        return '01d';
      case 'clouds':
        return '02d';
      case 'rain':
        return '09d';
      case 'drizzle':
        return '09d';
      case 'thunderstorm':
        return '11d';
      case 'snow':
        return '13d';
      case 'mist':
      case 'fog':
        return '50d';
      default:
        return '01d';
    }
  }

  /// Retourne un emoji pour les conditions météo
  String getWeatherEmoji() {
    switch (conditions.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}

/// Modèle pour les alertes météo
class WeatherAlert {
  final String type; // 'departure' ou 'arrival'
  final String severity; // 'warning', 'danger', etc.
  final String message;

  WeatherAlert({
    required this.type,
    required this.severity,
    required this.message,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      type: json['type'] ?? 'unknown',
      severity: json['severity'] ?? 'warning',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'message': message,
    };
  }
}

/// Modèle pour la réponse complète de météo d'une balade
class RideWeather {
  final WeatherForecast departure;
  final WeatherForecast arrival;
  final List<WeatherAlert> alerts;

  RideWeather({
    required this.departure,
    required this.arrival,
    this.alerts = const [],
  });

  factory RideWeather.fromJson(Map<String, dynamic> json) {
    return RideWeather(
      departure: WeatherForecast.fromJson(json['departure'] ?? {}),
      arrival: WeatherForecast.fromJson(json['arrival'] ?? {}),
      alerts: json['alerts'] != null
          ? (json['alerts'] as List)
              .map((a) => WeatherAlert.fromJson(a))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'departure': departure.toJson(),
      'arrival': arrival.toJson(),
      'alerts': alerts.map((a) => a.toJson()).toList(),
    };
  }
}

