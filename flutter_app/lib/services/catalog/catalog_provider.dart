import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';

/// Type de provider de catalogue
enum CatalogProviderType {
  carapi,
  localFr,
}

/// Interface abstraite pour un provider de catalogue
abstract class CatalogProvider {
  /// Récupère les marques pour un type de véhicule et une année
  Future<List<CatalogMake>> fetchMakes(String type, int year);

  /// Récupère les modèles pour une marque, année et type
  Future<List<CatalogModel>> fetchModels(String type, String makeId, int year);
}

