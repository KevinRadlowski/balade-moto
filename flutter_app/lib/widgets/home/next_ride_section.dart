import 'package:flutter/material.dart';
import '../../models/ride.dart';
import '../../screens/ride/ride_detail_screen.dart';
import '../../screens/ride/create_ride_with_map_screen.dart';
import '../../constants/home_style_constants.dart';
import '../../utils/ride_helper.dart';
import 'package:intl/intl.dart';

/// Section "Ma prochaine balade" améliorée et plus engageante
/// 
/// Affiche :
/// - Si balade existe : carte émotionnelle avec détails + CTA "Voir détails"
/// - Si aucune : empty state humain + CTA "Trouver une balade"
class NextRideSection extends StatelessWidget {
  final Ride? nextRide;
  final String Function(Ride) getLocationText;
  final VoidCallback? onDataReload;

  const NextRideSection({
    super.key,
    this.nextRide,
    required this.getLocationText,
    this.onDataReload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Ma prochaine balade',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nextRide != null)
            _NextRideCard(
              ride: nextRide!,
              locationText: getLocationText(nextRide!),
              onDataReload: onDataReload,
            )
          else
            _NoNextRideCard(),
        ],
      ),
    );
  }
}

/// Carte de la prochaine balade (version améliorée)
class _NextRideCard extends StatelessWidget {
  final Ride ride;
  final String locationText;
  final VoidCallback? onDataReload;

  const _NextRideCard({
    required this.ride,
    required this.locationText,
    this.onDataReload,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime(
      ride.date.year,
      ride.date.month,
      ride.date.day,
      int.parse(ride.heure.split(':')[0]),
      int.parse(ride.heure.split(':')[1]),
    );
    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');
    final isSoon = RideHelper.isSoon(dateTime);
    final expressSummary = RideHelper.getExpressSummary(
      waypoints: ride.waypoints,
      lieuDepart: ride.lieuDepart,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec emoji si bientôt
          Row(
            children: [
              if (isSoon) ...[
                const Text('🚀 ', style: TextStyle(fontSize: 20)),
              ],
              Expanded(
                child: Text(
                  ride.titre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date et heure
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Lieu
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Participants
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          // Résumé express
          if (expressSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      expressSummary,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // CTA principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RideDetailScreen(rideId: ride.id),
                  ),
                ).then((_) => onDataReload?.call());
              },
              icon: const Icon(Icons.visibility, size: 20),
              label: const Text(
                'Voir les détails',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state pour "Aucune balade prévue"
class _NoNextRideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Tu n\'as pas encore de balade prévue',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Rejoins-en une ou proposes la tienne',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateRideWithMapScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Trouver une balade',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
