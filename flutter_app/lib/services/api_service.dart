import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user.dart';
import '../models/ride.dart';
import '../config/api_config.dart';
import '../exceptions/auth_exception.dart';
import '../exceptions/resend_email_exception.dart';

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
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Authentification
  Future<Map<String, dynamic>> register(String email, String password, String pseudo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'pseudo': pseudo,
      }),
    );

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur d\'inscription');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password, {String? totpCode}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
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
        
        // Gérer spécifiquement les erreurs 403 (email non vérifié ou compte banni)
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
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/user/upload-avatar'),
    );

    // Ajouter le token d'authentification
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // Ajouter le fichier selon le type
    // Note: Cette méthode est uniquement utilisée sur mobile
    // Sur le web, on utilise _uploadImageFromBytes dans edit_profile_screen.dart
    try {
      String filePath;
      
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
      
      request.files.add(
        await http.MultipartFile.fromPath('avatar', filePath),
      );
    } catch (e) {
      throw Exception('Erreur lors de la préparation du fichier: $e');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['avatarUrl'];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'upload de l\'avatar');
    }
  }

  // Balades
  Future<List<Ride>> getRides({
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
    };

    final uri = Uri.parse('$baseUrl/rides').replace(queryParameters: queryParams);
    final response = await _makeRequest(() async {
      return await http.get(uri, headers: _headers);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['rides'] as List)
          .map((r) => Ride.fromJson(r))
          .toList();
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
      'lat': latitude.toString(),
      'lng': longitude.toString(),
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

  Future<void> joinRide(String id) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/rides/$id/join'),
        headers: _headers,
      );
    });

    if (response.statusCode != 200) {
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
  Future<List<dynamic>> getGroups({String? membre}) async {
    final uri = membre != null
        ? Uri.parse('$baseUrl/groups').replace(queryParameters: {'membre': membre})
        : Uri.parse('$baseUrl/groups');
    
    final response = await http.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['groups'] as List;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des groupes');
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String nom,
    String? description,
    String visibilite = 'publique',
  }) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: _headers,
        body: jsonEncode({
          'nom': nom,
          if (description != null && description.isNotEmpty) 'description': description,
          'visibilite': visibilite,
        }),
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
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
        Uri.parse('$baseUrl/user/search').replace(queryParameters: {
          'query': query,
          'limit': limit.toString(),
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
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du calcul de l\'itinéraire');
    }
  }
}

