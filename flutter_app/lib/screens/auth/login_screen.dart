import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/social_auth_service.dart';
import '../../services/navigation_state.dart';
import '../../utils/background_helper.dart';
import '../../exceptions/auth_exception.dart';
import '../../exceptions/resend_email_exception.dart';
import '../../widgets/auth/social_auth_buttons.dart';
import '../../widgets/legal/terms_consent_banner.dart';
import 'register_screen.dart';
import 'contact_support_screen.dart';
import 'forgot_password_screen.dart';
import '../main_navigation.dart';

class LoginScreen extends StatefulWidget {
  final String? message; // Message d'erreur (rouge) - pour compatibilité
  final String? successMessage; // Message de succès (vert)
  final bool showEmailWarning; // Afficher l'avertissement email (orange)
  
  const LoginScreen({
    super.key, 
    this.message,
    this.successMessage,
    this.showEmailWarning = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _biometricService = BiometricService();
  final _socialAuthService = SocialAuthService();
  bool _obscurePassword = true;
  bool _requires2FA = false;
  bool _requiresPhoneVerification = false;
  String? _userPhoneForVerification;
  String? _errorMessage;
  String? _successMessage;
  bool _showEmailWarning = false;
  bool _showResendButton = false;
  bool _showContactSupportButton = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricTypeName = 'Biométrie';
  bool _isCheckingBiometric = true;
  bool _biometricCheckInProgress = false; // Flag pour éviter les vérifications multiples
  bool _isLoggingIn = false; // Flag pour éviter les doubles soumissions
  bool _termsAccepted = false;
  bool _isCheckingTerms = true;

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final visible = phone.substring(phone.length - 4);
    final masked = '*' * (phone.length - 4);
    return '$masked$visible';
  }

  /// Navigue vers MainNavigation en réinitialisant toujours l'index à 0 (page d'accueil)
  void _navigateToHome() {
    final navigationState = Provider.of<NavigationState>(context, listen: false);
    navigationState.setIndex(0); // Toujours commencer sur la page d'accueil
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
    _checkTermsStatus();
    // Afficher les messages si passés depuis l'inscription
    if (widget.successMessage != null || widget.message != null || widget.showEmailWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _successMessage = widget.successMessage;
            _errorMessage = widget.message;
            _showEmailWarning = widget.showEmailWarning;
            if (widget.message != null) {
              _showResendButton = true;
            }
          });
        }
      });
    }
  }

  Future<void> _checkTermsStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAccepted = prefs.getBool('terms_accepted') ?? false;
      
      if (mounted) {
        setState(() {
          _termsAccepted = hasAccepted;
          _isCheckingTerms = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification du consentement: $e');
      if (mounted) {
        setState(() {
          _isCheckingTerms = false;
        });
      }
    }
  }

  // Méthode pour rafraîchir le statut des CGU après acceptation
  void _refreshTermsStatus() {
    _checkTermsStatus();
  }

  Future<void> _initializeBiometric() async {
    // Éviter les vérifications multiples simultanées
    if (_biometricCheckInProgress) return;
    
    _biometricCheckInProgress = true;
    try {
      // D'abord vérifier la disponibilité
      await _checkBiometricAvailability();
      // Ensuite vérifier si c'est activé
      await _checkBiometricEnabled();
    } finally {
      _biometricCheckInProgress = false;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      // Ne vérifier qu'une seule fois si déjà vérifié
      if (!_isCheckingBiometric && _biometricTypeName != 'Biométrie') {
        return;
      }
      
      // Ne pas vérifier si une vérification est déjà en cours
      if (_biometricCheckInProgress) {
        return;
      }
      
      debugPrint('Vérification de la disponibilité biométrique...');
      final isAvailable = await _biometricService.isAvailable();
      final typeName = await _biometricService.getBiometricTypeName();
      
      debugPrint('Biométrie disponible: $isAvailable');
      debugPrint('Type biométrique: $typeName');
      
      if (mounted) {
        // Ne faire setState que si les valeurs ont changé
        if (_biometricAvailable != isAvailable || 
            _biometricTypeName != typeName || 
            _isCheckingBiometric) {
          setState(() {
            _biometricAvailable = isAvailable;
            _biometricTypeName = typeName;
            _isCheckingBiometric = false;
          });
          debugPrint('État mis à jour - _biometricAvailable: $_biometricAvailable, _biometricTypeName: $_biometricTypeName');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la disponibilité biométrique: $e');
      if (mounted && _isCheckingBiometric) {
        setState(() {
          _biometricAvailable = false;
          _biometricTypeName = 'Biométrie';
          _isCheckingBiometric = false;
        });
      }
    }
  }

  Future<void> _checkBiometricEnabled() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final enabled = await authService.isBiometricEnabled();
      
      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
        });
        
        // Si la biométrie est activée et disponible, proposer la connexion automatique
        // Attendre un peu pour que l'UI soit prête
        if (enabled && _biometricAvailable) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _showBiometricLoginPrompt();
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la biométrie activée: $e');
    }
  }

  Future<void> _showBiometricLoginPrompt() async {
    // Proposer la connexion biométrique via un dialogue
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Connexion avec $_biometricTypeName'),
        content: Text('Voulez-vous vous connecter avec $_biometricTypeName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non, merci'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Oui, utiliser $_biometricTypeName'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _loginWithBiometrics();
    }
  }

  void _startCooldown({int? seconds}) {
    // Utiliser la valeur fournie ou 0 si non fournie
    _cooldownSeconds = seconds ?? 0;
    _cooldownTimer?.cancel();
    
    if (_cooldownSeconds <= 0) {
      return;
    }
    
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      }
    });
  }

  Future<void> _sendPhoneOtp() async {
    if (_userPhoneForVerification == null || _userPhoneForVerification!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendPhoneOtp(_userPhoneForVerification!);

      if (!mounted) return;

      setState(() {
        _isResending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code OTP envoyé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isResending = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _verifyPhoneOtpAndLogin() async {
    if (!mounted) return;
    
    // Sauvegarder la valeur du code OTP avant toute opération asynchrone
    final otpCode = _phoneOtpController.text;
    final phoneForVerification = _userPhoneForVerification;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (otpCode.length != 6) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Veuillez entrer un code OTP à 6 chiffres';
      });
      return;
    }

    if (phoneForVerification == null || phoneForVerification.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Numéro de téléphone non disponible';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
      // Réinitialiser le flag de vérification téléphone pour éviter les rebuilds
      _requiresPhoneVerification = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Vérifier l'OTP (utiliser les variables locales pour éviter d'accéder au controller après dispose)
      await authService.verifyPhoneOtp(phoneForVerification, otpCode);

      if (!mounted) return;

      // Si l'OTP est valide, se connecter automatiquement
      await authService.login(email, password);

      if (!mounted) return;

      // Succès - rediriger vers l'accueil
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;

      // Si l'erreur est liée à l'email non vérifié, on peut quand même permettre la connexion
      // car l'email est optionnel maintenant
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      if (errorMessage.contains('email') && errorMessage.contains('vérifié')) {
        // L'email n'est pas vérifié mais c'est optionnel, on peut quand même se connecter
        // Réessayer la connexion sans bloquer sur l'email
        try {
          final authServiceRetry = Provider.of<AuthService>(context, listen: false);
          await authServiceRetry.login(email, password);
          if (!mounted) return;
          _navigateToHome();
          return;
        } catch (e2) {
          // Si ça échoue encore, afficher l'erreur
          if (!mounted) return;
          setState(() {
            _isLoggingIn = false;
            _errorMessage = e2.toString().replaceAll('Exception: ', '');
            _requiresPhoneVerification = true; // Réafficher le champ OTP si nécessaire
          });
          return;
        }
      }

      setState(() {
        _isLoggingIn = false;
        _errorMessage = errorMessage;
        _requiresPhoneVerification = true; // Réafficher le champ OTP si nécessaire
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    final identifier = _emailController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre email ou téléphone')),
      );
      return;
    }
    
    // Si c'est un téléphone, on ne peut pas renvoyer l'email
    if (!identifier.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez utiliser votre email pour renvoyer l\'email de vérification')),
      );
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      final apiService = ApiService();
      apiService.setToken(token);

      final responseData = await apiService.resendVerificationEmail(identifier);

      if (!mounted) return;

      setState(() {
        _isResending = false;
      });
      
      // Succès - vérifier si le backend retourne un cooldown
      final retryAfter = responseData['retryAfter'] as int?;
      
      // Démarrer le cooldown avec la valeur du backend si disponible, sinon utiliser une valeur par défaut
      _startCooldown(seconds: retryAfter ?? 60);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de vérification renvoyé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isResending = false;
      });

      // Extraire retryAfter depuis l'exception si disponible
      int? retryAfterSeconds;
      if (e is ResendEmailException) {
        // Utiliser directement retryAfter depuis l'exception personnalisée
        retryAfterSeconds = e.retryAfter;
      } else {
        // Fallback : essayer d'extraire depuis le message d'erreur
        final errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        if (errorMessage.contains('secondes')) {
          final match = RegExp(r'(\d+)\s*seconde').firstMatch(errorMessage);
          if (match != null) {
            retryAfterSeconds = int.tryParse(match.group(1)!);
          } else {
            final parenMatch = RegExp(r'\((\d+)\s*secondes?\)').firstMatch(errorMessage);
            if (parenMatch != null) {
              retryAfterSeconds = int.tryParse(parenMatch.group(1)!);
            }
          }
        }
      }

      String errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      
      // Si retryAfter est disponible, démarrer le cooldown avec cette valeur exacte
      if (retryAfterSeconds != null && retryAfterSeconds > 0) {
        _startCooldown(seconds: retryAfterSeconds);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _login({bool enableBiometric = false}) async {
    // Empêcher les doubles soumissions
    if (_isLoggingIn) return;
    
    // Vérifier que les CGU sont acceptées
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les Conditions Générales d\'Utilisation pour vous connecter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Fermer le clavier pour éviter les problèmes de focus et les rechargements
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Ne pas effacer le message d'erreur immédiatement, seulement après une tentative réussie
    // Cela permet de garder les messages d'erreur visibles

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Normaliser l'identifiant (email ou téléphone)
      String identifier = _emailController.text.trim();
      // Si ce n'est pas un email (pas de @), normaliser comme téléphone
      if (!identifier.contains('@')) {
        identifier = identifier.replaceAll(RegExp(r'[\s-]'), '');
      }
      
      await authService.login(
        identifier,
        _passwordController.text,
        totpCode: _requires2FA ? _totpController.text : null,
        saveCredentials: enableBiometric,
      );

      if (!mounted) return;

      // Fallback : si login() retourne sans exception mais isAuthenticated == false
      if (!authService.isAuthenticated) {
        setState(() {
          _errorMessage = 'Une erreur est survenue lors de la connexion. Veuillez réessayer.';
          _isLoggingIn = false;
        });
        return;
      }

      // Connexion réussie
      setState(() {
        _errorMessage = null;
        _successMessage = null;
        _showEmailWarning = false;
        _showResendButton = false;
        _isLoggingIn = false;
      });
      
      // Si la biométrie est disponible et que l'utilisateur n'a pas encore activé, proposer
      if (_biometricAvailable && !_biometricEnabled && !enableBiometric) {
        _showBiometricEnableDialog();
      } else {
        _navigateToHome();
      }
      return; // Sortir immédiatement après succès
    } catch (e) {
      if (!mounted) {
        _isLoggingIn = false;
        return;
      }
      
      // Gérer AuthException avec code structuré
      if (e is AuthException) {
        setState(() {
          _isLoggingIn = false;
          
          switch (e.code) {
            case AuthException.emailNotVerified:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Votre email n\'a pas été vérifié. Veuillez vérifier votre boîte mail et cliquer sur le lien de validation, ou renvoyer un nouvel email de vérification.';
              _showResendButton = true;
              _showContactSupportButton = false;
              break;
              
            case AuthException.accountBanned:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Votre compte a été banni. Veuillez contacter le support pour plus d\'informations.';
              _showResendButton = false;
              _showContactSupportButton = true;
              break;
              
            case AuthException.twoFactorRequired:
              _requires2FA = true;
              _errorMessage = null; // Pas d'erreur pour 2FA, juste besoin du code
              _showResendButton = false;
              _showContactSupportButton = false;
              break;
              
            case AuthException.phoneVerificationRequired:
              _requiresPhoneVerification = true;
              _errorMessage = e.message.isNotEmpty 
                  ? e.message 
                  : 'Votre numéro de téléphone doit être vérifié avant de vous connecter. Veuillez entrer le code reçu par SMS.';
              _showResendButton = false;
              _showContactSupportButton = false;
              // Récupérer le numéro de téléphone depuis l'exception (retourné par le backend) ou depuis l'identifiant
              _userPhoneForVerification = e.phoneE164 ?? 
                  (_emailController.text.contains('@') 
                      ? null 
                      : _emailController.text.trim());
              // NE PAS envoyer automatiquement l'OTP - l'utilisateur doit cliquer sur "Renvoyer le code"
              break;
              
            case AuthException.invalidCredentials:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Email ou mot de passe incorrect';
              _showResendButton = false;
              _showContactSupportButton = false;
              break;
              
            case AuthException.accountLocked:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Votre compte a été verrouillé. Veuillez contacter le support.';
              _showResendButton = false;
              _showContactSupportButton = false;
              break;
              
            default:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Une erreur est survenue lors de la connexion.';
              _showResendButton = false;
              _showContactSupportButton = false;
          }
        });
        return;
      }
      
      // Fallback pour les autres types d'exceptions (ne devrait pas arriver normalement)
      setState(() {
        final errorText = e.toString().replaceAll('Exception: ', '').trim();
        _errorMessage = errorText.isEmpty 
            ? 'Une erreur est survenue lors de la connexion.' 
            : errorText;
        _showResendButton = false;
        _isLoggingIn = false;
      });
    } finally {
      // S'assurer que le flag est toujours réinitialisé
      if (mounted && _isLoggingIn) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (!_biometricAvailable || !_biometricEnabled) return;

    // Vérifier que les CGU sont acceptées
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les Conditions Générales d\'Utilisation pour vous connecter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Authentifier avec la biométrie
      final authenticated = await _biometricService.authenticate(
        reason: 'Utilisez $_biometricTypeName pour vous connecter',
      );

      if (!authenticated) {
        return; // L'utilisateur a annulé ou l'authentification a échoué
      }

      // Si l'authentification biométrique réussit, se connecter avec les identifiants sauvegardés
      final authService = Provider.of<AuthService>(context, listen: false);
      
      await authService.loginWithBiometrics();

      if (!mounted) return;

      if (authService.isAuthenticated) {
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Vérifier que les CGU sont acceptées
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les Conditions Générales d\'Utilisation pour vous connecter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoggingIn = true;
        _errorMessage = null;
      });

      final result = await _socialAuthService.signInWithGoogle();
      
      if (result == null) {
        if (mounted) {
          setState(() {
            _isLoggingIn = false;
          });
        }
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.socialLogin('google', result);

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        if (authService.isAuthenticated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    // Vérifier que les CGU sont acceptées
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les Conditions Générales d\'Utilisation pour vous connecter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoggingIn = true;
        _errorMessage = null;
      });

      final result = await _socialAuthService.signInWithApple();
      
      if (result == null) {
        if (mounted) {
          setState(() {
            _isLoggingIn = false;
          });
        }
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.socialLogin('apple', result);

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        if (authService.isAuthenticated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    // Vérifier que les CGU sont acceptées
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les Conditions Générales d\'Utilisation pour vous connecter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoggingIn = true;
        _errorMessage = null;
      });

      final result = await _socialAuthService.signInWithFacebook();
      
      if (result == null) {
        if (mounted) {
          setState(() {
            _isLoggingIn = false;
          });
        }
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.socialLogin('facebook', result);

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        if (authService.isAuthenticated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _showBiometricEnableDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activer $_biometricTypeName ?'),
        content: Text(
          'Voulez-vous activer $_biometricTypeName pour vous connecter plus rapidement ?\n\n'
          'Vos identifiants seront sauvegardés de manière sécurisée sur cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Réactiver la connexion avec saveCredentials = true
      await _login(enableBiometric: true);
      if (mounted) {
        setState(() {
          _biometricEnabled = true;
        });
        _navigateToHome();
      }
    } else if (mounted) {
      // L'utilisateur a choisi "Plus tard", naviguer quand même
      _navigateToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(getLoginBackgroundImageName()),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                physics: const ClampingScrollPhysics(), // Empêcher le scroll automatique qui pourrait masquer les messages
                child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled, // Désactiver la validation automatique pour éviter les rebuilds
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overlay semi-transparent pour améliorer la lisibilité
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        // Logo RideTogether
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Bienvenue',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Email ou téléphone',
                            hintText: 'votre@email.com ou +33612345678',
                            prefixIcon: Icon(
                              Icons.person_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre email ou téléphone';
                            }
                            // Si c'est un email, vérifier le format
                            if (value.contains('@')) {
                              if (!value.contains('.') || value.length < 5) {
                                return 'Email invalide';
                              }
                            } else {
                              // Si c'est un téléphone, vérifier qu'il contient au moins 8 chiffres
                              final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                              if (digitsOnly.length < 8) {
                                return 'Numéro de téléphone invalide';
                              }
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            // Focus sur le champ mot de passe au lieu de soumettre
                            FocusScope.of(context).nextFocus();
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: _requires2FA ? TextInputAction.next : TextInputAction.done,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            hintText: '••••••••',
                            prefixIcon: Icon(
                              Icons.lock_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre mot de passe';
                            }
                            if (value.length < 6) {
                              return 'Le mot de passe doit contenir au moins 6 caractères';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            // Si 2FA requis, aller au champ 2FA, sinon soumettre le formulaire
                            if (_requires2FA) {
                              FocusScope.of(context).nextFocus();
                            } else {
                              // Fermer le clavier et soumettre
                              FocusScope.of(context).unfocus();
                              if (!_isLoggingIn) {
                                _login();
                              }
                            }
                          },
                        ),
                        if (_requires2FA) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _totpController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Code 2FA',
                              hintText: '000000',
                              prefixIcon: Icon(
                                Icons.security,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              helperText: 'Entrez le code de votre application d\'authentification',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer le code 2FA';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) {
                              // Fermer le clavier et soumettre
                              FocusScope.of(context).unfocus();
                              if (!_isLoggingIn) {
                                _login();
                              }
                            },
                          ),
                        ],
                        // Message de succès (vert) - affiché en premier
                        if (_successMessage != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 20, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Message d'avertissement email (orange) - affiché après le succès
                        if (_showEmailWarning) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'N\'oubliez pas de valider votre email via le lien reçu par email.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Afficher le champ OTP si vérification téléphone requise
                                if (_requiresPhoneVerification) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    _userPhoneForVerification != null
                                        ? 'Entrez le code de vérification reçu par SMS au ${_maskPhone(_userPhoneForVerification!)}'
                                        : 'Entrez le code de vérification reçu par SMS',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_userPhoneForVerification == null || _userPhoneForVerification!.isEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Cliquez sur "Renvoyer le code" pour recevoir un code OTP',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Center(
                                    child: PinCodeTextField(
                                        key: const ValueKey('phone_otp_field'), // Clé pour stabiliser le widget
                                        appContext: context,
                                        length: 6,
                                        controller: _phoneOtpController,
                                        onChanged: (value) {
                                          // Ne pas faire de setState ici - cela cause des problèmes de rebuild
                                          // L'erreur sera effacée automatiquement quand l'utilisateur tape
                                        },
                                        pinTheme: PinTheme(
                                          shape: PinCodeFieldShape.box,
                                          borderRadius: BorderRadius.circular(12),
                                          fieldHeight: 56,
                                          fieldWidth: 40, // Réduit pour éviter le débordement
                                          activeFillColor: Colors.white,
                                          inactiveFillColor: Colors.grey.shade50,
                                          selectedFillColor: Colors.white,
                                          activeColor: Theme.of(context).colorScheme.primary,
                                          inactiveColor: Colors.grey.shade300,
                                          selectedColor: Theme.of(context).colorScheme.primary,
                                        ),
                                        enableActiveFill: true,
                                        keyboardType: TextInputType.number,
                                        textStyle: const TextStyle(
                                          fontSize: 18, // Légèrement réduit pour s'adapter
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _phoneOtpController,
                                    builder: (context, value, child) {
                                      final otpLength = value.text.length;
                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: (_isLoggingIn || otpLength != 6) 
                                              ? null 
                                              : _verifyPhoneOtpAndLogin,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _isLoggingIn
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Valider le code',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: (_isResending || _isLoggingIn) ? null : _sendPhoneOtp,
                                        child: _isResending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Text('Renvoyer le code'),
                                      ),
                                    ],
                                  ),
                                ] else if (_showResendButton) ...[
                                  // Afficher le bouton "Renvoyer l'email" uniquement si ce n'est pas une vérification téléphone
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: (_isResending || _cooldownSeconds > 0) 
                                        ? null 
                                        : _resendVerificationEmail,
                                    icon: _isResending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.email_outlined, size: 18),
                                    label: Text(
                                      _cooldownSeconds > 0
                                          ? 'Renvoyer dans ${_cooldownSeconds}s'
                                          : 'Renvoyer l\'email de vérification',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.primary,
                                      side: BorderSide(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_showContactSupportButton) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ContactSupportScreen(
                                            userEmail: _emailController.text.trim(),
                                            subject: 'Compte Banni',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                                    label: const Text(
                                      'Contacter le support',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.primary,
                                      side: BorderSide(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Lien "Mot de passe oublié"
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer<AuthService>(
                          builder: (context, authService, _) {
                            // Utiliser un StatefulBuilder pour éviter les rebuilds inutiles du formulaire
                            final isLoading = authService.isLoading || _isLoggingIn;
                            return ElevatedButton(
                              onPressed: isLoading ? null : () => _login(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Divider "OU" pour les boutons OAuth
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OU',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Boutons OAuth (toujours visibles)
                        SocialAuthButtons(
                          onGooglePressed: _handleGoogleSignIn,
                          onApplePressed: !kIsWeb ? _handleAppleSignIn : null,
                          onFacebookPressed: _handleFacebookSignIn,
                          isLoading: _isLoggingIn,
                        ),
                        
                        // Bouton de connexion biométrique (si disponible)
                        if (_biometricAvailable && !_isCheckingBiometric) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OU',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_biometricEnabled) ...[
                            // Si activé, afficher le bouton de connexion biométrique
                            OutlinedButton.icon(
                              onPressed: _loginWithBiometrics,
                              icon: Icon(
                                _biometricTypeName.contains('Face') || _biometricTypeName.contains('face')
                                    ? Icons.face 
                                    : Icons.fingerprint,
                                size: 22,
                              ),
                              label: Text(
                                'Se connecter avec $_biometricTypeName',
                                style: const TextStyle(fontSize: 15),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Si pas encore activé, afficher un bouton pour l'activer
                            OutlinedButton.icon(
                              onPressed: () {
                                // Proposer d'activer la biométrie
                                _showBiometricEnableDialog();
                              },
                              icon: Icon(
                                _biometricTypeName.contains('Face') || _biometricTypeName.contains('face')
                                    ? Icons.face_outlined 
                                    : Icons.fingerprint_outlined,
                                size: 22,
                              ),
                              label: Text(
                                'Activer $_biometricTypeName',
                                style: const TextStyle(fontSize: 15),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                        
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: 'Pas encore de compte ? '),
                                TextSpan(
                                  text: 'S\'inscrire',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            // Bannière de consentement CGU (si non acceptées)
            if (!_isCheckingTerms && !_termsAccepted)
              TermsConsentBanner(
                onAccepted: _refreshTermsStatus,
              ),
          ],
        ),
      ),
    );
  }
}

