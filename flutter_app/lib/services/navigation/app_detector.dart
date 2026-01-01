import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// Service pour détecter les apps de navigation installées
class AppDetector {
  /// Vérifie si Google Maps est installé
  /// Note: canLaunchUrl peut retourner false même si l'app est installée
  /// On utilise une approche plus permissive sur mobile
  static Future<bool> isGoogleMapsInstalled() async {
    // Sur mobile, on assume que Google Maps est disponible via l'URL web
    // qui fonctionne même si l'app n'est pas installée (ouvre le store)
    if (kIsWeb) {
      // Sur web, Google Maps est toujours disponible via l'URL web
      return true;
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      // Sur mobile, on assume que l'app peut être ouverte
      // Si elle n'est pas installée, l'URL web fonctionnera quand même
      return true;
    }
    
    // Sur desktop, essayer de détecter
    try {
      final uri = Uri.parse('comgooglemaps://');
      return await canLaunchUrl(uri);
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si Waze est installé
  /// Note: canLaunchUrl peut retourner false même si l'app est installée
  static Future<bool> isWazeInstalled() async {
    if (kIsWeb) {
      // Sur web, Waze n'est pas disponible
      return false;
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      // Sur mobile, on assume que Waze peut être installé
      // On essaie de détecter mais on est permissif
      try {
        final uri = Uri.parse('waze://');
        // Essayer canLaunchUrl mais ne pas faire confiance à 100%
        await canLaunchUrl(uri);
        // Si canLaunchUrl retourne false, on assume quand même que c'est possible
        // car l'app peut être installée mais canLaunchUrl peut échouer
        return true; // Permissif : on assume que c'est possible
      } catch (e) {
        // En cas d'erreur, on assume quand même que c'est possible
        return true;
      }
    }
    
    return false;
  }

  /// Vérifie si Apple Plans est disponible (iOS uniquement)
  static bool isApplePlansAvailable() {
    return Platform.isIOS;
  }

  /// Détecte toutes les apps de navigation disponibles
  /// Approche permissive : assume que les apps sont disponibles sur mobile
  static Future<Map<String, bool>> detectAvailableApps() async {
    if (kIsWeb) {
      // Sur web, seule Google Maps (via URL web) est disponible
      return {
        'google_maps': true,
        'waze': false,
        'apple_plans': false,
        'generic': true,
      };
    }
    
    // Sur mobile, on est permissif
    return {
      'google_maps': await isGoogleMapsInstalled(),
      'waze': await isWazeInstalled(),
      'apple_plans': isApplePlansAvailable(),
      'generic': true, // Toujours disponible (geo:)
    };
  }

  /// Obtient l'URL du store pour une app
  static String? getStoreUrl(String appId) {
    switch (appId) {
      case 'google_maps':
        if (Platform.isAndroid) {
          return 'https://play.google.com/store/apps/details?id=com.google.android.apps.maps';
        } else if (Platform.isIOS) {
          return 'https://apps.apple.com/app/google-maps/id585027354';
        }
        break;
      case 'waze':
        if (Platform.isAndroid) {
          return 'https://play.google.com/store/apps/details?id=com.waze';
        } else if (Platform.isIOS) {
          return 'https://apps.apple.com/app/waze-navigation-live/id323229106';
        }
        break;
    }
    return null;
  }
}

