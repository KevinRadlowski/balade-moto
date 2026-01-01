import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/navigation/navigation_service.dart';
import '../../services/navigation/step_by_step_navigation_service.dart';
import '../../services/navigation/providers/waze_provider.dart';
import '../../services/navigation/providers/apple_plans_provider.dart';
import '../../services/navigation/providers/google_maps_provider.dart';
import '../../services/navigation/app_detector.dart';

/// Écran pour la navigation par étapes (Waze, Apple Plans, etc.)
class StepByStepNavigationScreen extends StatefulWidget {
  final String rideId;
  final NavigationRoute route;
  final String providerId;

  const StepByStepNavigationScreen({
    super.key,
    required this.rideId,
    required this.route,
    required this.providerId,
  });

  @override
  State<StepByStepNavigationScreen> createState() =>
      _StepByStepNavigationScreenState();
}

class _StepByStepNavigationScreenState
    extends State<StepByStepNavigationScreen> {
  final StepByStepNavigationService _stepService =
      StepByStepNavigationService();

  StepNavigationState? _state;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    try {
      // Vérifier si une navigation est déjà en cours
      var existingState = await _stepService.getStepNavigation(widget.rideId);

      if (existingState == null) {
        // Démarrer une nouvelle navigation
        await _stepService.startStepNavigation(
          rideId: widget.rideId,
          route: widget.route,
          providerId: widget.providerId,
        );
        // Récupérer l'état après sauvegarde
        existingState = await _stepService.getStepNavigation(widget.rideId);
      }

      // Si l'état est toujours null après sauvegarde, créer un état directement
      if (existingState == null) {
        debugPrint('Impossible de récupérer l\'état après sauvegarde, création d\'un état direct');
        existingState = StepNavigationState(
          rideId: widget.rideId,
          route: widget.route,
          providerId: widget.providerId,
          currentStepIndex: 0,
        );
      }

      if (mounted) {
        setState(() {
          _state = existingState;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Erreur lors de l\'initialisation de la navigation par étapes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        // En cas d'erreur, créer un état directement depuis les arguments
        setState(() {
          _isLoading = false;
          _state = StepNavigationState(
            rideId: widget.rideId,
            route: widget.route,
            providerId: widget.providerId,
            currentStepIndex: 0,
          );
        });
      }
    }
  }

  Future<void> _loadState() async {
    try {
      final state = await _stepService.getStepNavigation(widget.rideId);
      if (mounted) {
        setState(() {
          if (state != null) {
            _state = state;
          } else if (_state != null) {
            // Si l'état n'est pas dans le stockage mais qu'on a un état local,
            // essayer de le sauvegarder
            _stepService.startStepNavigation(
              rideId: widget.rideId,
              route: widget.route,
              providerId: widget.providerId,
            ).then((_) async {
              // Après sauvegarde, mettre à jour l'index actuel
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(
                'step_nav_${widget.rideId}current_step',
                _state!.currentStepIndex,
              );
              // Recharger l'état
              final newState = await _stepService.getStepNavigation(widget.rideId);
              if (mounted && newState != null) {
                setState(() {
                  _state = newState;
                });
              }
            });
          } else {
            // Si on n'a pas d'état du tout, créer un état depuis les arguments
            _state = StepNavigationState(
              rideId: widget.rideId,
              route: widget.route,
              providerId: widget.providerId,
              currentStepIndex: 0,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'état: $e');
      // En cas d'erreur, créer un état depuis les arguments si on n'en a pas
      if (mounted && _state == null) {
        setState(() {
          _state = StepNavigationState(
            rideId: widget.rideId,
            route: widget.route,
            providerId: widget.providerId,
            currentStepIndex: 0,
          );
        });
      }
    }
  }

  Future<void> _openCurrentStep() async {
    if (_state == null) return;

    final currentWaypoint = _state!.currentWaypoint;
    if (currentWaypoint == null) return;

    try {
      String? url;

      // Générer l'URL selon le provider
      switch (widget.providerId) {
        case 'waze':
          final wazeProvider = WazeProvider();
          url = await wazeProvider.generateUrlForWaypoint(currentWaypoint);
          break;
        case 'apple_plans':
          final appleProvider = ApplePlansProvider();
          url = await appleProvider.generateUrlForWaypoint(currentWaypoint);
          break;
        default:
          // Fallback vers Google Maps
          final route = NavigationRoute(
            departure: currentWaypoint,
            checkpoints: [],
            arrival: currentWaypoint,
          );
          final googleMapsProvider = GoogleMapsProvider();
          url = await googleMapsProvider.generateUrl(route);
      }

      if (url != null) {
        final uri = Uri.parse(url);
        
        // Essayer de lancer l'URL même si canLaunchUrl retourne false
        // car canLaunchUrl peut être peu fiable
        try {
          // Essayer d'abord avec externalApplication
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          
          if (launched) {
            return; // Succès
          }
        } catch (e) {
          // Si externalApplication échoue, essayer platformDefault
          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.platformDefault,
            );
            
            if (launched) {
              return; // Succès
            }
          } catch (e2) {
            debugPrint('Erreur lors du lancement de l\'URL: $e2');
          }
        }
        
        // Si on arrive ici, le lancement a échoué
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Impossible d\'ouvrir ${widget.providerId == 'waze' ? 'Waze' : 'l\'application de navigation'}. '
                'Vérifiez que l\'application est installée.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Installer',
                onPressed: () => _openStore(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de générer l\'URL de navigation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _nextStep() async {
    if (_state == null) return;
    
    try {
      // Mettre à jour l'index localement d'abord pour une réponse immédiate
      if (_state!.hasNext) {
        setState(() {
          _state = StepNavigationState(
            rideId: _state!.rideId,
            route: _state!.route,
            providerId: _state!.providerId,
            currentStepIndex: _state!.currentStepIndex + 1,
          );
        });
      }
      
      // Sauvegarder dans le stockage
      await _stepService.nextStep(widget.rideId);
      
      // Recharger depuis le stockage pour être sûr
      await _loadState();
    } catch (e) {
      debugPrint('Erreur lors du passage à l\'étape suivante: $e');
      // En cas d'erreur, recharger l'état
      await _loadState();
    }
  }

  Future<void> _previousStep() async {
    if (_state == null) return;
    
    try {
      // Mettre à jour l'index localement d'abord pour une réponse immédiate
      if (_state!.hasPrevious) {
        setState(() {
          _state = StepNavigationState(
            rideId: _state!.rideId,
            route: _state!.route,
            providerId: _state!.providerId,
            currentStepIndex: _state!.currentStepIndex - 1,
          );
        });
      }
      
      // Sauvegarder dans le stockage
      await _stepService.previousStep(widget.rideId);
      
      // Recharger depuis le stockage pour être sûr
      await _loadState();
    } catch (e) {
      debugPrint('Erreur lors du retour à l\'étape précédente: $e');
      // En cas d'erreur, recharger l'état
      await _loadState();
    }
  }

  Future<void> _openStore() async {
    final storeUrl = AppDetector.getStoreUrl(widget.providerId);
    if (storeUrl != null) {
      final uri = Uri.parse(storeUrl);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'ouvrir le store: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text(
          'Voulez-vous réinitialiser la navigation par étapes ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _stepService.resetStepNavigation(widget.rideId);
      await _initializeNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigation par étapes')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement...'),
            ],
          ),
        ),
      );
    }

    if (_state == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigation par étapes')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Erreur: état de navigation introuvable',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final allWaypoints = _state!.allWaypoints;
    final currentIndex = _state!.currentStepIndex;
    final currentWaypoint = _state!.currentWaypoint;
    final isCompleted = _state!.isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation par étapes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Réinitialiser',
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Étape ${currentIndex + 1} / ${allWaypoints.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Terminé',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (currentIndex + 1) / allWaypoints.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),

          // Current waypoint info
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current waypoint card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getWaypointIcon(currentWaypoint?.type),
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getWaypointLabel(currentWaypoint?.type),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (currentWaypoint != null)
                                      Text(
                                        currentWaypoint.address,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (currentWaypoint != null) ...[
                            const SizedBox(height: 12),
                            Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${currentWaypoint.latitude.toStringAsFixed(6)}, ${currentWaypoint.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // All waypoints list
                  const Text(
                    'Itinéraire complet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...allWaypoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final wp = entry.value;
                    final isCurrent = index == currentIndex;
                    final isPast = index < currentIndex;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrent
                          ? Colors.blue.shade50
                          : isPast
                              ? Colors.green.shade50
                              : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? Colors.blue
                              : isPast
                                  ? Colors.green
                                  : Colors.grey,
                          child: Icon(
                            isPast
                                ? Icons.check
                                : _getWaypointIcon(wp.type),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${index + 1}. ${_getWaypointLabel(wp.type)}',
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : null,
                          ),
                        ),
                        subtitle: Text(wp.address),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'En cours',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton principal "Ouvrir navigation"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isCompleted ? null : _openCurrentStep,
                    icon: const Icon(Icons.navigation),
                    label: Text(isCompleted ? 'Navigation terminée' : 'Ouvrir navigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                // Boutons précédent/suivant
                if (_state!.hasPrevious || _state!.hasNext) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_state!.hasPrevious)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _previousStep,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text(
                              'Précédent',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (_state!.hasPrevious && _state!.hasNext)
                        const SizedBox(width: 12),
                      if (_state!.hasNext)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _nextStep,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text(
                              'Suivant',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWaypointIcon(String? type) {
    switch (type) {
      case 'depart':
        return Icons.play_arrow;
      case 'arrivee':
        return Icons.flag;
      case 'checkpoint':
        return Icons.location_on;
      default:
        return Icons.location_on;
    }
  }

  String _getWaypointLabel(String? type) {
    switch (type) {
      case 'depart':
        return 'Départ';
      case 'arrivee':
        return 'Arrivée';
      case 'checkpoint':
        return 'Point de passage';
      default:
        return 'Point';
    }
  }
}

