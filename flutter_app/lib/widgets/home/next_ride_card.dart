import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import '../../widgets/navigation/navigation_app_selector.dart';
import '../../screens/ride/ride_detail_screen.dart';
import '../../utils/ride_helper.dart';

/// Widget pour la carte "Ma prochaine balade"
/// 
/// Affiche les informations de la prochaine balade avec des CTA contextuels :
/// - Si la balade est "bientôt" (aujourd'hui ou < 2h) : Naviguer est le CTA principal
/// - Sinon : Voir la balade est le CTA principal
class NextRideCard extends StatelessWidget {
  final Ride ride;
  final String locationText;
  final VoidCallback onDataReload;

  const NextRideCard({
    super.key,
    required this.ride,
    required this.locationText,
    required this.onDataReload,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          ride.titre,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Date et heure
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              '${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Lieu de départ
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                locationText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
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
            Icon(Icons.people, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        // Résumé express (si disponible)
        if (expressSummary != null) ...[
          const SizedBox(height: 8),
          Text(
            expressSummary,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Boutons d'action avec CTA contextuel
        _buildActionButtons(context, isSoon),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isSoon) {
    if (isSoon) {
      // CTA principal = Naviguer
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigate(context),
              icon: const Icon(Icons.navigation, size: 20),
              label: const Text(
                'Naviguer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewRide(context),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Voir la balade'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewRide(context), // Chat via detail screen
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // CTA principal = Voir la balade
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _viewRide(context),
              icon: const Icon(Icons.visibility, size: 20),
              label: const Text(
                'Voir la balade',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('Naviguer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewRide(context), // Chat via detail screen
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  void _navigate(BuildContext context) {
    if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => NavigationAppSelector(
          waypoints: ride.waypoints!,
          rideId: ride.id,
          rideName: ride.titre,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun trajet configuré pour cette balade'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _viewRide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideDetailScreen(rideId: ride.id),
      ),
    ).then((_) => onDataReload());
  }
}

