import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user.dart';
import '../models/ride.dart';
import '../models/vehicle.dart';
import '../models/weather.dart';
import '../models/plan/user_plan.dart';
import '../config/api_config.dart';
import '../exceptions/auth_exception.dart';
import '../exceptions/resend_email_exception.dart';
import '../exceptions/plan_limit_exception.dart';
import 'route_cache_service.dart';

class ApiService {
  static const String baseUrl = ApiConfig.apiUrl;

  String? _token;
  Function()? _onTokenRefresh;

  void setToken(String? token) {
    _token = token;
  }

  void setOnTokenRefresh(Function()? callback) {
    _onTokenRefresh = callback;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Méthode pour rafraîchir le token
  Future<Map<String, dynamic>> refreshToken(String refreshTokenValue) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refreshToken': refreshTokenValue,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du rafraîchissement du token');
    }
  }

  // Callback pour la déconnexion automatique
  Function()? _onTokenExpired;

  void setOnTokenExpired(Function()? callback) {
    _onTokenExpired = callback;
  }

  // Méthode publique pour faire des requêtes GET avec rafraîchissement automatique du token
  Future<http.Response> get(Uri uri) async {
    return _makeRequest(() => http.get(uri, headers: _headers));
  }

  // Méthode publique pour faire des requêtes POST avec rafraîchissement automatique du token
  Future<http.Response> post(Uri uri, {String? body}) async {
    return _makeRequest(() => http.post(
      uri,
      headers: _headers,
      body: body,
    ));
  }

  // Méthode publique pour faire des requêtes PUT avec rafraîchissement automatique du token
  Future<http.Response> put(Uri uri, {String? body}) async {
    return _makeRequest(() => http.put(
      uri,
      headers: _headers,
      body: body,
    ));
  }

  // Méthode publique pour faire des requêtes PATCH avec rafraîchissement automatique du token
  Future<http.Response> patch(Uri uri, {String? body}) async {
    return _makeRequest(() => http.patch(
      uri,
      headers: _headers,
      body: body,
    ));
  }

  // Méthode publique pour faire des requêtes DELETE avec rafraîchissement automatique du token
  Future<http.Response> delete(Uri uri) async {
    return _makeRequest(() => http.delete(uri, headers: _headers));
  }

  // Wrapper pour les requêtes HTTP avec rafraîchissement automatique du token
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFn, {
    bool retryOn401 = true,
  }) async {
    try {
      final response = await requestFn();
      
      // Si le token est expiré (401), essayer de le rafraîchir
      if (response.statusCode == 401 && retryOn401) {
        try {
          final body = jsonDecode(response.body);
          final message = body['message']?.toString().toLowerCase() ?? '';
          
          // Vérifier si c'est une erreur de token expiré/invalide
          if (message.contains('expiré') || 
              message.contains('token invalide') ||
              message.contains('unauthorized') ||
              message.contains('invalid token')) {
            
            // Appeler le callback de rafraîchissement si disponible
            if (_onTokenRefresh != null) {
              try {
                await _onTokenRefresh!();
                // Réessayer la requête avec le nouveau token
                final retryResponse = await requestFn();
                
                // Si la nouvelle requête réussit, retourner la réponse
                if (retryResponse.statusCode != 401) {
                  return retryResponse;
                }
              } catch (e) {
                // Si le rafraîchissement échoue, déconnecter l'utilisateur
                debugPrint('Échec du rafraîchissement du token: $e');
                if (_onTokenExpired != null) {
                  _onTokenExpired!();
                }
                // Retourner la réponse 401 originale
                return response;
              }
            } else {
              // Pas de callback de rafraîchissement, déconnecter directement
              if (_onTokenExpired != null) {
                _onTokenExpired!();
              }
            }
          }
        } catch (e) {
          // Si le parsing échoue, vérifier quand même si c'est un 401
          // et déconnecter si nécessaire
          debugPrint('Erreur lors du parsing de la réponse 401: $e');
          if (_onTokenExpired != null) {
            _onTokenExpired!();
          }
        }
      }

      // Si erreur 403, vérifier si c'est une erreur de limite de plan
      if (response.statusCode == 403) {
        try {
          final json = jsonDecode(response.body);
          final code = json['code'] as String?;
          
          if (code == 'PLAN_LIMIT') {
            throw PlanLimitException.fromJson(json);
          }
        } catch (e) {
          // Si c'est déjà une PlanLimitException, la relancer
          if (e is PlanLimitException) {
            rethrow;
          }
          // Si le parsing échoue, continuer normalement (les autres erreurs 403 restent inchangées)
          debugPrint('Erreur lors du parsing de la réponse 403: $e');
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Authentification
  Future<Map<String, dynamic>> register(String email, String password, String pseudo, {String? phone, String? referralCode}) async {
    final body = {
      'email': email,
      'password': password,
      'pseudo': pseudo,
    };
    
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }
    
    if (referralCode != null && referralCode.isNotEmpty) {
      body['referralCode'] = referralCode;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur d\'inscription');
    }
  }

  Future<Map<String, dynamic>> login(String identifier, String password, {String? totpCode}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          if (totpCode != null) 'totpCode': totpCode,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Extraire le message d'erreur du backend
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          // Si le parsing échoue, utiliser le body brut
          throw AuthException(
            code: AuthException.unknown,
            message: 'Erreur de connexion: ${response.body}',
            statusCode: response.statusCode,
          );
        }
        
        final message = responseData['message'] ?? 'Erreur de connexion';
        
        // Gérer spécifiquement les erreurs 403 (email non vérifié, téléphone non vérifié ou compte banni)
        if (response.statusCode == 403) {
          // Vérifier si c'est un compte banni
          final isBanned = responseData['banned'] == true || 
                          message.toLowerCase().contains('banni') ||
                          message.toLowerCase().contains('banned');
          
          if (isBanned) {
            throw AuthException(
              code: AuthException.accountBanned,
              message: message,
              statusCode: 403,
            );
          }
          
          // Vérifier si c'est une vérification téléphone requise
          final requiresPhoneVerification = responseData['requiresPhoneVerification'] == true ||
                                            message.toLowerCase().contains('téléphone') ||
                                            message.toLowerCase().contains('telephone') ||
                                            message.toLowerCase().contains('phone');
          
          if (requiresPhoneVerification) {
            final phoneE164 = responseData['phoneE164'] as String?;
            throw AuthException(
              code: AuthException.phoneVerificationRequired,
              message: message,
              statusCode: 403,
              phoneE164: phoneE164, // Stocker le numéro de téléphone dans l'exception
            );
          }
          
          // Sinon, c'est probablement un email non vérifié
          throw AuthException(
            code: AuthException.emailNotVerified,
            message: message,
            statusCode: 403,
          );
        }
        
        // Gérer les erreurs 401 (identifiants invalides)
        if (response.statusCode == 401) {
          throw AuthException(
            code: AuthException.invalidCredentials,
            message: message,
            statusCode: 401,
          );
        }
        
        // Pour les autres erreurs, utiliser un code générique
        throw AuthException(
          code: AuthException.unknown,
          message: message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      // Si c'est déjà une AuthException, la relancer telle quelle
      if (e is AuthException) {
        rethrow;
      }
      // Si c'est une Exception, la convertir en AuthException
      if (e is Exception) {
        throw AuthException(
          code: AuthException.unknown,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
      // Sinon, wrapper dans une AuthException
      throw AuthException(
        code: AuthException.unknown,
        message: e.toString(),
      );
    }
  }

  /// Connexion via OAuth (Google, Apple, Facebook)
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String? accessToken,
    String? idToken,
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      // Construire le body selon le provider
      final body = <String, dynamic>{};
      
      // Pour Google, préférer l'idToken (JWT) mais accepter l'accessToken en fallback
      // ⚠️ PROBLÈME CONNU : Sur Flutter Web, google_sign_in ne retourne pas toujours l'idToken
      if (provider == 'google') {
        if (idToken != null && idToken.isNotEmpty) {
          // Préférer l'idToken (JWT) si disponible
          body['idToken'] = idToken;
        } else if (accessToken != null && accessToken.isNotEmpty) {
          // Fallback : utiliser l'accessToken si l'idToken n'est pas disponible (cas Flutter Web)
          body['accessToken'] = accessToken;
        } else {
          throw Exception('ID Token ou Access Token Google requis pour l\'authentification');
        }
      } else {
        // Pour les autres providers (Apple, Facebook), utiliser accessToken ou idToken selon le cas
        if (accessToken != null) {
          body['accessToken'] = accessToken;
        }
        if (idToken != null) {
          body['idToken'] = idToken;
        }
        if (firstName != null) {
          body['firstName'] = firstName;
        }
        if (lastName != null) {
          body['lastName'] = lastName;
        }
        if (email != null) {
          body['email'] = email;
        }
      }
      
      // 🔍 DEBUG : Log de la charge utile envoyée (sans afficher les tokens complets)
      final bodyForLog = <String, dynamic>{};
      if (body.containsKey('idToken')) {
        final token = body['idToken'] as String;
        bodyForLog['idToken'] = token.length > 10 ? '${token.substring(0, 10)}...' : '${token}...';
      }
      if (body.containsKey('accessToken')) {
        final token = body['accessToken'] as String;
        bodyForLog['accessToken'] = token.length > 10 ? '${token.substring(0, 10)}...' : '${token}...';
      }
      if (body.containsKey('firstName')) bodyForLog['firstName'] = body['firstName'];
      if (body.containsKey('lastName')) bodyForLog['lastName'] = body['lastName'];
      if (body.containsKey('email')) bodyForLog['email'] = body['email'];
      
      debugPrint('🔍 [DEBUG API] Requête POST vers: $baseUrl/auth/social/$provider');
      debugPrint('🔍 [DEBUG API] Headers: ${_headers.toString()}');
      debugPrint('🔍 [DEBUG API] Body (masqué): $bodyForLog');
      debugPrint('🔍 [DEBUG API] Content-Type présent: ${_headers.containsKey('Content-Type')}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/$provider'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Le serveur ne répond pas. Vérifiez que le serveur backend est démarré et accessible à $baseUrl');
        },
      );

      // 🔍 DEBUG : Logs de la réponse HTTP
      debugPrint('🔍 [DEBUG API] Réponse HTTP reçue:');
      debugPrint('   - Status Code: ${response.statusCode}');
      debugPrint('   - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Parser le JSON pour extraire le message d'erreur
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? response.body;
          debugPrint('🔍 [DEBUG API] Erreur parsée: $errorMessage');
          
          // Vérifier si c'est un compte banni
          if (response.statusCode == 403) {
            final isBanned = errorData['banned'] == true || 
                            errorMessage.toLowerCase().contains('banni') ||
                            errorMessage.toLowerCase().contains('banned');
            
            if (isBanned) {
              throw AuthException(
                code: AuthException.accountBanned,
                message: errorMessage,
                statusCode: 403,
              );
            }
          }
          
          throw Exception(errorMessage);
        } catch (e) {
          // Si c'est déjà une AuthException, la relancer
          if (e is AuthException) {
            rethrow;
          }
          // Si le parsing échoue, utiliser directement response.body
          if (e is FormatException) {
            debugPrint('🔍 [DEBUG API] Erreur de parsing JSON, utilisation de response.body brut');
            throw Exception(response.body);
          }
          rethrow;
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout de connexion: $e');
      throw Exception('Le serveur ne répond pas dans les temps. Vérifiez que le serveur backend est démarré et accessible à $baseUrl');
    } on http.ClientException catch (e) {
      debugPrint('Erreur client HTTP: $e');
      final errorMessage = e.message.toLowerCase();
      if (errorMessage.contains('connection') && errorMessage.contains('timeout')) {
        throw Exception('Le serveur ne répond pas. Vérifiez que le serveur backend est démarré et accessible à $baseUrl');
      } else if (errorMessage.contains('failed to fetch')) {
        throw Exception('Impossible de contacter le serveur. Vérifiez que le serveur backend est démarré et accessible à $baseUrl');
      }
      rethrow;
    } catch (e) {
      debugPrint('Erreur lors de la connexion OAuth: $e');
      // Vérifier si c'est une erreur de connexion
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') || 
          errorString.contains('timeout') || 
          errorString.contains('failed to fetch') ||
          errorString.contains('network')) {
        throw Exception('Impossible de se connecter au serveur. Vérifiez que le serveur backend est démarré et accessible à $baseUrl');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
    } catch (e) {
      // Ignorer les erreurs de logout (token expiré, etc.)
      // Le logout local sera effectué de toute façon
      debugPrint('Erreur lors du logout (ignorée): $e');
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: _headers,
      body: jsonEncode({
        'token': token,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la vérification de l\'email');
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    // Endpoint public, ne pas utiliser le token
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-verification'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseData;
    } else if (response.statusCode == 429) {
      // Erreur de cooldown - retourner retryAfter dans la réponse pour que le frontend puisse l'utiliser
      final retryAfter = responseData['retryAfter'] as int?;
      final message = responseData['message'] ?? 'Veuillez attendre avant de renvoyer l\'email';
      
      // Créer une exception personnalisée qui contient retryAfter
      throw ResendEmailException(
        message: message,
        retryAfter: retryAfter,
      );
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors du renvoi de l\'email');
    }
  }

  // Demander la réinitialisation du mot de passe
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    // Endpoint public, ne pas utiliser le token
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors de la demande de réinitialisation');
    }
  }

  // Réinitialiser le mot de passe avec le token
  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    // Endpoint public, ne pas utiliser le token
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': token,
        'newPassword': newPassword,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors de la réinitialisation du mot de passe');
    }
  }

  // Changer le mot de passe (utilisateur connecté)
  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final response = await post(
      Uri.parse('$baseUrl/user/change-password'),
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors du changement de mot de passe');
    }
  }

  /// Envoyer un email de contact au support
  Future<Map<String, dynamic>> sendContactEmail({
    required String email,
    required String subject,
    required String message,
  }) async {
    // Endpoint public, ne pas utiliser le token
    // Utiliser apiBaseUrl au lieu de baseUrl car /contact n'est pas sous /api
    final apiBaseUrl = baseUrl.replaceAll('/api', '');
    final response = await http.post(
      Uri.parse('$apiBaseUrl/contact'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'subject': subject,
        'message': message,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du message');
    }
  }

  Future<User> getMe() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['data']['user']);
    } else {
      throw Exception('Erreur lors de la récupération du profil');
    }
  }

  /// Récupère le plan de l'utilisateur connecté
  /// Utiliser un code promotionnel
  /// POST /api/users/me/promo-codes/redeem
  Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/users/me/promo-codes/redeem'),
        headers: _headers,
        body: jsonEncode({
          'code': code.trim().toUpperCase(),
        }),
      );
    });

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseData['data'] ?? {};
    } else {
      final message = responseData['message'] ?? 'Erreur lors de l\'utilisation du code promotionnel';
      throw Exception(message);
    }
  }

  /// Générer des codes promotionnels (admin)
  /// POST /api/admin/promo-codes/generate
  Future<Map<String, dynamic>> generatePromoCodes({
    required String type,
    required int count,
    int? discountPercent,
    int? premiumMonths,
    int? usageLimit,
    DateTime? validFrom,
    DateTime? validUntil,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'count': count,
    };

    if (discountPercent != null) {
      body['discountPercent'] = discountPercent;
    }
    if (premiumMonths != null) {
      body['premiumMonths'] = premiumMonths;
    }
    if (usageLimit != null) {
      body['usageLimit'] = usageLimit;
    }
    if (validFrom != null) {
      body['validFrom'] = validFrom.toIso8601String();
    }
    if (validUntil != null) {
      body['validUntil'] = validUntil.toIso8601String();
    }
    if (metadata != null) {
      body['metadata'] = metadata;
    }

    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/admin/promo-codes/generate'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return responseData['data'] ?? {};
    } else {
      final message = responseData['message'] ?? 'Erreur lors de la génération des codes promotionnels';
      final errors = responseData['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        final errorMessages = errors.map((e) => e['message'] ?? '').join(', ');
        throw Exception(errorMessages);
      }
      throw Exception(message);
    }
  }

  Future<UserPlan> getMyPlan() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/me/plan'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Si la réponse est { success:true, data:{...} }, utiliser data['data']
      // Si la réponse est directement { plan:..., limits:..., usage:... }, utiliser l'objet root
      // Ne jamais parser data['data']['plan'] (string) comme objet
      final planData = data['data'] ?? data;
      return UserPlan.fromJson(planData);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du plan');
    }
  }

  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? pseudo,
    String? email,
    String? vehiclePreference,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (pseudo != null) body['pseudo'] = pseudo;
    if (email != null) body['email'] = email;
    if (vehiclePreference != null) body['vehiclePreference'] = vehiclePreference;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/user/update-profile'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['data']['user']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du profil');
    }
  }

  // Uploader un background personnalisé
  Future<Map<String, dynamic>> uploadBackground({
    required dynamic imageFile,
    required String type, // balade, groupe, profil, global
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/user/upload-background'),
    );

    // Ajouter le token d'authentification
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // Ajouter le type de background
    request.fields['type'] = type;

    // Ajouter le fichier selon le type
    try {
      if (kIsWeb) {
        // Sur le web, utiliser bytes
        Uint8List bytes;
        String fileName;
        
        if (imageFile is PlatformFile) {
          if (imageFile.bytes == null || imageFile.bytes!.isEmpty) {
            throw Exception('Impossible de lire le fichier (bytes null ou vide)');
          }
          bytes = imageFile.bytes!;
          fileName = imageFile.name;
        } else {
          throw Exception('Type de fichier non supporté sur le web');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'background',
            bytes,
            filename: fileName,
          ),
        );
      } else {
        // Sur mobile, utiliser le chemin du fichier
        String filePath;
        if (imageFile is String) {
          filePath = imageFile;
        } else {
          throw Exception('Type de fichier non supporté');
        }

        request.files.add(
          await http.MultipartFile.fromPath('background', filePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'upload du background');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'upload du background: $e');
    }
  }

  // Supprimer un background personnalisé
  Future<void> deleteAccount() async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/user/delete-account'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du compte');
    }
  }

  Future<void> deleteBackground(String type) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/user/delete-background/$type'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du background');
    }
  }

  Future<String> uploadAvatar(dynamic imageFile) async {
    // Préparer le fichier selon le type
    String filePath;
    
    try {
      if (imageFile is String) {
        // Si c'est un chemin de fichier
        filePath = imageFile;
      } else if (!kIsWeb) {
        // Sur mobile uniquement, on peut avoir un io.File (qui est dart:io.File)
        // Utiliser la méthode toString() ou accéder à path si disponible
        if (imageFile is io.File) {
          filePath = (imageFile as dynamic).path;
        } else {
          throw Exception('Type de fichier non supporté sur mobile. Utilisez un File ou un chemin de fichier.');
        }
      } else {
        throw Exception('Cette méthode ne peut pas être utilisée sur le web. Utilisez _uploadImageFromBytes.');
      }
    } catch (e) {
      throw Exception('Erreur lors de la préparation du fichier: $e');
    }

    // Vérifier que le token est disponible
    if (_token == null || _token!.isEmpty) {
      throw Exception('Token d\'authentification manquant');
    }

    // Créer la requête multipart
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/user/upload-avatar'),
    );

    // Ajouter le token d'authentification
    request.headers['Authorization'] = 'Bearer $_token';

    // Ajouter le fichier
    request.files.add(
      await http.MultipartFile.fromPath('avatar', filePath),
    );

    // Envoyer la requête
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Gérer les erreurs d'authentification
    if (response.statusCode == 401) {
      // Essayer de rafraîchir le token si possible
      if (_onTokenRefresh != null) {
        try {
          await _onTokenRefresh!();
          // Réessayer avec le nouveau token
          var retryRequest = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/user/upload-avatar'),
          );
          retryRequest.headers['Authorization'] = 'Bearer $_token';
          retryRequest.files.add(
            await http.MultipartFile.fromPath('avatar', filePath),
          );
          final retryStreamedResponse = await retryRequest.send();
          final retryResponse = await http.Response.fromStream(retryStreamedResponse);
          
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            final avatarUrl = data['data']?['avatarUrl'];
            if (avatarUrl == null || avatarUrl.isEmpty) {
              throw Exception('L\'URL de l\'avatar retournée est vide');
            }
            return avatarUrl;
          }
        } catch (e) {
          if (_onTokenExpired != null) {
            _onTokenExpired!();
          }
        }
      }
      throw Exception('Token d\'authentification expiré ou invalide');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final avatarUrl = data['data']?['avatarUrl'];
      if (avatarUrl == null || avatarUrl.isEmpty) {
        throw Exception('L\'URL de l\'avatar retournée est vide');
      }
      return avatarUrl;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'upload de l\'avatar');
    }
  }

  // Balades
  Future<Map<String, dynamic>> getRides({
    String? typeVehicule,
    String? dateDebut,
    String? dateFin,
    String? search,
    double? latitude,
    double? longitude,
    double? rayon,
    String? sortBy,
    String? sortOrder,
    String? participant,
    String? organisateur,
    String? visibilite,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (typeVehicule != null) 'typeVehicule': typeVehicule,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (search != null) 'search': search,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (participant != null) 'participant': participant,
      if (organisateur != null) 'organisateur': organisateur,
      if (visibilite != null) 'visibilite': visibilite,
    };
    
    // Ajouter les paramètres géographiques si rayon > 0
    if (rayon != null && rayon > 0 && latitude != null && longitude != null) {
      queryParams['lat'] = latitude.toString();
      queryParams['lng'] = longitude.toString();
      queryParams['rayon'] = rayon.toString();
    }

    final uri = Uri.parse('$baseUrl/rides').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'rides': (data['data']['rides'] as List)
            .map((r) => Ride.fromJson(r))
            .toList(),
        'pagination': data['data']['pagination'],
      };
    } else {
      throw Exception('Erreur lors de la récupération des balades');
    }
  }

  Future<List<Ride>> getCalendar({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };

    final uri = Uri.parse('$baseUrl/rides/calendar').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['events'] as List)
          .map((e) => Ride.fromJson(e))
          .toList();
    } else {
      throw Exception('Erreur lors de la récupération du calendrier');
    }
  }

  Future<Ride> getRideById(String id) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$id'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      throw Exception('Erreur lors de la récupération de la balade');
    }
  }

  // Créer une balade
  /// Récupère les véhicules de l'utilisateur
  /// GET /api/garage/vehicles?type=moto|voiture
  Future<List<Vehicle>> getVehicles({String? type}) async {
    final queryParams = <String, String>{};
    if (type != null) {
      queryParams['type'] = type;
    }
    
    final uri = Uri.parse('$baseUrl/garage/vehicles').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final vehiclesList = data['data']['vehicles'] as List;
      return vehiclesList.map((v) => Vehicle.fromJson(v)).toList();
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des véhicules');
    }
  }

  Future<Ride> createRide({
    required String titre,
    String? description,
    required String typeVehicule,
    required String date,
    required String heure,
    required String lieuDepart,
    required String lieuArrivee,
    double rayon = 0,
    String visibilite = 'publique',
    String? ridingStyle,
    Map<String, dynamic>? localisation,
    List<Map<String, dynamic>>? waypoints, // Nouveau système de waypoints
    String? vehicleId, // ID du véhicule avec lequel l'organisateur effectue la balade
    String? groupId, // ID du groupe si la balade est créée depuis un groupe
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides'),
        headers: _headers,
        body: jsonEncode({
          'titre': titre,
          if (description != null && description.isNotEmpty) 'description': description,
          'typeVehicule': typeVehicule,
          'date': date,
          'heure': heure,
          'lieuDepart': lieuDepart,
          'lieuArrivee': lieuArrivee,
          'rayon': rayon,
          'visibilite': visibilite,
          if (ridingStyle != null) 'ridingStyle': ridingStyle,
          if (localisation != null) 'localisation': localisation,
          if (waypoints != null && waypoints.isNotEmpty) 'waypoints': waypoints,
          if (vehicleId != null) 'vehicleId': vehicleId,
          if (groupId != null) 'groupId': groupId,
        }),
      );
    });

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la création de la balade');
    }
  }

  // Géocoder une adresse (convertir en coordonnées GPS)
  Future<Map<String, dynamic>> geocodeAddress(String address) async {
    final queryParams = <String, String>{
      'address': address,
    };

    final uri = Uri.parse('$baseUrl/rides/geocode').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du géocodage de l\'adresse');
    }
  }

  // Géocodage inverse (coordonnées -> adresse)
  Future<Map<String, dynamic>> reverseGeocode(double latitude, double longitude) async {
    final queryParams = <String, String>{
      'lat': latitude.toString(),
      'lng': longitude.toString(),
    };

    final uri = Uri.parse('$baseUrl/rides/reverse-geocode').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du géocodage inverse');
    }
  }

  // Places Autocomplete
  Future<Map<String, dynamic>> placesAutocomplete(String input) async {
    final queryParams = <String, String>{
      'input': input,
    };

    final uri = Uri.parse('$baseUrl/rides/places/autocomplete').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'autocomplete Places');
    }
  }

  // Place Details
  Future<Map<String, dynamic>> placeDetails(String placeId) async {
    final queryParams = <String, String>{
      'placeId': placeId,
    };

    final uri = Uri.parse('$baseUrl/rides/places/details').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des détails du lieu');
    }
  }

  // Rechercher des balades proches
  Future<List<Ride>> getRidesNearby({
    required double latitude,
    required double longitude,
    double rayon = 10,
    String? typeVehicule,
    String? dateDebut,
    String? dateFin,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'rayon': rayon.toString(),
      'limit': limit.toString(),
      if (typeVehicule != null) 'typeVehicule': typeVehicule,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };

    final uri = Uri.parse('$baseUrl/rides/proches').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['rides'] as List)
          .map((r) => Ride.fromJson(r))
          .toList();
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la recherche de balades proches');
    }
  }

  // Récupérer les balades passées
  Future<List<Ride>> getPastRides({
    String? typeVehicule,
    String? dateFin,
    String? search,
    String sortBy = 'date',
    String sortOrder = 'desc',
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (typeVehicule != null) queryParams['typeVehicule'] = typeVehicule;
    if (dateFin != null) queryParams['dateFin'] = dateFin;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/rides/past').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['rides'] as List)
          .map((r) => Ride.fromJson(r))
          .toList();
    } else {
      throw Exception('Erreur lors de la récupération des balades passées');
    }
  }

  // Récupérer mes balades passées (auxquelles j'ai participé)
  Future<List<Ride>> getMyPastRides({
    String? typeVehicule,
    String? dateFin,
    String? search,
    String sortBy = 'date',
    String sortOrder = 'desc',
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (typeVehicule != null) queryParams['typeVehicule'] = typeVehicule;
    if (dateFin != null) queryParams['dateFin'] = dateFin;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/rides/my-past').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['rides'] as List)
          .map((r) => Ride.fromJson(r))
          .toList();
    } else {
      throw Exception('Erreur lors de la récupération de mes balades passées');
    }
  }

  Future<void> inviteUsersToRide(String rideId, List<String> userIds) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/rides/$rideId/invite'),
        headers: _headers,
        body: jsonEncode({
          'userIds': userIds,
        }),
      ),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi des invitations');
    }
  }

  Future<void> acceptRideInvitation(String rideId, {String? vehicleId}) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/rides/$rideId/invitations/accept'),
        headers: _headers,
        body: jsonEncode({
          if (vehicleId != null) 'vehicleId': vehicleId,
        }),
      ),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'acceptation de l\'invitation');
    }
  }

  Future<void> declineRideInvitation(String rideId) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('$baseUrl/rides/$rideId/invitations/decline'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du refus de l\'invitation');
    }
  }

  /// Rejoindre une balade
  /// Retourne un Map avec 'status': 'joined' | 'pending_approval' | 'waitlisted'
  /// et potentiellement 'position' pour waitlisted
  Future<Map<String, dynamic>> joinRide(String id, {String? vehicleId}) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$id/join'),
        headers: _headers,
        body: jsonEncode({
          if (vehicleId != null) 'vehicleId': vehicleId,
        }),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'message': data['message'] ?? 'Succès',
        'status': data['data']?['status'] ?? 'joined',
        'position': data['data']?['position'],
      };
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Erreur lors de la participation');
    }
  }

  // Reviews
  Future<Map<String, dynamic>> createOrUpdateReview({
    required String rideId,
    required int rating,
    String? comment,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/reviews/rides/$rideId'),
        headers: _headers,
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'enregistrement de la review');
    }
  }

  Future<Map<String, dynamic>> getRideReviews(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/reviews/rides/$rideId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des reviews');
    }
  }

  Future<Map<String, dynamic>> hasUserReviewed(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/reviews/rides/$rideId/check'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la vérification');
    }
  }

  Future<void> leaveRide(String id) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/rides/$id/join'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Erreur lors de la sortie de la balade');
    }
  }

  // ========== OUTILS ORGANISATEUR ==========

  /// Mettre à jour les paramètres organisateur d'une balade
  Future<Map<String, dynamic>> updateOrganizerSettings(
    String rideId, {
    bool? requiresApproval,
    int? maxParticipants,
    bool? enableWaitlist,
    Map<String, dynamic>? autoReminder,
    Map<String, dynamic>? recurrence,
  }) async {
    final body = <String, dynamic>{};
    if (requiresApproval != null) body['requiresApproval'] = requiresApproval;
    if (maxParticipants != null) body['maxParticipants'] = maxParticipants;
    if (enableWaitlist != null) body['enableWaitlist'] = enableWaitlist;
    if (autoReminder != null) body['autoReminder'] = autoReminder;
    if (recurrence != null) body['recurrence'] = recurrence;

    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/rides/$rideId/organizer-settings'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour des paramètres');
    }
  }

  /// Demander à rejoindre une balade (avec validation manuelle)
  Future<Map<String, dynamic>> requestToJoinRide(String rideId, {String? vehicleId, String? message}) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/request-join'),
        headers: _headers,
        body: jsonEncode({
          if (vehicleId != null) 'vehicleId': vehicleId,
          if (message != null) 'message': message,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la demande');
    }
  }

  /// Obtenir les demandes en attente
  Future<Map<String, dynamic>> getPendingRequests(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/pending-requests'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des demandes');
    }
  }

  /// Approuver une demande de participation
  Future<void> approveJoinRequest(String rideId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/pending-requests/$userId/approve'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'approbation');
    }
  }

  /// Refuser une demande de participation
  Future<void> rejectJoinRequest(String rideId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/pending-requests/$userId/reject'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du refus');
    }
  }

  /// Obtenir la liste d'attente
  Future<Map<String, dynamic>> getWaitlist(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/waitlist'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération de la liste d\'attente');
    }
  }

  /// Promouvoir un utilisateur de la liste d'attente
  Future<void> promoteFromWaitlist(String rideId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/waitlist/$userId/promote'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la promotion');
    }
  }

  /// Retirer un utilisateur de la liste d'attente
  Future<void> removeFromWaitlist(String rideId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/rides/$rideId/waitlist/$userId'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du retrait');
    }
  }

  /// Créer la prochaine occurrence d'une balade récurrente
  Future<Map<String, dynamic>> createNextOccurrence(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/create-next-occurrence'),
        headers: _headers,
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la création');
    }
  }

  /// Envoyer un rappel aux participants
  Future<Map<String, dynamic>> sendRideReminder(String rideId, {String? message}) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/send-reminder'),
        headers: _headers,
        body: jsonEncode({
          if (message != null) 'message': message,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du rappel');
    }
  }

  // ========== FONCTIONS AVANCÉES ==========

  /// Exporter une balade en format GPX
  Future<String> exportRideGPX(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/export/gpx'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      // Le backend retourne le fichier GPX en texte
      return response.body;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'export GPX');
    }
  }

  /// Exporter une balade en format PDF
  Future<Uint8List> exportRidePDF(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/export/pdf'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      // Le backend retourne le PDF en bytes
      return response.bodyBytes;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'export PDF');
    }
  }

  /// Mettre à jour la visibilité d'une balade (pour le mode secret)
  /// Retourne le secretLink si le mode secret est activé
  Future<Map<String, dynamic>> updateRideVisibility(String rideId, String visibility) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/rides/$rideId/visibility'),
        headers: _headers,
        body: jsonEncode({'visibilite': visibility}),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'secretLink': data['data']?['secretLink'],
        'ride': data['data']?['ride'],
      };
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour de la visibilité');
    }
  }

  // ========== WAYPOINTS API ==========
  
  /// Ajouter ou modifier un waypoint
  Future<Ride> addOrUpdateWaypoint(String rideId, Map<String, dynamic> waypoint) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/rides/$rideId/waypoints'),
        headers: _headers,
        body: jsonEncode({'waypoint': waypoint}),
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du waypoint');
    }
  }

  /// Supprimer un waypoint
  Future<Ride> deleteWaypoint(String rideId, String waypointId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/rides/$rideId/waypoints/$waypointId'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du waypoint');
    }
  }

  /// Obtenir le résumé des waypoints
  Future<Map<String, dynamic>> getWaypointSummary(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/waypoint-summary'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['waypointSummary'];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du résumé');
    }
  }

  // ========== DANGER REPORTS API ==========
  
  /// Signaler un danger
  Future<Map<String, dynamic>> reportDanger(String rideId, {
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/waypoints/danger-report'),
        headers: _headers,
        body: jsonEncode({
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude]
          },
          'description': description,
        }),
      );
    });
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du signalement');
    }
  }

  /// Lister les signalements de danger
  Future<List<dynamic>> getDangerReports(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/danger-reports'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['reports'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des signalements');
    }
  }

  /// Approuver un signalement (organisateur)
  Future<Map<String, dynamic>> approveDangerReport(String reportId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/danger-reports/$reportId/approve'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'approbation');
    }
  }

  /// Rejeter un signalement (organisateur)
  Future<Map<String, dynamic>> rejectDangerReport(String reportId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/danger-reports/$reportId/reject'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du rejet');
    }
  }

  /// Promouvoir un signalement en waypoint (organisateur)
  Future<Ride> promoteDangerReportToWaypoint(String reportId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/danger-reports/$reportId/promote'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la promotion');
    }
  }

  // ========== ANNULATION / REPORT / REPROGRAMMATION API ==========

  /// Annuler une balade
  Future<Ride> cancelRide(String rideId, {
    required String reasonCode,
    String? reasonText,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/cancel'),
        headers: _headers,
        body: jsonEncode({
          'reasonCode': reasonCode,
          if (reasonText != null) 'reasonText': reasonText,
        }),
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'annulation');
    }
  }

  /// Reporter une balade
  Future<Ride> postponeRide(String rideId, {
    required String reasonCode,
    String? reasonText,
    DateTime? newDateTime,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/postpone'),
        headers: _headers,
        body: jsonEncode({
          'reasonCode': reasonCode,
          if (reasonText != null) 'reasonText': reasonText,
          if (newDateTime != null) 'newDateTime': newDateTime.toIso8601String(),
        }),
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du report');
    }
  }

  /// Reprogrammer une balade (créer une nouvelle balade)
  Future<Ride> rescheduleRide(String rideId, {
    required DateTime newDateTime,
    bool keepVisibility = true,
    bool keepParticipants = false,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/reschedule'),
        headers: _headers,
        body: jsonEncode({
          'newDateTime': newDateTime.toIso8601String(),
          'keepVisibility': keepVisibility,
          'keepParticipants': keepParticipants,
        }),
      );
    });
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la reprogrammation');
    }
  }

  // ========== MÉTÉO API ==========

  /// Récupérer la météo pour une balade (départ et arrivée)
  Future<RideWeather?> getRideWeather(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/rides/$rideId/weather'),
        headers: _headers,
      );
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return RideWeather.fromJson(data['data']);
    } else if (response.statusCode == 503) {
      // Service météo indisponible (clé API non configurée)
      final errorData = jsonDecode(response.body);
      debugPrint('Service météo indisponible: ${errorData['message']}');
      return null; // Retourner null au lieu de throw
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération de la météo');
    }
  }

  /// Mettre à jour une balade (uniquement par l'organisateur)
  /// Permet de modifier le titre et la description
  Future<Ride> updateRide(String rideId, {String? titre, String? description}) async {
    final Map<String, dynamic> body = {};
    if (titre != null) body['titre'] = titre;
    if (description != null) body['description'] = description;

    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/rides/$rideId'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Ride.fromJson(data['data']['ride']);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour de la balade');
    }
  }

  // Supprimer une balade (uniquement par l'organisateur)
  Future<void> deleteRide(String id) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/rides/$id'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression de la balade');
    }
  }

  Future<void> likeRide(String id) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$id/like'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Erreur lors du like');
    }
  }

  Future<void> rateRide(String id, double note) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$id/note'),
        headers: _headers,
        body: jsonEncode({'note': note}),
      );
    });

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Erreur lors de la notation');
    }
  }

  // Indiquer son arrivée au lieu de départ (pour un participant)
  Future<Map<String, dynamic>> markArrival(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/arrival'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'enregistrement de l\'arrivée');
    }

    return jsonDecode(response.body);
  }

  // Valider/invalider la ponctualité d'un participant (pour l'organisateur)
  Future<Map<String, dynamic>> validatePunctuality(String rideId, String userId, bool isOnTime) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/participants/$userId/validate-punctuality'),
        headers: _headers,
        body: jsonEncode({'isOnTime': isOnTime}),
      );
    });

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la validation de la ponctualité');
    }

    return jsonDecode(response.body);
  }

  // Groupes
  Future<Map<String, dynamic>> getGroups({
    String? scope,
    String? q,
    String? owner,
    String? visibilite,
    String? region,
    String? departmentCode,
    String? city,
    double? nearLat,
    double? nearLng,
    double? nearKm,
    int page = 1,
    int limit = 20,
    // Paramètre legacy pour compatibilité
    String? membre,
  }) async {
    // Construire les query parameters (ignorer ceux qui sont null)
    final queryParams = <String, String>{};
    
    if (scope != null) queryParams['scope'] = scope;
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (owner != null && owner.isNotEmpty) queryParams['owner'] = owner;
    if (visibilite != null) queryParams['visibilite'] = visibilite;
    if (region != null && region.isNotEmpty) queryParams['region'] = region;
    if (departmentCode != null && departmentCode.isNotEmpty) {
      queryParams['departmentCode'] = departmentCode;
    }
    if (city != null && city.isNotEmpty) queryParams['city'] = city;
    if (nearLat != null) queryParams['nearLat'] = nearLat.toString();
    if (nearLng != null) queryParams['nearLng'] = nearLng.toString();
    if (nearKm != null) queryParams['nearKm'] = nearKm.toString();
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();
    
    // Compatibilité legacy : si membre est fourni, utiliser scope='joined' avec un filtre
    // Note: Le backend ne supporte plus directement 'membre', donc on utilise scope='joined'
    // mais cela ne filtre que les groupes où l'utilisateur actuel est membre
    // Pour un filtre par membre spécifique, il faudrait une autre approche
    if (membre != null) {
      // Pour la compatibilité, on peut utiliser scope='joined' mais cela filtre par l'utilisateur actuel
      // On garde le paramètre membre pour ne pas casser le code existant, mais il sera ignoré
      // car le backend utilise maintenant scope='joined' qui filtre par req.user._id
      queryParams['scope'] = 'joined';
    }

    final uri = Uri.parse('$baseUrl/groups').replace(queryParameters: queryParams);
    
    final response = await _makeRequest(() => http.get(uri, headers: _headers));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des groupes');
    }
  }

  Future<bool> toggleFavoriteGroup(String groupId) async {
    final uri = Uri.parse('$baseUrl/groups/$groupId/favorite');
    
    final response = await _makeRequest(() => http.post(
      uri,
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['isFavorite'] as bool;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la modification du favori');
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String nom,
    String? description,
    String visibilite = 'publique',
    Map<String, dynamic>? location,
  }) async {
    final response = await _makeRequest(() async {
      final body = <String, dynamic>{
        'nom': nom,
        if (description != null && description.isNotEmpty) 'description': description,
        'visibilite': visibilite,
        if (location != null) 'location': location,
      };
      
      return await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      
      // Si c'est une erreur PLAN_LIMIT, elle a déjà été interceptée dans _makeRequest
      // et convertie en PlanLimitException, donc on ne devrait pas arriver ici
      // Mais pour être sûr, vérifier à nouveau
      if (errorData['code'] == 'PLAN_LIMIT') {
        throw PlanLimitException.fromJson(errorData);
      }
      
      throw Exception(errorData['message'] ?? 'Erreur lors de la création du groupe');
    }
  }

  Future<Map<String, dynamic>> getGroupById(String groupId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du groupe');
    }
  }

  /// Récupérer les balades d'un groupe pour le calendrier
  Future<Map<String, dynamic>> getGroupRides(String groupId, {
    required DateTime from,
    required DateTime to,
    String? view,
  }) async {
    final queryParams = <String, String>{
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      if (view != null) 'view': view,
    };

    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/groups/$groupId/rides').replace(queryParameters: queryParams),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des balades du groupe');
    }
  }

  /// Obtenir l'URL d'export ICS du calendrier d'un groupe (avec token pour authentification)
  Future<String> getGroupCalendarIcsUrl(String groupId, DateTime from, DateTime to) async {
    final queryParams = <String, String>{
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    };
    
    // Ajouter le token en query param pour l'authentification
    if (_token != null) {
      queryParams['token'] = _token!;
    }
    
    return '${baseUrl}/groups/$groupId/calendar.ics?${Uri(queryParameters: queryParams).query}';
  }

  /// Obtenir des suggestions d'utilisateurs pour les mentions @pseudo
  Future<List<Map<String, dynamic>>> suggestGroupMembers(String groupId, String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final queryParams = <String, String>{
      'q': query.trim(),
    };

    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/groups/$groupId/members/suggest').replace(queryParameters: queryParams),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final suggestions = data['data']['suggestions'] as List?;
      return suggestions?.cast<Map<String, dynamic>>() ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des suggestions');
    }
  }

  /// Associer une balade à un groupe
  Future<Map<String, dynamic>> associateRideToGroup(String rideId, String groupId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$rideId/associate-group'),
        headers: _headers,
        body: jsonEncode({
          'groupId': groupId,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'association de la balade au groupe');
    }
  }

  Future<Map<String, dynamic>> joinGroup(String groupId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la jonction au groupe');
    }
  }

  Future<Map<String, dynamic>> updateGroup(
    String groupId, {
    String? nom,
    String? description,
    String? visibilite,
  }) async {
    final body = <String, dynamic>{};
    if (nom != null) body['nom'] = nom;
    if (description != null) body['description'] = description;
    if (visibilite != null) body['visibilite'] = visibilite;

    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: _headers,
        body: jsonEncode(body),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la modification du groupe');
    }
  }

  Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du groupe');
    }
  }

  Future<Map<String, dynamic>> addMemberToGroup(
    String groupId, {
    String? userId,
    String? pseudo,
    String? email,
    String? role,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/groups/$groupId/members'),
        headers: _headers,
        body: jsonEncode({
          if (userId != null) 'userId': userId,
          if (pseudo != null) 'pseudo': pseudo,
          if (email != null) 'email': email,
          if (role != null) 'role': role,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'ajout du membre');
    }
  }

  // Rechercher des utilisateurs par pseudo ou email (pour autocomplétion)
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 10}) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/users/search').replace(queryParameters: {
          'q': query,
          if (limit != 10) 'limit': limit.toString(),
        }),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']['users'] ?? []);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la recherche d\'utilisateurs');
    }
  }

  Future<Map<String, dynamic>> removeMemberFromGroup(String groupId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/groups/$groupId/members/$userId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du retrait du membre');
    }
  }

  Future<Map<String, dynamic>> updateMemberRole(
    String groupId,
    String userId, {
    required String role,
  }) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/groups/$groupId/members/$userId/role'),
        headers: _headers,
        body: jsonEncode({'role': role}),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la modification du rôle');
    }
  }

  Future<Map<String, dynamic>> getGroupMessages(String groupId, {int page = 1, int limit = 50}) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/groups/$groupId/messages').replace(queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        }),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des messages');
    }
  }

  Future<Map<String, dynamic>> banUserFromGroup(String groupId, String userId, {String? reason}) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/groups/$groupId/ban/$userId'),
        headers: _headers,
        body: jsonEncode({
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du bannissement');
    }
  }

  Future<Map<String, dynamic>> unbanUserFromGroup(String groupId, String userId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/groups/$groupId/ban/$userId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du débannissement');
    }
  }

  // Messages
  Future<List<dynamic>> getMessagesByRide(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/messages/rides/$rideId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['messages'] as List;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des messages');
    }
  }

  Future<List<dynamic>> getMessagesByGroup(String groupId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/groups/$groupId/messages'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['messages'] as List;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des messages');
    }
  }

  // Nouvelle méthode pour créer une note avec commentaire
  Future<Map<String, dynamic>> createRating({
    required String balade,
    required int note,
    String? commentaire,
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: _headers,
        body: jsonEncode({
          'balade': balade,
          'note': note,
          if (commentaire != null && commentaire.isNotEmpty) 'commentaire': commentaire,
        }),
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la création de la note');
    }
  }

  // Récupérer les notes d'une balade
  Future<Map<String, dynamic>> getRatingsByRide(String rideId, {int page = 1, int limit = 10}) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/ratings/ride/$rideId?page=$page&limit=$limit'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des notes');
    }
  }

  // Vérifier si l'utilisateur a déjà noté une balade
  Future<bool> hasUserRatedRide(String rideId, String userId) async {
    try {
      final ratings = await getRatingsByRide(rideId, limit: 100);
      final ratingsList = ratings['data']?['ratings'] as List?;
      if (ratingsList == null) return false;
      
      return ratingsList.any((rating) => 
        rating['utilisateur']?['id'] == userId || 
        rating['utilisateur']?['_id'] == userId
      );
    } catch (e) {
      return false;
    }
  }

  // Liker ou unliker une balade (toggle)
  Future<Map<String, dynamic>> toggleLike(String balade) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/likes'),
        headers: _headers,
        body: jsonEncode({
          'balade': balade,
        }),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du like');
    }
  }

  // Récupérer les likes d'une balade
  Future<Map<String, dynamic>> getLikesByRide(String rideId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/likes/ride/$rideId'),
        headers: _headers,
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des likes');
    }
  }

  // Calculer un itinéraire via le backend (pour éviter CORS)
  Future<Map<String, dynamic>> calculateRoute({
    required String origin, // Format: "lat,lng"
    required String destination, // Format: "lat,lng"
    String? waypoints, // Format: "lat1,lng1|lat2,lng2|..."
    bool? avoidTolls,
    bool? avoidHighways,
  }) async {
    // Vérifier d'abord le cache côté client
    final routeCacheService = RouteCacheService();
    final cached = routeCacheService.get(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
    );
    
    if (cached != null) {
      return cached;
    }

    final queryParams = <String, String>{
      'origin': origin,
      'destination': destination,
    };
    
    if (waypoints != null && waypoints.isNotEmpty) {
      queryParams['waypoints'] = waypoints;
    }
    
    if (avoidTolls == true) {
      queryParams['avoidTolls'] = 'true';
    }
    
    if (avoidHighways == true) {
      queryParams['avoidHighways'] = 'true';
    }

    final uri = Uri.parse('$baseUrl/rides/directions/route').replace(queryParameters: queryParams);
    
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Mettre en cache la réponse
      routeCacheService.set(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        avoidTolls: avoidTolls,
        avoidHighways: avoidHighways,
        data: data,
      );
      
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du calcul de l\'itinéraire');
    }
  }

  // ==================== PARRAINAGE ====================

  // Obtenir les informations de parrainage de l'utilisateur connecté
  Future<Map<String, dynamic>> getMyReferralInfo() async {
    final response = await get(
      Uri.parse('$baseUrl/referral/my-info'),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['data'];
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors de la récupération des informations de parrainage');
    }
  }

  // Valider un code de parrainage
  Future<Map<String, dynamic>> validateReferralCode(String code) async {
    final response = await post(
      Uri.parse('$baseUrl/referral/validate'),
      body: jsonEncode({
        'code': code,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors de la validation du code');
    }
  }

  // ==================== OTP TÉLÉPHONE ====================

  // Envoyer un code OTP par SMS
  Future<void> sendPhoneOtp(String phone) async {
    final response = await post(
      Uri.parse('$baseUrl/auth/phone/send-otp'),
      body: jsonEncode({
        'phone': phone,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return;
    } else {
      throw Exception(responseData['message'] ?? 'Erreur lors de l\'envoi du code OTP');
    }
  }

  // Vérifier un code OTP
  Future<void> verifyPhoneOtp(String phone, String code) async {
    final response = await post(
      Uri.parse('$baseUrl/auth/phone/verify-otp'),
      body: jsonEncode({
        'phone': phone,
        'code': code,
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return;
    } else {
      throw Exception(responseData['message'] ?? 'Code OTP invalide');
    }
  }
}

