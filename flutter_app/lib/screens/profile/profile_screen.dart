import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../models/user.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../../widgets/profile/reputation_card.dart';
import '../../widgets/profile/emergency_contact_card.dart';
import '../../widgets/profile/referral_card.dart';
import '../../providers/emergency_contact_provider.dart';
import '../../providers/plan_provider.dart';
import '../auth/phone_verification_screen.dart';
import '../premium/premium_screen.dart';
import 'package:intl/intl.dart';

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
    // Charger le contact d'urgence au premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<EmergencyContactProvider>(context, listen: false);
        provider.loadContact();
      }
    });
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

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isChanging = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 28,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Modifier le mot de passe',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Message d'erreur
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Ancien mot de passe
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: obscureOldPassword,
                      enabled: !isChanging,
                      decoration: InputDecoration(
                        labelText: 'Ancien mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOldPassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureOldPassword = !obscureOldPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre ancien mot de passe';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Nouveau mot de passe
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      enabled: !isChanging,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        helperText: 'Au moins 6 caractères',
                        helperMaxLines: 1,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nouveau mot de passe';
                        }
                        if (value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Confirmation
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      enabled: !isChanging,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez confirmer le mot de passe';
                        }
                        if (value != newPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Boutons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isChanging
                              ? null
                              : () {
                                  oldPasswordController.dispose();
                                  newPasswordController.dispose();
                                  confirmPasswordController.dispose();
                                  Navigator.of(context).pop();
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isChanging
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setDialogState(() {
                                    isChanging = true;
                                    errorMessage = null;
                                  });

                                  try {
                                    final authService =
                                        Provider.of<AuthService>(context, listen: false);
                                    final token =
                                        await authService.storage.read(key: 'token');
                                    _apiService.setToken(token);

                                    await _apiService.changePassword(
                                      oldPasswordController.text,
                                      newPasswordController.text,
                                    );

                                    if (!mounted) return;

                                    oldPasswordController.dispose();
                                    newPasswordController.dispose();
                                    confirmPasswordController.dispose();

                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mot de passe modifié avec succès'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;

                                    setDialogState(() {
                                      errorMessage =
                                          e.toString().replaceAll('Exception: ', '');
                                      isChanging = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isChanging
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Modifier',
                                  style: TextStyle(fontSize: 16),
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
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDeleting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Supprimer mon compte',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        '⚠️ Cette action est irréversible',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toutes vos données seront définitivement supprimées :',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Votre profil\n• Vos balades\n• Vos groupes\n• Vos messages',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pour confirmer, veuillez entrer votre mot de passe :',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le mot de passe est requis';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                if (!formKey.currentState!.validate()) return;
                
                setDialogState(() {
                  isDeleting = true;
                });
                
                try {
                  // Vérifier le mot de passe en tentant une connexion
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final user = authService.user;
                  
                  final userEmail = user?.email;
                  if (userEmail == null) {
                    throw Exception('Impossible de récupérer vos informations');
                  }
                  
                  // Tenter de se connecter pour vérifier le mot de passe
                  await authService.login(userEmail, passwordController.text);
                  
                  // Si la connexion réussit, supprimer le compte
                  final token = await authService.storage.read(key: 'token');
                  _apiService.setToken(token);
                  await _apiService.deleteAccount();
                  
                  if (mounted) {
                    Navigator.of(context).pop(true);
                    
                    // Déconnecter et rediriger vers login
                    await authService.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Votre compte a été supprimé avec succès'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  setDialogState(() {
                    isDeleting = false;
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().contains('incorrect') || e.toString().contains('mot de passe')
                              ? 'Mot de passe incorrect'
                              : 'Erreur lors de la suppression : ${e.toString().replaceAll('Exception: ', '')}'
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.red.shade300,
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Supprimer définitivement'),
            ),
          ],
        ),
      ),
    );
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
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo RideTogether en header
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
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
                            trailing: _user!.emailVerified
                                ? Icon(Icons.check_circle, color: Colors.green[700], size: 20)
                                : Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                          ),
                          if (!_user!.emailVerified)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 16),
                              child: Text(
                                'Email non vérifié',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _ProfileField(
                            icon: Icons.phone,
                            label: 'Téléphone',
                            value: _user!.phoneE164 ?? _user!.phone ?? 'Non renseigné',
                            trailing: (_user!.phoneE164 != null || _user!.phone != null)
                                ? (_user!.phoneVerified
                                    ? Icon(Icons.check_circle, color: Colors.green[700], size: 20)
                                    : Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20))
                                : null,
                            onTap: () => _showPhoneVerificationDialog(),
                          ),
                          if ((_user!.phoneE164 != null || _user!.phone != null) && !_user!.phoneVerified)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 16),
                              child: Text(
                                'Téléphone non vérifié',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Section Premium
                          const _PremiumCard(),
                          const SizedBox(height: 16),
                          // Section réputation et badges
                          if (_user != null)
                            ReputationCard(userId: _user!.id),
                          const SizedBox(height: 16),
                          // Section parrainage
                          const ReferralCard(),
                          const SizedBox(height: 16),
                          // Section contact d'urgence
                          const EmergencyContactCard(),
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
                                    title: Text(_biometricTypeName),
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
                                  const Divider(),
                                  ListTile(
                                    leading: const Icon(Icons.lock_outline),
                                    title: const Text('Modifier le mot de passe'),
                                    subtitle: const Text('Changer votre mot de passe'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _showChangePasswordDialog(),
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
                          const SizedBox(height: 24),
                          // Section "Paramètres avancés" - Discrète
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      size: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Paramètres avancés',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () => _showChangePasswordDialog(),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                          color: Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Modifier le mot de passe',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                InkWell(
                                  onTap: () => _showDeleteAccountDialog(),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Colors.red.shade400,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Supprimer mon compte',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.red.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: Colors.grey.shade400,
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
    );
  }

  Future<void> _showPhoneVerificationDialog() async {
    final userPhone = _user?.phoneE164 ?? _user?.phone;
    if (userPhone == null || userPhone.isEmpty) {
      // Si pas de téléphone, proposer d'en ajouter un
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter un téléphone dans les paramètres'),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(
          phone: userPhone,
          isRegistration: false,
        ),
      ),
    );

    if (result == true && mounted) {
      // Rafraîchir le profil après vérification
      await _loadProfile();
    }
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
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
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Carte Premium affichant le statut du plan
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final plan = planProvider.plan;
        final isPremium = planProvider.isPremium;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPremium
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
              width: isPremium ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPremium ? Icons.workspace_premium : Icons.account_circle,
                    color: isPremium
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'Compte Premium' : 'Compte Standard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPremium
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (isPremium && plan?.premiumExpiresAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Expire le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(plan!.premiumExpiresAt!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (isPremium) ...[
                // Contenu pour Premium
                const SizedBox(height: 16),
                _buildBenefit(context, Icons.directions_car, 'Garage illimité'),
                const SizedBox(height: 6),
                _buildBenefit(context, Icons.group, 'Groupes privés illimités'),
                const SizedBox(height: 6),
                _buildBenefit(context, Icons.directions_bike, 'Balades privées illimitées'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Gérer Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Contenu pour Standard
                const SizedBox(height: 16),
                Text(
                  'Débloque avec Premium :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBenefit(context, Icons.directions_car, 'Garage illimité (Premium)'),
                const SizedBox(height: 6),
                _buildBenefit(context, Icons.group, 'Groupes privés illimités (Premium)'),
                const SizedBox(height: 6),
                _buildBenefit(context, Icons.directions_bike, 'Balades privées illimitées (Premium)'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Voir Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              // Section Code promo (pour tous les utilisateurs)
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _PromoCodeSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefit(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

/// Section pour saisir et utiliser un code promotionnel
class _PromoCodeSection extends StatefulWidget {
  const _PromoCodeSection();

  @override
  State<_PromoCodeSection> createState() => _PromoCodeSectionState();
}

class _PromoCodeSectionState extends State<_PromoCodeSection> {
  final TextEditingController _codeController = TextEditingController();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      return;
    }

    setState(() {
      _isRedeeming = true;
    });

    try {
      final planProvider = Provider.of<PlanProvider>(context, listen: false);
      await planProvider.redeemPromoCode(code);

      // Afficher le message de succès
      if (mounted && planProvider.lastRedeemMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(planProvider.lastRedeemMessage!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Vider le champ après succès
      _codeController.clear();
    } catch (e) {
      // Afficher l'erreur
      if (mounted) {
        final planProvider = Provider.of<PlanProvider>(context, listen: false);
        final errorMessage = planProvider.lastRedeemError ?? 
            e.toString().replaceAll('Exception: ', '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_offer,
              size: 20,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Code promo / cadeau',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                enabled: !_isRedeeming,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'RT-XXXX-XXXX-XXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: _isRedeeming
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                inputFormatters: [
                  // Formatter pour mettre en majuscules et supprimer les espaces
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-]')),
                ],
                onChanged: (value) {
                  // Supprimer les espaces au milieu
                  final cleaned = value.replaceAll(' ', '').toUpperCase();
                  if (cleaned != value) {
                    _codeController.value = TextEditingValue(
                      text: cleaned,
                      selection: TextSelection.collapsed(offset: cleaned.length),
                    );
                  }
                  setState(() {}); // Pour mettre à jour l'état du bouton
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (_isRedeeming || _codeController.text.trim().isEmpty)
                  ? null
                  : _redeemCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Appliquer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

