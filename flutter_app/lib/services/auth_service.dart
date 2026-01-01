import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage storage;
  final ApiService apiService;

  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthService({
    required this.storage,
    required this.apiService,
  }) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await storage.read(key: 'token');
      if (token != null) {
        apiService.setToken(token);
        _user = await apiService.getMe();
        _isAuthenticated = true;
      }
    } catch (e) {
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, String pseudo) async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.register(email, password, pseudo);
      // Après inscription, l'utilisateur doit vérifier son email
      // Pas de connexion automatique
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password, {String? totpCode, bool saveCredentials = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.login(email, password, totpCode: totpCode);
      
      if (response['data'] != null) {
        final token = response['data']['token'];
        final refreshToken = response['data']['refreshToken'];
        
        await storage.write(key: 'token', value: token);
        await storage.write(key: 'refreshToken', value: refreshToken);
        
        // Sauvegarder les identifiants si demandé (pour la biométrie)
        if (saveCredentials) {
          await storage.write(key: 'saved_email', value: email);
          await storage.write(key: 'saved_password', value: password);
          await storage.write(key: 'biometric_enabled', value: 'true');
        }
        
        apiService.setToken(token);
        _user = User.fromJson(response['data']['user']);
        _isAuthenticated = true;
      } else if (response['requires2FA'] == true) {
        // Nécessite un code 2FA
        throw Exception('2FA_REQUIRED');
      }
    } catch (e) {
      rethrow;
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
}

