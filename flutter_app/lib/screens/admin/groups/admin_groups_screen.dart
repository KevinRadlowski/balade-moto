import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin/admin_group.dart';
import '../../../services/admin/admin_groups_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_helper.dart';

class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key});

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  late final AdminGroupsService _service;
  final TextEditingController _searchController = TextEditingController();

  List<AdminGroup> _groups = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  final int _limit = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AdminGroupsService(apiService: authService.apiService);
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _groups = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getGroups(
        page: _currentPage,
        limit: _limit,
        query: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final newGroups = (result['groups'] as List<AdminGroup>);
      final pagination = result['pagination'] as Map<String, dynamic>?;

      setState(() {
        _groups.addAll(newGroups);
        _currentPage++;
        _hasMore = pagination?['pages'] != null &&
            _currentPage <= (pagination!['pages'] as int);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du chargement');
      }
    }
  }

  Future<void> _deleteGroup(AdminGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: Text('Voulez-vous supprimer "${group.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteGroup(group.id);
      setState(() {
        _groups.removeWhere((g) => g.id == group.id);
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Groupe supprimé');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la suppression');
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _loadGroups(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération des groupes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Rechercher (nom)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadGroups(refresh: true),
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Erreur: $_error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadGroups(refresh: true),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _groups.isEmpty && !_isLoading
                      ? const Center(child: Text('Aucun groupe'))
                      : ListView.builder(
                          itemCount: _groups.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _groups.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton(
                                          onPressed: () => _loadGroups(),
                                          child: const Text('Charger plus'),
                                        ),
                                ),
                              );
                            }

                            final group = _groups[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(group.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visibilité: ${group.isPublic ? "Publique" : "Privée"}',
                                    ),
                                    if (group.membersCount != null)
                                      Text('Membres: ${group.membersCount}'),
                                    if (group.createdByEmail != null)
                                      Text('Par: ${group.createdByEmail}'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteGroup(group),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

