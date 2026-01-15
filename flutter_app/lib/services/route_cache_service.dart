import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service de cache pour les directions de routes
/// Évite les appels API répétés pour les mêmes routes
class RouteCacheService {
  static final RouteCacheService _instance = RouteCacheService._internal();
  factory RouteCacheService() => _instance;
  RouteCacheService._internal();

  // Cache en mémoire (Map<clé, données>)
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Génère une clé de cache unique basée sur les paramètres de la route
  String _generateCacheKey({
    required String origin,
    required String destination,
    String? waypoints,
    bool? avoidTolls,
    bool? avoidHighways,
  }) {
    final waypointsStr = waypoints ?? '';
    final avoidTollsStr = avoidTolls == true ? 'tolls' : '';
    final avoidHighwaysStr = avoidHighways == true ? 'highways' : '';
    
    final keyString = '$origin|$destination|$waypointsStr|$avoidTollsStr|$avoidHighwaysStr';
    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Récupère les directions depuis le cache
  Map<String, dynamic>? get({
    required String origin,
    required String destination,
    String? waypoints,
    bool? avoidTolls,
    bool? avoidHighways,
  }) {
    final key = _generateCacheKey(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
    );
    
    return _cache[key];
  }

  /// Stocke les directions dans le cache
  void set({
    required String origin,
    required String destination,
    String? waypoints,
    bool? avoidTolls,
    bool? avoidHighways,
    required Map<String, dynamic> data,
  }) {
    final key = _generateCacheKey(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
    );
    
    _cache[key] = data;
    
    // Limiter la taille du cache à 100 entrées pour éviter une consommation mémoire excessive
    if (_cache.length > 100) {
      // Supprimer les 20 entrées les plus anciennes (FIFO)
      final keysToRemove = _cache.keys.take(20).toList();
      for (final keyToRemove in keysToRemove) {
        _cache.remove(keyToRemove);
      }
    }
  }

  /// Vide le cache
  void clear() {
    _cache.clear();
  }

  /// Retourne la taille actuelle du cache
  int get size => _cache.length;
}






