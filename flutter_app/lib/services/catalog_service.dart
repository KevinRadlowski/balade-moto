import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/catalog_make.dart';
import '../models/catalog_model.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class CatalogService {
  final ApiService _apiService;

  CatalogService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // Cache mémoire pour les marques par type+année
  final Map<String, List<CatalogMake>> _makesCache = {};
  
  // Cache mémoire pour les modèles par make+year+type
  final Map<String, List<CatalogModel>> _modelsCache = {};

  /// Génère une clé de cache pour les marques
  String _getMakesCacheKey(String type, int year) {
    return '$type:$year';
  }

  /// Génère une clé de cache pour les modèles
  String _getModelsCacheKey(String type, String make, int year) {
    return '$type:$make:$year';
  }

  /// Extrait les items d'une réponse JSON (gère différents formats)
  List<dynamic> _extractItems(dynamic responseJson) {
    if (responseJson is String) {
      try {
        responseJson = jsonDecode(responseJson);
      } catch (e) {
        debugPrint('[Catalog] Erreur parsing JSON string: $e');
        throw Exception('Parsing failed: réponse non-JSON valide');
      }
    }
    
    if (responseJson is! Map<String, dynamic>) {
      debugPrint('[Catalog] ERREUR: responseJson n\'est pas une Map, type: ${responseJson.runtimeType}');
      throw Exception('Parsing failed: format de réponse invalide (attendu Map, reçu ${responseJson.runtimeType})');
    }
    
    // Format A: { items: [...] }
    if (responseJson.containsKey('items')) {
      final items = responseJson['items'];
      if (items is List) {
        return items;
      }
    }
    
    // Format B: { success: true, data: { items: [...] } }
    if (responseJson.containsKey('data') && responseJson['data'] is Map) {
      final data = responseJson['data'] as Map<String, dynamic>;
      if (data.containsKey('items') && data['items'] is List) {
        return data['items'] as List;
      }
    }
    
    debugPrint('[Catalog] ERREUR: Aucun champ items trouvé dans la réponse');
    debugPrint('[Catalog] Keys disponibles: ${responseJson.keys.toList()}');
    throw Exception('Parsing failed: aucun champ items trouvé dans la réponse');
  }

  /// Récupère les marques pour un type de véhicule et une année
  /// Utilise le cache mémoire si disponible
  Future<List<CatalogMake>> fetchMakes(String type, int year) async {
    debugPrint('[Catalog] fetchMakes appelé avec type: $type, year: $year (CarAPI)');
    
    final cacheKey = _getMakesCacheKey(type, year);
    
    // Vérifier le cache
    if (_makesCache.containsKey(cacheKey)) {
      debugPrint('[Catalog] Cache hit pour makes:$cacheKey (${_makesCache[cacheKey]!.length} marques)');
      return _makesCache[cacheKey]!;
    }

    try {
      // Utiliser les nouveaux endpoints CarAPI
      final endpoint = type == 'voiture' ? '/catalog/voiture/makes' : '/catalog/moto/makes';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint')
          .replace(queryParameters: {'year': year.toString()});

      debugPrint('[Catalog] Appel API: $uri');

      final response = await _apiService.get(uri);

      debugPrint('[Catalog] Réponse reçue: statusCode=${response.statusCode}, bodyType=${response.body.runtimeType}, bodyLength=${response.body.length}');
      
      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
          
          debugPrint('[Catalog] Données parsées: type=${data.runtimeType}, keys=${data is Map ? data.keys.toList() : 'N/A'}');
          
          final itemsList = _extractItems(data);
          debugPrint('[Catalog] Items extraits: ${itemsList.length} items');
          
          final makes = itemsList
              .map((json) {
                try {
                  return CatalogMake.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('[Catalog] Erreur parsing item: $e, json: $json');
                  return null;
                }
              })
              .whereType<CatalogMake>()
              .toList();

          debugPrint('[Catalog] ${makes.length} marques parsées pour type:$type, year:$year');
          if (makes.isNotEmpty) {
            debugPrint('[Catalog] Premières marques: ${makes.take(5).map((m) => m.name).join(", ")}');
          }

          // Mettre en cache
          _makesCache[cacheKey] = makes;
          debugPrint('[Catalog] ${makes.length} marques mises en cache pour $cacheKey');

          return makes;
        } catch (e, stackTrace) {
          debugPrint('[Catalog] ERREUR parsing JSON: $e');
          debugPrint('[Catalog] Stack trace: $stackTrace');
          throw Exception('Parsing makes failed: $e');
        }
      } else {
        debugPrint('[Catalog] ERREUR HTTP: statusCode=${response.statusCode}, body=${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des marques (${response.statusCode})');
        } catch (e) {
          throw Exception('Erreur lors de la récupération des marques (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Catalog] ERREUR fetchMakes: $e');
      debugPrint('[Catalog] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupère les modèles pour une marque, année et type
  /// Utilise le cache mémoire si disponible
  Future<List<CatalogModel>> fetchModels(String type, String makeId, int year) async {
    final cacheKey = _getModelsCacheKey(type, makeId, year);

    // Vérifier le cache
    if (_modelsCache.containsKey(cacheKey)) {
      debugPrint('[Catalog] Cache hit pour models:$cacheKey');
      return _modelsCache[cacheKey]!;
    }

    try {
      // Utiliser les nouveaux endpoints CarAPI
      final endpoint = type == 'voiture' ? '/catalog/voiture/models' : '/catalog/moto/models';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint').replace(
        queryParameters: {
          'makeId': makeId, // Utiliser makeId au lieu de make
          'year': year.toString(),
        },
      );

      debugPrint('[Catalog] Appel API fetchModels: $uri');

      final response = await _apiService.get(uri);

      debugPrint('[Catalog] Réponse fetchModels: statusCode=${response.statusCode}, bodyType=${response.body.runtimeType}, bodyLength=${response.body.length}');

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
          
          debugPrint('[Catalog] Données fetchModels parsées: type=${data.runtimeType}, keys=${data is Map ? data.keys.toList() : 'N/A'}');
          
          final itemsList = _extractItems(data);
          debugPrint('[Catalog] Items fetchModels extraits: ${itemsList.length} items');
          
          final models = itemsList
              .map((json) {
                try {
                  return CatalogModel.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('[Catalog] Erreur parsing model item: $e, json: $json');
                  return null;
                }
              })
              .whereType<CatalogModel>()
              .toList();

          // Mettre en cache
          _modelsCache[cacheKey] = models;
          debugPrint('[Catalog] ${models.length} modèles mis en cache pour $cacheKey');

          return models;
        } catch (e, stackTrace) {
          debugPrint('[Catalog] ERREUR parsing JSON fetchModels: $e');
          debugPrint('[Catalog] Stack trace: $stackTrace');
          throw Exception('Parsing models failed: $e');
        }
      } else {
        debugPrint('[Catalog] ERREUR HTTP fetchModels: statusCode=${response.statusCode}, body=${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des modèles (${response.statusCode})');
        } catch (e) {
          throw Exception('Erreur lors de la récupération des modèles (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Catalog] ERREUR fetchModels: $e');
      debugPrint('[Catalog] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Vide le cache mémoire
  void clearCache() {
    _makesCache.clear();
    _modelsCache.clear();
    debugPrint('[Catalog] Cache vidé');
  }
}
