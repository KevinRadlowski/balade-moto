import 'dart:io' show Platform;
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Service pour gérer l'authentification biométrique (Face ID, Touch ID, empreinte digitale)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Vérifie si l'authentification biométrique est disponible
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      debugPrint('Biométrie - canCheckBiometrics: $canCheck');
      debugPrint('Biométrie - isDeviceSupported: $isDeviceSupported');
      debugPrint('Biométrie - availableBiometrics: $availableBiometrics');
      
      // La biométrie est disponible si :
      // 1. Le device est supporté, OU
      // 2. On peut vérifier la biométrie, OU
      // 3. Il y a des types biométriques disponibles
      final isAvailable = isDeviceSupported || canCheck || availableBiometrics.isNotEmpty;
      debugPrint('Biométrie - isAvailable: $isAvailable');
      
      return isAvailable;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la disponibilité biométrique: $e');
      return false;
    }
  }

  /// Obtient les types de biométrie disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des types biométriques: $e');
      return [];
    }
  }

  /// Vérifie si Face ID est disponible (iOS uniquement)
  Future<bool> isFaceIdAvailable() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.face);
    } catch (e) {
      debugPrint('Erreur lors de la vérification de Face ID: $e');
      return false;
    }
  }

  /// Vérifie si Touch ID est disponible (iOS uniquement)
  Future<bool> isTouchIdAvailable() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } catch (e) {
      debugPrint('Erreur lors de la vérification de Touch ID: $e');
      return false;
    }
  }

  /// Vérifie si l'empreinte digitale est disponible (Android)
  Future<bool> isFingerprintAvailable() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } catch (e) {
      debugPrint('Erreur lors de la vérification de l\'empreinte digitale: $e');
      return false;
    }
  }

  /// Obtient le nom de la méthode biométrique disponible
  Future<String> getBiometricTypeName() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        // Sur iOS, c'est Touch ID, sur Android c'est empreinte digitale
        if (!kIsWeb && Platform.isAndroid) {
          return 'Empreinte digitale';
        } else if (!kIsWeb && Platform.isIOS) {
          return 'Touch ID';
        }
        return 'Empreinte digitale';
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        return 'Authentification biométrique';
      } else if (availableBiometrics.contains(BiometricType.weak)) {
        return 'Authentification biométrique';
      }
      
      return 'Biométrie';
    } catch (e) {
      debugPrint('Erreur lors de la récupération du nom biométrique: $e');
      return 'Biométrie';
    }
  }

  /// Authentifie l'utilisateur avec la biométrie
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour vous connecter',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final isAvailable = await this.isAvailable();
      if (!isAvailable) {
        debugPrint('L\'authentification biométrique n\'est pas disponible');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Forcer l'utilisation de la biométrie uniquement
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Erreur PlatformException lors de l\'authentification biométrique: $e');
      return false;
    } catch (e) {
      debugPrint('Erreur lors de l\'authentification biométrique: $e');
      return false;
    }
  }

  /// Arrête l'authentification en cours (si stickyAuth est activé)
  Future<bool> stopAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt de l\'authentification: $e');
      return false;
    }
  }
}

