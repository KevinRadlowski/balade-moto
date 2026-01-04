import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import 'local_fr_vehicle_catalog_provider.dart';
import '../api_service.dart';
import '../catalog_overlay_service.dart';

/// Service de catalogue utilisant uniquement le référentiel local France
class CatalogRouterService {
  final LocalFrVehicleCatalogProvider localFrProvider;

  CatalogRouterService({
    LocalFrVehicleCatalogProvider? localFrProvider,
    ApiService? apiService,
  }) : localFrProvider = localFrProvider ?? LocalFrVehicleCatalogProvider(
          overlayService: apiService != null 
            ? CatalogOverlayService(apiService: apiService)
            : null,
        );

  /// Récupère les marques pour un type de véhicule et une année
  Future<List<CatalogMake>> fetchMakes(String type, int year) async {
    debugPrint('[CatalogRouter] fetchMakes($type, $year)');
    return await localFrProvider.fetchMakes(type, year);
  }

  /// Récupère les modèles pour une marque, année et type
  Future<List<CatalogModel>> fetchModels(String type, String makeId, int year) async {
    debugPrint('[CatalogRouter] fetchModels($type, $makeId, $year)');
    return await localFrProvider.fetchModels(type, makeId, year);
  }

  /// Vide le cache
  void clearCache() {
    localFrProvider.clearCache();
    debugPrint('[CatalogRouter] Cache vidé');
  }
}

