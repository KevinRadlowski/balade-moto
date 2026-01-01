/// Configuration de l'URL de l'API backend
/// 
/// Pour le développement local :
/// - Sur la même machine : utilisez 'http://localhost:5000'
/// - Depuis un autre appareil sur le réseau : utilisez 'http://VOTRE_IP_LOCALE:5000'
///   Exemple : 'http://192.168.56.1:5000' ou 'http://192.168.1.70:5000'
/// 
/// Pour trouver votre IP locale :
/// - Windows : ipconfig (cherchez "Adresse IPv4")
/// - Mac/Linux : ifconfig ou ip addr
class ApiConfig {
  // URL de base de l'API
  // Changez cette valeur selon votre environnement
  static const String apiBaseUrl = 'http://192.168.1.70:5000';
  
  // URL complète pour les endpoints API
  static const String apiUrl = '$apiBaseUrl/api';
  
  // URL pour les fichiers statiques (avatars, images, etc.)
  static String getFileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) {
      // Si l'URL contient localhost, la remplacer par l'IP LAN
      if (path.contains('localhost') || path.contains('127.0.0.1')) {
        return path.replaceAll('localhost', Uri.parse(apiBaseUrl).host)
                   .replaceAll('127.0.0.1', Uri.parse(apiBaseUrl).host);
      }
      return path;
    }
    if (path.startsWith('/uploads')) return '$apiBaseUrl$path';
    return '$apiBaseUrl/uploads$path';
  }
  
  // URL pour Socket.io
  static const String socketUrl = apiBaseUrl;
  
  // Clé API Google Maps
  // ⚠️ IMPORTANT : Cette clé doit être définie via la variable d'environnement GOOGLE_MAPS_API_KEY
  // Pour lancer l'app avec la clé : flutter run --dart-define=GOOGLE_MAPS_API_KEY=votre-cle
  // Ou définissez-la dans votre IDE/CI
  // TODO: Migrer vers un proxy backend pour sécuriser la clé
  static String get googleMapsApiKey {
    const key = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (key.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY non définie. '
        'Lancez avec: flutter run --dart-define=GOOGLE_MAPS_API_KEY=votre-cle'
      );
    }
    return key;
  }
}


