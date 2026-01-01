import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import 'register_screen.dart';
import '../main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _biometricService = BiometricService();
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

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
  }

  Future<void> _initializeBiometric() async {
    // D'abord vérifier la disponibilité
    await _checkBiometricAvailability();
    // Ensuite vérifier si c'est activé
    await _checkBiometricEnabled();
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
      debugPrint('Vérification de la disponibilité biométrique...');
      final isAvailable = await _biometricService.isAvailable();
      final typeName = await _biometricService.getBiometricTypeName();
      
      debugPrint('Biométrie disponible: $isAvailable');
      debugPrint('Type biométrique: $typeName');
      
      if (mounted) {
        setState(() {
          _biometricAvailable = isAvailable;
          _biometricTypeName = typeName;
          _isCheckingBiometric = false;
        });
        debugPrint('État mis à jour - _biometricAvailable: $_biometricAvailable, _biometricTypeName: $_biometricTypeName');
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la disponibilité biométrique: $e');
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
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

  void _startCooldown() {
    _cooldownSeconds = 60;
    _cooldownTimer?.cancel();
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

      await apiService.resendVerificationEmail(_emailController.text.trim());

      if (!mounted) return;

      _startCooldown();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de vérification renvoyé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Vérifier si c'est une erreur de cooldown
      if (errorMessage.contains('attendre') || errorMessage.contains('secondes')) {
        final match = RegExp(r'(\d+)\s*seconde').firstMatch(errorMessage);
        if (match != null) {
          setState(() {
            _cooldownSeconds = int.parse(match.group(1)!);
          });
          _startCooldown();
        } else {
          // Si le message contient un nombre entre parenthèses (format: "message (60 secondes)")
          final parenMatch = RegExp(r'\((\d+)\s*secondes?\)').firstMatch(errorMessage);
          if (parenMatch != null) {
            setState(() {
              _cooldownSeconds = int.parse(parenMatch.group(1)!);
            });
            _startCooldown();
          }
        }
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
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

      if (authService.isAuthenticated) {
        // Si la biométrie est disponible et que l'utilisateur n'a pas encore activé, proposer
        if (_biometricAvailable && !_biometricEnabled && !enableBiometric) {
          _showBiometricEnableDialog();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('2FA_REQUIRED')) {
        setState(() {
          _requires2FA = true;
        });
      } else {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        final lowerErrorMsg = errorMsg.toLowerCase();
        setState(() {
          _errorMessage = errorMsg;
          // Afficher le bouton de renvoi si l'erreur concerne la vérification d'email
          _showResendButton = lowerErrorMsg.contains('vérifier votre email') ||
                             lowerErrorMsg.contains('vérifier votre email avant') ||
                             (lowerErrorMsg.contains('email') && 
                              lowerErrorMsg.contains('vérif'));
        });
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (!_biometricAvailable || !_biometricEnabled) return;

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
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/car_moto_login_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overlay semi-transparent pour améliorer la lisibilité
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Icon(
                          Icons.motorcycle,
                          size: 80,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Bienvenue',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
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
                ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
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
                ),
                        if (_requires2FA) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _totpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Code 2FA',
                              prefixIcon: Icon(Icons.security),
                              border: OutlineInputBorder(),
                              helperText: 'Entrez le code de votre application d\'authentification',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer le code 2FA';
                      }
                      return null;
                    },
                  ),
                ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
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
                                        : const Icon(Icons.email_outlined),
                                    label: Text(
                                      _cooldownSeconds > 0
                                          ? 'Renvoyer dans ${_cooldownSeconds}s'
                                          : 'Renvoyer l\'email de vérification',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Consumer<AuthService>(
                          builder: (context, authService, _) {
                            return ElevatedButton(
                              onPressed: authService.isLoading ? null : () => _login(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: authService.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Se connecter'),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Bouton de connexion biométrique (si disponible)
                        if (_biometricAvailable && !_isCheckingBiometric) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          if (_biometricEnabled) ...[
                            // Si activé, afficher le bouton de connexion biométrique
                            OutlinedButton.icon(
                              onPressed: _loginWithBiometrics,
                              icon: Icon(
                                _biometricTypeName.contains('Face') || _biometricTypeName.contains('face')
                                    ? Icons.face 
                                    : Icons.fingerprint,
                                size: 24,
                              ),
                              label: Text('Se connecter avec $_biometricTypeName'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                                size: 24,
                              ),
                              label: Text('Activer $_biometricTypeName'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text('Pas encore de compte ? S\'inscrire'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

