import 'package:flutter/material.dart';
import '../../models/ride.dart';
import '../../screens/ride/ride_detail_screen.dart';
import '../../constants/home_style_constants.dart';
import 'package:intl/intl.dart';

/// Section "Découvrir" améliorée avec aspect social
/// 
/// Affiche des balades suggérées avec :
/// - Mini avatars empilés des participants
/// - Tags contextuels (Populaire, Nouveau, Ce week-end)
/// - Bouton "Voir plus" visible
class DiscoverRidesSection extends StatelessWidget {
  final List<Ride> rides;
  final String Function(Ride) getLocationText;
  final VoidCallback? onDataReload;
  final VoidCallback? onSeeMore;

  const DiscoverRidesSection({
    super.key,
    required this.rides,
    required this.getLocationText,
    this.onDataReload,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.explore, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Découvrir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onSeeMore,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Voir plus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rides.map((ride) => _DiscoverRideCard(
                ride: ride,
                locationText: getLocationText(ride),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideDetailScreen(rideId: ride.id),
                    ),
                  ).then((_) => onDataReload?.call());
                },
              )),
        ],
      ),
    );
  }
}

/// Carte d'une balade dans la section Découvrir
class _DiscoverRideCard extends StatelessWidget {
  final Ride ride;
  final String locationText;
  final VoidCallback onTap;

  const _DiscoverRideCard({
    required this.ride,
    required this.locationText,
    required this.onTap,
  });

  String? _getTag() {
    final now = DateTime.now();
    final rideDateTime = DateTime(
      ride.date.year,
      ride.date.month,
      ride.date.day,
      int.parse(ride.heure.split(':')[0]),
      int.parse(ride.heure.split(':')[1]),
    );
    
    final daysUntil = rideDateTime.difference(now).inDays;
    
    // Nouveau (si la date est dans les prochains jours et récente)
    if (daysUntil >= 0 && daysUntil <= 3 && ride.date.isAfter(now.subtract(const Duration(days: 7)))) {
      return 'Nouveau';
    }
    
    // Ce week-end
    if (daysUntil >= 0 && daysUntil <= 2) {
      final weekday = rideDateTime.weekday;
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        return 'Ce week-end';
      }
    }
    
    // Populaire (si beaucoup de participants)
    if (ride.participants.length >= 5) {
      return 'Populaire';
    }
    
    return null;
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'Nouveau':
        return Colors.blue.shade700;
      case 'Ce week-end':
        return Colors.orange.shade700;
      case 'Populaire':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

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
    final tag = _getTag();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: HomeStyleConstants.innerCardDecoration,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
        child: Padding(
          padding: HomeStyleConstants.innerCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Titre + Tag
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ride.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTagColor(tag).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getTagColor(tag).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTagColor(tag),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Ligne 2 : Date et heure
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Ligne 3 : Lieu
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Ligne 4 : Participants avec avatars empilés
              Row(
                children: [
                  // Avatars empilés
                  _buildStackedAvatars(),
                  const SizedBox(width: 8),
                  // Nombre de participants
                  Text(
                    '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Type de véhicule
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ride.typeVehicule == 'moto'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride.typeVehicule == 'moto' ? '🏍️ Moto' : '🚗 Voiture',
                      style: TextStyle(
                        fontSize: 11,
                        color: ride.typeVehicule == 'moto'
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedAvatars() {
    final participants = ride.participants.take(3).toList();
    final remaining = ride.participants.length - participants.length;

    return SizedBox(
      width: 40,
      height: 24,
      child: Stack(
        children: [
          ...participants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            return Positioned(
              left: index * 14.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    (participant.pseudo != null && participant.pseudo!.isNotEmpty
                        ? participant.pseudo!.substring(0, 1).toUpperCase()
                        : participant.displayName.isNotEmpty
                            ? participant.displayName.substring(0, 1).toUpperCase()
                            : '?'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (remaining > 0)
            Positioned(
              left: participants.length * 14.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade400,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
