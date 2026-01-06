import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  final String? error;

  const ResetPasswordScreen({super.key, this.token, this.error});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _passwordReset = false;
  String? _errorMessage;
  
  // États pour la validation en temps réel
  bool _isPasswordValid = false;
  bool _isConfirmValid = false;
  String _passwordValidationMessage = 'Au moins 6 caractères';
  String _confirmValidationMessage = 'Les mots de passe doivent correspondre';

  @override
  void initState() {
    super.initState();
    // Ajouter les écouteurs pour la validation en temps réel
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirm);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _confirmPasswordController.removeListener(_validateConfirm);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validation en temps réel du nouveau mot de passe
  void _validatePassword() {
    final value = _passwordController.text;
    
    setState(() {
      if (value.isEmpty) {
        _isPasswordValid = false;
        _passwordValidationMessage = 'Au moins 6 caractères';
      } else if (value.length < 6) {
        _isPasswordValid = false;
        _passwordValidationMessage = '❌ Le mot de passe doit contenir au moins 6 caractères (${value.length}/6)';
      } else {
        _isPasswordValid = true;
        _passwordValidationMessage = '✅ Le mot de passe respecte les critères (${value.length} caractères)';
      }
      
      // Re-vérifier la confirmation si elle a déjà été saisie
      if (_confirmPasswordController.text.isNotEmpty) {
        _validateConfirm();
      }
    });
  }

  // Validation en temps réel de la confirmation
  void _validateConfirm() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    
    setState(() {
      if (confirm.isEmpty) {
        _isConfirmValid = false;
        _confirmValidationMessage = 'Les mots de passe doivent correspondre';
      } else if (password.isEmpty) {
        _isConfirmValid = false;
        _confirmValidationMessage = 'Veuillez d\'abord saisir le nouveau mot de passe';
      } else if (confirm == password) {
        _isConfirmValid = true;
        _confirmValidationMessage = '✅ Les mots de passe correspondent';
      } else {
        _isConfirmValid = false;
        _confirmValidationMessage = '❌ Les mots de passe ne correspondent pas';
      }
    });
  }

  Future<void> _resetPassword() async {
    if (widget.token == null) {
      setState(() {
        _errorMessage = 'Token de réinitialisation manquant. Veuillez demander un nouveau lien.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.resetPassword(
        widget.token!,
        _passwordController.text,
      );
      
      if (!mounted) return;

      setState(() {
        _passwordReset = true;
        _isLoading = false;
      });

      // Rediriger vers la page de connexion après 2 secondes
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            message: 'Mot de passe réinitialisé avec succès ! Vous pouvez maintenant vous connecter.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialiser le mot de passe'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_passwordReset)
                    Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Mot de passe réinitialisé !',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Redirection vers la page de connexion...',
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else if (widget.error != null || widget.token == null)
                    Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Lien invalide',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.error == 'token_invalid' || widget.error == 'token_missing'
                              ? 'Ce lien de réinitialisation a expiré ou est invalide. Veuillez demander un nouveau lien.'
                              : 'Une erreur est survenue. Veuillez demander un nouveau lien.',
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('Retour à la connexion'),
                        ),
                      ],
                    )
                  else if (widget.error != null || widget.token == null)
                    Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Lien invalide',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.error == 'token_invalid' || widget.error == 'token_missing'
                              ? 'Ce lien de réinitialisation a expiré ou est invalide. Veuillez demander un nouveau lien.'
                              : 'Une erreur est survenue. Veuillez demander un nouveau lien.',
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('Retour à la connexion'),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 80,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Nouveau mot de passe',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Entrez votre nouveau mot de passe. Il doit contenir au moins 6 caractères.',
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            hintText: 'Au moins 6 caractères',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _passwordController.text.isEmpty
                                    ? Colors.grey
                                    : _isPasswordValid
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _passwordController.text.isEmpty
                                    ? Colors.grey
                                    : _isPasswordValid
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _passwordController.text.isEmpty
                                    ? Theme.of(context).primaryColor
                                    : _isPasswordValid
                                        ? Colors.green
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
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
                        const SizedBox(height: 8),
                        Text(
                          _passwordValidationMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: _passwordController.text.isEmpty
                                ? Colors.grey
                                : _isPasswordValid
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            hintText: 'Répétez le mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _confirmPasswordController.text.isEmpty
                                    ? Colors.grey
                                    : _isConfirmValid
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _confirmPasswordController.text.isEmpty
                                    ? Colors.grey
                                    : _isConfirmValid
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _confirmPasswordController.text.isEmpty
                                    ? Theme.of(context).primaryColor
                                    : _isConfirmValid
                                        ? Colors.green
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez confirmer le mot de passe';
                            }
                            if (value != _passwordController.text) {
                              return 'Les mots de passe ne correspondent pas';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _confirmValidationMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: _confirmPasswordController.text.isEmpty
                                ? Colors.grey
                                : _isConfirmValid
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700]),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Réinitialiser le mot de passe'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('Retour à la connexion'),
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
