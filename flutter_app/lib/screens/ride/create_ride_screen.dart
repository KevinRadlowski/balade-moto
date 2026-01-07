import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/plan_provider.dart';
import '../../exceptions/plan_limit_exception.dart';
import '../../widgets/premium/premium_upsell_modal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../home/home_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Contrôleurs
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _lieuDepartController = TextEditingController();
  final _lieuArriveeController = TextEditingController();
  
  // État
  String _typeVehicule = 'moto';
  String _visibilite = 'publique';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  Position? _currentPosition;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _lieuDepartController.dispose();
    _lieuArriveeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission de localisation refusée')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée définitivement')),
          );
        }
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de récupérer la position actuelle')),
          );
        }
        return;
      }

      // Récupérer l'adresse (optionnel, on continue même si ça échoue)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final street = place.street ?? '';
          final postalCode = place.postalCode ?? '';
          final locality = place.locality ?? '';
          final address = '$street $postalCode $locality'.trim();
          if (mounted) {
            _lieuDepartController.text = address.isNotEmpty ? address : 'Position actuelle';
          }
        } else if (mounted) {
          // Si on ne peut pas récupérer l'adresse, on met quand même la position
          _lieuDepartController.text = 'Position actuelle (${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)})';
        }
      } catch (geocodingError) {
        // Si la géocodification inverse échoue, on utilise quand même la position
        if (mounted) {
          _lieuDepartController.text = 'Position actuelle (${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)})';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la récupération de la position: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date et une heure')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Formater la date et l'heure
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Préparer la localisation GPS si disponible
      Map<String, dynamic>? localisation;
      if (_currentPosition != null) {
        localisation = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
      }

      await _apiService.createRide(
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        typeVehicule: _typeVehicule,
        date: dateTime.toIso8601String(),
        heure: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        lieuDepart: _lieuDepartController.text.trim(),
        lieuArrivee: _lieuArriveeController.text.trim(),
        visibilite: _visibilite,
        localisation: localisation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balade créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        // Rafraîchir l'écran d'accueil avant de revenir
        HomeScreen.refresh(context);
        Navigator.of(context).pop(true); // Retour avec succès
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
        title: const Text('Créer une balade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titreController,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le titre est requis';
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
                maxLength: 2000,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _typeVehicule,
                decoration: const InputDecoration(
                  labelText: 'Type de véhicule *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: const [
                  DropdownMenuItem(value: 'moto', child: Text('🏍️ Moto')),
                  DropdownMenuItem(value: 'voiture', child: Text('🚗 Voiture')),
                ],
                onChanged: (value) {
                  setState(() {
                    _typeVehicule = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : 'Sélectionner une date',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Heure *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Sélectionner une heure',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lieuDepartController,
                decoration: InputDecoration(
                  labelText: 'Lieu de départ *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: _isGettingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                          tooltip: 'Utiliser ma position actuelle',
                        ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le lieu de départ est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lieuArriveeController,
                decoration: const InputDecoration(
                  labelText: 'Lieu d\'arrivée *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le lieu d\'arrivée est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<PlanProvider>(
                builder: (context, planProvider, _) {
                  return DropdownButtonFormField<String>(
                    value: _visibilite,
                    decoration: const InputDecoration(
                      labelText: 'Visibilité *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.visibility),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'publique',
                        child: Text('🌐 Publique'),
                      ),
                      DropdownMenuItem(
                        value: 'privee',
                        child: Text('🔒 Privée'),
                      ),
                    ],
                    onChanged: (value) {
                      // Si l'utilisateur choisit "privée" mais n'a pas les droits
                      if (value == 'privee' && !planProvider.canCreatePrivateRide) {
                        // Forcer à "publique"
                        setState(() {
                          _visibilite = 'publique';
                        });
                        // Afficher un SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Les balades privées sont réservées aux membres Premium'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        // Ouvrir la modale premium
                        showPremiumUpsellModal(
                          context,
                          reason: 'Les balades privées sont réservées aux membres Premium. Passez en Premium pour créer des balades privées illimitées.',
                        );
                      } else {
                        setState(() {
                          _visibilite = value!;
                        });
                      }
                    },
                  );
                },
              ),
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
                          'Créer la balade',
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

