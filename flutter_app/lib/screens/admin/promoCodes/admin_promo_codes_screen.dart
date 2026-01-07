import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/admin/admin_only.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/admin/admin_promo_codes_service.dart';
import '../../../../models/admin/promo_code.dart';
import '../../../../utils/snackbar_helper.dart';

class AdminPromoCodesScreen extends StatefulWidget {
  const AdminPromoCodesScreen({super.key});

  @override
  State<AdminPromoCodesScreen> createState() => _AdminPromoCodesScreenState();
}

class _AdminPromoCodesScreenState extends State<AdminPromoCodesScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AdminPromoCodesService _service;
  late final TabController _tabController;
  
  // Contrôleurs
  final _countController = TextEditingController(text: '1');
  final _usageLimitController = TextEditingController(text: '1');
  final _discountPercentController = TextEditingController();
  final _premiumMonthsController = TextEditingController();
  
  // État du formulaire (onglet Générer)
  String _selectedType = 'DISCOUNT_PERCENT';
  bool _hasExpirationDate = false;
  DateTime? _validUntil;
  DateTime? _validFrom;
  
  // État de génération
  bool _isGenerating = false;
  String? _error;
  List<GeneratedPromoCode> _generatedCodes = [];

  // État de l'historique (onglet Historique)
  List<PromoCodeListItem> _historyItems = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  int _currentPage = 0;
  final int _limit = 20;
  bool _hasMoreHistory = true;
  bool _activeOnly = false;
  String? _filterType; // null = Tous

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AdminPromoCodesService(apiService: authService.apiService);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyItems.isEmpty && !_isLoadingHistory) {
        _loadHistory(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countController.dispose();
    _usageLimitController.dispose();
    _discountPercentController.dispose();
    _premiumMonthsController.dispose();
    super.dispose();
  }

  // ========== ONGLET GÉNÉRER ==========

  Future<void> _generateCodes() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final count = int.parse(_countController.text);
      final usageLimit = int.parse(_usageLimitController.text);
      
      int? discountPercent;
      int? premiumMonths;
      
      if (_selectedType == 'DISCOUNT_PERCENT') {
        discountPercent = int.parse(_discountPercentController.text);
      } else if (_selectedType == 'GRANT_PREMIUM_MONTHS') {
        premiumMonths = int.parse(_premiumMonthsController.text);
      }

      final request = AdminGeneratePromoCodesRequest(
        type: _selectedType,
        count: count,
        discountPercent: discountPercent,
        premiumMonths: premiumMonths,
        usageLimit: usageLimit,
        validFrom: _validFrom,
        validUntil: _hasExpirationDate ? _validUntil : null,
      );

      final codes = await _service.adminGeneratePromoCodes(request);

      setState(() {
        _generatedCodes = codes;
        _isGenerating = false;
      });

      if (mounted) {
        SnackBarHelper.showSuccess(context, '${codes.length} code(s) généré(s) avec succès');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isGenerating = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, _error ?? 'Erreur lors de la génération');
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      SnackBarHelper.showSuccess(context, 'Code copié dans le presse-papiers');
    }
  }

  Future<void> _copyAllCodes() async {
    if (_generatedCodes.isEmpty) return;
    
    final allCodes = _generatedCodes.map((c) => c.code).join('\n');
    await Clipboard.setData(ClipboardData(text: allCodes));
    if (mounted) {
      SnackBarHelper.showSuccess(context, 'Tous les codes copiés dans le presse-papiers');
    }
  }

  Future<void> _shareCodes() async {
    if (_generatedCodes.isEmpty) return;
    
    final allCodes = _generatedCodes.map((c) => c.code).join('\n');
    await Share.share(allCodes, subject: 'Codes promotionnels RideTogether');
  }

  Future<void> _selectDate(BuildContext context, bool isUntil) async {
    final now = DateTime.now();
    final firstDate = isUntil && _validFrom != null ? _validFrom! : now;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: isUntil ? (_validUntil ?? now.add(const Duration(days: 30))) : now,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isUntil ? (_validUntil ?? now) : now,
        ),
      );

      if (time != null) {
        final dateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isUntil) {
            _validUntil = dateTime;
          } else {
            _validFrom = dateTime;
          }
        });
      }
    }
  }

  // ========== ONGLET HISTORIQUE ==========

  Future<void> _loadHistory({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _historyItems = [];
      _hasMoreHistory = true;
    }

    if (_isLoadingHistory || !_hasMoreHistory) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final skip = _currentPage * _limit;
      final page = await _service.adminListPromoCodes(
        active: _activeOnly ? true : null,
        type: _filterType,
        limit: _limit,
        skip: skip,
      );

      setState(() {
        if (refresh) {
          _historyItems = page.items;
        } else {
          _historyItems.addAll(page.items);
        }
        _currentPage++;
        _hasMoreHistory = page.items.length >= _limit;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString().replaceAll('Exception: ', '');
        _isLoadingHistory = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du chargement');
      }
    }
  }

  Future<void> _deactivateCode(PromoCodeListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver le code'),
        content: Text('Voulez-vous désactiver le code "${item.codePrefix}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.adminDeactivatePromoCode(item.id);
      setState(() {
        final index = _historyItems.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _historyItems[index] = PromoCodeListItem(
            id: item.id,
            codePrefix: item.codePrefix,
            type: item.type,
            isActive: false,
            usedCount: item.usedCount,
            usageLimit: item.usageLimit,
            validUntil: item.validUntil,
            discountPercent: item.discountPercent,
            premiumMonths: item.premiumMonths,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          );
        }
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Code désactivé');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la désactivation');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminOnly(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Codes promo'),
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
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Générer'),
              Tab(text: 'Historique'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGenerateTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Formulaire de génération
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Génération de codes promotionnels',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Type de code
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type de code',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'DISCOUNT_PERCENT',
                          child: Text('Réduction (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'GRANT_PREMIUM_MONTHS',
                          child: Text('Premium X mois'),
                        ),
                        DropdownMenuItem(
                          value: 'GRANT_PREMIUM_PERMANENT',
                          child: Text('Premium illimité'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                            _discountPercentController.clear();
                            _premiumMonthsController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Nombre de codes
                    TextFormField(
                      controller: _countController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de codes',
                        border: OutlineInputBorder(),
                        helperText: 'Entre 1 et 500',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le nombre de codes est requis';
                        }
                        final count = int.tryParse(value);
                        if (count == null || count < 1 || count > 500) {
                          return 'Le nombre doit être entre 1 et 500';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Usage limit
                    TextFormField(
                      controller: _usageLimitController,
                      decoration: const InputDecoration(
                        labelText: 'Usage',
                        border: OutlineInputBorder(),
                        helperText: 'Nombre d\'utilisations par code (défaut: 1)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'L\'usage est requis';
                        }
                        final limit = int.tryParse(value);
                        if (limit == null || limit < 1) {
                          return 'L\'usage doit être >= 1';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Champs conditionnels selon le type
                    if (_selectedType == 'DISCOUNT_PERCENT') ...[
                      TextFormField(
                        controller: _discountPercentController,
                        decoration: const InputDecoration(
                          labelText: 'Pourcentage',
                          border: OutlineInputBorder(),
                          helperText: 'Entre 1 et 100',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le pourcentage est requis';
                          }
                          final percent = int.tryParse(value);
                          if (percent == null || percent < 1 || percent > 100) {
                            return 'Le pourcentage doit être entre 1 et 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    if (_selectedType == 'GRANT_PREMIUM_MONTHS') ...[
                      TextFormField(
                        controller: _premiumMonthsController,
                        decoration: const InputDecoration(
                          labelText: 'Durée (mois)',
                          border: OutlineInputBorder(),
                          helperText: 'Nombre de mois Premium',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La durée est requise';
                          }
                          final months = int.tryParse(value);
                          if (months == null || months < 1) {
                            return 'La durée doit être >= 1';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Dates de validité
                    SwitchListTile(
                      title: const Text('Définir une date d\'expiration'),
                      value: _hasExpirationDate,
                      onChanged: (value) {
                        setState(() {
                          _hasExpirationDate = value;
                          if (!value) {
                            _validUntil = null;
                          }
                        });
                      },
                    ),
                    
                    if (_hasExpirationDate) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Valide jusqu\'au'),
                        subtitle: Text(
                          _validUntil != null
                              ? '${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year} ${_validUntil!.hour}:${_validUntil!.minute.toString().padLeft(2, '0')}'
                              : 'Non définie',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, true),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Valide à partir de (optionnel)'),
                      subtitle: Text(
                        _validFrom != null
                            ? '${_validFrom!.day}/${_validFrom!.month}/${_validFrom!.year} ${_validFrom!.hour}:${_validFrom!.minute.toString().padLeft(2, '0')}'
                            : 'Non définie',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_validFrom != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _validFrom = null;
                                });
                              },
                            ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                      onTap: () => _selectDate(context, false),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bouton Générer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateCodes,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text(_isGenerating ? 'Génération...' : 'Générer'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    
                    // Erreur
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Section codes générés
            if (_generatedCodes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Codes générés (affichés une seule fois)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ces codes ne seront plus affichés ensuite. Sauvegardez-les maintenant.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_generatedCodes.length} code(s) généré(s)',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all),
                                tooltip: 'Copier tout',
                                onPressed: _copyAllCodes,
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                tooltip: 'Partager',
                                onPressed: _shareCodes,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400,
                        child: ListView.builder(
                          itemCount: _generatedCodes.length,
                          itemBuilder: (context, index) {
                            final code = _generatedCodes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  code.code,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('Préfixe: ${code.prefix}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyCode(code.code),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Actifs uniquement'),
                      value: _activeOnly,
                      onChanged: (value) {
                        setState(() {
                          _activeOnly = value;
                        });
                        _loadHistory(refresh: true);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Tous'),
                  ),
                  DropdownMenuItem(
                    value: 'DISCOUNT_PERCENT',
                    child: Text('Réduction'),
                  ),
                  DropdownMenuItem(
                    value: 'GRANT_PREMIUM_MONTHS',
                    child: Text('Premium mois'),
                  ),
                  DropdownMenuItem(
                    value: 'GRANT_PREMIUM_PERMANENT',
                    child: Text('Premium illimité'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterType = value;
                  });
                  _loadHistory(refresh: true);
                },
              ),
            ],
          ),
        ),
        
        // Liste
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadHistory(refresh: true),
            child: _historyError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Erreur: $_historyError'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadHistory(refresh: true),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _historyItems.isEmpty && !_isLoadingHistory
                    ? const Center(child: Text('Aucun code promotionnel'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyItems.length + (_hasMoreHistory ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _historyItems.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _isLoadingHistory
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () => _loadHistory(),
                                        child: const Text('Charger plus'),
                                      ),
                              ),
                            );
                          }

                          final item = _historyItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Row(
                                children: [
                                  Text(
                                    'RT-${item.codePrefix}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.isActive
                                          ? Colors.green.shade100
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item.isActive ? 'Actif' : 'Inactif',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: item.isActive
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Type: ${item.typeDisplayName}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Usage: ${item.usedCount}/${item.usageLimit}',
                                  ),
                                  if (item.validUntil != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Valide jusqu\'au: ${DateFormat('dd/MM/yyyy HH:mm').format(item.validUntil!)}',
                                      style: TextStyle(
                                        color: item.validUntil!.isBefore(DateTime.now())
                                            ? Colors.red
                                            : null,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: item.isActive
                                  ? IconButton(
                                      icon: const Icon(Icons.block, color: Colors.orange),
                                      tooltip: 'Désactiver',
                                      onPressed: () => _deactivateCode(item),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
