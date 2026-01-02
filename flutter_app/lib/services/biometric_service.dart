import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Service pour gérer l'authentification biométrique (Face ID, Touch ID, empreinte digitale)
/// 
/// Gère automatiquement les différences entre plateformes :
/// - Web : biométrie non disponible (pas d'exception)
/// - Mobile (Android/iOS) : utilise local_auth normalement
class BiometricService {
  LocalAuthentication? _localAuth;

  /// Initialise le service (lazy initialization pour éviter les erreurs sur web)
  LocalAuthentication get _auth {
    if (kIsWeb) {
      throw UnsupportedError('local_auth n\'est pas supporté sur le web');
    }
    _localAuth ??= LocalAuthentication();
    return _localAuth!;
  }

  /// Vérifie si l'authentification biométrique est disponible
  /// 
  /// Sur web, retourne toujours false sans lever d'exception.
  /// Sur mobile, vérifie la disponibilité réelle via local_auth.
  Future<bool> isAvailable() async {
    // Sur web, la biométrie n'est jamais disponible
    if (kIsWeb) {
      debugPrint('Biométrie - Non disponible sur le web');
      return false;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      final availableBiometrics = await _auth.getAvailableBiometrics();
      
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
    } on MissingPluginException catch (e) {
      // Ne pas logger en erreur, juste en info
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la vérification: $e');
      return false;
    }
  }

  /// Obtient les types de biométrie disponibles
  /// 
  /// Sur web, retourne toujours une liste vide sans lever d'exception.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return [];
    }

    try {
      return await _auth.getAvailableBiometrics();
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return [];
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la récupération des types: $e');
      return [];
    }
  }

  /// Vérifie si Face ID est disponible (iOS uniquement)
  /// 
  /// Sur web, retourne toujours false.
  Future<bool> isFaceIdAvailable() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.face);
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la vérification de Face ID: $e');
      return false;
    }
  }

  /// Vérifie si Touch ID est disponible (iOS uniquement)
  /// 
  /// Sur web, retourne toujours false.
  Future<bool> isTouchIdAvailable() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la vérification de Touch ID: $e');
      return false;
    }
  }

  /// Vérifie si l'empreinte digitale est disponible (Android)
  /// 
  /// Sur web, retourne toujours false.
  Future<bool> isFingerprintAvailable() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la vérification de l\'empreinte digitale: $e');
      return false;
    }
  }

  /// Obtient le nom de la méthode biométrique disponible
  /// 
  /// Sur web, retourne "Non disponible sur le web".
  Future<String> getBiometricTypeName() async {
    if (kIsWeb) {
      return 'Non disponible sur le web';
    }

    try {
      final availableBiometrics = await getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        // Sur iOS, c'est Touch ID, sur Android c'est empreinte digitale
        // Utiliser une détection de plateforme qui fonctionne sur mobile
        try {
          // Essayer d'utiliser Platform uniquement si on n'est pas sur web
          // Note: Platform.isAndroid/isIOS ne fonctionne pas sur web, donc on utilise une heuristique
          // Si on a fingerprint, on peut supposer Android par défaut (plus commun)
          // iOS aura généralement Face ID en priorité
          return 'Empreinte digitale';
        } catch (_) {
          return 'Empreinte digitale';
        }
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        return 'Authentification biométrique';
      } else if (availableBiometrics.contains(BiometricType.weak)) {
        return 'Authentification biométrique';
      }
      
      return 'Biométrie';
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return 'Biométrie non disponible';
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de la récupération du nom: $e');
      return 'Biométrie';
    }
  }

  /// Authentifie l'utilisateur avec la biométrie
  /// 
  /// Sur web, retourne toujours false sans lever d'exception.
  /// Sur mobile, lance l'authentification biométrique.
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour vous connecter',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    if (kIsWeb) {
      debugPrint('Biométrie - Authentification non disponible sur le web');
      return false;
    }

    try {
      final isAvailable = await this.isAvailable();
      if (!isAvailable) {
        debugPrint('Biométrie - L\'authentification n\'est pas disponible');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Forcer l'utilisation de la biométrie uniquement
        ),
      );
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Biométrie - Erreur PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de l\'authentification: $e');
      return false;
    }
  }

  /// Arrête l'authentification en cours (si stickyAuth est activé)
  /// 
  /// Sur web, retourne toujours false sans lever d'exception.
  Future<bool> stopAuthentication() async {
    if (kIsWeb) {
      return false;
    }

    try {
      return await _auth.stopAuthentication();
    } on MissingPluginException catch (e) {
      debugPrint('Biométrie - Plugin non disponible: $e');
      return false;
    } catch (e) {
      debugPrint('Biométrie - Erreur lors de l\'arrêt: $e');
      return false;
    }
  }
}

