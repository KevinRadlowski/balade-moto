import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/social_auth_service.dart';
import '../../utils/background_helper.dart';
import '../../exceptions/auth_exception.dart';
import '../../exceptions/resend_email_exception.dart';
import '../../widgets/auth/social_auth_buttons.dart';
import '../../widgets/legal/terms_consent_banner.dart';
import 'register_screen.dart';
import '../main_navigation.dart';

class LoginScreen extends StatefulWidget {
  final String? message;
  
  const LoginScreen({super.key, this.message});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _biometricService = BiometricService();
  final _socialAuthService = SocialAuthService();
  bool _obscurePassword = true;
  bool _requires2FA = false;
  String? _errorMessage;
  bool _showResendButton = false;
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

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
    _checkTermsStatus();
    // Afficher le message si passé depuis l'inscription
    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _errorMessage = widget.message;
            _showResendButton = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _cooldownTimer?.cancel();
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

  Future<void> _resendVerificationEmail() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre email')),
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

      final responseData = await apiService.resendVerificationEmail(_emailController.text.trim());

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
      
      await authService.login(
        _emailController.text.trim(),
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
        _showResendButton = false;
        _isLoggingIn = false;
      });
      
      // Si la biométrie est disponible et que l'utilisateur n'a pas encore activé, proposer
      if (_biometricAvailable && !_biometricEnabled && !enableBiometric) {
        _showBiometricEnableDialog();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
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
              break;
              
            case AuthException.twoFactorRequired:
              _requires2FA = true;
              _errorMessage = null; // Pas d'erreur pour 2FA, juste besoin du code
              break;
              
            case AuthException.invalidCredentials:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Email ou mot de passe incorrect';
              _showResendButton = false;
              break;
              
            case AuthException.accountLocked:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Votre compte a été verrouillé. Veuillez contacter le support.';
              _showResendButton = false;
              break;
              
            default:
              _errorMessage = (e.message.isNotEmpty) 
                  ? e.message 
                  : 'Une erreur est survenue lors de la connexion.';
              _showResendButton = false;
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } else if (mounted) {
      // L'utilisateur a choisi "Plus tard", naviguer quand même
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
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
                            labelText: 'Email',
                            hintText: 'votre@email.com',
                            prefixIcon: Icon(
                              Icons.email_outlined,
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
                              return 'Veuillez entrer votre email';
                            }
                            if (!value.contains('@')) {
                              return 'Email invalide';
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
                                if (_showResendButton) ...[
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
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
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

