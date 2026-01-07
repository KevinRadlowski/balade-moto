import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../exceptions/auth_exception.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage storage;
  final ApiService apiService;

  User? _user;
  bool _isLoading = false;
  bool _isInitializing = true; // Pour _checkAuth() au boot uniquement
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _user?.role == 'ADMIN';

  AuthService({
    required this.storage,
    required this.apiService,
  }) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final token = await storage.read(key: 'token');
      if (token != null) {
        apiService.setToken(token);
        _user = await apiService.getMe();
        _isAuthenticated = true;
      }
    } catch (e) {
      // Ne pas appeler logout() ici car cela pourrait causer des problèmes
      // Juste réinitialiser l'état
      _user = null;
      _isAuthenticated = false;
      apiService.setToken(null);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String pseudo, {String? phone, String? referralCode}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.register(email, password, pseudo, phone: phone, referralCode: referralCode);
      // Retourner les informations sur l'envoi d'email et le parrainage
      return {
        'emailSent': response['emailSent'] ?? true,
        'referralRewardGranted': response['referralRewardGranted'] ?? false,
        'phoneRequiresVerification': response['phoneRequiresVerification'] ?? false,
        'message': response['message'] ?? 'Inscription réussie',
      };
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connexion via OAuth (Google, Apple, Facebook)
  /// Appelle l'API backend une seule fois avec les tokens fournis par SocialAuthService
  Future<void> socialLogin(String provider, Map<String, dynamic> socialData) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Appel unique à l'API backend avec les tokens récupérés par SocialAuthService
      final response = await apiService.socialLogin(
        provider: provider,
        accessToken: socialData['accessToken'],
        idToken: socialData['idToken'],
        firstName: socialData['firstName'],
        lastName: socialData['lastName'],
        email: socialData['email'],
      );
      
      // Vérifier que la réponse contient les données attendues
      if (response['data'] != null) {
        final token = response['data']['token'];
        final refreshToken = response['data']['refreshToken'];
        
        // Sauvegarder les tokens
        await storage.write(key: 'token', value: token);
        await storage.write(key: 'refreshToken', value: refreshToken);
        
        // Mettre à jour l'état d'authentification
        apiService.setToken(token);
        _user = User.fromJson(response['data']['user']);
        _isAuthenticated = true;
        
        // Ne pas lever d'exception en cas de succès (status 200)
        // La navigation sera gérée par l'écran appelant
      } else {
        throw AuthException(
          code: AuthException.unknown,
          message: 'Erreur lors de la connexion : réponse invalide du serveur',
        );
      }
    } catch (e) {
      // Réinitialiser l'état en cas d'erreur
      _isAuthenticated = false;
      _user = null;
      apiService.setToken(null);
      
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        code: AuthException.unknown,
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String identifier, String password, {String? totpCode, bool saveCredentials = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.login(identifier, password, totpCode: totpCode);
      
      if (response['data'] != null) {
        final token = response['data']['token'];
        final refreshToken = response['data']['refreshToken'];
        
        await storage.write(key: 'token', value: token);
        await storage.write(key: 'refreshToken', value: refreshToken);
        
        // Sauvegarder les identifiants si demandé (pour la biométrie)
        if (saveCredentials) {
          await storage.write(key: 'saved_email', value: identifier);
          await storage.write(key: 'saved_password', value: password);
          await storage.write(key: 'biometric_enabled', value: 'true');
        }
        
        apiService.setToken(token);
        _user = User.fromJson(response['data']['user']);
        _isAuthenticated = true;
      } else if (response['requires2FA'] == true) {
        // Nécessite un code 2FA
        throw AuthException(
          code: AuthException.twoFactorRequired,
          message: 'Code 2FA requis',
        );
      } else {
        // Si la réponse ne contient pas de données et pas de 2FA, c'est une erreur
        throw AuthException(
          code: AuthException.unknown,
          message: 'Erreur de connexion: réponse invalide',
        );
      }
    } catch (e) {
      // Si c'est déjà une AuthException, la propager telle quelle
      if (e is AuthException) {
        rethrow;
      }
      // Sinon, wrapper dans une AuthException
      throw AuthException(
        code: AuthException.unknown,
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connexion via biométrie (utilise les identifiants sauvegardés)
  Future<void> loginWithBiometrics() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Récupérer les identifiants sauvegardés
      final savedEmail = await storage.read(key: 'saved_email');
      final savedPassword = await storage.read(key: 'saved_password');

      if (savedEmail == null || savedPassword == null) {
        throw Exception('Aucun identifiant sauvegardé. Veuillez vous connecter manuellement.');
      }

      // Utiliser les identifiants sauvegardés pour se connecter
      await login(savedEmail, savedPassword, saveCredentials: false);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vérifie si la biométrie est activée
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await storage.read(key: 'biometric_enabled');
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Désactive la biométrie (supprime les identifiants sauvegardés)
  Future<void> disableBiometric() async {
    try {
      await storage.delete(key: 'saved_email');
      await storage.delete(key: 'saved_password');
      await storage.delete(key: 'biometric_enabled');
    } catch (e) {
      debugPrint('Erreur lors de la désactivation de la biométrie: $e');
    }
  }

  Future<void> logout({bool keepBiometric = false}) async {
    try {
      await apiService.logout();
    } catch (e) {
      // Continue même si l'API échoue
    }
    
    await storage.delete(key: 'token');
    await storage.delete(key: 'refreshToken');
    
    // Supprimer les identifiants sauvegardés sauf si on veut garder la biométrie
    if (!keepBiometric) {
      await disableBiometric();
    }
    
    apiService.setToken(null);
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> loadUser() async {
    try {
      final token = await storage.read(key: 'token');
      if (token != null) {
        apiService.setToken(token);
        _user = await apiService.getMe();
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      // Ignorer les erreurs
    }
  }

  // Rafraîchir le token automatiquement
  Future<bool> refreshToken() async {
    try {
      final refreshTokenValue = await storage.read(key: 'refreshToken');
      if (refreshTokenValue == null) {
        debugPrint('Aucun refresh token disponible');
        await logout();
        return false;
      }

      final response = await apiService.refreshToken(refreshTokenValue);
      
      if (response['data'] != null) {
        final newToken = response['data']['token'];
        final newRefreshToken = response['data']['refreshToken'];
        
        await storage.write(key: 'token', value: newToken);
        await storage.write(key: 'refreshToken', value: newRefreshToken);
        
        apiService.setToken(newToken);
        debugPrint('Token rafraîchi avec succès');
        return true;
      }
      debugPrint('Réponse de rafraîchissement invalide');
      await logout();
      return false;
    } catch (e) {
      // Si le refresh token est invalide ou expiré, déconnecter l'utilisateur
      debugPrint('Erreur lors du rafraîchissement du token: $e');
      await logout();
      return false;
    }
  }

  void updateUser(User updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  // ==================== OTP TÉLÉPHONE ====================

  /// Envoyer un code OTP par SMS
  Future<void> sendPhoneOtp(String phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.sendPhoneOtp(phone);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vérifier un code OTP
  Future<void> verifyPhoneOtp(String phone, String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.verifyPhoneOtp(phone, code);
      // Rafraîchir les données utilisateur après vérification
      if (_isAuthenticated) {
        await loadUser();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

