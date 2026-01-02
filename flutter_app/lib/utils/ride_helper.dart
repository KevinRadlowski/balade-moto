/// Helper pour les utilitaires liés aux balades
class RideHelper {
  /// Vérifie si une balade est "bientôt" (aujourd'hui OU démarre dans moins de 2 heures)
  /// 
  /// Retourne true si :
  /// - La balade est aujourd'hui, OU
  /// - La balade démarre dans moins de 2 heures
  static bool isSoon(DateTime rideDateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rideDate = DateTime(rideDateTime.year, rideDateTime.month, rideDateTime.day);
    
    // Si c'est aujourd'hui
    if (rideDate == today) {
      return true;
    }
    
    // Si c'est demain ou plus tard, vérifier si c'est dans moins de 2 heures
    final difference = rideDateTime.difference(now);
    return difference.inHours < 2 && difference.inHours >= 0;
  }
  
  /// Obtient un résumé express d'une balade (1 ligne max)
  /// 
  /// Priorité :
  /// 1. "X points de passage" (si waypoints disponibles)
  /// 2. "Départ : Nom de ville/quartier" (si adresse disponible)
  /// 3. null (si aucune donnée)
  static String? getExpressSummary({
    required List<dynamic>? waypoints,
    required dynamic lieuDepart,
  }) {
    // Priorité 1 : Points de passage
    if (waypoints != null && waypoints.isNotEmpty) {
      final count = waypoints.length;
      if (count == 1) {
        return '1 point de passage';
      } else {
        return '$count points de passage';
      }
    }
    
    // Priorité 2 : Ville/quartier de départ
    if (lieuDepart != null) {
      String address = '';
      if (lieuDepart is String) {
        address = lieuDepart;
      } else if (lieuDepart is Map && lieuDepart['address'] != null) {
        address = lieuDepart['address'].toString();
      }
      
      if (address.isNotEmpty) {
        // Extraire la ville (généralement après la dernière virgule)
        final parts = address.split(',');
        if (parts.length > 1) {
          final city = parts.last.trim();
          // Ne pas afficher si c'est des coordonnées GPS
          if (!city.contains(RegExp(r'^-?\d+\.?\d*$'))) {
            return 'Départ : $city';
          }
        } else {
          // Si pas de virgule, prendre les 2-3 premiers mots
          final words = address.split(' ');
          if (words.length > 3) {
            return 'Départ : ${words[0]} ${words[1]}...';
          } else if (words.isNotEmpty) {
            return 'Départ : ${words[0]}';
          }
        }
      }
    }
    
    // Aucune donnée disponible
    return null;
  }
}


