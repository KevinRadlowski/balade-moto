import 'package:flutter/material.dart';

/// Constantes de style réutilisables pour la page d'accueil
/// Assure une cohérence visuelle entre toutes les cards
class HomeStyleConstants {
  // Radius standard des cards
  static const double cardRadius = 16.0;
  static const double innerCardRadius = 12.0;
  
  // Opacité du fond glass
  static const double glassBackgroundOpacity = 0.85;
  static const double innerCardBackgroundOpacity = 0.3;
  
  // Blur (si nécessaire pour un effet glassmorphism plus poussé)
  static const double blurRadius = 10.0;
  
  // Padding standard
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets innerCardPadding = EdgeInsets.all(12.0);
  
  // Border
  static const double borderWidth = 1.0;
  static const double borderOpacity = 0.3;
  
  // Shadow
  static const double shadowOpacity = 0.1;
  static const Offset shadowOffset = Offset(0, 4);
  
  /// Style de card glassmorphism standard
  static BoxDecoration get glassCardDecoration => BoxDecoration(
    color: Colors.white.withOpacity(glassBackgroundOpacity),
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(
      color: Colors.white.withOpacity(borderOpacity),
      width: borderWidth,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(shadowOpacity),
        blurRadius: blurRadius,
        offset: shadowOffset,
      ),
    ],
  );
  
  /// Style de card interne (pour les items dans les sections)
  static BoxDecoration get innerCardDecoration => BoxDecoration(
    color: Colors.white.withOpacity(innerCardBackgroundOpacity),
    borderRadius: BorderRadius.circular(innerCardRadius),
    border: Border.all(
      color: Colors.white.withOpacity(borderOpacity),
      width: borderWidth,
    ),
  );
}





