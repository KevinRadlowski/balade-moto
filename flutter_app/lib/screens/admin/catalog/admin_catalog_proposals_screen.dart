import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin/catalog_proposal.dart';
import '../../../services/admin/admin_catalog_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_helper.dart';

class AdminCatalogProposalsScreen extends StatefulWidget {
  const AdminCatalogProposalsScreen({super.key});

  @override
  State<AdminCatalogProposalsScreen> createState() =>
      _AdminCatalogProposalsScreenState();
}

class _AdminCatalogProposalsScreenState
    extends State<AdminCatalogProposalsScreen> with SingleTickerProviderStateMixin {
  late final AdminCatalogService _service;
  final TextEditingController _reasonController = TextEditingController();

  List<CatalogProposal> _proposals = [];
  bool _isLoading = false;
  String? _error;
  String _selectedStatus = 'PENDING';
  int _currentPage = 1;
  final int _limit = 50;
  bool _hasMore = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AdminCatalogService(apiService: authService.apiService);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedStatus = ['PENDING', 'APPROVED', 'REJECTED'][_tabController.index];
          _currentPage = 1;
          _proposals = [];
          _hasMore = true;
        });
        _loadProposals();
      }
    });
    _loadProposals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _proposals = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getProposals(
        status: _selectedStatus,
        page: _currentPage,
        limit: _limit,
      );

      final newProposals = (result['proposals'] as List<CatalogProposal>);
      final pagination = result['pagination'] as Map<String, dynamic>?;

      setState(() {
        _proposals.addAll(newProposals);
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

  Future<void> _approveProposal(CatalogProposal proposal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver la proposition'),
        content: Text('Voulez-vous approuver "${proposal.displayName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.approveProposal(proposal.id);
      setState(() {
        _proposals.removeWhere((p) => p.id == proposal.id);
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Proposition approuvée');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de l\'approbation');
      }
    }
  }

  Future<void> _rejectProposal(CatalogProposal proposal) async {
    _reasonController.clear();
    bool isValid = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rejeter la proposition'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Voulez-vous rejeter "${proposal.displayName}" ?'),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Raison du rejet *',
                  hintText: 'Ex: Modèle déjà existant',
                ),
                maxLines: 3,
                onChanged: (value) {
                  setDialogState(() {
                    isValid = value.trim().isNotEmpty;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isValid
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Rejeter'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    if (_reasonController.text.trim().isEmpty) {
      if (mounted) {
        SnackBarHelper.showError(context, 'La raison est obligatoire');
      }
      return;
    }

    try {
      await _service.rejectProposal(proposal.id, _reasonController.text.trim());
      setState(() {
        _proposals.removeWhere((p) => p.id == proposal.id);
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Proposition rejetée');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du rejet');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Propositions de catalogue'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Approuvées'),
            Tab(text: 'Rejetées'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadProposals(refresh: true),
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Erreur: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadProposals(refresh: true),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : _proposals.isEmpty && !_isLoading
                ? const Center(child: Text('Aucune proposition'))
                : ListView.builder(
                    itemCount: _proposals.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _proposals.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                    onPressed: () => _loadProposals(),
                                    child: const Text('Charger plus'),
                                  ),
                          ),
                        );
                      }

                      final proposal = _proposals[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(proposal.displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${proposal.type}'),
                              if (proposal.createdByEmail != null)
                                Text('Par: ${proposal.createdByEmail}'),
                              Text(
                                'Date: ${proposal.createdAt.toString().split(' ')[0]}',
                              ),
                            ],
                          ),
                          trailing: _selectedStatus == 'PENDING'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _approveProposal(proposal),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _rejectProposal(proposal),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

