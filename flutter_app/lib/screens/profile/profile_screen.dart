import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../models/user.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final BiometricService _biometricService = BiometricService();
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricTypeName = 'Biométrie';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final enabled = await authService.isBiometricEnabled();
      final available = await _biometricService.isAvailable();
      final typeName = await _biometricService.getBiometricTypeName();
      
      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
          _biometricAvailable = available;
          _biometricTypeName = typeName;
        });
      }
    } catch (e) {
      // Ignorer les erreurs
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final user = await _apiService.getMe();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Construire l'URL complète de l'avatar si nécessaire
  String _buildAvatarUrl(String avatarUrl) {
    // Utiliser ApiConfig.getFileUrl() qui gère le remplacement de localhost
    return ApiConfig.getFileUrl(avatarUrl);
  }

  Future<void> _showEnableBiometricDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activer $_biometricTypeName'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour activer $_biometricTypeName, veuillez entrer vos identifiants :',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mot de passe requis';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.login(
          emailController.text.trim(),
          passwordController.text,
          saveCredentials: true,
        );
        
        if (mounted) {
          setState(() {
            _biometricEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_biometricTypeName activé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    // Priorité : background spécifique > background global > background par défaut
    final customProfilBackground = user?.customBackgrounds?['profil'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customProfilBackground != null && customProfilBackground.isNotEmpty)
        ? customProfilBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getProfilBackgroundImageName(user?.vehiclePreference);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundImage.startsWith('http') || backgroundImage.startsWith('/uploads')
                ? NetworkImage(backgroundImage.startsWith('/uploads') 
                    ? ApiConfig.getFileUrl(backgroundImage)
                    : backgroundImage)
                : AssetImage(backgroundImage) as ImageProvider,
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, 0.2), // Centré horizontalement, légèrement décalé vers le bas pour mieux centrer la moto
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadProfile,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _user == null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Profil non trouvé',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Section avatar et nom
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Theme.of(context).primaryColor,
                                  backgroundImage: _user!.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                                      ? NetworkImage(_buildAvatarUrl(_user!.avatarUrl!))
                                      : null,
                                  child: _user!.avatarUrl == null || _user!.avatarUrl!.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfileScreen(),
                                      ),
                                    ).then((_) {
                                      // Recharger le profil après modification
                                      _loadProfile();
                                    });
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Modifier le profil'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Section informations
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _ProfileField(
                            icon: Icons.person,
                            label: 'Nom complet',
                            value: _user!.firstName != null && _user!.lastName != null
                                ? '${_user!.firstName} ${_user!.lastName}'
                                : 'Non renseigné',
                          ),
                          const SizedBox(height: 12),
                          _ProfileField(
                            icon: Icons.alternate_email,
                            label: 'Pseudo',
                            value: _user!.pseudo ?? 'Non renseigné',
                          ),
                          const SizedBox(height: 12),
                          _ProfileField(
                            icon: Icons.email,
                            label: 'Email',
                            value: _user!.email,
                          ),
                          const SizedBox(height: 12),
                          _ProfileField(
                            icon: Icons.directions_car,
                            label: 'Préférence de véhicule',
                            value: _user!.vehiclePreference == 'moto'
                                ? '🏍️ Moto'
                                : _user!.vehiclePreference == 'voiture'
                                    ? '🚗 Voiture'
                                    : 'Les deux',
                          ),
                                const SizedBox(height: 12),
                                _ProfileField(
                                  icon: Icons.verified,
                                  label: 'Email vérifié',
                                  value: _user!.emailVerified ? 'Oui' : 'Non',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Section paramètres de sécurité
                          if (_biometricAvailable) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sécurité',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile(
                                    title: Text('$_biometricTypeName'),
                                    subtitle: Text('Utiliser $_biometricTypeName pour se connecter'),
                                    value: _biometricEnabled,
                                    onChanged: (value) async {
                                      if (value) {
                                        // Activer la biométrie
                                        final authService = Provider.of<AuthService>(context, listen: false);
                                        final savedEmail = await authService.storage.read(key: 'saved_email');
                                        final savedPassword = await authService.storage.read(key: 'saved_password');
                                        
                                        if (savedEmail == null || savedPassword == null) {
                                          // Demander les identifiants pour les sauvegarder
                                          _showEnableBiometricDialog();
                                        } else {
                                          // Les identifiants sont déjà sauvegardés, activer directement
                                          await authService.storage.write(key: 'biometric_enabled', value: 'true');
                                          setState(() {
                                            _biometricEnabled = true;
                                          });
                                        }
                                      } else {
                                        // Désactiver la biométrie
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Désactiver la biométrie ?'),
                                            content: const Text(
                                              'Vos identifiants sauvegardés seront supprimés. '
                                              'Vous devrez vous connecter manuellement la prochaine fois.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Désactiver', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirm == true) {
                                          final authService = Provider.of<AuthService>(context, listen: false);
                                          await authService.disableBiometric();
                                          setState(() {
                                            _biometricEnabled = false;
                                          });
                                        }
                                      }
                                    },
                                    secondary: Icon(
                                      _biometricTypeName.contains('Face') 
                                          ? Icons.face 
                                          : Icons.fingerprint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Bouton de déconnexion
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Confirmation avant déconnexion
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Déconnexion'),
                                    content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true) {
                                  final authService = Provider.of<AuthService>(context, listen: false);
                                  await authService.logout();
                                  if (mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.logout, size: 24),
                              label: const Text(
                                'Me déconnecter',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black87),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

