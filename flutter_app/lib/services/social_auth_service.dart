import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:js' as js;

enum SocialAuthProvider {
  google,
  apple,
  facebook,
}

class SocialAuthService {
  // Initialisation lazy de GoogleSignIn pour éviter les erreurs si le Client ID n'est pas configuré
  GoogleSignIn? _googleSignIn;
  bool _googleSignInError = false; // Flag pour indiquer si l'initialisation a échoué
  
  /// Vérifie si Google Sign In est disponible
  bool get isGoogleSignInAvailable {
    if (kIsWeb && _googleSignInError) return false;
    return true; // Sur mobile, toujours disponible. Sur web, on vérifiera à l'utilisation
  }
  
  GoogleSignIn? _getGoogleSignIn() {
    if (_googleSignInError) return null; // Si erreur précédente, ne pas réessayer
    if (_googleSignIn != null) return _googleSignIn;
    
    // Initialiser GoogleSignIn avec gestion d'erreur
    // Sur web, utiliser le Web Client ID. Sur Android/iOS, ne pas passer clientId (config native)
    try {
      // TODO: Migrer vers variable d'environnement de build si possible
      // Pour l'instant, utiliser la valeur en dur comme fallback
      const webClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '481162301788-2j9lpcm9s7pkskh9uftkjikg0enavo23.apps.googleusercontent.com',
      );
      
      if (kIsWeb && webClientId.isEmpty) {
        debugPrint('⚠️ [Google Auth] GOOGLE_WEB_CLIENT_ID non défini, utilisation de la valeur par défaut');
      }
      
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // Sur web uniquement : passer le Web Client ID
        // Sur Android/iOS : clientId = null (utilise la configuration native)
        clientId: kIsWeb ? webClientId : null,
      );
      return _googleSignIn;
    } catch (e) {
      // Si erreur lors de l'initialisation (Client ID non configuré), marquer l'erreur
      if (e.toString().contains('ClientID not set') || 
          e.toString().contains('appClientId') ||
          e.toString().contains('google-signin-client_id') ||
          e.toString().contains('ClientID')) {
        _googleSignInError = true;
        debugPrint('Google Sign In non configuré. Veuillez configurer le Client ID dans index.html');
        return null;
      }
      rethrow;
    }
  }

  /// Connexion avec Google
  /// Utilise uniquement GoogleSignInAccount et GoogleSignInAuthentication
  /// Ne fait AUCUN appel à l'API People (people.googleapis.com)
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Obtenir GoogleSignIn (initialisation lazy avec gestion d'erreur)
      final googleSignIn = _getGoogleSignIn();
      if (googleSignIn == null) {
        debugPrint('Google Sign In non disponible (Client ID non configuré)');
        return null;
      }
      
      // Démarrer le processus de connexion Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // L'utilisateur a annulé la connexion
        return null;
      }

      // Obtenir les détails d'authentification (idToken et accessToken)
      // ⚠️ IMPORTANT : Ne pas utiliser de méthodes qui déclenchent un appel à l'API People
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // ⚠️ PROBLÈME CONNU : Sur Flutter Web, google_sign_in ne retourne pas toujours l'idToken
      // Solution : Si idToken manquant, utiliser l'accessToken pour obtenir les infos utilisateur
      // via l'API Google userinfo (différente de People API, pas besoin d'activation)
      
      String? idToken = googleAuth.idToken;
      String? accessToken = googleAuth.accessToken;
      
      // 🔍 DEBUG : Logs temporaires pour diagnostiquer le problème de connexion Google
      debugPrint('🔍 [DEBUG Google Auth] État des tokens:');
      debugPrint('   - idToken: ${idToken != null ? "${idToken.substring(0, idToken.length > 10 ? 10 : idToken.length)}..." : "NULL"}');
      debugPrint('   - accessToken: ${accessToken != null ? "${accessToken.substring(0, accessToken.length > 10 ? 10 : accessToken.length)}..." : "NULL"}');
      debugPrint('   - Platform: ${kIsWeb ? "Web" : "Mobile"}');
      
      // Log de l'URL courante sur web pour diagnostiquer redirect_uri_mismatch
      if (kIsWeb) {
        try {
          final currentUrl = Uri.base.toString();
          debugPrint('   - Current URL: $currentUrl');
          debugPrint('   - Origin: ${Uri.base.origin}');
        } catch (e) {
          debugPrint('   - Impossible de lire l\'URL courante: $e');
        }
      }
      
      // Si idToken manquant sur web, on utilise l'accessToken
      // Le backend pourra soit valider l'idToken, soit utiliser l'accessToken pour obtenir les infos
      if (kIsWeb && (idToken == null || idToken.isEmpty)) {
        debugPrint('⚠️ ID Token manquant sur Web, utilisation de l\'accessToken');
        // Sur web, si idToken manquant, on envoie l'accessToken
        // Le backend utilisera l'accessToken pour obtenir les infos depuis userinfo.googleapis.com
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('Access Token Google manquant. Impossible de procéder à l\'authentification.');
        }
      } else if (!kIsWeb && (idToken == null || idToken.isEmpty)) {
        // Sur mobile, l'idToken devrait toujours être présent
        throw Exception('ID Token Google manquant. Impossible de procéder à l\'authentification.');
      }
      
      // ⚠️ IMPORTANT : Ne pas accéder à googleUser.email, googleUser.displayName, etc.
      // car cela peut déclencher un appel automatique à l'API People sur le web.
      // Le backend extraira toutes les informations depuis l'idToken (JWT) ou l'accessToken.
      
      // Préparer les tokens à retourner (sans appeler l'API ici)
      // L'appel API sera fait par AuthService.socialLogin()
      final accessTokenToSend = (idToken == null || idToken.isEmpty) ? accessToken : null;
      final idTokenToSend = (idToken != null && idToken.isNotEmpty) ? idToken : null;
      
      // 🔍 DEBUG : Log des tokens qui seront retournés
      debugPrint('🔍 [DEBUG Google Auth] Tokens récupérés (seront envoyés au backend par AuthService):');
      debugPrint('   - idToken: ${idTokenToSend != null ? "${idTokenToSend.substring(0, idTokenToSend.length > 10 ? 10 : idTokenToSend.length)}..." : "NULL"}');
      debugPrint('   - accessToken: ${accessTokenToSend != null ? "${accessTokenToSend.substring(0, accessTokenToSend.length > 10 ? 10 : accessTokenToSend.length)}..." : "NULL"}');

      // Retourner uniquement les tokens (pas d'appel API ici)
      // AuthService.socialLogin() se chargera d'appeler l'API backend
      return {
        'idToken': idTokenToSend,
        'accessToken': accessTokenToSend,
      };
    } catch (e) {
      debugPrint('Erreur lors de la connexion Google: $e');
      // Si c'est une erreur de Client ID non configuré, retourner null au lieu de throw
      if (e.toString().contains('ClientID not set') || 
          e.toString().contains('appClientId') ||
          e.toString().contains('google-signin-client_id')) {
        debugPrint('Google Sign In non configuré. Veuillez configurer le Client ID dans index.html');
        // Ne pas throw pour éviter de casser l'app, juste retourner null
        return null;
      }
      rethrow;
    }
  }

  /// Connexion avec Apple
  /// Retourne uniquement les tokens et données utilisateur (pas d'appel API)
  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      // Vérifier si Apple Sign In est disponible (pas sur web)
      if (kIsWeb) {
        throw Exception('Apple Sign In n\'est pas disponible sur le web');
      }

      // Demander l'autorisation
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Retourner uniquement les tokens et données (pas d'appel API ici)
      // AuthService.socialLogin() se chargera d'appeler l'API backend
      return {
        'accessToken': credential.identityToken,
        'idToken': credential.identityToken,
        'firstName': credential.givenName,
        'lastName': credential.familyName,
        'email': credential.email,
      };
    } catch (e) {
      debugPrint('Erreur lors de la connexion Apple: $e');
      rethrow;
    }
  }

  /// Récupère le SDK Facebook depuis globalThis (uniquement sur Web)
  /// Utilise dart:js pour accéder à FB (global)
  dynamic _getFacebookSdk() {
    if (!kIsWeb) {
      return null;
    }
    try {
      // Utiliser js.context pour accéder directement à FB (global, équivalent à getProperty(globalThis, 'FB'))
      return js.context['FB'];
    } catch (e) {
      return null;
    }
  }

  /// Attend que le SDK Facebook soit chargé et initialisé (uniquement sur Web)
  /// Poll FB et __fbReady toutes les 100ms pendant max 10 secondes
  Future<void> _waitForFacebookSdkLoaded() async {
    if (!kIsWeb) {
      // Sur mobile, pas besoin d'attendre le SDK
      return;
    }

    const maxWaitTime = Duration(seconds: 10);
    const pollInterval = Duration(milliseconds: 100);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      try {
        final fb = _getFacebookSdk();
        final fbReady = js.context['__fbReady'];
        
        if (fb != null && fbReady == true) {
          debugPrint('✅ Facebook SDK chargé et prêt');
          return;
        }
        
        // Logs de diagnostic
        debugPrint('⏳ [FB SDK] En attente... FB=${fb != null}, __fbReady=$fbReady');
      } catch (e) {
        // Ignorer les erreurs d'accès
        debugPrint('⚠️ Erreur lors de la vérification du SDK Facebook: $e');
      }

      // Attendre avant de réessayer
      await Future.delayed(pollInterval);
    }

    // Timeout : le SDK n'est pas prêt
    final errorMsg = 'Facebook SDK non prêt après ${maxWaitTime.inSeconds}s. Vérifiez que FB.init() a été appelé dans index.html et que l\'option "Login with the JavaScript SDK" est activée dans Facebook Developers.';
    debugPrint('❌ [FB SDK] $errorMsg');
    throw Exception(errorMsg);
  }

  /// Connexion avec Facebook
  /// Retourne uniquement les tokens et données utilisateur (pas d'appel API)
  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        // Sur Web : utiliser directement le SDK Facebook via js_util
        await _waitForFacebookSdkLoaded();
        
        final fb = _getFacebookSdk();
        if (fb == null) {
          throw Exception('Facebook SDK non disponible');
        }

        // Appeler FB.login via js.callMethod (équivalent à js_util.callMethod)
        final completer = Completer<Map<String, dynamic>?>();
        
        // Créer un callback JavaScript compatible
        void loginCallback(js.JsObject response) {
          try {
            // Log du status de réponse FB.login
            final status = response['status'];
            debugPrint('🔍 [FB Login] Status de réponse: $status');
            
            if (status != null) {
              final statusStr = status.toString();
              if (statusStr == 'connected') {
                debugPrint('✅ [FB Login] Utilisateur connecté');
              } else if (statusStr == 'not_authorized') {
                debugPrint('⚠️ [FB Login] Utilisateur non autorisé');
                completer.complete(null);
                return;
              } else {
                debugPrint('⚠️ [FB Login] Status inconnu: $statusStr');
              }
            }
            
            // Récupérer authResponse.accessToken (équivalent à getProperty)
            final authResponse = response['authResponse'];
            if (authResponse == null) {
              debugPrint('⚠️ [FB Login] authResponse est null');
              completer.complete(null);
              return;
            }
            
            final authResponseObj = authResponse as js.JsObject;
            final accessToken = authResponseObj['accessToken'];
            if (accessToken == null) {
              debugPrint('⚠️ [FB Login] accessToken est null dans authResponse');
              completer.complete(null);
              return;
            }
            
            final tokenString = accessToken.toString();
            debugPrint('✅ [FB Login] Token récupéré avec succès');
            completer.complete({
              'accessToken': tokenString,
            });
          } catch (e) {
            debugPrint('❌ [FB Login] Erreur lors de la récupération du token: $e');
            completer.completeError(Exception('Erreur lors de la récupération du token Facebook: $e'));
          }
        };

        // Appeler FB.login avec les permissions (équivalent à callMethod)
        // Note: Dans dart:js, on peut passer directement la fonction comme callback
        final fbObj = fb as js.JsObject;
        fbObj.callMethod('login', [
          loginCallback,
          js.JsObject.jsify({
            'scope': 'email,public_profile',
          }),
        ]);

        // Attendre la réponse
        final result = await completer.future;
        return result;
      } else {
        // Sur mobile : utiliser le package flutter_facebook_auth (comportement inchangé)
        final LoginResult result = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
        );

        if (result.status != LoginStatus.success) {
          if (result.status == LoginStatus.cancelled) {
            debugPrint('ℹ️ [FB Login] Connexion annulée par l\'utilisateur');
            return null; // L'utilisateur a annulé
          }
          debugPrint('❌ [FB Login] Erreur: ${result.message}');
          throw Exception('Erreur lors de la connexion Facebook: ${result.message}');
        }

        // Obtenir les informations utilisateur
        final AccessToken accessToken = result.accessToken!;
        
        // Obtenir les données du profil
        final userData = await FacebookAuth.instance.getUserData();
        
        // Retourner uniquement les tokens et données (pas d'appel API ici)
        // AuthService.socialLogin() se chargera d'appeler l'API backend
        return {
          'accessToken': accessToken.tokenString,
          'idToken': null,
          'firstName': userData['first_name'] as String?,
          'lastName': userData['last_name'] as String?,
          'email': userData['email'] as String?,
        };
      }
    } catch (e) {
      debugPrint('❌ [FB Login] Erreur lors de la connexion Facebook: $e');
      
      // Gérer spécifiquement le timeout du SDK
      if (e.toString().contains('non prêt') || e.toString().contains('timeout')) {
        throw Exception('Le SDK Facebook n\'est pas prêt. Vérifiez que l\'option "Login with the JavaScript SDK" est activée dans Facebook Developers Console.');
      }
      
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // Déconnexion Google
      if (_googleSignIn != null && await _googleSignIn!.isSignedIn()) {
        await _googleSignIn!.signOut();
      }

      // Déconnexion Facebook
      await FacebookAuth.instance.logOut();
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion sociale: $e');
    }
  }
}

