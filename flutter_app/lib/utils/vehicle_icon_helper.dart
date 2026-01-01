import 'package:flutter/material.dart';

/// Helper pour obtenir l'icône de véhicule selon la préférence
/// 
/// Règles :
/// - "moto" → Icons.motorcycle
/// - "voiture" → Icons.directions_car
/// - "les deux" → Icons.motorcycle (par défaut moto)
/// - null ou autre → Icons.motorcycle (par défaut moto)
IconData getVehicleIcon(String? vehiclePreference) {
  switch (vehiclePreference) {
    case 'voiture':
      return Icons.directions_car;
    case 'moto':
    case 'les deux':
    default:
      return Icons.motorcycle;
  }
}


