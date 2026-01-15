import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/plan_provider.dart';
import '../../exceptions/plan_limit_exception.dart';
import '../../widgets/premium/premium_upsell_modal.dart';
import '../../widgets/location_autocomplete_field.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibilite = 'publique';
  LocationFilterData? _selectedLocation;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Vérification de sécurité : bloquer la création si limite atteinte
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    if (_visibilite == 'privee' && !planProvider.canCreatePrivateGroup) {
      // Forcer la visibilité à "publique" pour empêcher la soumission
      setState(() {
        _visibilite = 'publique';
      });
      
      // Afficher la modale
      showPremiumUpsellModal(
        context,
        reason: planProvider.isPremium
            ? 'Erreur inattendue'
            : 'Vous avez atteint votre limite de groupes privés avec le plan Standard (1 groupe maximum). Passez en Premium pour créer un nombre illimité de groupes privés.',
      );
      
      return; // Empêcher la soumission
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      await _apiService.createGroup(
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        visibilite: _visibilite,
        location: _selectedLocation != null
            ? {
                'city': _selectedLocation!.city,
                'departmentCode': _selectedLocation!.departmentCode,
                'departmentName': _selectedLocation!.departmentName,
                'regionName': _selectedLocation!.regionName,
                'countryCode': _selectedLocation!.countryCode,
                'geo': _selectedLocation!.hasCoordinates
                    ? {
                        'type': 'Point',
                        'coordinates': [
                          _selectedLocation!.lng!,
                          _selectedLocation!.lat!,
                        ],
                      }
                    : null,
              }
            : null,
      );

      if (mounted) {
        // Rafraîchir le plan pour mettre à jour les quotas
        final planProvider = Provider.of<PlanProvider>(context, listen: false);
        await planProvider.loadPlan(silent: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Groupe créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // Intercepter PlanLimitException et ouvrir la modale premium
        if (e is PlanLimitException) {
          showPremiumUpsellModal(
            context,
            reason: e.message,
            details: e.details,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom du groupe est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final planProvider = context.read<PlanProvider>();
                  final canCreatePrivate = planProvider.canCreatePrivateGroup;
                  
                  return DropdownButtonFormField<String>(
                    value: _visibilite,
                    decoration: const InputDecoration(
                      labelText: 'Visibilité *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.visibility),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'publique',
                        child: Text('🌐 Publique'),
                      ),
                      DropdownMenuItem(
                        value: 'privee',
                        enabled: canCreatePrivate,
                        child: Text(
                          '🔒 Privée${canCreatePrivate ? '' : ' (Premium)'}',
                          style: TextStyle(
                            color: canCreatePrivate ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                onChanged: (value) async {
                  if (value == null) return;

                  final planProvider = context.read<PlanProvider>();

                  // Cas 1: l'utilisateur choisit "Privée" mais n'a pas le droit
                  if (value == 'privee' && !planProvider.canCreatePrivateGroup) {
                    // Rollback immédiat (FORCE l'UI à rester sur publique)
                    if (mounted) {
                      setState(() {
                        _visibilite = 'publique';
                      });
                    }

                    // Ouvrir la modale Premium (ne change PAS _visibilite dans onDismiss)
                    showPremiumUpsellModal(
                      context,
                      reason: planProvider.isPremium
                          ? 'Erreur inattendue'
                          : 'Vous avez atteint votre limite de groupes privés avec le plan Standard (1 groupe maximum). Passez en Premium pour créer un nombre illimité de groupes privés.',
                    );

                    return;
                  }

                  // Cas 2: sélection autorisée
                  setState(() {
                    _visibilite = value;
                  });
                },
                  );
                },
              ),
              const SizedBox(height: 16),
              LocationAutocompleteField(
                labelText: 'Localisation (optionnel)',
                hintText: 'Tapez une ville, région ou département...',
                onLocationSelected: (locationData) {
                  setState(() {
                    _selectedLocation = locationData;
                  });
                },
              ),
              if (_selectedLocation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedLocation!.displayName ?? 'Lieu sélectionné',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            if (_selectedLocation!.city != null ||
                                _selectedLocation!.departmentName != null ||
                                _selectedLocation!.regionName != null)
                              Text(
                                [
                                  if (_selectedLocation!.city != null) _selectedLocation!.city,
                                  if (_selectedLocation!.departmentName != null)
                                    _selectedLocation!.departmentName,
                                  if (_selectedLocation!.regionName != null)
                                    _selectedLocation!.regionName,
                                ].join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.blue.shade700),
                        onPressed: () {
                          setState(() {
                            _selectedLocation = null;
                          });
                        },
                        tooltip: 'Supprimer la localisation',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Créer le groupe',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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



