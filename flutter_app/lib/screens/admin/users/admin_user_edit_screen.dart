import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin/admin_user.dart';
import '../../../services/admin/admin_users_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_helper.dart';

class AdminUserEditScreen extends StatefulWidget {
  final AdminUser? user;

  const AdminUserEditScreen({super.key, this.user});

  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AdminUsersService _service;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'MEMBER';
  bool _banned = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AdminUsersService(apiService: authService.apiService);
    if (widget.user != null) {
      _emailController.text = widget.user!.email;
      _selectedRole = widget.user!.role;
      _banned = widget.user!.banned ?? false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.user == null) {
        // Créer
        if (_passwordController.text.isEmpty) {
          SnackBarHelper.showError(context, 'Le mot de passe est requis');
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
        await _service.createUser(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
        );
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Utilisateur créé');
          Navigator.pop(context, true);
        }
      } else {
        // Mettre à jour
        await _service.updateUser(
          widget.user!.id,
          email: _emailController.text.trim(),
          role: _selectedRole,
          password: _passwordController.text.isEmpty
              ? null
              : _passwordController.text,
          banned: _banned,
        );
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Utilisateur mis à jour');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          widget.user == null
              ? 'Erreur lors de la création'
              : 'Erreur lors de la mise à jour',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user == null ? 'Créer un utilisateur' : 'Modifier l\'utilisateur'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'L\'email est requis';
                }
                if (!value.contains('@')) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Rôle *',
                prefixIcon: Icon(Icons.security),
              ),
              items: const [
                DropdownMenuItem(value: 'MEMBER', child: Text('Membre')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: widget.user == null ? 'Mot de passe *' : 'Nouveau mot de passe (optionnel)',
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (widget.user == null && (value == null || value.isEmpty)) {
                  return 'Le mot de passe est requis';
                }
                if (value != null && value.isNotEmpty && value.length < 6) {
                  return 'Le mot de passe doit contenir au moins 6 caractères';
                }
                return null;
              },
            ),
            if (widget.user != null) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Banni'),
                subtitle: const Text('Empêcher l\'utilisateur de se connecter'),
                value: _banned,
                onChanged: (value) {
                  setState(() {
                    _banned = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.user == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

