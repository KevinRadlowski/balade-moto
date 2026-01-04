import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import 'catalog_provider.dart';

/// Structure de cache pour une année
class YearCatalog {
  final int year;
  final List<String> makes;
  final Map<String, List<String>> modelsByMake; // makeUpper -> models
  final Map<String, String> makeIdToMakeName; // makeId -> makeUpper

  YearCatalog({
    required this.year,
    required this.makes,
    required this.modelsByMake,
    required this.makeIdToMakeName,
  });
}

/// Provider de catalogue utilisant les fichiers JSON locaux français
class LocalFrCatalogProvider implements CatalogProvider {
  // Cache par année
  final Map<int, YearCatalog> _yearCache = {};

  /// Génère un slug stable pour un ID
  String _slug(String text) {
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Génère un ID stable pour une marque
  String _generateMakeId(String makeUpper) {
    return 'LOCALFR_MAKE_${_slug(makeUpper)}';
  }

  /// Génère un ID stable pour un modèle
  String _generateModelId(String makeUpper, String modelName, int year) {
    return 'LOCALFR_MODEL_${_slug(makeUpper)}__${_slug(modelName)}__$year';
  }

  /// Charge et parse un fichier JSON depuis les assets
  Future<Map<String, dynamic>> _loadAssetJson(String path) async {
    try {
      debugPrint('[LocalFrCatalog] Chargement asset: $path');
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> json = jsonDecode(jsonString);
      debugPrint('[LocalFrCatalog] Asset chargé: $path (${jsonString.length} bytes)');
      return json;
    } catch (e) {
      debugPrint('[LocalFrCatalog] ERREUR chargement asset $path: $e');
      rethrow;
    }
  }

  /// Charge le catalogue pour une année (avec cache)
  Future<YearCatalog> _loadYearCatalog(int year) async {
    if (_yearCache.containsKey(year)) {
      debugPrint('[LocalFrCatalog] Cache hit pour année $year');
      return _yearCache[year]!;
    }

    debugPrint('[LocalFrCatalog] Chargement catalogue année $year...');

    try {
      // Charger _models.json
      final modelsPath = 'assets/reference/vehicles/cars/fr/${year}_models.json';
      final modelsJson = await _loadAssetJson(modelsPath);
      
      final makesList = (modelsJson['makes'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          [];
      
      debugPrint('[LocalFrCatalog] Parsed ${year}_models.json: ${makesList.length} marques');

      // Charger _makes.json
      final makesPath = 'assets/reference/vehicles/cars/fr/${year}_makes.json';
      final makesJson = await _loadAssetJson(makesPath);
      
      final makeBlocks = (makesJson['makeBlocks'] as List<dynamic>?) ?? [];
      debugPrint('[LocalFrCatalog] Parsed ${year}_makes.json: ${makeBlocks.length} makeBlocks');

      // Construire la map modelsByMake et makeIdToMakeName
      final modelsByMake = <String, List<String>>{};
      final makeIdToMakeName = <String, String>{};

      for (final block in makeBlocks) {
        final makeUpper = (block['make'] as String?)?.toUpperCase() ?? '';
        final models = (block['models'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        if (makeUpper.isNotEmpty) {
          modelsByMake[makeUpper] = models;
          final makeId = _generateMakeId(makeUpper);
          makeIdToMakeName[makeId] = makeUpper;
        }
      }

      final catalog = YearCatalog(
        year: year,
        makes: makesList,
        modelsByMake: modelsByMake,
        makeIdToMakeName: makeIdToMakeName,
      );

      _yearCache[year] = catalog;
      debugPrint('[LocalFrCatalog] Catalogue année $year mis en cache (${makesList.length} marques, ${modelsByMake.length} marques avec modèles)');

      return catalog;
    } catch (e) {
      debugPrint('[LocalFrCatalog] ERREUR chargement catalogue année $year: $e');
      rethrow;
    }
  }

  @override
  Future<List<CatalogMake>> fetchMakes(String type, int year) async {
    // Pour l'instant, LOCAL_FR ne supporte que les voitures
    if (type != 'voiture') {
      debugPrint('[LocalFrCatalog] Type "$type" non supporté, retour liste vide');
      return [];
    }

    try {
      final catalog = await _loadYearCatalog(year);
      
      final makes = catalog.makes.map((makeUpper) {
        final makeId = _generateMakeId(makeUpper);
        return CatalogMake(
          id: makeId,
          name: makeUpper,
        );
      }).toList();

      debugPrint('[LocalFrCatalog] fetchMakes($type, $year): ${makes.length} marques');
      return makes;
    } catch (e) {
      debugPrint('[LocalFrCatalog] ERREUR fetchMakes: $e');
      throw Exception('Erreur lors du chargement des marques depuis le référentiel local: $e');
    }
  }

  @override
  Future<List<CatalogModel>> fetchModels(String type, String makeId, int year) async {
    // Pour l'instant, LOCAL_FR ne supporte que les voitures
    if (type != 'voiture') {
      debugPrint('[LocalFrCatalog] Type "$type" non supporté, retour liste vide');
      return [];
    }

    try {
      final catalog = await _loadYearCatalog(year);
      
      // Récupérer le nom de la marque depuis l'ID
      final makeUpper = catalog.makeIdToMakeName[makeId];
      if (makeUpper == null) {
        debugPrint('[LocalFrCatalog] Marque non trouvée pour makeId: $makeId');
        return [];
      }

      // Récupérer les modèles pour cette marque
      final modelNames = catalog.modelsByMake[makeUpper] ?? [];
      
      final models = modelNames.map((modelName) {
        final modelId = _generateModelId(makeUpper, modelName, year);
        return CatalogModel(
          id: modelId,
          name: modelName,
          makeName: makeUpper,
        );
      }).toList();

      debugPrint('[LocalFrCatalog] fetchModels($type, makeId=$makeId, makeName=$makeUpper, $year): ${models.length} modèles');
      return models;
    } catch (e) {
      debugPrint('[LocalFrCatalog] ERREUR fetchModels: $e');
      throw Exception('Erreur lors du chargement des modèles depuis le référentiel local: $e');
    }
  }

  /// Vide le cache
  void clearCache() {
    _yearCache.clear();
    debugPrint('[LocalFrCatalog] Cache vidé');
  }
}

