import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import '../../screens/ride/ride_detail_screen.dart';
import '../../constants/home_style_constants.dart';

/// Widget pour une carte de balade dans la section "Découvrir"
/// 
/// Style compact avec titre, date, distance et bouton "Voir"
class DiscoverPreviewCard extends StatelessWidget {
  final Ride ride;
  final String locationText;
  final VoidCallback onDataReload;

  const DiscoverPreviewCard({
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
    final dateFormat = DateFormat('d MMM', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: HomeStyleConstants.innerCardDecoration,
      child: InkWell(
        onTap: () => _viewRide(context),
        borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
        child: Padding(
          padding: HomeStyleConstants.innerCardPadding,
          child: Row(
            children: [
              // Icône type véhicule
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (ride.typeVehicule == 'moto' ? Colors.orange : Colors.blue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ride.typeVehicule == 'moto' ? Icons.motorcycle : Icons.directions_car,
                  color: ride.typeVehicule == 'moto' ? Colors.orange.shade700 : Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Infos balade
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.titre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(dateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bouton voir
              TextButton(
                onPressed: () => _viewRide(context),
                child: const Text('Voir'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewRide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideDetailScreen(rideId: ride.id),
      ),
    ).then((_) => onDataReload());
  }
}










