import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import 'catalog_provider.dart';
import '../catalog_overlay_service.dart';
import '../api_service.dart';

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

/// Provider de catalogue utilisant les fichiers JSON locaux français (voitures + motos)
class LocalFrVehicleCatalogProvider implements CatalogProvider {
  // Cache par (type, year) : key = "type_year"
  final Map<String, YearCatalog> _cache = {};
  final CatalogOverlayService _overlayService;

  LocalFrVehicleCatalogProvider({
    CatalogOverlayService? overlayService,
    ApiService? apiService,
  }) : _overlayService = overlayService ?? CatalogOverlayService(
          apiService: apiService,
        );

  /// Retourne le chemin de base selon le type de véhicule
  String _basePathForType(String type) {
    if (type == 'voiture') {
      return 'assets/reference/vehicles/cars/fr';
    }
    if (type == 'moto') {
      return 'assets/reference/vehicles/motos/fr';
    }
    throw Exception('Type de véhicule inconnu: $type (attendu: "voiture" ou "moto")');
  }

  /// Génère une clé de cache
  String _cacheKey(String type, int year) {
    return '${type}_$year';
  }

  /// Génère un slug stable pour un ID
  String _slug(String text) {
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Normalise un nom pour comparaison (uppercase, collapse spaces, remove extra chars)
  String _normalizeForCompare(String name) {
    return name
        .toUpperCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .replaceAll(RegExp(r'-+'), '-') // Collapse multiple dashes
        .replaceAll(RegExp(r'_+'), '_'); // Collapse multiple underscores
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
      debugPrint('[LocalFrVehicleCatalog] Chargement asset: $path');
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> json = jsonDecode(jsonString);
      debugPrint('[LocalFrVehicleCatalog] Asset chargé: $path (${jsonString.length} bytes)');
      return json;
    } catch (e) {
      debugPrint('[LocalFrVehicleCatalog] ERREUR chargement asset $path: $e');
      rethrow;
    }
  }

  /// Charge le catalogue pour un type et une année (avec cache)
  Future<YearCatalog> _loadYearCatalog(String type, int year) async {
    final cacheKey = _cacheKey(type, year);
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[LocalFrVehicleCatalog] Cache hit pour $cacheKey');
      return _cache[cacheKey]!;
    }

    debugPrint('[LocalFrVehicleCatalog] Chargement catalogue $type année $year...');

    try {
      final basePath = _basePathForType(type);
      
      // Charger _models.json
      final modelsPath = '$basePath/${year}_models.json';
      final modelsJson = await _loadAssetJson(modelsPath);
      
      final makesList = (modelsJson['makes'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          [];
      
      debugPrint('[LocalFrVehicleCatalog] Parsed ${year}_models.json ($type): ${makesList.length} marques');

      // Charger _makes.json
      final makesPath = '$basePath/${year}_makes.json';
      final makesJson = await _loadAssetJson(makesPath);
      
      final makeBlocks = (makesJson['makeBlocks'] as List<dynamic>?) ?? [];
      debugPrint('[LocalFrVehicleCatalog] Parsed ${year}_makes.json ($type): ${makeBlocks.length} makeBlocks');

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

      _cache[cacheKey] = catalog;
      debugPrint('[LocalFrVehicleCatalog] Catalogue $cacheKey mis en cache (${makesList.length} marques, ${modelsByMake.length} marques avec modèles)');

      return catalog;
    } catch (e) {
      debugPrint('[LocalFrVehicleCatalog] ERREUR chargement catalogue $type année $year: $e');
      rethrow;
    }
  }

  @override
  Future<List<CatalogMake>> fetchMakes(String type, int year) async {
    // Vérifier que le type est supporté
    if (type != 'voiture' && type != 'moto') {
      debugPrint('[LocalFrVehicleCatalog] Type "$type" non supporté, retour liste vide');
      return [];
    }

    try {
      final catalog = await _loadYearCatalog(type, year);
      
      // Récupérer les marques locales
      final localMakes = catalog.makes.map((makeUpper) {
        final makeId = _generateMakeId(makeUpper);
        return CatalogMake(
          id: makeId,
          name: makeUpper,
        );
      }).toList();

      final localCount = localMakes.length;
      debugPrint('[LocalFrVehicleCatalog] fetchMakes($type, $year): $localCount marques locales');

      // Récupérer les marques approuvées de TOUTES les années (best-effort, ne bloque pas si erreur)
      int overlayCount = 0;
      try {
        // Utiliser getApprovedMakes pour récupérer toutes les marques approuvées (toutes années)
        final overlayMakesList = await _overlayService.getApprovedMakes(type);
        overlayCount = overlayMakesList.length;
        debugPrint('[LocalFrVehicleCatalog] Overlay: $overlayCount marques approuvées (toutes années)');

        // Normaliser et créer une map pour retrouver rapidement la marque originale
        final Map<String, String> normalizedToOriginal = {};
        for (final make in overlayMakesList) {
          final makeUpper = make.toUpperCase().trim();
          if (makeUpper.isNotEmpty) {
            final normalized = _normalizeForCompare(makeUpper);
            if (!normalizedToOriginal.containsKey(normalized)) {
              normalizedToOriginal[normalized] = makeUpper;
            }
          }
        }

        // Ajouter les marques de l'overlay qui ne sont pas déjà dans localMakes (comparaison normalisée)
        int addedCount = 0;
        for (final normalized in normalizedToOriginal.keys) {
          final overlayMakeOriginal = normalizedToOriginal[normalized] ?? '';
          
          if (overlayMakeOriginal.isEmpty) {
            debugPrint('[LocalFrVehicleCatalog] WARNING: Marque originale non trouvée pour normalisée: $normalized');
            continue;
          }
          
          final exists = localMakes.any((m) => _normalizeForCompare(m.name) == normalized);
          if (!exists) {
            final makeId = _generateMakeId(overlayMakeOriginal);
            localMakes.add(CatalogMake(id: makeId, name: overlayMakeOriginal));
            addedCount++;
            debugPrint('[LocalFrVehicleCatalog] Marque overlay ajoutée: $overlayMakeOriginal (normalisée: $normalized)');
          }
        }
        debugPrint('[LocalFrVehicleCatalog] fetchMakes: $addedCount marques overlay ajoutées (toutes années)');
      } catch (e) {
        debugPrint('[LocalFrVehicleCatalog] Erreur overlay marques (non bloquant): $e');
      }

      // Trier par ordre alphabétique
      localMakes.sort((a, b) => a.name.compareTo(b.name));

      final mergedCount = localMakes.length;
      debugPrint('[LocalFrVehicleCatalog] fetchMakes($type, $year): localCount=$localCount overlayCount=$overlayCount merged=$mergedCount');
      return localMakes;
    } catch (e) {
      debugPrint('[LocalFrVehicleCatalog] ERREUR fetchMakes: $e');
      throw Exception('Erreur lors du chargement des marques depuis le référentiel local: $e');
    }
  }

  @override
  Future<List<CatalogModel>> fetchModels(String type, String makeId, int year) async {
    // Vérifier que le type est supporté
    if (type != 'voiture' && type != 'moto') {
      debugPrint('[LocalFrVehicleCatalog] Type "$type" non supporté, retour liste vide');
      return [];
    }

    try {
      final catalog = await _loadYearCatalog(type, year);
      
      // Récupérer le nom de la marque depuis l'ID (local ou overlay)
      String? makeUpper = catalog.makeIdToMakeName[makeId];
      
      // Si la marque n'est pas dans le catalogue local, chercher dans l'overlay
      if (makeUpper == null) {
        try {
          final overlayEntries = await _overlayService.getApprovedEntries(type, year);
          // Extraire le nom de la marque depuis makeId (format: LOCALFR_MAKE_<SLUG>)
          final makeIdSlug = makeId.replaceFirst('LOCALFR_MAKE_', '');
          // Chercher dans l'overlay une marque dont le slug correspond
          for (final entry in overlayEntries) {
            final entryMake = (entry['make'] as String?)?.toUpperCase().trim() ?? '';
            if (entryMake.isNotEmpty && _slug(entryMake) == makeIdSlug) {
              makeUpper = entryMake;
              break;
            }
          }
        } catch (e) {
          debugPrint('[LocalFrVehicleCatalog] Erreur lors de la recherche de la marque dans overlay: $e');
        }
      }
      
      if (makeUpper == null) {
        debugPrint('[LocalFrVehicleCatalog] Marque non trouvée pour makeId: $makeId');
        return [];
      }

      // À ce point, makeUpper ne peut pas être null
      final makeUpperFinal = makeUpper;

      // Récupérer les modèles locaux pour cette marque
      final localModelNames = catalog.modelsByMake[makeUpperFinal] ?? [];
      
      final models = localModelNames.map((modelName) {
        final modelId = _generateModelId(makeUpperFinal, modelName, year);
        return CatalogModel(
          id: modelId,
          name: modelName,
          makeName: makeUpperFinal,
        );
      }).toList();

      final localCount = models.length;
      debugPrint('[LocalFrVehicleCatalog] fetchModels($type, makeId=$makeId, makeName=$makeUpperFinal, $year): $localCount modèles locaux');

      // Normaliser le nom de la marque pour comparaison
      final makeUpperNormalized = _normalizeForCompare(makeUpperFinal);

      // Récupérer l'overlay (best-effort, ne bloque pas si erreur)
      int overlayCount = 0;
      try {
        final overlayEntries = await _overlayService.getApprovedEntries(type, year);
        
        // Filtrer les entrées pour cette marque (comparaison normalisée)
        final overlayModelsSet = overlayEntries
            .where((e) {
              final entryMake = (e['make'] as String?)?.toUpperCase().trim() ?? '';
              return entryMake.isNotEmpty && _normalizeForCompare(entryMake) == makeUpperNormalized;
            })
            .map((e) => (e['model'] as String?)?.toUpperCase().trim() ?? '')
            .where((model) => model.isNotEmpty)
            .toSet();

        overlayCount = overlayModelsSet.length;
        debugPrint('[LocalFrVehicleCatalog] Overlay: $overlayCount modèles approuvés pour $makeUpperFinal');

        // Ajouter les modèles de l'overlay qui ne sont pas déjà dans models (comparaison normalisée)
        int addedCount = 0;
        for (final overlayModel in overlayModelsSet) {
          final exists = models.any((m) => _normalizeForCompare(m.name) == _normalizeForCompare(overlayModel));
          if (!exists) {
            final modelId = _generateModelId(makeUpperFinal, overlayModel, year);
            models.add(CatalogModel(
              id: modelId,
              name: overlayModel,
              makeName: makeUpperFinal,
            ));
            addedCount++;
            debugPrint('[LocalFrVehicleCatalog] Modèle overlay ajouté: $overlayModel');
          }
        }
        debugPrint('[LocalFrVehicleCatalog] fetchModels: $addedCount modèles overlay ajoutés');
      } catch (e) {
        debugPrint('[LocalFrVehicleCatalog] Erreur overlay (non bloquant): $e');
      }

      // Trier par ordre alphabétique
      models.sort((a, b) => a.name.compareTo(b.name));

      final mergedCount = models.length;
      debugPrint('[LocalFrVehicleCatalog] fetchModels($type, makeId=$makeId, makeName=$makeUpperFinal, $year): localCount=$localCount overlayCount=$overlayCount merged=$mergedCount');
      return models;
    } catch (e) {
      debugPrint('[LocalFrVehicleCatalog] ERREUR fetchModels: $e');
      throw Exception('Erreur lors du chargement des modèles depuis le référentiel local: $e');
    }
  }

  /// Vide le cache
  void clearCache() {
    _cache.clear();
    _overlayService.clearCache();
    debugPrint('[LocalFrVehicleCatalog] Cache vidé');
  }
}

