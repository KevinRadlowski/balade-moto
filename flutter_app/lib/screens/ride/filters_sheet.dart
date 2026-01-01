import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class FiltersSheet extends StatefulWidget {
  final String? typeVehicule;
  final String? dateDebut;
  final String? dateFin;
  final String? search;
  final double? rayon;
  final String? lieu;

  const FiltersSheet({
    super.key,
    this.typeVehicule,
    this.dateDebut,
    this.dateFin,
    this.search,
    this.rayon,
    this.lieu,
  });

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  String? _typeVehicule;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final _searchController = TextEditingController();
  double? _rayon;
  String? _lieu;
  final _lieuController = TextEditingController();
  bool _isLoadingLocation = false;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _typeVehicule = widget.typeVehicule;
    _dateDebut = widget.dateDebut != null ? DateTime.parse(widget.dateDebut!) : null;
    _dateFin = widget.dateFin != null ? DateTime.parse(widget.dateFin!) : null;
    _searchController.text = widget.search ?? '';
    _rayon = widget.rayon;
    _lieu = widget.lieu;
    _lieuController.text = widget.lieu ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lieuController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_dateDebut ?? DateTime.now()) : (_dateFin ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Les services de localisation sont désactivés')),
          );
        }
        return;
      }

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
            const SnackBar(content: Text('Permission de localisation définitivement refusée')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _lieu = '${place.locality ?? ''}, ${place.country ?? ''}'.trim();
          _lieuController.text = _lieu!;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _applyFilters() async {
    // Si un lieu et un rayon sont spécifiés, géocoder l'adresse
    String? lieu = _lieuController.text.trim().isEmpty ? null : _lieuController.text.trim();
    double? rayon = _rayon;
    double? latitude;
    double? longitude;
    String? formattedAddress;

    if (lieu != null && rayon != null && rayon > 0) {
      setState(() {
        _isGeocoding = true;
      });

      try {
        // Géocoder l'adresse via le backend
        final apiService = ApiService();
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        apiService.setToken(token);

        final geocodeResult = await apiService.geocodeAddress(lieu);
        latitude = geocodeResult['latitude']?.toDouble();
        longitude = geocodeResult['longitude']?.toDouble();
        formattedAddress = geocodeResult['address']?.toString();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du géocodage de l\'adresse: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isGeocoding = false;
        });
        return; // Ne pas appliquer les filtres si le géocodage échoue
      } finally {
        if (mounted) {
          setState(() {
            _isGeocoding = false;
          });
        }
      }
    }

    if (mounted) {
      debugPrint('🔍 Filtres appliqués: lieu=$lieu, rayon=$rayon, lat=$latitude, lng=$longitude');
      Navigator.of(context).pop({
        'typeVehicule': _typeVehicule,
        'dateDebut': _dateDebut?.toIso8601String().split('T')[0],
        'dateFin': _dateFin?.toIso8601String().split('T')[0],
        'search': _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        'rayon': rayon,
        'lieu': lieu,
        'latitude': latitude,
        'longitude': longitude,
        'formattedAddress': formattedAddress,
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _typeVehicule = null;
      _dateDebut = null;
      _dateFin = null;
      _searchController.clear();
      _rayon = null;
      _lieu = null;
      _lieuController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Rechercher',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    hintText: 'Titre ou description...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type de véhicule',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Tous')),
                    ButtonSegment(value: 'moto', label: Text('Moto')),
                    ButtonSegment(value: 'voiture', label: Text('Voiture')),
                  ],
                  selected: {_typeVehicule},
                  onSelectionChanged: (Set<String?> newSelection) {
                    setState(() {
                      _typeVehicule = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _dateDebut != null
                              ? DateFormat('dd/MM/yyyy').format(_dateDebut!)
                              : 'Date de début',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, false),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _dateFin != null
                              ? DateFormat('dd/MM/yyyy').format(_dateFin!)
                              : 'Date de fin',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Localisation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lieuController,
                        decoration: const InputDecoration(
                          labelText: 'Lieu de départ',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                          hintText: 'Ville ou adresse (ex: Lyon)...',
                          helperText: 'Saisissez une ville ou une adresse pour filtrer les balades par proximité',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _lieu = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      tooltip: 'Utiliser ma position',
                    ),
                  ],
                ),
                if (_rayon != null && _rayon! > 0 && _lieuController.text.trim().isNotEmpty) ...[
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
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Les balades seront filtrées dans un rayon de ${_rayon!.toInt()} km autour de "${_lieuController.text.trim()}"',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Rayon (km)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _rayon ?? 0,
                        min: 0,
                        max: 200,
                        divisions: 40,
                        label: _rayon != null ? '${_rayon!.toInt()} km' : '0 km',
                        onChanged: (value) {
                          setState(() {
                            _rayon = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        _rayon != null ? '${_rayon!.toInt()} km' : '0 km',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isGeocoding) ? null : () async => await _applyFilters(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isGeocoding
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Géocodage en cours...'),
                          ],
                        )
                      : const Text('Appliquer les filtres'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

