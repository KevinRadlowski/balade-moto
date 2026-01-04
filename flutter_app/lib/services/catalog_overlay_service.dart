import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/api_config.dart';
import 'api_service.dart';

/// Structure de cache avec TTL
class _CacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime expiresAt;
  
  _CacheEntry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Service pour récupérer les entrées approuvées depuis le backend
class CatalogOverlayService {
  final ApiService _apiService;

  CatalogOverlayService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // Cache en mémoire par (type, year) avec TTL pour les entrées complètes
  final Map<String, _CacheEntry> _cache = {};
  
  // Cache pour les marques (par type uniquement, toutes années)
  final Map<String, _CacheEntry> _makesCache = {};
  
  // TTL par défaut : 10 minutes
  static const Duration _defaultTtl = Duration(minutes: 10);
  
  // Version du catalogue (pour invalidation)
  String? _catalogVersion;

  String _cacheKey(String type, int year) {
    return '${type}_$year';
  }
  
  String _makesCacheKey(String type) {
    return 'makes_$type';
  }

  /// Vérifie la version du catalogue et invalide le cache si nécessaire
  Future<void> _checkCatalogVersion() async {
    try {
      final endpoint = '/catalog/version';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint');
      
      final response = await _apiService.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newVersion = data['data']?['version'] as String?;
        
        if (newVersion != null) {
          if (_catalogVersion == null) {
            // Première vérification, juste stocker la version
            _catalogVersion = newVersion;
            debugPrint('[CatalogOverlay] Version initiale: $newVersion');
          } else if (newVersion != _catalogVersion) {
            // Version changée, invalider le cache
            debugPrint('[CatalogOverlay] Version changée: $_catalogVersion -> $newVersion, invalidation cache');
            _cache.clear();
            _catalogVersion = newVersion;
          }
        }
      } else {
        debugPrint('[CatalogOverlay] Erreur vérification version: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CatalogOverlay] Erreur vérification version (non bloquant): $e');
    }
  }

  /// Récupère les entrées approuvées pour un type et une année
  Future<List<Map<String, dynamic>>> getApprovedEntries(String type, int year) async {
    final cacheKey = _cacheKey(type, year);

    // Vérifier le cache (avec expiration)
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired) {
        debugPrint('[CatalogOverlay] Cache hit pour $cacheKey');
        return entry.data;
      } else {
        debugPrint('[CatalogOverlay] Cache expiré pour $cacheKey');
        _cache.remove(cacheKey);
      }
    }

    // Vérifier la version du catalogue (best-effort, non bloquant)
    await _checkCatalogVersion();

    try {
      final endpoint = '/catalog/approved';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint').replace(
        queryParameters: {
          'type': type,
          'year': year.toString(),
        },
      );

      debugPrint('[CatalogOverlay] Appel API: $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final makeBlocks = (data['data']?['makeBlocks'] as List<dynamic>?) ?? [];
        
        debugPrint('[CatalogOverlay] HTTP 200 - ${makeBlocks.length} makeBlocks reçus');

        // Convertir en format simple pour le cache
        final entries = <Map<String, dynamic>>[];
        for (final block in makeBlocks) {
          final make = block['make'] as String? ?? '';
          final models = (block['models'] as List<dynamic>?) ?? [];
          for (final model in models) {
            entries.add({
              'make': make,
              'model': model.toString(),
            });
          }
        }

        _cache[cacheKey] = _CacheEntry(entries, _defaultTtl);
        debugPrint('[CatalogOverlay] ${entries.length} entrées approuvées mises en cache pour $cacheKey (TTL: ${_defaultTtl.inMinutes}min)');

        return entries;
      } else {
        debugPrint('[CatalogOverlay] ERREUR HTTP: statusCode=${response.statusCode}, body=${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[CatalogOverlay] ERREUR: $e');
      // En cas d'erreur, retourner liste vide (best-effort)
      return [];
    }
  }

  /// Récupère toutes les marques approuvées pour un type (toutes années confondues)
  Future<List<String>> getApprovedMakes(String type) async {
    final cacheKey = _makesCacheKey(type);

    // Vérifier le cache (avec expiration)
    if (_makesCache.containsKey(cacheKey)) {
      final entry = _makesCache[cacheKey]!;
      if (!entry.isExpired) {
        debugPrint('[CatalogOverlay] Cache hit pour marques $cacheKey');
        return (entry.data as List).map((e) => e['make'] as String).toList();
      } else {
        debugPrint('[CatalogOverlay] Cache expiré pour marques $cacheKey');
        _makesCache.remove(cacheKey);
      }
    }

    // Vérifier la version du catalogue (best-effort, non bloquant)
    await _checkCatalogVersion();

    try {
      final endpoint = '/catalog/approved/makes';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint').replace(
        queryParameters: {
          'type': type,
        },
      );

      debugPrint('[CatalogOverlay] Appel API pour marques: $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final makes = (data['data']?['makes'] as List<dynamic>?) ?? [];
        
        debugPrint('[CatalogOverlay] HTTP 200 - ${makes.length} marques approuvées reçues');

        // Convertir en format simple pour le cache
        final cacheData = makes.map((make) => {'make': make.toString()}).toList();

        _makesCache[cacheKey] = _CacheEntry(cacheData, _defaultTtl);
        debugPrint('[CatalogOverlay] ${makes.length} marques approuvées mises en cache pour $cacheKey (TTL: ${_defaultTtl.inMinutes}min)');

        return makes.map((make) => make.toString()).toList();
      } else {
        debugPrint('[CatalogOverlay] ERREUR HTTP pour marques: statusCode=${response.statusCode}, body=${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[CatalogOverlay] ERREUR récupération marques: $e');
      // En cas d'erreur, retourner liste vide (best-effort)
      return [];
    }
  }

  /// Vide le cache
  void clearCache() {
    _cache.clear();
    _makesCache.clear();
    _catalogVersion = null;
    debugPrint('[CatalogOverlay] Cache vidé');
  }
}

