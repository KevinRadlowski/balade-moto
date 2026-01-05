import 'package:intl/intl.dart';

class NumberFormatter {
  static final NumberFormat _kmFormat = NumberFormat('#,###', 'fr_FR');
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  /// Formate un nombre de kilomètres avec espaces (ex: 12 345 km)
  static String formatKm(double km) {
    return '${_kmFormat.format(km.toInt())} km';
  }

  /// Formate un nombre de kilomètres sans unité (ex: 12 345)
  static String formatKmNumber(double km) {
    return _kmFormat.format(km.toInt());
  }

  /// Formate un montant en euros (ex: 12 345 €)
  static String formatCurrency(double amount) {
    return '${_currencyFormat.format(amount.toInt())} €';
  }

  /// Formate un nombre entier avec espaces (ex: 12 345)
  static String formatInt(int value) {
    return _kmFormat.format(value);
  }

  /// Formate un kilométrage optionnel (null => "—")
  static String formatKmOptional(int? km) {
    if (km == null) return '—';
    return formatKm(km.toDouble());
  }

  /// Formate une date relative (ex: "Il y a 5 mois", "Aujourd'hui")
  static String formatRelativeDate(DateTime? date) {
    if (date == null) return 'Aucune';

    final now = DateTime.now();
    final difference = now.difference(date);

    // Moins d'un jour
    if (difference.inDays < 1) {
      // Vérifier si c'est aujourd'hui (même jour)
      if (date.year == now.year && 
          date.month == now.month && 
          date.day == now.day) {
        return 'Aujourd\'hui';
      }
      // Sinon, c'est hier
      return 'Hier';
    }

    // Moins de 30 jours
    if (difference.inDays < 30) {
      return 'Il y a ${difference.inDays} ${difference.inDays == 1 ? 'jour' : 'jours'}';
    }

    // Calculer les mois
    final months = (now.year - date.year) * 12 + (now.month - date.month);
    
    // Ajuster si le jour du mois de la date est après le jour actuel
    final adjustedMonths = date.day > now.day ? months - 1 : months;
    
    if (adjustedMonths < 12) {
      return 'Il y a $adjustedMonths ${adjustedMonths == 1 ? 'mois' : 'mois'}';
    }

    // Calculer les années
    final years = now.year - date.year;
    // Ajuster si l'anniversaire n'est pas encore passé cette année
    final adjustedYears = (now.month < date.month || 
                           (now.month == date.month && now.day < date.day)) 
        ? years - 1 
        : years;
    
    return 'Il y a $adjustedYears ${adjustedYears == 1 ? 'an' : 'ans'}';
  }
}





