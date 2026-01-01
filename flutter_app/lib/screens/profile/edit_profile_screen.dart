import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/vehicle_icon_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  
  String? _selectedVehiclePreference;
  String? _avatarUrl;
  dynamic _selectedImage; // Peut être File (mobile) ou bytes (web)
  bool _isLoading = false;
  String? _errorMessage;
  
  // Backgrounds personnalisés
  Map<String, String?>? _customBackgrounds;
  Map<String, dynamic> _selectedBackgroundImages = {}; // type -> image

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Construire l'URL complète de l'avatar si nécessaire
  String _buildAvatarUrl(String avatarUrl) {
    // Utiliser ApiConfig.getFileUrl() qui gère le remplacement de localhost
    return ApiConfig.getFileUrl(avatarUrl);
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Recharger les données utilisateur depuis le serveur pour avoir l'avatar à jour
    try {
      final token = await authService.storage.read(key: 'token');
      final apiService = ApiService();
      apiService.setToken(token);
      final user = await apiService.getMe();
      
      _firstNameController.text = user.firstName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _pseudoController.text = user.pseudo ?? '';
      _emailController.text = user.email;
      _selectedVehiclePreference = user.vehiclePreference ?? 'moto';
      _avatarUrl = user.avatarUrl;
      _customBackgrounds = user.customBackgrounds;
      
      // Mettre à jour l'utilisateur dans AuthService
      authService.updateUser(user);
    } catch (e) {
      // En cas d'erreur, utiliser les données locales
      final user = authService.user;
      if (user != null) {
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _pseudoController.text = user.pseudo ?? '';
        _emailController.text = user.email;
        _selectedVehiclePreference = user.vehiclePreference ?? 'moto';
        _avatarUrl = user.avatarUrl;
        _customBackgrounds = user.customBackgrounds;
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    
    try {
      if (kIsWeb) {
        // Pour le web (PC), utiliser file_picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null) {
          final file = result.files.single;
          
          if (file.bytes != null) {
            // Uploader l'image depuis les bytes (web)
            await _uploadImageFromBytes(file.bytes!, file.name);
          } else {
            throw Exception('Impossible de lire le fichier sélectionné');
          }
        }
      } else {
        // Pour mobile, utiliser image_picker
        final ImagePicker picker = ImagePicker();
        
        // Demander à l'utilisateur de choisir la source
        final ImageSource? source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choisir une source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galerie'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Appareil photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
        
        if (source != null) {
          final XFile? image = await picker.pickImage(
            source: source,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );

          if (image != null) {
            // Sur mobile uniquement, créer un File depuis le chemin
            if (!kIsWeb) {
              // Utiliser le chemin directement pour éviter les problèmes avec io.File
              await _uploadImage(image.path);
            } else {
              throw Exception('Cette méthode ne devrait pas être appelée sur le web');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImage(String imagePath) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      // Uploader l'image (sur mobile uniquement)
      final avatarUrl = await apiService.uploadAvatar(imagePath);

      setState(() {
        _avatarUrl = avatarUrl;
        // Sur mobile, stocker le chemin pour l'affichage local
        // On ne stocke pas le File directement car il sera créé dynamiquement si nécessaire
        if (!kIsWeb) {
          _selectedImage = imagePath; // Stocker le chemin au lieu du File
        }
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploadée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImageFromBytes(List<int> bytes, String fileName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');

      // Uploader via une requête multipart
      final uri = Uri.parse('${ApiService.baseUrl}/user/upload-avatar');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      // Convertir les bytes en MultipartFile
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _avatarUrl = data['data']['avatarUrl'];
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploadée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'upload');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      // Mettre à jour le profil (l'avatar a déjà été uploadé si nécessaire)
      final updatedUser = await apiService.updateProfile(
        firstName: _firstNameController.text.trim().isEmpty 
            ? null 
            : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty 
            ? null 
            : _lastNameController.text.trim(),
        pseudo: _pseudoController.text.trim(),
        email: _emailController.text.trim(),
        vehiclePreference: _selectedVehiclePreference,
        avatarUrl: _avatarUrl,
      );

      // Mettre à jour l'utilisateur dans AuthService
      authService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Widget _buildBackgroundSelector(String title, String type, String description, IconData icon) {
    final currentBackground = _customBackgrounds?[type];
    final hasSelectedImage = _selectedBackgroundImages.containsKey(type);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (currentBackground != null && currentBackground.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(currentBackground),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickBackgroundImage(type),
                    icon: const Icon(Icons.image, size: 18),
                    label: Text(hasSelectedImage ? 'Changer' : 'Sélectionner'),
                  ),
                ),
                if (currentBackground != null && currentBackground.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _deleteBackground(type),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage(String type) async {
    try {
      FilePickerResult? result;
      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedBackgroundImages[type] = file;
        });
        
        // Uploader immédiatement
        await _uploadBackground(type, file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadBackground(String type, PlatformFile file) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      final result = await apiService.uploadBackground(
        imageFile: file,
        type: type,
      );

      // Mettre à jour les backgrounds personnalisés
      setState(() {
        if (_customBackgrounds == null) {
          _customBackgrounds = {};
        }
        _customBackgrounds![type] = result['data']['url'];
        _selectedBackgroundImages.remove(type);
      });

      // Recharger les données utilisateur
      final user = await apiService.getMe();
      authService.updateUser(user);
      _customBackgrounds = user.customBackgrounds;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background uploadé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBackground(String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le background'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce background ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      await apiService.deleteBackground(type);

      // Mettre à jour les backgrounds personnalisés
      setState(() {
        if (_customBackgrounds == null) {
          _customBackgrounds = {};
        }
        _customBackgrounds![type] = null;
      });

      // Recharger les données utilisateur
      final user = await apiService.getMe();
      authService.updateUser(user);
      _customBackgrounds = user.customBackgrounds;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: _avatarUrl != null && 
                                       _avatarUrl!.isNotEmpty && 
                                       (_avatarUrl!.startsWith('http') || _avatarUrl!.startsWith('/uploads'))
                            ? NetworkImage(_buildAvatarUrl(_avatarUrl!)) as ImageProvider
                            : null, // Utiliser uniquement l'URL du serveur pour l'affichage
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty || 
                               (!_avatarUrl!.startsWith('http') && !_avatarUrl!.startsWith('/uploads'))) &&
                               (kIsWeb || _selectedImage == null || _selectedImage is! String)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: _isLoading ? null : _pickImage,
                          padding: EdgeInsets.zero,
                          tooltip: kIsWeb ? 'Sélectionner une image' : 'Prendre une photo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Prénom
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              // Nom
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              // Pseudo
              TextFormField(
                controller: _pseudoController,
                decoration: const InputDecoration(
                  labelText: 'Pseudo *',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                  helperText: '3-30 caractères, lettres, chiffres, tirets et underscores uniquement',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le pseudo est requis';
                  }
                  if (value.length < 3) {
                    return 'Le pseudo doit contenir au moins 3 caractères';
                  }
                  if (value.length > 30) {
                    return 'Le pseudo ne peut pas dépasser 30 caractères';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
                    return 'Le pseudo ne peut contenir que des lettres, chiffres, tirets et underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'email est requis';
                  }
                  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Préférence de véhicule
              DropdownButtonFormField<String>(
                value: _selectedVehiclePreference,
                decoration: const InputDecoration(
                  labelText: 'Préférence de véhicule',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'moto',
                    child: Row(
                      children: [
                        Text('🏍️ '),
                        SizedBox(width: 8),
                        Text('Moto'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'voiture',
                    child: Row(
                      children: [
                        Text('🚗 '),
                        SizedBox(width: 8),
                        Text('Voiture'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'les deux',
                    child: Row(
                      children: [
                        Text('🏍️🚗 '),
                        SizedBox(width: 8),
                        Text('Les deux'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedVehiclePreference = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Section Backgrounds personnalisés
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Backgrounds personnalisés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Background global
              _buildBackgroundSelector(
                'Background global',
                'global',
                'Appliqué à toute l\'application',
                Icons.public,
              ),
              const SizedBox(height: 16),
              
              // Background balades
              _buildBackgroundSelector(
                'Background balades',
                'balade',
                'Écran d\'accueil (liste des balades)',
                getVehicleIcon(_selectedVehiclePreference),
              ),
              const SizedBox(height: 16),
              
              // Background groupes
              _buildBackgroundSelector(
                'Background groupes',
                'groupe',
                'Groupes de discussion',
                Icons.group,
              ),
              const SizedBox(height: 16),
              
              // Background profil
              _buildBackgroundSelector(
                'Background profil',
                'profil',
                'Écran de profil',
                Icons.person,
              ),
              const SizedBox(height: 24),
              
              // Message d'erreur
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer les modifications'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

