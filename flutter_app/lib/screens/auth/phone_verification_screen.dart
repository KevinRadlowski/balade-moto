import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../utils/background_helper.dart';
import 'login_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phone;
  final bool isRegistration;

  const PhoneVerificationScreen({
    super.key,
    required this.phone,
    this.isRegistration = false,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _errorMessage;
  String? _successMessage;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Envoyer automatiquement l'OTP à l'arrivée si c'est une inscription
    if (widget.isRegistration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendOtp();
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final visible = phone.substring(phone.length - 4);
    final masked = '*' * (phone.length - 4);
    return '$masked$visible';
  }

  Future<void> _sendOtp() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendPhoneOtp(widget.phone);

      setState(() {
        _isSendingOtp = false;
        _resendCooldown = 60; // 60 secondes de cooldown
        _successMessage = 'Code OTP envoyé avec succès';
      });

      // Démarrer le compte à rebours
      _startCooldown();
    } catch (e) {
      setState(() {
        _isSendingOtp = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
        _startCooldown();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Veuillez entrer un code à 6 chiffres';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.verifyPhoneOtp(widget.phone, _otpController.text);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _successMessage = 'Téléphone vérifié avec succès !';
      });

      // Attendre un peu avant de rediriger
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // Rediriger selon le contexte
      if (widget.isRegistration) {
        // Après inscription, rediriger vers login avec message de succès
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              successMessage: 'Votre téléphone a été vérifié avec succès. Vous pouvez maintenant vous connecter.',
              showEmailWarning: true, // Après inscription, l'email n'est probablement pas encore vérifié
            ),
          ),
        );
      } else {
        // Depuis le profil, retourner en arrière
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRegistration ? 'Vérification téléphone' : 'Vérifier mon téléphone'),
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
            child: Container(
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
                  Icon(
                    Icons.phone_android,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vérification du téléphone',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nous avons envoyé un code de vérification à 6 chiffres au numéro :',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _maskPhone(widget.phone),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  PinCodeTextField(
                    appContext: context,
                    length: 6,
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 56,
                      fieldWidth: 48,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.grey[300],
                      selectedColor: Theme.of(context).colorScheme.primary,
                    ),
                    enableActiveFill: true,
                    onCompleted: (code) {
                      _verifyOtp();
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_successMessage != null)
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
                              _successMessage!,
                              style: TextStyle(color: Colors.green[700], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Vérifier'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous n\'avez pas reçu le code ? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _resendCooldown > 0 || _isSendingOtp ? null : _sendOtp,
                        child: _isSendingOtp
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _resendCooldown > 0
                                    ? 'Renvoyer (${_resendCooldown}s)'
                                    : 'Renvoyer',
                              ),
                      ),
                    ],
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
