import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ride.dart';
import '../../models/waypoint.dart';
import '../../models/weather.dart';
import '../../widgets/rating_form.dart';
import '../../widgets/average_rating_display.dart';
import '../../widgets/navigation/navigation_app_selector.dart';
import '../chat/ride_chat_screen_v2.dart';
import '../../config/api_config.dart';
import '../../utils/background_helper.dart';
import '../../constants/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../providers/live_ride_provider.dart';
import 'live_ride_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../models/vehicle.dart';
import '../garage/add_vehicle_screen.dart';
import '../../widgets/ride/organizer_tools_section.dart';
import '../../widgets/ride/advanced_features_section.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;

  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  Ride? _ride;
  bool _isLoading = true;
  bool _isParticipant = false;
  bool _isLiked = false;
  int _totalLikes = 0;
  bool _hasRated = false;
  bool _isSubmittingRating = false;
  String? _errorMessage;
  Map<String, dynamic>? _ratingsData;
  RideInvitation? _userInvitation; // Invitation pending de l'utilisateur
  
  // Pour la carte
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isCalculatingRoute = false;
  
  // Distance et durée de la balade
  double? _totalDistance; // en km
  String? _estimatedDuration; // formaté (ex: "2 h 30 min")
  
  // Météo
  RideWeather? _weather;
  bool _isLoadingWeather = false;
  DateTime? _lastWeatherRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocale();
    _loadRide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quand l'app revient au premier plan, recharger les données si nécessaire
    if (state == AppLifecycleState.resumed) {
      // Recharger la balade pour avoir les dernières données
      _loadRide();
    }
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('fr_FR', null);
  }

  Future<void> _loadRide() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final ride = await _apiService.getRideById(widget.rideId);
      
      // Vérifier si l'utilisateur a déjà noté (utiliser le système reviews pour la cohérence)
      bool hasRated = false;
      if (authService.user?.id != null) {
        try {
          final reviewCheck = await _apiService.hasUserReviewed(widget.rideId);
          hasRated = reviewCheck['data']?['hasReviewed'] ?? false;
        } catch (e) {
          debugPrint('Erreur vérification note: $e');
          // Fallback sur l'ancien système si le nouveau échoue
          try {
            hasRated = await _apiService.hasUserRatedRide(widget.rideId, authService.user!.id);
          } catch (e2) {
            debugPrint('Erreur vérification note (fallback): $e2');
          }
        }
      }

      // Charger les notes pour afficher la moyenne et le nombre
      Map<String, dynamic>? ratingsData;
      try {
        ratingsData = await _apiService.getRatingsByRide(widget.rideId);
      } catch (e) {
        debugPrint('Erreur chargement notes: $e');
      }
      
      if (mounted) {
        setState(() {
          _ride = ride;
          _isParticipant = ride.participants.any((p) => p.id == authService.user?.id);
          
          // Vérifier si l'utilisateur a une invitation pending
          _userInvitation = ride.invitations?.where(
            (inv) => inv.userId == authService.user?.id && inv.status == 'pending',
          ).firstOrNull;
          _isLiked = ride.hasUserLiked ?? ride.likes.contains(authService.user?.id);
          _totalLikes = ride.totalLikes ?? ride.likes.length;
          _hasRated = hasRated;
          _ratingsData = ratingsData;
          _isLoading = false;
        });
      }
      
      // Charger le trajet sur la carte si des waypoints existent
      if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
        _loadRouteOnMap(ride.waypoints!);
      }
      
      // Charger la météo (uniquement pour les balades futures)
      if (!_isRidePast) {
        _loadWeather();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool get _isRidePast {
    if (_ride == null) return false;
    final rideDate = DateTime(
      _ride!.date.year,
      _ride!.date.month,
      _ride!.date.day,
      int.parse(_ride!.heure.split(':')[0]),
      int.parse(_ride!.heure.split(':')[1]),
    );
    return rideDate.isBefore(DateTime.now());
  }

  Future<void> _joinRide({bool forceRefresh = false}) async {
    if (_ride == null) return;

    try {
      // Charger les véhicules du type requis
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);
      
      // Si forceRefresh, attendre un peu pour laisser le temps au backend de créer le véhicule
      if (forceRefresh) {
        await Future.delayed(const Duration(milliseconds: 1000));
        // Faire une première tentative de chargement
        var vehicles = await _apiService.getVehicles(type: _ride!.typeVehicule);
        // Si toujours vide, attendre encore un peu et réessayer (max 3 tentatives)
        int retries = 0;
        while (vehicles.isEmpty && retries < 3 && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          vehicles = await _apiService.getVehicles(type: _ride!.typeVehicule);
          retries++;
        }
        // Utiliser les véhicules trouvés (peut être vide si le véhicule n'a pas encore été créé)
        final finalVehicles = vehicles;
        
        String? selectedVehicleId;
        
        if (finalVehicles.isEmpty) {
          // Aucun véhicule trouvé même après les tentatives : afficher une modal de conseil
          final shouldContinue = await _showNoVehicleDialog();
          if (!shouldContinue || !mounted) return;
          // Continuer sans véhicule (vehicleId sera null)
        } else if (finalVehicles.length == 1) {
          // Un seul véhicule : sélection automatique
          selectedVehicleId = finalVehicles.first.id;
        } else {
          // Plusieurs véhicules : afficher une modal de sélection
          final result = await _showVehicleSelectionDialog(finalVehicles);
          if (result == null || !mounted) return; // L'utilisateur a annulé
          selectedVehicleId = result;
        }
        
        // Rejoindre la balade avec le véhicule sélectionné (ou null)
        final response = await _apiService.joinRide(_ride!.id, vehicleId: selectedVehicleId);
        
        if (mounted) {
          final status = response['status'] ?? 'joined';
          String message;
          Color backgroundColor;
          IconData icon;
          
          switch (status) {
            case 'pending_approval':
              message = 'Demande envoyée ! L\'organisateur doit approuver votre participation.';
              backgroundColor = Colors.orange;
              icon = Icons.hourglass_empty;
              break;
            case 'waitlisted':
              final position = response['position'] ?? '?';
              message = 'Vous êtes sur liste d\'attente (position $position).';
              backgroundColor = Colors.blue;
              icon = Icons.queue;
              break;
            default:
              message = 'Vous avez rejoint la balade avec succès !';
              backgroundColor = Colors.green;
              icon = Icons.check_circle;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: backgroundColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          
          await _loadRide();
        }
        return;
      }
      
      final vehicles = await _apiService.getVehicles(type: _ride!.typeVehicule);
      
      String? selectedVehicleId;
      
      if (vehicles.isEmpty) {
        // Aucun véhicule : afficher une modal de conseil
        final shouldContinue = await _showNoVehicleDialog();
        if (!shouldContinue || !mounted) return;
        // Continuer sans véhicule (vehicleId sera null)
      } else if (vehicles.length == 1) {
        // Un seul véhicule : sélection automatique
        selectedVehicleId = vehicles.first.id;
      } else {
        // Plusieurs véhicules : afficher une modal de sélection
        final result = await _showVehicleSelectionDialog(vehicles);
        if (result == null || !mounted) return; // L'utilisateur a annulé
        selectedVehicleId = result;
      }
      
      // Rejoindre la balade avec le véhicule sélectionné (ou null)
      final response = await _apiService.joinRide(_ride!.id, vehicleId: selectedVehicleId);
      
      if (mounted) {
        final status = response['status'] ?? 'joined';
        String message;
        Color backgroundColor;
        IconData icon;
        
        switch (status) {
          case 'pending_approval':
            message = 'Demande envoyée ! L\'organisateur doit approuver votre participation.';
            backgroundColor = Colors.orange;
            icon = Icons.hourglass_empty;
            break;
          case 'waitlisted':
            final position = response['position'] ?? '?';
            message = 'Balade complète. Vous êtes en position $position sur la liste d\'attente.';
            backgroundColor = Colors.blue;
            icon = Icons.format_list_numbered;
            break;
          default: // 'joined'
            message = 'Vous participez maintenant à cette balade !';
            backgroundColor = AppTheme.successColor;
            icon = Icons.check_circle;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: backgroundColor.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Affiche une modal informant l'utilisateur qu'il n'a pas de véhicule
  /// Retourne true si l'utilisateur veut continuer, false s'il annule
  Future<bool> _showNoVehicleDialog() async {
    final vehicleTypeName = _ride!.typeVehicule == 'moto' ? 'moto' : 'voiture';
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _ride!.typeVehicule == 'moto' ? Icons.two_wheeler : Icons.directions_car,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Aucun véhicule disponible'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous n\'avez pas de $vehicleTypeName dans votre garage.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pour que cette balade soit comptabilisée dans les statistiques de votre véhicule, il est recommandé d\'ajouter un véhicule dans votre garage.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Continuer sans véhicule'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(false);
                // Naviguer vers l'écran d'ajout de véhicule
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddVehicleScreen(),
                  ),
                );
                
                // Si un véhicule a été ajouté, relancer le join avec forceRefresh
                if (result == true && mounted) {
                  // Attendre un peu pour laisser le temps au backend de créer le véhicule
                  await Future.delayed(const Duration(milliseconds: 800));
                  // Relancer le join qui va maintenant trouver le nouveau véhicule
                  // forceRefresh va attendre un peu et recharger les véhicules
                  if (mounted) {
                    _joinRide(forceRefresh: true);
                  }
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter un véhicule'),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// Affiche une modal pour sélectionner un véhicule parmi plusieurs
  /// Retourne l'ID du véhicule sélectionné, ou null si annulé
  Future<String?> _showVehicleSelectionDialog(List<Vehicle> vehicles) async {
    String? selectedVehicleId = vehicles.first.id; // Par défaut, le premier
    
    return await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    _ride!.typeVehicule == 'moto' ? Icons.two_wheeler : Icons.directions_car,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Choisir un véhicule'),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sélectionnez le véhicule avec lequel vous participez à cette balade :',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ...vehicles.map((vehicle) {
                    return RadioListTile<String>(
                      title: Text(vehicle.displayName),
                      subtitle: vehicle.make != null && vehicle.model != null
                          ? Text('${vehicle.make} ${vehicle.model}')
                          : null,
                      value: vehicle.id,
                      groupValue: selectedVehicleId,
                      onChanged: (value) {
                        setState(() {
                          selectedVehicleId = value;
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedVehicleId);
                  },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _leaveRide() async {
    if (_ride == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la balade'),
        content: const Text('Êtes-vous sûr de vouloir quitter cette balade ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.leaveRide(_ride!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vous avez quitté la balade'),
            backgroundColor: AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startLiveRide() async {
    if (_ride == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
      
      // Vérifier que l'utilisateur est bien l'organisateur
      if (authService.user?.id != _ride!.organisateur.id) {
        SnackBarHelper.showError(context, 'Seul l\'organisateur peut démarrer la balade');
        return;
      }

      // Démarrer la balade en direct
      await liveRideProvider.startLiveRide(rideId: _ride!.id);

      if (mounted) {
        // Naviguer vers l'écran Live Ride
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LiveRideScreen(
              rideId: _ride!.id,
              ride: _ride!,
            ),
          ),
        );
        
        // Recharger les données de la balade pour mettre à jour le statut
        _loadRide();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du démarrage: ${e.toString()}');
      }
    }
  }

  Future<void> _showParticipants() async {
    if (_ride == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 28, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_ride!.participants.length} participant${_ride!.participants.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste des participants
              Expanded(
                child: _ride!.participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun participant',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _ride!.participants.length,
                        itemBuilder: (context, index) {
                          final participant = _ride!.participants[index];
                          // Utiliser le pseudo pour l'anonymat
                          final displayName = participant.pseudo ?? 'Utilisateur';
                          // Vérifier si ce participant est l'organisateur
                          final isOrganizer = _ride!.organisateur.id == participant.id;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isOrganizer 
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: isOrganizer ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isOrganizer) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Organisateur',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinLiveRide() async {
    if (_ride == null) return;

    try {
      if (mounted) {
        // Naviguer directement vers l'écran Live Ride
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LiveRideScreen(
              rideId: _ride!.id,
              ride: _ride!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur: ${e.toString()}');
      }
    }
  }

  Future<void> _toggleLike(bool newLikeState) async {
    if (_ride == null) return;

    setState(() {
      _isLiked = newLikeState;
      _totalLikes = newLikeState ? _totalLikes + 1 : _totalLikes - 1;
    });

    try {
      final response = await _apiService.toggleLike(_ride!.id);
      
      if (mounted) {
        setState(() {
          _isLiked = response['data']?['isLiked'] ?? newLikeState;
          _totalLikes = response['data']?['totalLikes'] ?? _totalLikes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !newLikeState;
          _totalLikes = newLikeState ? _totalLikes - 1 : _totalLikes + 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitRating(int rating, String? comment) async {
    if (_ride == null) return;

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      // Utiliser createOrUpdateReview pour la cohérence avec la liste "Mes balades"
      await _apiService.createOrUpdateReview(
        rideId: _ride!.id,
        rating: rating,
        comment: comment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Note envoyée avec succès !',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppTheme.successColor.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
        await _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Future<void> _showEditRideDialog() async {
    if (_ride == null) return;

    final titreController = TextEditingController(text: _ride!.titre);
    final descriptionController = TextEditingController(text: _ride!.description ?? '');
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Modifier la balade'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Titre',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titreController,
                      decoration: InputDecoration(
                        hintText: 'Titre de la balade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLength: 200,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Description de la balade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 5,
                      maxLength: 2000,
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              actions: [
                if (isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final titre = titreController.text.trim();
                      final description = descriptionController.text.trim();

                      if (titre.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le titre ne peut pas être vide'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        isSubmitting = true;
                      });

                      try {
                        final updatedRide = await _apiService.updateRide(
                          _ride!.id,
                          titre: titre,
                          description: description.isEmpty ? null : description,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          setState(() {
                            _ride = updatedRide;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Balade modifiée avec succès'),
                              backgroundColor: AppTheme.successColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() {
                            isSubmitting = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppTheme.errorColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRide() async {
    if (_ride == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la balade'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette balade ? Cette action est irréversible et supprimera tous les messages associés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteRide(_ride!.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Balade supprimée avec succès'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ========== ANNULATION / REPORT / REPROGRAMMATION ==========

  Future<void> _cancelRide() async {
    if (_ride == null) return;

    String? selectedReasonCode;
    final reasonTextController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cancel, color: AppTheme.errorColor),
                  SizedBox(width: 8),
                  Text('Annuler la balade'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif d\'annulation *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ...['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'].map((code) {
                      String label;
                      switch (code) {
                        case 'WEATHER':
                          label = 'Météo défavorable';
                          break;
                        case 'MECHANICAL':
                          label = 'Problème mécanique';
                          break;
                        case 'ROAD_CLOSED':
                          label = 'Route fermée';
                          break;
                        case 'LOW_PARTICIPATION':
                          label = 'Peu de participants';
                          break;
                        case 'OTHER':
                          label = 'Autre raison';
                          break;
                        default:
                          label = code;
                      }
                      return RadioListTile<String>(
                        title: Text(label),
                        value: code,
                        groupValue: selectedReasonCode,
                        onChanged: (value) {
                          setState(() {
                            selectedReasonCode = value;
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Détails (optionnel)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonTextController,
                      decoration: InputDecoration(
                        hintText: 'Précisez la raison...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 3,
                      maxLength: 500,
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              actions: [
                if (isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: selectedReasonCode == null
                        ? null
                        : () async {
                            setState(() {
                              isSubmitting = true;
                            });

                            try {
                              await _apiService.cancelRide(
                                _ride!.id,
                                reasonCode: selectedReasonCode!,
                                reasonText: reasonTextController.text.trim().isEmpty
                                    ? null
                                    : reasonTextController.text.trim(),
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                await _loadRide();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Balade annulée avec succès'),
                                    backgroundColor: AppTheme.successColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: AppTheme.errorColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer l\'annulation'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _postponeRide() async {
    if (_ride == null) return;

    String? selectedReasonCode;
    final reasonTextController = TextEditingController();
    DateTime? selectedNewDateTime;
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Reporter la balade'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif de report *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ...['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'].map((code) {
                      String label;
                      switch (code) {
                        case 'WEATHER':
                          label = 'Météo défavorable';
                          break;
                        case 'MECHANICAL':
                          label = 'Problème mécanique';
                          break;
                        case 'ROAD_CLOSED':
                          label = 'Route fermée';
                          break;
                        case 'LOW_PARTICIPATION':
                          label = 'Peu de participants';
                          break;
                        case 'OTHER':
                          label = 'Autre raison';
                          break;
                        default:
                          label = code;
                      }
                      return RadioListTile<String>(
                        title: Text(label),
                        value: code,
                        groupValue: selectedReasonCode,
                        onChanged: (value) {
                          setState(() {
                            selectedReasonCode = value;
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Nouvelle date/heure (optionnel)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        selectedNewDateTime == null
                            ? 'Sélectionner une date'
                            : DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(selectedNewDateTime!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _ride!.date.isAfter(DateTime.now()) ? _ride!.date : DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_ride!.date),
                          );
                          if (time != null) {
                            setState(() {
                              selectedNewDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Détails (optionnel)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonTextController,
                      decoration: InputDecoration(
                        hintText: 'Précisez la raison...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 3,
                      maxLength: 500,
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              actions: [
                if (isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: selectedReasonCode == null
                        ? null
                        : () async {
                            setState(() {
                              isSubmitting = true;
                            });

                            try {
                              await _apiService.postponeRide(
                                _ride!.id,
                                reasonCode: selectedReasonCode!,
                                reasonText: reasonTextController.text.trim().isEmpty
                                    ? null
                                    : reasonTextController.text.trim(),
                                newDateTime: selectedNewDateTime,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                await _loadRide();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Balade reportée avec succès'),
                                    backgroundColor: AppTheme.successColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: AppTheme.errorColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer le report'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _rescheduleRide() async {
    if (_ride == null) return;

    DateTime? selectedNewDateTime;
    bool keepVisibility = true;
    bool keepParticipants = false;
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.event_repeat, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Reprogrammer la balade'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouvelle date et heure *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        selectedNewDateTime == null
                            ? 'Sélectionner une date'
                            : DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(selectedNewDateTime!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_ride!.date),
                          );
                          if (time != null) {
                            setState(() {
                              selectedNewDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Conserver la visibilité'),
                      subtitle: const Text('La nouvelle balade aura la même visibilité que l\'originale'),
                      value: keepVisibility,
                      onChanged: (value) {
                        setState(() {
                          keepVisibility = value ?? true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Conserver les participants'),
                      subtitle: const Text('Les participants seront automatiquement ajoutés à la nouvelle balade'),
                      value: keepParticipants,
                      onChanged: (value) {
                        setState(() {
                          keepParticipants = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                if (isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: selectedNewDateTime == null
                        ? null
                        : () async {
                            setState(() {
                              isSubmitting = true;
                            });

                            try {
                              final newRide = await _apiService.rescheduleRide(
                                _ride!.id,
                                newDateTime: selectedNewDateTime!,
                                keepVisibility: keepVisibility,
                                keepParticipants: keepParticipants,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                // Naviguer vers la nouvelle balade
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => RideDetailScreen(rideId: newRide.id),
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Balade reprogrammée avec succès'),
                                    backgroundColor: AppTheme.successColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: AppTheme.errorColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reprogrammer'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  String _getHeroBackgroundImage() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    
    // Priorité : background spécifique > background global > background par défaut
    final customBaladeBackground = user?.customBackgrounds?['balade'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customBaladeBackground != null && customBaladeBackground.isNotEmpty)
        ? customBaladeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBaladeBackgroundImageName(user?.vehiclePreference);
    
    return backgroundImage;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    
    // Background pour le body
    final customBaladeBackground = user?.customBackgrounds?['balade'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customBaladeBackground != null && customBaladeBackground.isNotEmpty)
        ? customBaladeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBaladeBackgroundImageName(user?.vehiclePreference);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundImage.startsWith('http') || backgroundImage.startsWith('/uploads')
                ? NetworkImage(backgroundImage.startsWith('/uploads') 
                    ? ApiConfig.getFileUrl(backgroundImage)
                    : backgroundImage)
                : AssetImage(backgroundImage) as ImageProvider,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            opacity: 0.15,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRide,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _ride == null
                    ? const Center(child: Text('Balade non trouvée'))
                    : _buildPremiumContent(),
      ),
    );
  }

  Widget _buildPremiumContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.35; // 35% de la hauteur d'écran
    
    return CustomScrollView(
      slivers: [
        // Hero Header avec image de couverture
        SliverAppBar(
          expandedHeight: heroHeight,
          pinned: false,
          floating: false,
          snap: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Image.asset(
                  'assets/images/logo.png',
                  height: 24,
                  fit: BoxFit.contain,
                ),
                onPressed: () {},
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeroHeader(heroHeight),
          ),
        ),
        
        // Contenu principal
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BANNIÈRES D'ANNULATION/REPORT EN PREMIER (très visibles)
                if (_ride!.status == 'cancelled' && _ride!.cancellation != null) ...[
                  _buildCancellationBanner(),
                  const SizedBox(height: 20),
                ],
                if (_ride!.status == 'postponed' && _ride!.postponement != null) ...[
                  _buildPostponementBanner(),
                  const SizedBox(height: 20),
                ],
                
                // Description (titre supprimé car déjà dans le hero)
                if (_ride!.description != null && _ride!.description!.isNotEmpty) ...[
                  _buildDescriptionCard(),
                  const SizedBox(height: 20),
                ],
                
                // Météo (uniquement pour les balades futures)
                if (!_isRidePast) ...[
                  _buildWeatherSection(),
                  const SizedBox(height: 20),
                ],
                
                // Cards d'informations
                const SizedBox(height: 20),
                _buildInfoCards(),
                
                // Carte Google Maps
                if (_ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  _buildWaypointsList(),
                ],
                
                // Notes
                if (_ratingsData != null && 
                    (_ratingsData!['data']?['moyenne'] ?? 0) > 0) ...[
                  const SizedBox(height: 24),
                  _buildRatingSection(),
                ],
                
                // Formulaire de notation
                if (_isRidePast && _isParticipant && !_hasRated) ...[
                  const SizedBox(height: 24),
                  _buildRatingFormCard(),
                ] else if (_isRidePast && _isParticipant && _hasRated) ...[
                  const SizedBox(height: 24),
                  _buildRatedCard(),
                ],
                
                // Bandeau si reprogrammée
                if (_ride!.reprogrammedToRideId != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_repeat,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cette balade a été reprogrammée',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Une nouvelle balade a été créée avec les mêmes informations',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => RideDetailScreen(rideId: _ride!.reprogrammedToRideId!),
                              ),
                            );
                          },
                          child: const Text('Voir la nouvelle balade'),
                        ),
                      ],
                    ),
                  ),
                ],


                // Outils organisateur (uniquement pour l'organisateur)
                if (_ride!.organisateur.id == Provider.of<AuthService>(context, listen: false).user?.id) ...[
                  const SizedBox(height: 24),
                  OrganizerToolsSection(
                    ride: _ride!,
                    apiService: _apiService,
                    onRideUpdated: _loadRide,
                  ),
                ],
                
                // Fonctions avancées (accessible à tous)
                const SizedBox(height: 24),
                AdvancedFeaturesSection(
                  ride: _ride!,
                  apiService: _apiService,
                  onRideUpdated: _loadRide,
                ),
                
                // Actions principales
                const SizedBox(height: 32),
                _buildActionButtons(),
                
                // Actions secondaires
                if (_isParticipant) ...[
                  const SizedBox(height: 16),
                  _buildSecondaryActions(),
                ],
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(double height) {
    final backgroundImage = _getHeroBackgroundImage();
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: backgroundImage.startsWith('http') || backgroundImage.startsWith('/uploads')
              ? NetworkImage(backgroundImage.startsWith('/uploads') 
                  ? ApiConfig.getFileUrl(backgroundImage)
                  : backgroundImage)
              : AssetImage(backgroundImage) as ImageProvider,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge véhicule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ride!.typeVehicule == 'moto'
                        ? AppTheme.secondaryColor.withOpacity(0.9)
                        : AppTheme.primaryColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _ride!.typeVehicule == 'moto' ? '🏍️' : '🚗',
                        style: const TextStyle(fontSize: 18, height: 1.0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ride!.typeVehicule == 'moto' ? 'Moto' : 'Voiture',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Badges (visibilité + premium + statut)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Badge visibilité
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _ride!.visibilite == 'privee'
                            ? Colors.grey.shade800.withOpacity(0.9)
                            : Colors.blue.shade700.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _ride!.visibilite == 'privee' ? '🔒' : '🌍',
                            style: const TextStyle(fontSize: 14, height: 1.0),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _ride!.visibilite == 'privee' ? 'Privée' : 'Publique',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge "Organisateur Premium"
                    if (_ride!.isOrganizerPremium == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Organisateur Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Badge "Annulée"
                    if (_ride!.status == 'cancelled')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Annulée',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Badge "Reportée"
                    if (_ride!.status == 'postponed')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Reportée',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Titre avec bouton d'édition pour l'organisateur
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _ride!.titre,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          height: 1.2,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              offset: const Offset(0, 2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (Provider.of<AuthService>(context, listen: false).user?.id == _ride!.organisateur.id)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.white.withOpacity(0.9), size: 22),
                        onPressed: _showEditRideDialog,
                        tooltip: 'Modifier le titre et la description',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Date
                Text(
                  _formatDateTime(_ride!.date, _ride!.heure),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// Bannière d'annulation (très visible en haut)
  Widget _buildCancellationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balade annulée',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Raison: ${_ride!.cancellation!.reasonLabel}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                if (_ride!.cancellation!.cancelReasonText != null && _ride!.cancellation!.cancelReasonText!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _ride!.cancellation!.cancelReasonText!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bannière de report (très visible en haut)
  Widget _buildPostponementBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balade reportée',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Raison: ${_ride!.postponement!.reasonLabel}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                if (_ride!.postponement!.postponeReasonText != null && _ride!.postponement!.postponeReasonText!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _ride!.postponement!.postponeReasonText!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
                if (_ride!.postponement!.newDateTime != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Nouvelle date: ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(_ride!.postponement!.newDateTime!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Charger la météo pour la balade
  Future<void> _loadWeather({bool forceRefresh = false}) async {
    if (_ride == null) return;
    
    // Cooldown : ne pas recharger si déjà chargé il y a moins de 5 minutes (sauf forceRefresh)
    if (!forceRefresh && 
        _lastWeatherRefresh != null && 
        DateTime.now().difference(_lastWeatherRefresh!) < const Duration(minutes: 5)) {
      return;
    }
    
    setState(() {
      _isLoadingWeather = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);
      
      final weather = await _apiService.getRideWeather(_ride!.id);
      
      if (mounted) {
        setState(() {
          _weather = weather; // Peut être null si service indisponible
          _isLoadingWeather = false;
          if (weather != null) {
            _lastWeatherRefresh = DateTime.now();
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement météo: $e');
      // Si c'est une erreur 503 (service indisponible), ne pas afficher d'erreur
      // Le message sera affiché dans l'UI
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          // Garder _weather à null pour afficher le message "non disponible"
        });
      }
    }
  }

  /// Section météo
  Widget _buildWeatherSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Météo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_weather != null)
                IconButton(
                  icon: _isLoadingWeather
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: _isLoadingWeather
                      ? null
                      : () => _loadWeather(forceRefresh: true),
                  tooltip: 'Rafraîchir la météo',
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingWeather && _weather == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_weather == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Météo non disponible',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Le service météo n\'est pas configuré',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _loadWeather(forceRefresh: true),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Alertes météo
            if (_weather!.alerts.isNotEmpty) ...[
              ..._weather!.alerts.map((alert) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.severity == 'danger'
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: alert.severity == 'danger'
                        ? Colors.red.shade300
                        : Colors.orange.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert.severity == 'danger' ? Icons.warning : Icons.info,
                      color: alert.severity == 'danger' ? Colors.red : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: alert.severity == 'danger' ? Colors.red.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            // Météo départ et arrivée
            Row(
              children: [
                // Départ
                Expanded(
                  child: _buildWeatherCard(
                    title: 'Départ',
                    forecast: _weather!.departure,
                  ),
                ),
                const SizedBox(width: 12),
                // Arrivée
                Expanded(
                  child: _buildWeatherCard(
                    title: 'Arrivée',
                    forecast: _weather!.arrival,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Carte météo individuelle (départ ou arrivée)
  Widget _buildWeatherCard({
    required String title,
    required WeatherForecast forecast,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                forecast.getWeatherEmoji(),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (forecast.temperature != null)
                      Text(
                        '${forecast.temperature!.round()}°C',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      forecast.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWeatherInfo(
                icon: Icons.air,
                value: '${forecast.windSpeed.round()} km/h',
              ),
              const SizedBox(width: 12),
              _buildWeatherInfo(
                icon: Icons.water_drop,
                value: '${forecast.precipitationProb.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Info météo individuelle (vent, pluie)
  Widget _buildWeatherInfo({required IconData icon, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOrganizer = _ride!.organisateur.id == authService.user?.id;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _ride!.description!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (isOrganizer)
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey.shade600, size: 20),
                  onPressed: _showEditRideDialog,
                  tooltip: 'Modifier la description',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        // Première carte : Informations de la balade
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              // Date et heure
              _InfoRow(
                icon: Icons.calendar_today,
                iconColor: AppTheme.primaryColor,
                title: 'Date et heure',
                value: _formatDateTime(_ride!.date, _ride!.heure),
              ),
              const Divider(height: 24),
              // Lieu de départ
              _InfoRow(
                icon: Icons.location_on,
                iconColor: AppTheme.successColor,
                title: 'Lieu de départ',
                value: _ride!.lieuDepart is String
                    ? _ride!.lieuDepart as String
                    : 'Lieu de départ',
              ),
              const Divider(height: 24),
              // Lieu d'arrivée
              _InfoRow(
                icon: Icons.place,
                iconColor: AppTheme.errorColor,
                title: 'Lieu d\'arrivée',
                value: _ride!.lieuArrivee is String
                    ? _ride!.lieuArrivee as String
                    : 'Lieu d\'arrivée',
              ),
              // Distance si disponible
              if (_totalDistance != null) ...[
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.straighten,
                  iconColor: AppTheme.infoColor,
                  title: 'Distance',
                  value: '${_totalDistance!.toStringAsFixed(1)} km',
                ),
              ],
              // Temps estimé si disponible
              if (_estimatedDuration != null) ...[
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.access_time,
                  iconColor: AppTheme.warningColor,
                  title: 'Temps estimé',
                  value: _estimatedDuration!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Deuxième carte : Organisateur et Participants
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              // Organisateur
              Row(
                children: [
                  Expanded(
                    child: _InfoRow(
                      icon: Icons.person,
                      iconColor: AppTheme.primaryColor,
                      title: 'Organisateur',
                      value: _ride!.organisateur.pseudo ?? _ride!.organisateur.displayName,
                    ),
                  ),
                  // Badge "Organisateur Premium"
                  if (_ride!.isOrganizerPremium == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            size: 16,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 24),
              // Participants
              _InfoRow(
                icon: Icons.people,
                iconColor: AppTheme.secondaryColor,
                title: 'Participants',
                value: '${_ride!.participants.length} participant${_ride!.participants.length > 1 ? 's' : ''}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.map, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Itinéraire',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 350,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Bloquer les notifications de scroll quand on interagit avec la carte
                  return true;
                },
                child: RawGestureDetector(
                  gestures: <Type, GestureRecognizerFactory>{
                    VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                      (VerticalDragGestureRecognizer instance) {
                        instance.onStart = (_) {};
                        instance.onUpdate = (_) {};
                        instance.onEnd = (_) {};
                        instance.onCancel = () {};
                      },
                    ),
                    ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                      () => ScaleGestureRecognizer(),
                      (ScaleGestureRecognizer instance) {
                        instance.onStart = (_) {};
                        instance.onUpdate = (_) {};
                        instance.onEnd = (_) {};
                      },
                    ),
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (controller) {
                        if (mounted) {
                          _mapController = controller;
                          if (_ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) {
                            _loadRouteOnMap(_ride!.waypoints!);
                          }
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: _ride!.waypoints != null && _ride!.waypoints!.isNotEmpty
                            ? LatLng(
                                _ride!.waypoints!.first.latitude,
                                _ride!.waypoints!.first.longitude,
                              )
                            : const LatLng(45.7640, 4.8357),
                        zoom: 12,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      mapType: MapType.normal,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  if (_isCalculatingRoute)
                    Container(
                      color: Colors.white.withOpacity(0.8),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construire la liste des waypoints sous la carte
  Widget _buildWaypointsList() {
    if (_ride == null || _ride!.waypoints == null || _ride!.waypoints!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Trier les waypoints par ordre
    final sortedWaypoints = List<Waypoint>.from(_ride!.waypoints!);
    sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.route, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Checkpoints',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: sortedWaypoints.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final waypoint = sortedWaypoints[index];
              return _buildWaypointItem(waypoint, index);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Construire un item de waypoint dans la liste
  Widget _buildWaypointItem(Waypoint waypoint, int index) {
    // Déterminer le type d'affichage
    String title;
    IconData icon;
    Color iconColor;
    
    if (waypoint.type == 'depart') {
      title = 'Départ';
      icon = Icons.play_circle_filled;
      iconColor = Colors.green;
    } else if (waypoint.type == 'arrivee') {
      title = 'Arrivée';
      icon = Icons.flag;
      iconColor = Colors.red;
    } else {
      // Checkpoint avec type spécifique
      switch (waypoint.waypointType) {
        case 'fuel':
          title = 'Pause carburant';
          icon = Icons.local_gas_station;
          iconColor = Colors.orange;
          break;
        case 'coffee':
          title = 'Pause café';
          icon = Icons.local_cafe;
          iconColor = Colors.brown;
          break;
        case 'danger':
          title = 'Danger';
          icon = Icons.warning;
          iconColor = Colors.red;
          break;
        case 'viewpoint':
          title = 'Point de vue';
          icon = Icons.landscape;
          iconColor = Colors.purple;
          break;
        default:
          title = 'Checkpoint ${index + 1}';
          icon = Icons.location_on;
          iconColor = AppTheme.primaryColor;
      }
    }

    return InkWell(
      onTap: () {
        // Centrer la carte sur ce waypoint
        _centerMapOnWaypoint(waypoint);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            // Numéro/icône
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (waypoint.isMandatoryStop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Obligatoire',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    waypoint.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (waypoint.note != null && waypoint.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      waypoint.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Icône de navigation
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  /// Centrer la carte sur un waypoint spécifique
  void _centerMapOnWaypoint(Waypoint waypoint) {
    if (_mapController == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(waypoint.latitude, waypoint.longitude),
          zoom: 15.0,
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: AverageRatingDisplay(
        averageRating: (_ratingsData!['data']?['moyenne'] ?? 0).toDouble(),
        totalRatings: _ratingsData!['data']?['nombreNotes'] ?? 0,
      ),
    );
  }

  Widget _buildRatingFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: RatingForm(
        onSubmit: _submitRating,
        isLoading: _isSubmittingRating,
      ),
    );
  }

  Widget _buildRatedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.successColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Vous avez déjà noté cette balade',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOrganizer = _ride!.organisateur.id == authService.user?.id;
    final isLive = _ride!.status == 'in_progress';
    
    return Column(
      children: [
        // Si l'utilisateur est l'organisateur
        if (isOrganizer) ...[
          // Si la balade est programmée ou reportée ET pas encore passée, afficher "Démarrer la balade"
          if ((_ride!.status == 'scheduled' || _ride!.status == 'postponed') && !_isRidePast) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startLiveRide,
                icon: const Icon(Icons.play_arrow_outlined, size: 22),
                label: const Text(
                  'Démarrer la balade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ] else if (isLive) ...[
            // Si la balade est en cours, afficher "Rejoindre la balade en cours"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _joinLiveRide,
                icon: const Icon(Icons.navigation_outlined, size: 22),
                label: const Text(
                  'Rejoindre la balade en cours',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
          // Bouton "Inviter des participants" si balade privée
          if (_ride!.visibilite == 'privee') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _inviteParticipants,
                icon: const Icon(Icons.person_add, size: 22),
                label: const Text(
                  'Inviter des participants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
          // Bouton "Voir les participants" pour l'organisateur
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showParticipants,
              icon: const Icon(Icons.people_outline, size: 22),
              label: Text(
                'Voir les participants (${_ride!.participants.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
        ] else ...[
          // Si l'utilisateur n'est pas l'organisateur
          // Vérifier si l'utilisateur a une invitation pending
          if (_userInvitation != null && !_isParticipant) ...[
            // Boutons Accepter/Refuser l'invitation
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptInvitation,
                    icon: const Icon(Icons.check, size: 22),
                    label: const Text(
                      'Accepter',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _declineInvitation,
                    icon: const Icon(Icons.close, size: 22),
                    label: const Text(
                      'Refuser',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!_isParticipant) ...[
            // Bouton principal : Participer ou Naviguer/Rejoindre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _joinRide,
                icon: const Icon(Icons.person_add_outlined, size: 22),
                label: const Text(
                  'Participer à la balade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ] else ...[
            // Si participant
            if (isLive) ...[
              // Si la balade est en cours, afficher "Rejoindre la balade en cours"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joinLiveRide,
                  icon: const Icon(Icons.navigation_outlined, size: 22),
                  label: const Text(
                    'Rejoindre la balade en cours',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (!_isRidePast && _ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) ...[
              // Si la date/heure n'est pas passée, afficher "Naviguer"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => NavigationAppSelector(
                        waypoints: _ride!.waypoints!,
                        rideId: _ride!.id,
                        rideName: _ride!.titre,
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 22),
                  label: const Text(
                    'Naviguer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Bouton "Voir les participants"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showParticipants,
                icon: const Icon(Icons.people_outline, size: 22),
                label: Text(
                  'Voir les participants (${_ride!.participants.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ],
        
        // Actions secondaires : Like et Chat - version améliorée
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Like - version améliorée avec fond
            Container(
              decoration: BoxDecoration(
                color: _isLiked 
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isLiked 
                      ? AppTheme.errorColor.withOpacity(0.3)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleLike(!_isLiked),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 22,
                          color: _isLiked ? AppTheme.errorColor : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_totalLikes',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _isLiked ? AppTheme.errorColor : Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isParticipant) ...[
              const SizedBox(width: 12),
              // Chat - version améliorée avec fond
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideChatScreenV2(
                            rideId: _ride!.id,
                            rideTitle: _ride!.titre,
                            participantCount: _ride!.participants.length,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 22,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chat',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryActions() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOrganizer = _ride!.organisateur.id == authService.user?.id;
    // Permettre les actions si la balade n'est pas annulée ou terminée
    // (même si elle est reportée, on peut toujours l'annuler, la reporter à nouveau ou la reprogrammer)
    final canCancelOrPostpone = isOrganizer && 
        _ride!.status != 'cancelled' && 
        _ride!.status != 'completed';
    
    return Column(
      children: [
        if (isOrganizer) ...[
          // Actions d'annulation/report/reprogrammation (si balade pas encore annulée/complétée)
          if (canCancelOrPostpone) ...[
            // Annuler
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _cancelRide,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 22,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Annuler la balade',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Reporter
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _postponeRide,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 22,
                          color: Colors.orange.shade900,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Reporter la balade',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Reprogrammer
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _rescheduleRide,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_repeat_outlined,
                          size: 22,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Reprogrammer la balade',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Supprimer - version améliorée avec fond
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _deleteRide,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 22,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Supprimer la balade',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          // Quitter - version améliorée avec fond
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _leaveRide,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.exit_to_app,
                        size: 22,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quitter la balade',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _inviteParticipants() async {
    final List<Map<String, dynamic>> selectedUsers = [];
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Inviter des participants'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) async {
                    final query = textEditingValue.text.trim();
                    if (query.length < 2) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }

                    try {
                      setDialogState(() {
                        isLoading = true;
                      });

                      final authService = Provider.of<AuthService>(context, listen: false);
                      final token = await authService.storage.read(key: 'token');
                      _apiService.setToken(token);

                      final results = await _apiService.searchUsers(query, limit: 10);
                      
                      setDialogState(() {
                        isLoading = false;
                      });

                      // Filtrer les utilisateurs déjà sélectionnés
                      final selectedIds = selectedUsers.map((u) => u['id']).toSet();
                      return results.where((user) => !selectedIds.contains(user['id']));
                    } catch (e) {
                      setDialogState(() {
                        isLoading = false;
                      });
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                  },
                  displayStringForOption: (option) {
                    final pseudo = option['pseudo'] ?? '';
                    final email = option['email'] ?? '';
                    return '$pseudo ($email)';
                  },
                  onSelected: (option) {
                    setDialogState(() {
                      // Vérifier si l'utilisateur n'est pas déjà sélectionné
                      if (!selectedUsers.any((u) => u['id'] == option['id'])) {
                        selectedUsers.add(option);
                      }
                    });
                    // Le champ sera automatiquement vidé par Autocomplete après sélection
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Pseudo ou email',
                        hintText: 'Tapez au moins 2 caractères...',
                        suffixIcon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (value) {
                        onFieldSubmitted();
                        // Vider le champ après soumission
                        textEditingController.clear();
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final pseudo = option['pseudo'] ?? '';
                              final email = option['email'] ?? '';
                              final avatarUrl = option['avatarUrl'] ?? option['avatar'];

                              return ListTile(
                                leading: avatarUrl != null && avatarUrl.toString().isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          avatarUrl.toString().startsWith('http')
                                              ? avatarUrl.toString()
                                              : ApiConfig.getFileUrl(avatarUrl.toString())
                                        ),
                                        radius: 20,
                                      )
                                    : const CircleAvatar(
                                        radius: 20,
                                        child: Icon(Icons.person),
                                      ),
                                title: Text(pseudo),
                                subtitle: Text(email),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vous pouvez rechercher par pseudo ou email',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (selectedUsers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Utilisateurs sélectionnés:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selectedUsers.map((user) {
                    final pseudo = user['pseudo'] ?? '';
                    final email = user['email'] ?? '';
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 20),
                      title: Text(pseudo),
                      subtitle: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setDialogState(() {
                            selectedUsers.removeWhere((u) => u['id'] == user['id']);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedUsers.isEmpty
                  ? null
                  : () async {
                      final userIds = selectedUsers.map((u) => u['id'].toString()).toList();
                      Navigator.pop(context);
                      
                      try {
                        await _apiService.inviteUsersToRide(_ride!.id, userIds);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${selectedUsers.length} invitation(s) envoyée(s)'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _loadRide(); // Recharger pour voir les invitations
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: Text('Inviter (${selectedUsers.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvitation() async {
    if (_ride == null) return;

    try {
      // Charger les véhicules du type requis
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);
      
      final vehicles = await _apiService.getVehicles(type: _ride!.typeVehicule);
      
      String? selectedVehicleId;
      
      if (vehicles.isEmpty) {
        // Aucun véhicule : afficher une modal de conseil
        final shouldContinue = await _showNoVehicleDialog();
        if (!shouldContinue || !mounted) return;
        // Continuer sans véhicule (vehicleId sera null)
      } else if (vehicles.length == 1) {
        // Un seul véhicule : sélection automatique
        selectedVehicleId = vehicles.first.id;
      } else {
        // Plusieurs véhicules : afficher une modal de sélection
        final result = await _showVehicleSelectionDialog(vehicles);
        if (result == null || !mounted) return; // L'utilisateur a annulé
        selectedVehicleId = result;
      }
      
      // Accepter l'invitation avec le véhicule sélectionné (ou null)
      await _apiService.acceptRideInvitation(_ride!.id, vehicleId: selectedVehicleId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation acceptée'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadRide(); // Recharger pour mettre à jour l'état
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvitation() async {
    try {
      await _apiService.declineRideInvitation(_ride!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation refusée'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadRide(); // Recharger pour mettre à jour l'état
        // Optionnel : sortir de l'écran si l'invitation est refusée
        // Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime date, String heure) {
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(heure.split(':')[0]),
      int.parse(heure.split(':')[1]),
    );
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(dateTime);
  }

  Future<void> _loadRouteOnMap(List<Waypoint> waypoints) async {
    if (waypoints.isEmpty) return;

    if (mounted) {
      setState(() {
        _isCalculatingRoute = true;
        _markers.clear();
        _polylines.clear();
      });
    }

    final sortedWaypoints = List<Waypoint>.from(waypoints);
    sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));

    for (int i = 0; i < sortedWaypoints.length; i++) {
      final waypoint = sortedWaypoints[i];
      final markerId = MarkerId('waypoint_$i');

      // Construire le titre avec le type de waypoint
      String title;
      if (waypoint.type == 'depart') {
        title = 'Départ';
      } else if (waypoint.type == 'arrivee') {
        title = 'Arrivée';
      } else {
        title = waypoint.getTypeName();
      }

      // Ajouter badge "Obligatoire" si nécessaire
      String snippet = waypoint.address;
      if (waypoint.isMandatoryStop) {
        snippet = '⚠️ Arrêt obligatoire\n$snippet';
      }
      if (waypoint.note != null && waypoint.note!.isNotEmpty) {
        snippet = '$snippet\n${waypoint.note}';
      }

      // Choisir la couleur selon waypointType
      double markerHue;
      if (waypoint.type == 'depart') {
        markerHue = BitmapDescriptor.hueGreen.toDouble();
      } else if (waypoint.type == 'arrivee') {
        markerHue = BitmapDescriptor.hueRed.toDouble();
      } else {
        switch (waypoint.waypointType) {
          case 'fuel':
            markerHue = BitmapDescriptor.hueOrange.toDouble();
            break;
          case 'coffee':
            markerHue = BitmapDescriptor.hueYellow.toDouble();
            break;
          case 'danger':
            markerHue = BitmapDescriptor.hueRed.toDouble();
            break;
          case 'viewpoint':
            markerHue = BitmapDescriptor.hueViolet.toDouble();
            break;
          default:
            markerHue = BitmapDescriptor.hueBlue.toDouble();
        }
      }

      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(waypoint.latitude, waypoint.longitude),
          infoWindow: InfoWindow(
            title: title,
            snippet: snippet,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        ),
      );
    }

    if (sortedWaypoints.length >= 2) {
      try {
        final origin = '${sortedWaypoints.first.latitude},${sortedWaypoints.first.longitude}';
        final destination = '${sortedWaypoints.last.latitude},${sortedWaypoints.last.longitude}';
        final waypointsParam = sortedWaypoints
            .sublist(1, sortedWaypoints.length - 1)
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');

        final response = await _apiService.calculateRoute(
          origin: origin,
          destination: destination,
          waypoints: waypointsParam.isNotEmpty ? waypointsParam : null,
        );

        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          
          if (data['status'] == 'OK') {
            if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final route = data['routes'][0] as Map<String, dynamic>;
              
              double totalDistance = 0;
              int totalDuration = 0;
              
              if (route['legs'] != null) {
                final legs = route['legs'] as List;
                for (final leg in legs) {
                  if (leg['distance'] != null && leg['distance']['value'] != null) {
                    totalDistance += (leg['distance']['value'] as int).toDouble() / 1000;
                  }
                  if (leg['duration'] != null && leg['duration']['value'] != null) {
                    totalDuration += leg['duration']['value'] as int;
                  }
                }
              }
              
              String durationText = '';
              if (totalDuration > 0) {
                final hours = totalDuration ~/ 3600;
                final minutes = (totalDuration % 3600) ~/ 60;
                if (hours > 0) {
                  durationText = '$hours h';
                  if (minutes > 0) {
                    durationText += ' $minutes min';
                  }
                } else {
                  durationText = '$minutes min';
                }
              }
              
              List<LatLng> routePoints = [];
              if (route['overview_polyline'] != null) {
                final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
                if (overviewPolyline['points'] != null) {
                  routePoints = _decodePolyline(overviewPolyline['points'] as String);
                }
              }

              if (routePoints.isNotEmpty) {
                final validPoints = routePoints.where((point) {
                  return point.latitude >= -90 && point.latitude <= 90 &&
                         point.longitude >= -180 && point.longitude <= 180;
                }).toList();

                if (validPoints.isNotEmpty) {
                  _polylines.add(
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: validPoints,
                      color: AppTheme.primaryColor,
                      width: 5,
                      geodesic: false,
                    ),
                  );
                }
              }
              
              if (mounted) {
                setState(() {
                  _totalDistance = totalDistance > 0 ? totalDistance : null;
                  _estimatedDuration = durationText.isNotEmpty ? durationText : null;
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erreur lors du calcul du trajet: $e');
      }
    }

    if (sortedWaypoints.isNotEmpty && mounted) {
      final firstWaypoint = sortedWaypoints.first;
      try {
        await _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(firstWaypoint.latitude, firstWaypoint.longitude),
              zoom: 12,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Erreur lors de l\'animation de la caméra: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    if (encoded.isEmpty) return points;
    
    int index = 0;
    int lat = 0;
    int lng = 0;

    try {
      while (index < encoded.length) {
        int shift = 0;
        int result = 0;
        int byte;
        do {
          if (index >= encoded.length) return points;
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) return points;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        int dlat;
        if ((result & 1) != 0) {
          final unsigned = result >> 1;
          dlat = -unsigned - 1;
        } else {
          dlat = (result >> 1);
        }
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          if (index >= encoded.length) return points;
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) return points;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        int dlng;
        if ((result & 1) != 0) {
          final unsigned = result >> 1;
          dlng = -unsigned - 1;
        } else {
          dlng = (result >> 1);
        }
        lng += dlng;

        final decodedLat = lat / 1e5;
        final decodedLng = lng / 1e5;
        
        if (decodedLat >= -90 && decodedLat <= 90 && 
            decodedLng >= -180 && decodedLng <= 180) {
          points.add(LatLng(decodedLat, decodedLng));
        } else {
          break;
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du décodage de la polyligne: $e');
    }

    return points;
  }
}

// Widget pour une ligne d'information dans une carte groupée
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade900,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

