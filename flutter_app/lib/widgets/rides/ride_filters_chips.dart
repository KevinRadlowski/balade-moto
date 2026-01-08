import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Widget de chips de filtre pour les balades
class RideFiltersChips extends StatefulWidget {
  final String? typeVehicule;
  final String? visibilite;
  final String? dateDebut;
  final String? dateFin;
  final String? search;
  final double? latitude;
  final double? longitude;
  final double? rayon;
  final String sortBy;
  final String sortOrder;
  final bool showVisibilite;
  final Function(String?) onTypeVehiculeChanged;
  final Function(String?) onVisibiliteChanged;
  final Function(String?) onDateDebutChanged;
  final Function(String?) onDateFinChanged;
  final Function(String?) onSearchChanged;
  final Function(double?, double?, double?) onLocationChanged; // lat, lng, rayon
  final Function(String, String) onSortChanged;
  final VoidCallback onClearFilters;

  const RideFiltersChips({super.key, 
    required this.typeVehicule,
    this.visibilite,
    this.dateDebut,
    this.dateFin,
    this.search,
    this.latitude,
    this.longitude,
    this.rayon,
    required this.sortBy,
    required this.sortOrder,
    required this.showVisibilite,
    required this.onTypeVehiculeChanged,
    required this.onVisibiliteChanged,
    required this.onDateDebutChanged,
    required this.onDateFinChanged,
    required this.onSearchChanged,
    required this.onLocationChanged,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  @override
  State<RideFiltersChips> createState() => _RideFiltersChipsState();
}

class _RideFiltersChipsState extends State<RideFiltersChips> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _showAdvancedFilters = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.search ?? '';
    _updateLocationDisplay();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _updateLocationDisplay() {
    if (widget.latitude != null && widget.longitude != null && widget.rayon != null) {
      _locationController.text = '${widget.rayon!.toInt()} km';
    } else {
      _locationController.text = '';
    }
  }

  bool get hasActiveFilters {
    return widget.typeVehicule != null ||
        widget.visibilite != null ||
        widget.dateDebut != null ||
        widget.dateFin != null ||
        (widget.search != null && widget.search!.isNotEmpty) ||
        widget.sortBy != 'date' ||
        widget.sortOrder != 'asc';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une balade...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged(null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                widget.onSearchChanged(value.isEmpty ? null : value);
              },
              onSubmitted: (value) {
                widget.onSearchChanged(value.isEmpty ? null : value);
              },
            ),
          ),
          
          // Chips de filtre
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Type de véhicule
                _buildTypeVehiculeChip(),
                const SizedBox(width: 8),
                
                // Visibilité (si activé)
                if (widget.showVisibilite) ...[
                  _buildVisibiliteChip(),
                  const SizedBox(width: 8),
                ],
                
                // Période
                _buildPeriodChip(),
                const SizedBox(width: 8),
                
                // Tri
                _buildSortChip(),
                const SizedBox(width: 8),
                
                // Rayon de recherche
                _buildRadiusChip(),
                const SizedBox(width: 8),
                
                // Bouton filtres avancés
                _buildAdvancedFiltersButton(),
                
                // Bouton réinitialiser
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  _buildClearFiltersChip(),
                ],
              ],
            ),
          ),
          
          // Filtres avancés (dates personnalisées)
          if (_showAdvancedFilters) _buildAdvancedFilters(),
        ],
      ),
    );
  }

  Widget _buildTypeVehiculeChip() {
    return FilterChip(
      label: Text(
        widget.typeVehicule == null
            ? 'Tous véhicules'
            : widget.typeVehicule == 'moto'
                ? '🏍️ Moto'
                : '🚗 Voiture',
      ),
      selected: widget.typeVehicule != null,
      onSelected: (selected) {
        if (selected) {
          _showTypeVehiculeMenu();
        } else {
          widget.onTypeVehiculeChanged(null);
        }
      },
      avatar: widget.typeVehicule != null
          ? const Icon(Icons.check, size: 16)
          : null,
    );
  }

  void _showTypeVehiculeMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tous véhicules'),
              onTap: () {
                widget.onTypeVehiculeChanged(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.motorcycle, color: Colors.orange),
              title: const Text('🏍️ Moto'),
              onTap: () {
                widget.onTypeVehiculeChanged('moto');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.blue),
              title: const Text('🚗 Voiture'),
              onTap: () {
                widget.onTypeVehiculeChanged('voiture');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibiliteChip() {
    return FilterChip(
      label: Text(
        widget.visibilite == null
            ? 'Toutes visibilités'
            : widget.visibilite == 'publique'
                ? '🌐 Publique'
                : '🔒 Privée',
      ),
      selected: widget.visibilite != null,
      onSelected: (selected) {
        if (selected) {
          _showVisibiliteMenu();
        } else {
          widget.onVisibiliteChanged(null);
        }
      },
      avatar: widget.visibilite != null
          ? const Icon(Icons.check, size: 16)
          : null,
    );
  }

  void _showVisibiliteMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Toutes visibilités'),
              onTap: () {
                widget.onVisibiliteChanged(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.green),
              title: const Text('🌐 Publique'),
              onTap: () {
                widget.onVisibiliteChanged('publique');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.orange),
              title: const Text('🔒 Privée'),
              onTap: () {
                widget.onVisibiliteChanged('privee');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip() {
    String periodLabel = 'Période';
    if (widget.dateDebut != null || widget.dateFin != null) {
      if (widget.dateDebut != null && widget.dateFin != null) {
        final debut = DateTime.parse(widget.dateDebut!);
        final fin = DateTime.parse(widget.dateFin!);
        periodLabel = '${DateFormat('dd/MM').format(debut)} - ${DateFormat('dd/MM').format(fin)}';
      } else if (widget.dateDebut != null) {
        final debut = DateTime.parse(widget.dateDebut!);
        periodLabel = 'À partir du ${DateFormat('dd/MM').format(debut)}';
      } else if (widget.dateFin != null) {
        final fin = DateTime.parse(widget.dateFin!);
        periodLabel = 'Jusqu\'au ${DateFormat('dd/MM').format(fin)}';
      }
    }

    return FilterChip(
      label: Text(periodLabel),
      selected: widget.dateDebut != null || widget.dateFin != null,
      onSelected: (selected) {
        if (selected) {
          _showPeriodMenu();
        } else {
          widget.onDateDebutChanged(null);
          widget.onDateFinChanged(null);
        }
      },
      avatar: (widget.dateDebut != null || widget.dateFin != null)
          ? const Icon(Icons.check, size: 16)
          : null,
    );
  }

  void _showPeriodMenu() {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Aujourd\'hui'),
              onTap: () {
                final today = DateTime(now.year, now.month, now.day);
                widget.onDateDebutChanged(today.toIso8601String());
                widget.onDateFinChanged(today.toIso8601String());
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_week),
              title: const Text('Cette semaine'),
              onTap: () {
                final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                final endOfWeek = startOfWeek.add(const Duration(days: 6));
                widget.onDateDebutChanged(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toIso8601String());
                widget.onDateFinChanged(DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day).toIso8601String());
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Ce mois'),
              onTap: () {
                // Commencer à partir d'aujourd'hui, pas du 1er du mois
                final today = DateTime(now.year, now.month, now.day);
                final endOfMonth = DateTime(now.year, now.month + 1, 0);
                widget.onDateDebutChanged(today.toIso8601String());
                widget.onDateFinChanged(endOfMonth.toIso8601String());
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Personnalisé'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showAdvancedFilters = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Aucune période'),
              onTap: () {
                widget.onDateDebutChanged(null);
                widget.onDateFinChanged(null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    String sortLabel = 'Tri';
    if (widget.sortBy == 'date') {
      sortLabel = widget.sortOrder == 'asc' ? '📅 Date ↑' : '📅 Date ↓';
    } else if (widget.sortBy == 'likes') {
      sortLabel = '⭐ Popularité';
    }

    return FilterChip(
      label: Text(sortLabel),
      selected: widget.sortBy != 'date' || widget.sortOrder != 'asc',
      onSelected: (selected) {
        if (selected) {
          _showSortMenu();
        } else {
          widget.onSortChanged('date', 'asc');
        }
      },
      avatar: (widget.sortBy != 'date' || widget.sortOrder != 'asc')
          ? const Icon(Icons.check, size: 16)
          : null,
    );
  }

  Widget _buildRadiusChip() {
    String radiusLabel = 'Rayon';
    if (widget.rayon != null && widget.rayon! > 0) {
      radiusLabel = '${widget.rayon!.toInt()} km';
    }

    return FilterChip(
      label: Text(radiusLabel),
      selected: widget.rayon != null && widget.rayon! > 0,
      onSelected: (selected) {
        if (selected) {
          _showRadiusMenu();
        } else {
          widget.onLocationChanged(null, null, null);
        }
      },
      avatar: (widget.rayon != null && widget.rayon! > 0)
          ? const Icon(Icons.check, size: 16)
          : null,
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('📅 Date (croissant)'),
              onTap: () {
                widget.onSortChanged('date', 'asc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('📅 Date (décroissant)'),
              onTap: () {
                widget.onSortChanged('date', 'desc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('⭐ Popularité'),
              onTap: () {
                widget.onSortChanged('likes', 'desc');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRadiusMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rechercher dans un rayon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Ma position actuelle'),
              subtitle: const Text('Utiliser la géolocalisation'),
              onTap: () async {
                Navigator.pop(context);
                await _useCurrentLocation();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Choisir une adresse'),
              subtitle: const Text('Rechercher une ville ou une adresse'),
              onTap: () {
                Navigator.pop(context);
                _showLocationPicker();
              },
            ),
            if (widget.latitude != null && widget.longitude != null && widget.rayon != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Retirer le filtre de rayon'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onLocationChanged(null, null, null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Demander la permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission de localisation refusée'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La localisation est désactivée. Activez-la dans les paramètres.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obtenir la position actuelle
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Proposer de choisir le rayon
      _showRadiusSelector(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de géolocalisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) {
        final addressController = TextEditingController();
        return AlertDialog(
          title: const Text('Rechercher une adresse'),
          content: TextField(
            controller: addressController,
            decoration: const InputDecoration(
              hintText: 'Ex: Lyon, Paris, 69001...',
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: true,
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context);
                await _geocodeAddress(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                if (addressController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  await _geocodeAddress(addressController.text.trim());
                }
              },
              child: const Text('Rechercher'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _geocodeAddress(String address) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Utiliser l'API Google Maps Geocoding
      final apiKey = ApiConfig.googleMapsApiKey;
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$apiKey&language=fr';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final latitude = location['lat'] as double;
          final longitude = location['lng'] as double;
          
          _showRadiusSelector(latitude, longitude);
        } else {
          String errorMessage = 'Adresse introuvable';
          if (data['status'] == 'ZERO_RESULTS') {
            errorMessage = 'Aucun résultat trouvé pour cette adresse';
          } else if (data['status'] == 'OVER_QUERY_LIMIT') {
            errorMessage = 'Limite de requêtes dépassée. Veuillez réessayer plus tard.';
          } else if (data['status'] == 'REQUEST_DENIED') {
            errorMessage = 'Erreur d\'authentification avec Google Maps';
          } else if (data['error_message'] != null) {
            errorMessage = data['error_message'];
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur HTTP ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showRadiusSelector(double latitude, double longitude) {
    double selectedRadius = widget.rayon ?? 50.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir le rayon de recherche'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rayon: ${selectedRadius.toInt()} km'),
              Slider(
                value: selectedRadius,
                min: 0,
                max: 200,
                divisions: 40,
                label: '${selectedRadius.toInt()} km',
                onChanged: (value) {
                  setDialogState(() {
                    selectedRadius = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [10, 25, 50, 100, 200].map((radius) {
                  return ChoiceChip(
                    label: Text('$radius km'),
                    selected: selectedRadius == radius,
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() {
                          selectedRadius = radius.toDouble();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onLocationChanged(latitude, longitude, selectedRadius);
                _updateLocationDisplay();
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFiltersButton() {
    return FilterChip(
      label: const Text('⚙️ Avancé'),
      selected: _showAdvancedFilters,
      onSelected: (selected) {
        setState(() {
          _showAdvancedFilters = selected;
        });
      },
    );
  }

  Widget _buildClearFiltersChip() {
    return ActionChip(
      label: const Text('Réinitialiser'),
      avatar: const Icon(Icons.clear, size: 16),
      onPressed: widget.onClearFilters,
      backgroundColor: Colors.red.shade50,
      labelStyle: TextStyle(color: Colors.red.shade700),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dates personnalisées',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    widget.dateDebut != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.dateDebut!))
                        : 'Date début',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.dateDebut != null
                          ? DateTime.parse(widget.dateDebut!)
                          : DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      widget.onDateDebutChanged(picked.toIso8601String());
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    widget.dateFin != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.dateFin!))
                        : 'Date fin',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.dateFin != null
                          ? DateTime.parse(widget.dateFin!)
                          : DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      widget.onDateFinChanged(picked.toIso8601String());
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

