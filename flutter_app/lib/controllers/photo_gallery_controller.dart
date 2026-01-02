import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../services/garage_service.dart';

/// Controller pour gérer la pagination et le chargement des photos d'un véhicule
class PhotoGalleryController extends ChangeNotifier {
  final GarageService _garageService;
  final String vehicleId;

  List<VehiclePhoto> _photos = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  static const int _pageSize = 24;

  PhotoGalleryController({
    required this.vehicleId,
    GarageService? garageService,
  }) : _garageService = garageService ?? GarageService();

  // Getters
  List<VehiclePhoto> get photos => _photos;
  int get page => _page;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  bool get isEmpty => _photos.isEmpty && !_isLoading;

  /// Charger la première page
  Future<void> loadFirstPage() async {
    if (_isLoading) return;

    _page = 1;
    _hasMore = true;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _garageService.listVehiclePhotos(
        vehicleId,
        page: _page,
        limit: _pageSize,
      );

      _photos = result['items'] as List<VehiclePhoto>;
      _hasMore = result['hasMore'] as bool;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _photos = [];
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger la page suivante
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final nextPage = _page + 1;
      final result = await _garageService.listVehiclePhotos(
        vehicleId,
        page: nextPage,
        limit: _pageSize,
      );

      final newPhotos = result['items'] as List<VehiclePhoto>;
      _photos.addAll(newPhotos);
      _hasMore = result['hasMore'] as bool;
      _page = nextPage;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      // Ne pas bloquer si une page échoue, on garde ce qu'on a
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rafraîchir (recharger depuis le début)
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    await loadFirstPage();

    _isRefreshing = false;
    notifyListeners();
  }

  /// Ajouter une photo localement (optimiste, avant confirmation serveur)
  void addLocal(VehiclePhoto photo) {
    _photos.insert(0, photo); // Ajouter au début
    notifyListeners();
  }

  /// Supprimer une photo localement (optimiste)
  /// Retourne l'index de la photo supprimée pour rollback si nécessaire
  int? removeLocalByIndex(int index) {
    if (index < 0 || index >= _photos.length) return null;
    
    _photos.removeAt(index);
    notifyListeners();
    
    // Retourner l'index pour permettre le rollback
    return index;
  }

  /// Supprimer une photo par URL (si on connaît l'URL mais pas l'index)
  int? removeLocalByUrl(String url) {
    final index = _photos.indexWhere((p) => p.url == url);
    if (index == -1) return null;
    return removeLocalByIndex(index);
  }

  /// Rollback : réinsérer une photo à un index donné
  void rollbackAdd(int index, VehiclePhoto photo) {
    if (index < 0 || index > _photos.length) {
      _photos.insert(0, photo);
    } else {
      _photos.insert(index, photo);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

