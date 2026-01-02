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
}

