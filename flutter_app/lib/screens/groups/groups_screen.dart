import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/group.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../../widgets/location_autocomplete_field.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _discoverScrollController = ScrollController();
  Timer? _searchDebounce;

  // Données
  List<Group> _favoriteGroups = [];
  List<Group> _joinedGroups = [];
  List<Group> _discoverGroups = [];
  
  // États de chargement
  bool _isLoadingFavorites = false;
  bool _isLoadingJoined = false;
  bool _isLoadingDiscover = false;
  bool _isLoadingMoreDiscover = false;
  
  // Pagination discover
  int _discoverPage = 1;
  bool _hasMoreDiscover = true;
  static const int _discoverLimit = 20;

  // Filtres
  String? _searchQuery;
  String? _visibiliteFilter;
  String? _regionFilter;
  String? _departmentCodeFilter;
  String? _cityFilter;
  bool _nearMeEnabled = false;
  double _nearMeRadius = 25.0; // km
  Position? _userPosition;
  
  // Filtres de localisation (depuis autocomplete)
  LocationFilterData? _selectedLocation;
  bool _filterAroundLocation = false;

  // IDs pour éviter les duplications
  final Set<String> _favoriteIds = {};
  final Set<String> _joinedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _discoverScrollController.addListener(_onDiscoverScroll);
    _loadAllData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _discoverScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().isEmpty 
            ? null 
            : _searchController.text.trim();
      });
      _loadAllData();
    });
  }

  void _onDiscoverScroll() {
    if (_discoverScrollController.position.pixels >= 
        _discoverScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreDiscover && _hasMoreDiscover) {
        _loadMoreDiscover();
      }
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadFavorites(),
      _loadJoined(),
      _loadDiscover(reset: true),
    ]);
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() => _isLoadingFavorites = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final result = await _apiService.getGroups(
        scope: 'favorites',
        q: _searchQuery,
        owner: _searchQuery, // Recherche aussi dans le propriétaire
        visibilite: _visibiliteFilter,
        region: _regionFilter,
        departmentCode: _departmentCodeFilter,
        city: _cityFilter,
        nearLat: _nearMeEnabled ? _userPosition?.latitude : null,
        nearLng: _nearMeEnabled ? _userPosition?.longitude : null,
        nearKm: _nearMeEnabled ? _nearMeRadius : null,
        limit: 100,
      );

      final groupsData = result['groups'] as List;
      final groups = groupsData.map((g) => Group.fromJson(g)).toList();

      if (mounted) {
        setState(() {
          _favoriteGroups = groups;
          _favoriteIds.clear();
          _favoriteIds.addAll(groups.map((g) => g.id));
          _isLoadingFavorites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFavorites = false);
        debugPrint('Erreur lors du chargement des favoris: $e');
      }
    }
  }

  Future<void> _loadJoined() async {
    if (!mounted) return;
    setState(() => _isLoadingJoined = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final result = await _apiService.getGroups(
        scope: 'joined',
        q: _searchQuery,
        owner: _searchQuery,
        visibilite: _visibiliteFilter,
        region: _regionFilter,
        departmentCode: _departmentCodeFilter,
        city: _cityFilter,
        nearLat: _nearMeEnabled ? _userPosition?.latitude : null,
        nearLng: _nearMeEnabled ? _userPosition?.longitude : null,
        nearKm: _nearMeEnabled ? _nearMeRadius : null,
        limit: 100,
      );

      final groupsData = result['groups'] as List;
      final groups = groupsData.map((g) => Group.fromJson(g)).toList();

      if (mounted) {
        setState(() {
          _joinedGroups = groups;
          _joinedIds.clear();
          _joinedIds.addAll(groups.map((g) => g.id));
          _isLoadingJoined = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingJoined = false);
        debugPrint('Erreur lors du chargement des groupes rejoints: $e');
      }
    }
  }

  Future<void> _loadDiscover({bool reset = false}) async {
    if (!mounted) return;
    
    if (reset) {
      setState(() {
        _discoverPage = 1;
        _hasMoreDiscover = true;
        _discoverGroups = [];
        _isLoadingDiscover = true;
      });
    } else {
      setState(() => _isLoadingMoreDiscover = true);
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Déterminer les paramètres de localisation
      double? nearLat;
      double? nearLng;
      double? nearKm;
      String? region;
      String? departmentCode;
      String? city;

      if (_filterAroundLocation && _selectedLocation != null && _selectedLocation!.hasCoordinates) {
        // Si "Filtrer autour de ce lieu" est activé, utiliser les coordonnées
        nearLat = _selectedLocation!.lat;
        nearLng = _selectedLocation!.lng;
        nearKm = _nearMeRadius;
      } else if (_selectedLocation != null && _selectedLocation!.hasLocation) {
        // Sinon, utiliser les filtres texte (region/department/city)
        region = _selectedLocation!.regionName;
        departmentCode = _selectedLocation!.departmentCode;
        city = _selectedLocation!.city;
      } else if (_nearMeEnabled) {
        // Fallback: utiliser la position de l'utilisateur si "Près de moi" est activé
        nearLat = _userPosition?.latitude;
        nearLng = _userPosition?.longitude;
        nearKm = _nearMeRadius;
      }

      final result = await _apiService.getGroups(
        scope: 'discover',
        q: _searchQuery,
        owner: _searchQuery,
        visibilite: _visibiliteFilter,
        region: region ?? _regionFilter,
        departmentCode: departmentCode ?? _departmentCodeFilter,
        city: city ?? _cityFilter,
        nearLat: nearLat,
        nearLng: nearLng,
        nearKm: nearKm,
        page: _discoverPage,
        limit: _discoverLimit,
      );

      final groupsData = result['groups'] as List;
      final pagination = result['pagination'] as Map<String, dynamic>;
      final newGroups = groupsData.map((g) => Group.fromJson(g)).toList();

      // Filtrer les groupes déjà dans favoris ou rejoints
      final filteredGroups = newGroups.where((g) {
        return !_favoriteIds.contains(g.id) && !_joinedIds.contains(g.id);
      }).toList();

      if (mounted) {
        setState(() {
          if (reset) {
            _discoverGroups = filteredGroups;
          } else {
            _discoverGroups.addAll(filteredGroups);
          }
          _hasMoreDiscover = _discoverPage < (pagination['pages'] as int? ?? 1);
          _isLoadingDiscover = false;
          _isLoadingMoreDiscover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDiscover = false;
          _isLoadingMoreDiscover = false;
        });
        debugPrint('Erreur lors du chargement des groupes à découvrir: $e');
      }
    }
  }

  Future<void> _loadMoreDiscover() async {
    if (!_hasMoreDiscover || _isLoadingMoreDiscover) return;
    
    setState(() => _discoverPage++);
    await _loadDiscover(reset: false);
  }

  Future<void> _toggleFavorite(Group group) async {
    final wasFavorite = group.isFavorite ?? false;
    
    // Mise à jour optimiste
    setState(() {
      if (wasFavorite) {
        _favoriteGroups.removeWhere((g) => g.id == group.id);
        _favoriteIds.remove(group.id);
        // Mettre à jour le groupe dans toutes les listes
        _updateGroupInLists(group.id, isFavorite: false);
      } else {
        final updatedGroup = Group(
          id: group.id,
          nom: group.nom,
          description: group.description,
          visibilite: group.visibilite,
          createur: group.createur,
          membres: group.membres,
          bannedUsers: group.bannedUsers,
          unreadCount: group.unreadCount,
          lastMessageAt: group.lastMessageAt,
          isFavorite: true,
          isMember: group.isMember,
          location: group.location,
        );
        _favoriteGroups.insert(0, updatedGroup);
        _favoriteIds.add(group.id);
        _updateGroupInLists(group.id, isFavorite: true);
      }
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final newFavoriteState = await _apiService.toggleFavoriteGroup(group.id);
      
      if (mounted) {
        // Si l'état a changé (erreur côté serveur), corriger
        if (newFavoriteState != !wasFavorite) {
          setState(() {
            if (newFavoriteState) {
              if (!_favoriteIds.contains(group.id)) {
                final updatedGroup = Group(
                  id: group.id,
                  nom: group.nom,
                  description: group.description,
                  visibilite: group.visibilite,
                  createur: group.createur,
                  membres: group.membres,
                  bannedUsers: group.bannedUsers,
                  unreadCount: group.unreadCount,
                  lastMessageAt: group.lastMessageAt,
                  isFavorite: true,
                  isMember: group.isMember,
                  location: group.location,
                );
                _favoriteGroups.insert(0, updatedGroup);
                _favoriteIds.add(group.id);
              }
              _updateGroupInLists(group.id, isFavorite: true);
            } else {
              _favoriteGroups.removeWhere((g) => g.id == group.id);
              _favoriteIds.remove(group.id);
              _updateGroupInLists(group.id, isFavorite: false);
            }
          });
        }
      }
    } catch (e) {
      // Rollback en cas d'erreur
      if (mounted) {
        setState(() {
          if (wasFavorite) {
            final updatedGroup = Group(
              id: group.id,
              nom: group.nom,
              description: group.description,
              visibilite: group.visibilite,
              createur: group.createur,
              membres: group.membres,
              bannedUsers: group.bannedUsers,
              unreadCount: group.unreadCount,
              lastMessageAt: group.lastMessageAt,
              isFavorite: true,
              isMember: group.isMember,
              location: group.location,
            );
            _favoriteGroups.insert(0, updatedGroup);
            _favoriteIds.add(group.id);
            _updateGroupInLists(group.id, isFavorite: true);
          } else {
            _favoriteGroups.removeWhere((g) => g.id == group.id);
            _favoriteIds.remove(group.id);
            _updateGroupInLists(group.id, isFavorite: false);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateGroupInLists(String groupId, {required bool isFavorite}) {
    // Mettre à jour dans joinedGroups
    final joinedIndex = _joinedGroups.indexWhere((g) => g.id == groupId);
    if (joinedIndex != -1) {
      final group = _joinedGroups[joinedIndex];
      _joinedGroups[joinedIndex] = Group(
        id: group.id,
        nom: group.nom,
        description: group.description,
        visibilite: group.visibilite,
        createur: group.createur,
        membres: group.membres,
        bannedUsers: group.bannedUsers,
        unreadCount: group.unreadCount,
        lastMessageAt: group.lastMessageAt,
        isFavorite: isFavorite,
        isMember: group.isMember,
        location: group.location,
      );
    }

    // Mettre à jour dans discoverGroups
    final discoverIndex = _discoverGroups.indexWhere((g) => g.id == groupId);
    if (discoverIndex != -1) {
      final group = _discoverGroups[discoverIndex];
      _discoverGroups[discoverIndex] = Group(
        id: group.id,
        nom: group.nom,
        description: group.description,
        visibilite: group.visibilite,
        createur: group.createur,
        membres: group.membres,
        bannedUsers: group.bannedUsers,
        unreadCount: group.unreadCount,
        lastMessageAt: group.lastMessageAt,
        isFavorite: isFavorite,
        isMember: group.isMember,
        location: group.location,
      );
    }
  }

  Future<void> _loadUserPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _nearMeEnabled = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _nearMeEnabled = false);
          return;
        }
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _userPosition = position;
          });
        }
      } else {
        setState(() => _nearMeEnabled = false);
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la position: $e');
      if (mounted) {
        setState(() => _nearMeEnabled = false);
      }
    }
  }

  Future<void> _showFiltersSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersBottomSheet(
        visibilite: _visibiliteFilter,
        selectedLocation: _selectedLocation,
        filterAroundLocation: _filterAroundLocation,
        nearMeEnabled: _nearMeEnabled,
        nearMeRadius: _nearMeRadius,
      ),
    );

    if (result != null) {
      setState(() {
        _visibiliteFilter = result['visibilite'];
        _selectedLocation = result['selectedLocation'] as LocationFilterData?;
        _filterAroundLocation = result['filterAroundLocation'] as bool? ?? false;
        _nearMeEnabled = result['nearMeEnabled'] as bool;
        _nearMeRadius = result['nearMeRadius'] as double;
        
        // Mettre à jour les anciens filtres pour compatibilité
        if (_selectedLocation != null) {
          _regionFilter = _selectedLocation!.regionName;
          _departmentCodeFilter = _selectedLocation!.departmentCode;
          _cityFilter = _selectedLocation!.city;
        } else {
          _regionFilter = null;
          _departmentCodeFilter = null;
          _cityFilter = null;
        }
      });

      if (_nearMeEnabled && _userPosition == null) {
        await _loadUserPosition();
      }

      _loadAllData();
    }
  }

  Future<void> _navigateToCreateGroup() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateGroupScreen(),
      ),
    );
    if (result == true) {
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    final customGroupeBackground = user?.customBackgrounds?['groupe'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customGroupeBackground != null && customGroupeBackground.isNotEmpty)
        ? customGroupeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBackgroundImageName(user?.vehiclePreference);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupes de discussion'),
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
            alignment: Alignment.center,
          ),
        ),
        child: Column(
          children: [
            // Barre de recherche et filtres
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.9),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher (nom, description, propriétaire)',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFiltersSheet,
                    tooltip: 'Filtres',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // Contenu scrollable
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAllData,
                child: CustomScrollView(
                  slivers: [
                    // Section Favoris
                    if (_favoriteGroups.isNotEmpty || _isLoadingFavorites)
                      _buildSectionHeader('⭐ Favoris', _isLoadingFavorites),
                    if (_isLoadingFavorites)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_favoriteGroups.isEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _GroupCard(
                            group: _favoriteGroups[index],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(
                                    groupId: _favoriteGroups[index].id,
                                  ),
                                ),
                              );
                              _loadAllData();
                            },
                            onToggleFavorite: () => _toggleFavorite(_favoriteGroups[index]),
                          ),
                          childCount: _favoriteGroups.length,
                        ),
                      ),

                    // Section Mes groupes
                    if (_joinedGroups.isNotEmpty || _isLoadingJoined)
                      _buildSectionHeader('👥 Mes groupes', _isLoadingJoined),
                    if (_isLoadingJoined)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_joinedGroups.isEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _GroupCard(
                            group: _joinedGroups[index],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(
                                    groupId: _joinedGroups[index].id,
                                  ),
                                ),
                              );
                              _loadAllData();
                            },
                            onToggleFavorite: () => _toggleFavorite(_joinedGroups[index]),
                          ),
                          childCount: _joinedGroups.length,
                        ),
                      ),

                    // Section Découvrir
                    _buildSectionHeader('🔍 Découvrir', _isLoadingDiscover),
                    if (_isLoadingDiscover && _discoverGroups.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_discoverGroups.isEmpty && !_isLoadingDiscover)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.explore, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun groupe à découvrir',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < _discoverGroups.length) {
                              return _GroupCard(
                                group: _discoverGroups[index],
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailScreen(
                                        groupId: _discoverGroups[index].id,
                                      ),
                                    ),
                                  );
                                  _loadAllData();
                                },
                                onToggleFavorite: () => _toggleFavorite(_discoverGroups[index]),
                              );
                            } else if (_isLoadingMoreDiscover) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          childCount: _discoverGroups.length + (_isLoadingMoreDiscover ? 1 : 0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateGroup,
        icon: const Icon(Icons.add),
        label: const Text('Créer un groupe'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isLoading) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white.withOpacity(0.7),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white.withOpacity(0.85),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  group.nom[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            group.isFavorite == true
                                ? Icons.star
                                : Icons.star_border,
                            color: group.isFavorite == true
                                ? Colors.amber
                                : Colors.grey,
                          ),
                          onPressed: onToggleFavorite,
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (group.description != null && group.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            group.visibilite == 'publique' ? 'Public' : 'Privé',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: group.visibilite == 'publique'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          labelStyle: TextStyle(
                            color: group.visibilite == 'publique'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: TextStyle(
                            color: Colors.blue.shade700,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (group.location != null && group.location!.city != null)
                          Chip(
                            label: Text(
                              group.location!.city!,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersBottomSheet extends StatefulWidget {
  final String? visibilite;
  final LocationFilterData? selectedLocation;
  final bool filterAroundLocation;
  final bool nearMeEnabled;
  final double nearMeRadius;

  const _FiltersBottomSheet({
    this.visibilite,
    this.selectedLocation,
    this.filterAroundLocation = false,
    required this.nearMeEnabled,
    required this.nearMeRadius,
  });

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  late String? _visibilite;
  LocationFilterData? _selectedLocation;
  late bool _filterAroundLocation;
  late bool _nearMeEnabled;
  late double _nearMeRadius;

  @override
  void initState() {
    super.initState();
    _visibilite = widget.visibilite;
    _selectedLocation = widget.selectedLocation;
    _filterAroundLocation = widget.filterAroundLocation;
    _nearMeEnabled = widget.nearMeEnabled;
    _nearMeRadius = widget.nearMeRadius;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Visibilité
                const Text(
                  'Visibilité',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Tous')),
                    ButtonSegment(value: 'publique', label: Text('Publics')),
                    ButtonSegment(value: 'privee', label: Text('Privés')),
                  ],
                  selected: {_visibilite},
                  onSelectionChanged: (Set<String?> selected) {
                    setState(() {
                      _visibilite = selected.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Localisation
                const Text(
                  'Localisation',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                LocationAutocompleteField(
                  initialValue: _selectedLocation?.displayName,
                  labelText: 'Lieu',
                  hintText: 'Tapez une ville, région ou département...',
                  onLocationSelected: (locationData) {
                    setState(() {
                      _selectedLocation = locationData;
                      // Si un lieu est sélectionné et qu'on n'a pas encore activé "Filtrer autour",
                      // on peut proposer cette option
                    });
                  },
                ),
                if (_selectedLocation != null && _selectedLocation!.hasCoordinates) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filtrer autour de ce lieu',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rayon: ${_nearMeRadius.toInt()} km',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _filterAroundLocation,
                        onChanged: (value) {
                          setState(() => _filterAroundLocation = value);
                        },
                      ),
                    ],
                  ),
                  if (_filterAroundLocation) ...[
                    const SizedBox(height: 12),
                    Slider(
                      value: _nearMeRadius,
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '${_nearMeRadius.toInt()} km',
                      onChanged: (value) {
                        setState(() => _nearMeRadius = value);
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                // Près de moi
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Près de moi',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rayon: ${_nearMeRadius.toInt()} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _nearMeEnabled,
                      onChanged: (value) {
                        setState(() => _nearMeEnabled = value);
                      },
                    ),
                  ],
                ),
                if (_nearMeEnabled) ...[
                  const SizedBox(height: 12),
                  Slider(
                    value: _nearMeRadius,
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: '${_nearMeRadius.toInt()} km',
                    onChanged: (value) {
                      setState(() => _nearMeRadius = value);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _visibilite = null;
                            _selectedLocation = null;
                            _filterAroundLocation = false;
                            _nearMeEnabled = false;
                            _nearMeRadius = 25.0;
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'visibilite': _visibilite,
                            'selectedLocation': _selectedLocation,
                            'filterAroundLocation': _filterAroundLocation,
                            'nearMeEnabled': _nearMeEnabled,
                            'nearMeRadius': _nearMeRadius,
                          });
                        },
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
