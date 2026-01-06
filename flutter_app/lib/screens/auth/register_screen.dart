import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/background_helper.dart';
import 'login_screen.dart';
import 'phone_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? referralCode;
  
  const RegisterScreen({super.key, this.referralCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;
  String? _referralCode;
  bool _isValidatingReferralCode = false;
  bool _referralCodeValid = false;
  String? _referralCodeError;
  String? _phoneNumber;
  String? _countryCode;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Récupérer le code de parrainage depuis l'URL ou le paramètre
    _referralCode = widget.referralCode;
    if (_referralCode == null) {
      // Essayer de récupérer depuis l'URL (pour Flutter Web)
      try {
        final uri = Uri.base;
        _referralCode = uri.queryParameters['ref'];
      } catch (e) {
        // Ignorer les erreurs
      }
    }
    
    // Préremplir le champ si un code est détecté
    if (_referralCode != null && _referralCode!.isNotEmpty) {
      _referralCodeController.text = _referralCode!.toUpperCase();
      // Valider le code au démarrage s'il est prérempli
      _validateReferralCode(_referralCode!.toUpperCase());
    }
  }

  Future<void> _validateReferralCode(String code) async {
    if (code.trim().isEmpty) {
      setState(() {
        _referralCodeValid = false;
        _referralCodeError = null;
      });
      return;
    }

    setState(() {
      _isValidatingReferralCode = true;
      _referralCodeError = null;
      _referralCodeValid = false;
    });

    try {
      final result = await _apiService.validateReferralCode(code);
      setState(() {
        _referralCodeValid = result['valid'] == true;
        _referralCodeError = result['valid'] == false ? result['message'] : null;
        _isValidatingReferralCode = false;
      });
    } catch (e) {
      setState(() {
        _referralCodeValid = false;
        _referralCodeError = 'Erreur lors de la validation du code';
        _isValidatingReferralCode = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pseudoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Vérifier que tous les contrôleurs sont initialisés
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final pseudo = _pseudoController.text.trim();
      
      if (email.isEmpty || password.isEmpty || pseudo.isEmpty) {
        setState(() {
          _errorMessage = 'Veuillez remplir tous les champs obligatoires';
        });
        return;
      }
      
      // Vérifier que le téléphone est fourni (OBLIGATOIRE)
      if (_phoneNumber == null || _phoneNumber!.isEmpty || _countryCode == null) {
        setState(() {
          _errorMessage = 'Le numéro de téléphone est obligatoire pour créer un compte. Veuillez renseigner votre numéro au format international.';
        });
        return;
      }
      
      // Normaliser le téléphone (format E.164)
      // intl_phone_field fournit déjà le format complet avec indicatif
      String normalizedPhone = '$_countryCode$_phoneNumber';
      // Retirer les espaces et tirets
      normalizedPhone = normalizedPhone.replaceAll(RegExp(r'[\s-]'), '');
      
      // Vérifier que le numéro contient au moins 8 chiffres
      final digitsOnly = normalizedPhone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 8) {
        setState(() {
          _errorMessage = 'Le numéro de téléphone doit contenir au moins 8 chiffres. Format attendu: indicatif pays + numéro (ex: +33612345678)';
        });
        return;
      }
      
      // Utiliser le code depuis le champ ou celui détecté dans l'URL
      final referralCodeToUse = _referralCodeController.text.trim().isNotEmpty
          ? _referralCodeController.text.trim().toUpperCase()
          : _referralCode;
      
      final result = await authService.register(
        email,
        password,
        pseudo,
        phone: normalizedPhone,
        referralCode: referralCodeToUse,
      );

      if (!mounted) return;

      // Déterminer le message selon si l'email a été envoyé ou non et si le parrainage a fonctionné
      final emailSent = result['emailSent'] ?? true;
      final referralRewardGranted = result['referralRewardGranted'] ?? false;
      final phoneRequiresVerification = result['phoneRequiresVerification'] ?? false;
      
      // Rediriger vers la vérification OTP (téléphone obligatoire maintenant)
      if (phoneRequiresVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PhoneVerificationScreen(
              phone: normalizedPhone,
              isRegistration: true,
            ),
          ),
        );
        return;
      }
      
      String message;
      if (referralRewardGranted) {
        message = emailSent
            ? 'Inscription réussie ! Vous avez reçu 1 mois d\'abonnement Premium gratuit grâce au parrainage. Un email de validation a été envoyé à votre adresse.'
            : 'Inscription réussie ! Vous avez reçu 1 mois d\'abonnement Premium gratuit grâce au parrainage. Cependant, l\'email de vérification n\'a pas pu être envoyé. Veuillez utiliser le bouton "Renvoyer l\'email de vérification" ci-dessous.';
      } else {
        message = emailSent
            ? 'Un email de validation a été envoyé à votre adresse. Veuillez vérifier votre boîte mail et cliquer sur le lien pour activer votre compte.'
            : 'Votre compte a été créé avec succès. Cependant, l\'email de vérification n\'a pas pu être envoyé (le service email n\'est pas configuré). Veuillez utiliser le bouton "Renvoyer l\'email de vérification" ci-dessous pour recevoir votre lien de validation.';
      }

      // Retourner immédiatement à la page de connexion avec un message
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            message: message,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
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
                          'Créer un compte',
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
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                IntlPhoneField(
                  decoration: const InputDecoration(
                    labelText: 'Téléphone *',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatoire - Format international requis (ex: +33612345678)',
                    errorMaxLines: 3,
                  ),
                  initialCountryCode: 'FR',
                  onChanged: (phone) {
                    setState(() {
                      _countryCode = phone.countryCode;
                      _phoneNumber = phone.number;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pseudoController,
                  decoration: const InputDecoration(
                    labelText: 'Pseudo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    helperText: '3-30 caractères (lettres, chiffres, tirets, underscores)',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un pseudo';
                    }
                    if (value.trim().length < 3) {
                      return 'Le pseudo doit contenir au moins 3 caractères';
                    }
                    if (value.trim().length > 30) {
                      return 'Le pseudo ne peut pas dépasser 30 caractères';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
                      return 'Le pseudo ne peut contenir que des lettres, chiffres, tirets et underscores';
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
                    helperText: 'Au moins 6 caractères',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un mot de passe';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer votre mot de passe';
                    }
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Code de parrainage (optionnel)',
                    prefixIcon: const Icon(Icons.card_giftcard),
                    suffixIcon: _isValidatingReferralCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _referralCodeController.text.trim().isNotEmpty
                            ? (_referralCodeValid
                                ? Icon(Icons.check_circle, color: Colors.green[700])
                                : Icon(Icons.error, color: Colors.red[700]))
                            : null,
                    border: const OutlineInputBorder(),
                    helperText: 'Entrez le code de parrainage pour recevoir 1 mois Premium gratuit',
                    errorText: _referralCodeError,
                  ),
                  onChanged: (value) {
                    // Convertir en majuscules automatiquement
                    final upperValue = value.toUpperCase();
                    if (value != upperValue) {
                      _referralCodeController.value = TextEditingValue(
                        text: upperValue,
                        selection: TextSelection.collapsed(offset: upperValue.length),
                      );
                    }
                    // Valider le code après un délai (debounce)
                    if (upperValue.trim().isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted && _referralCodeController.text.trim() == upperValue.trim()) {
                          _validateReferralCode(upperValue.trim());
                        }
                      });
                    } else {
                      setState(() {
                        _referralCodeValid = false;
                        _referralCodeError = null;
                      });
                    }
                  },
                ),
                if (_referralCodeController.text.trim().isNotEmpty && _referralCodeValid && !_isValidatingReferralCode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vous recevrez 1 mois d\'abonnement Premium gratuit après inscription !',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    return ElevatedButton(
                      onPressed: authService.isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: authService.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('S\'inscrire'),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Déjà un compte ? Se connecter'),
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

