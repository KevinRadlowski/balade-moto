import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/navigation/navigation_service.dart';
import '../../services/navigation/providers/navigation_provider.dart';
import '../../services/navigation/app_detector.dart';
import '../../models/waypoint.dart';

/// Widget pour sélectionner une app de navigation avec détection des apps installées
class NavigationAppSelector extends StatefulWidget {
  final List<Waypoint> waypoints;
  final String? rideId;
  final String? rideName;

  const NavigationAppSelector({
    super.key,
    required this.waypoints,
    this.rideId,
    this.rideName,
  });

  @override
  State<NavigationAppSelector> createState() => _NavigationAppSelectorState();
}

class _NavigationAppSelectorState extends State<NavigationAppSelector> {
  final NavigationService _navigationService = NavigationService();
  final Map<String, bool> _availableApps = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detectApps();
  }

  Future<void> _detectApps() async {
    final apps = await AppDetector.detectAvailableApps();
    setState(() {
      _availableApps.addAll(apps);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Extraire la route depuis les waypoints
    final route = _navigationService.extractRoute(widget.waypoints);
    
    // Debug: vérifier que la route est correcte
    if (route.checkpoints.isEmpty && widget.waypoints.length > 2) {
      // Il devrait y avoir des checkpoints si on a plus de 2 waypoints
      debugPrint('NavigationAppSelector: Attention - ${widget.waypoints.length} waypoints mais ${route.checkpoints.length} checkpoints');
    }
    
    final providers = _navigationService.getAllProviders();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Titre
          const Text(
            'Choisir une application de navigation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Info sur les waypoints
          if (route.checkpoints.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${route.checkpoints.length} point${route.checkpoints.length > 1 ? 's' : ''} intermédiaire${route.checkpoints.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Liste des apps
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: providers.map((provider) {
                final isAvailable = _availableApps[provider.id] ?? false;
                final capabilities = provider.getCapabilities();
                final supportsMulti = capabilities.supportsMultiWaypoints;
                final supportsStepByStep = capabilities.supportsStepByStep;

                return _buildAppTile(
                  provider: provider,
                  isAvailable: isAvailable,
                  supportsMulti: supportsMulti,
                  supportsStepByStep: supportsStepByStep,
                  route: route,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Bouton Annuler
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile({
    required NavigationProvider provider,
    required bool isAvailable,
    required bool supportsMulti,
    required bool supportsStepByStep,
    required NavigationRoute route,
  }) {
    final hasCheckpoints = route.checkpoints.isNotEmpty;

    String subtitle;
    Color subtitleColor;
    IconData subtitleIcon;

    if (!isAvailable) {
      subtitle = 'Non installé';
      subtitleColor = Colors.orange;
      subtitleIcon = Icons.warning_amber_rounded;
    } else if (supportsMulti) {
      subtitle = hasCheckpoints
          ? '✓ Itinéraire complet avec checkpoints'
          : 'Itinéraire complet';
      subtitleColor = Colors.green;
      subtitleIcon = Icons.check_circle;
    } else if (supportsStepByStep && hasCheckpoints) {
      subtitle = 'Mode par étapes recommandé';
      subtitleColor = Colors.blue;
      subtitleIcon = Icons.navigation;
    } else {
      subtitle = 'Destination uniquement';
      subtitleColor = Colors.grey;
      subtitleIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getIconData(provider.iconName),
          color: isAvailable ? Colors.blue : Colors.grey,
        ),
        title: Text(provider.displayName),
        subtitle: Row(
          children: [
            Icon(subtitleIcon, size: 16, color: subtitleColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: isAvailable
            ? const Icon(Icons.chevron_right)
            : IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Installer',
                onPressed: () => _openStore(provider.id),
              ),
        enabled: isAvailable,
        onTap: isAvailable
            ? () => _handleAppSelection(provider, route)
            : null,
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'map':
        return Icons.map;
      case 'navigation':
        return Icons.navigation;
      case 'phone_android':
        return Icons.phone_android;
      default:
        return Icons.map;
    }
  }

  Future<void> _handleAppSelection(
    NavigationProvider provider,
    NavigationRoute route,
  ) async {
    final capabilities = provider.getCapabilities();
    final hasCheckpoints = route.checkpoints.isNotEmpty;

    // Si l'app ne supporte pas les waypoints multiples ET qu'il y a des checkpoints
    // ET que le provider supporte le mode par étapes, proposer le mode par étapes
    if (!capabilities.supportsMultiWaypoints &&
        hasCheckpoints &&
        capabilities.supportsStepByStep) {
      // Proposer le mode par étapes
      final useStepByStep = await _showStepByStepDialog(provider);
      if (useStepByStep == null) return; // Annulé

      if (useStepByStep) {
        // Ouvrir l'écran de navigation par étapes
        if (widget.rideId != null && mounted) {
          Navigator.of(context).pop(); // Fermer le bottom sheet
          Navigator.of(context).pushNamed(
            '/step-by-step-navigation',
            arguments: {
              'rideId': widget.rideId,
              'route': route,
              'providerId': provider.id,
            },
          );
        }
        return;
      }
    }

    // Navigation directe
    await _launchNavigation(provider, route);
  }

  Future<bool?> _showStepByStepDialog(NavigationProvider provider) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mode de navigation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${provider.displayName} ne supporte pas les waypoints multiples dans l\'URL.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisissez un mode :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.blue),
              title: const Text('Mode par étapes'),
              subtitle: Text(
                'Ouvrir ${provider.displayName} étape par étape avec suivi de progression',
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.grey),
              title: const Text('Destination uniquement'),
              subtitle: const Text('Ouvrir directement vers l\'arrivée'),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchNavigation(
    NavigationProvider provider,
    NavigationRoute route,
  ) async {
    try {
      final url = await provider.generateUrl(route);
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de générer l\'URL de navigation'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

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
          if (mounted) {
            Navigator.of(context).pop(); // Fermer le bottom sheet
          }
          return;
        }
      } catch (e) {
        // Si externalApplication échoue, essayer platformDefault
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          
          if (launched) {
            if (mounted) {
              Navigator.of(context).pop(); // Fermer le bottom sheet
            }
            return;
          }
        } catch (e2) {
          // Les deux ont échoué
        }
      }
      
      // Si on arrive ici, le lancement a échoué
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir ${provider.displayName}. Vérifiez que l\'application est installée.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Installer',
              onPressed: () => _openStore(provider.id),
            ),
          ),
        );
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

  Future<void> _openStore(String appId) async {
    final storeUrl = AppDetector.getStoreUrl(appId);
    if (storeUrl != null) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

