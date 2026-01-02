/// Retourne le nom du fichier background selon la préférence de véhicule de l'utilisateur
/// pour les groupes de discussion
/// Si un background personnalisé est fourni, il est utilisé en priorité
String getBackgroundImageName(String? vehiclePreference, {String? customBackground}) {
  // Utiliser le background personnalisé s'il est fourni
  if (customBackground != null && customBackground.isNotEmpty) {
    return customBackground;
  }
  
  // Sinon, utiliser le background par défaut selon la préférence
  switch (vehiclePreference) {
    case 'moto':
      return 'assets/images/moto_background.png';
    case 'voiture':
      return 'assets/images/car_background.png';
    case 'les deux':
      return 'assets/images/car_moto_background.png';
    default:
      // Par défaut, utiliser moto_background si aucune préférence
      return 'assets/images/moto_background.png';
  }
}

/// Retourne le nom du fichier background pour l'écran d'accueil (balades)
/// Si un background personnalisé est fourni, il est utilisé en priorité
String getBaladeBackgroundImageName(String? vehiclePreference, {String? customBackground}) {
  // Utiliser le background personnalisé s'il est fourni
  if (customBackground != null && customBackground.isNotEmpty) {
    return customBackground;
  }
  
  // Sinon, utiliser le background par défaut selon la préférence
  switch (vehiclePreference) {
    case 'moto':
      return 'assets/images/moto_balade_background.png';
    case 'voiture':
      return 'assets/images/car_balade_background.png';
    case 'les deux':
      return 'assets/images/car_moto_balade_background.png';
    default:
      // Par défaut, utiliser moto_balade_background si aucune préférence
      return 'assets/images/moto_balade_background.png';
  }
}

/// Retourne le nom du fichier background pour l'écran de profil
/// Si un background personnalisé est fourni, il est utilisé en priorité
String getProfilBackgroundImageName(String? vehiclePreference, {String? customBackground}) {
  // Utiliser le background personnalisé s'il est fourni
  if (customBackground != null && customBackground.isNotEmpty) {
    return customBackground;
  }
  
  // Sinon, utiliser le background par défaut selon la préférence
  switch (vehiclePreference) {
    case 'moto':
      return 'assets/images/moto_profil_background.png';
    case 'voiture':
      return 'assets/images/car_profil_background.png';
    case 'les deux':
      return 'assets/images/car_moto_profil_background.png';
    default:
      // Par défaut, utiliser moto_profil_background si aucune préférence
      return 'assets/images/moto_profil_background.png';
  }
}

/// Retourne le nom du fichier background pour l'écran de login
String getLoginBackgroundImageName() {
  // Le background de login est toujours car_moto_login_background.png
  return 'assets/images/car_moto_login_background.png';
}

/// Retourne le background global si défini, sinon null
String? getGlobalBackground({String? customBackground}) {
  if (customBackground != null && customBackground.isNotEmpty) {
    return customBackground;
  }
  return null;
}

