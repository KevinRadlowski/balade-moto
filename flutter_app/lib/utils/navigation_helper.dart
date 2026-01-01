import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../models/waypoint.dart';

/// Helper pour ouvrir les applications de navigation avec les waypoints d'une balade
class NavigationHelper {
  /// Affiche un dialogue pour choisir l'application de navigation
  static Future<void> showNavigationDialog(
    BuildContext context,
    List<Waypoint> waypoints,
  ) async {
    if (waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun point de passage configuré pour cette balade'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Trier les waypoints par ordre
    final sortedWaypoints = List<Waypoint>.from(waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Extraire le point de départ et d'arrivée
    final departure = sortedWaypoints.firstWhere(
      (w) => w.type == 'depart',
      orElse: () => sortedWaypoints.first,
    );
    final arrival = sortedWaypoints.firstWhere(
      (w) => w.type == 'arrivee',
      orElse: () => sortedWaypoints.last,
    );
    final checkpoints = sortedWaypoints
        .where((w) => w.type == 'checkpoint')
        .toList();

    // Afficher le dialogue de choix
    final app = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une application de navigation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('Google Maps'),
              subtitle: const Text('Ouvrir avec Google Maps'),
              onTap: () => Navigator.of(context).pop('google_maps'),
            ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.blue),
              title: const Text('Waze'),
              subtitle: Text(
                checkpoints.isNotEmpty
                    ? '⚠️ Destination uniquement\n(${checkpoints.length} point${checkpoints.length > 1 ? 's' : ''} intermédiaire${checkpoints.length > 1 ? 's' : ''} non supporté${checkpoints.length > 1 ? 's' : ''})'
                    : 'Ouvrir avec Waze',
              ),
              onTap: () => Navigator.of(context).pop('waze'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.green),
              title: const Text('Autre application'),
              subtitle: const Text('Choisir parmi les apps installées'),
              onTap: () => Navigator.of(context).pop('other'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (app == null) return;

    switch (app) {
      case 'google_maps':
        await _openGoogleMaps(departure, arrival, checkpoints);
        break;
      case 'waze':
        await _openWaze(departure, arrival, checkpoints, context);
        break;
      case 'other':
        await _openGenericNavigation(departure, arrival, checkpoints);
        break;
    }
  }

  /// Ouvre Google Maps avec les waypoints
  static Future<void> _openGoogleMaps(
    Waypoint departure,
    Waypoint arrival,
    List<Waypoint> checkpoints,
  ) async {
    // Construire l'URL Google Maps avec waypoints
    // Format: https://www.google.com/maps/dir/?api=1&origin=lat,lng&waypoints=lat1,lng1|lat2,lng2&destination=lat,lng
    final origin = '${departure.latitude},${departure.longitude}';
    final destination = '${arrival.latitude},${arrival.longitude}';
    
    String url;
    if (checkpoints.isNotEmpty) {
      // Construire la liste des waypoints (tous les checkpoints + arrivée si nécessaire)
      final waypointsList = <String>[];
      
      // Ajouter tous les checkpoints
      for (var checkpoint in checkpoints) {
        waypointsList.add('${checkpoint.latitude},${checkpoint.longitude}');
      }
      
      final waypointsParam = waypointsList.join('|');
      url =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&waypoints=$waypointsParam&destination=$destination';
    } else {
      // Pas de waypoints intermédiaires, juste départ -> arrivée
      url =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Impossible d\'ouvrir Google Maps');
    }
  }

  /// Ouvre Waze avec les waypoints
  /// Note: Waze ne supporte pas les waypoints multiples dans l'URL comme Google Maps
  /// On ouvre vers la destination finale, l'utilisateur devra ajouter les points intermédiaires manuellement dans Waze
  static Future<void> _openWaze(
    Waypoint departure,
    Waypoint arrival,
    List<Waypoint> checkpoints,
    BuildContext? context,
  ) async {
    // Essayer plusieurs formats d'URL Waze (ordre de priorité)
    // Format correct pour Waze: waze://?ll=lat,lng&navigate=yes
    final urls = [
      // Format 1: waze:// avec coordonnées (Android/iOS natif - format le plus fiable)
      'waze://?ll=${arrival.latitude},${arrival.longitude}&navigate=yes',
      // Format 2: waze:// avec coordonnées (format alternatif)
      'waze://?lat=${arrival.latitude}&lon=${arrival.longitude}&navigate=yes',
      // Format 3: waze:// avec adresse (si les coordonnées ne fonctionnent pas)
      'waze://?q=${Uri.encodeComponent(arrival.address)}&navigate=yes',
      // Format 4: https://waze.com/ul (pour web/fallback)
      'https://waze.com/ul?q=loc:${arrival.latitude},${arrival.longitude}&navigate=yes',
      // Format 5: Alternative avec https://waze.com
      'https://waze.com/ul?ll=${arrival.latitude},${arrival.longitude}&navigate=yes',
    ];

    bool opened = false;
    Exception? lastError;
    
    for (var url in urls) {
      try {
        final uri = Uri.parse(url);
        // Essayer de lancer l'URL directement
        // Note: canLaunchUrl peut retourner false même si l'app est installée,
        // donc on essaie directement launchUrl
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            opened = true;
            break;
          }
        } catch (e) {
          // Si launchUrl échoue avec externalApplication, essayer avec platformDefault
          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.platformDefault,
            );
            if (launched) {
              opened = true;
              break;
            }
          } catch (e2) {
            // Si les deux échouent, vérifier avec canLaunchUrl comme dernier recours
            if (await canLaunchUrl(uri)) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                opened = true;
                break;
              } catch (e3) {
                lastError = e3 is Exception ? e3 : Exception(e3.toString());
                continue;
              }
            } else {
              lastError = e2 is Exception ? e2 : Exception(e2.toString());
              continue;
            }
          }
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Continuer avec le format suivant
        continue;
      }
    }

    if (!opened) {
      // Si aucun format ne fonctionne, essayer avec Google Maps en fallback
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waze n\'est pas installé ou ne peut pas être ouvert. Ouverture avec Google Maps...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await _openGoogleMaps(departure, arrival, checkpoints);
      } else {
        throw lastError ?? Exception('Impossible d\'ouvrir Waze. Veuillez installer l\'application Waze.');
      }
    } else if (context != null && checkpoints.isNotEmpty) {
      // Afficher un dialogue informatif sur les waypoints
      // On attend un peu pour laisser Waze s'ouvrir
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Points intermédiaires'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waze ne supporte pas les waypoints multiples dans l\'URL.\n\n'
                    'Waze a été ouvert vers la destination finale.\n\n'
                    'Points intermédiaires à ajouter manuellement dans Waze :',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...checkpoints.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final checkpoint = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$index. ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  checkpoint.address,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Ouvre une application de navigation générique (utilise les coordonnées)
  static Future<void> _openGenericNavigation(
    Waypoint departure,
    Waypoint arrival,
    List<Waypoint> checkpoints,
  ) async {
    // Utiliser geo: pour ouvrir une app de navigation par défaut
    // Format: geo:lat,lng?q=lat,lng(label)
    final url = 'geo:${arrival.latitude},${arrival.longitude}?q=${arrival.latitude},${arrival.longitude}(${Uri.encodeComponent(arrival.address)})';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: utiliser Google Maps
      await _openGoogleMaps(departure, arrival, checkpoints);
    }
  }

  /// Ouvre directement Google Maps sans dialogue (pour usage rapide)
  static Future<void> openGoogleMapsDirectly(
    List<Waypoint> waypoints,
  ) async {
    if (waypoints.isEmpty) return;

    final sortedWaypoints = List<Waypoint>.from(waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    final departure = sortedWaypoints.firstWhere(
      (w) => w.type == 'depart',
      orElse: () => sortedWaypoints.first,
    );
    final arrival = sortedWaypoints.firstWhere(
      (w) => w.type == 'arrivee',
      orElse: () => sortedWaypoints.last,
    );
    final checkpoints = sortedWaypoints
        .where((w) => w.type == 'checkpoint')
        .toList();

    await _openGoogleMaps(departure, arrival, checkpoints);
  }
}

