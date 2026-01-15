import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/group.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../chat/group_chat_screen_v2.dart';
import 'group_calendar_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final ApiService _apiService = ApiService();
  Group? _group;
  bool _isLoading = true;
  bool _isMember = false;
  bool _isAdmin = false;
  bool _isCreator = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final groupData = await _apiService.getGroupById(widget.groupId);
      final groupJson = groupData['data']['group'];
      _group = Group.fromJson(groupJson);
      
      // Vérifier si l'utilisateur est membre depuis le backend
      _isMember = groupData['data']['isMember'] ?? false;
      
      // Vérification supplémentaire : comparer avec l'ID de l'utilisateur connecté
      // (au cas où le backend ne retournerait pas correctement isMember)
      if (_group != null) {
        try {
          final currentUser = await _apiService.getMe();
          final currentUserId = currentUser.id;
          
          // Vérifier si l'utilisateur est le créateur
          final isCreator = _group!.createur.userId.toString() == currentUserId.toString();
          _isCreator = isCreator;
          
          // Vérifier si l'utilisateur est dans la liste des membres
          final isMemberInList = _group!.membres.any((membre) => membre.userId.toString() == currentUserId.toString());
          
          // Vérifier si l'utilisateur est admin (créateur ou membre avec rôle admin)
          final adminMember = _group!.membres.firstWhere(
            (membre) => membre.userId.toString() == currentUserId.toString() && membre.role == 'admin',
            orElse: () => GroupMember(userId: '', role: 'membre', dateAjout: DateTime.now()),
          );
          _isAdmin = isCreator || (adminMember.userId.isNotEmpty && adminMember.role == 'admin');
          
          // Utiliser la valeur du backend si disponible, sinon utiliser la vérification locale
          _isMember = _isMember || isMemberInList || isCreator;
        } catch (e) {
          // Si on ne peut pas récupérer l'utilisateur, on garde la valeur du backend
          print('Erreur lors de la vérification du membre: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_group == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      await _apiService.joinGroup(widget.groupId);
      
      // Recharger les informations du groupe
      await _loadGroup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez rejoint le groupe avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (_group == null) return;

    // Confirmation avant de quitter
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: Text(
          'Êtes-vous sûr de vouloir quitter "${_group!.nom}" ? Vous ne recevrez plus les notifications de ce groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Récupérer l'ID de l'utilisateur actuel
      final currentUser = await _apiService.getMe();
      final currentUserId = currentUser.id;

      // Utiliser removeMemberFromGroup pour retirer l'utilisateur actuel
      await _apiService.removeMemberFromGroup(widget.groupId, currentUserId);
      
      // Recharger les informations du groupe
      await _loadGroup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez quitté le groupe avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    // Priorité : background spécifique > background global > background par défaut
    final customGroupeBackground = user?.customBackgrounds?['groupe'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customGroupeBackground != null && customGroupeBackground.isNotEmpty)
        ? customGroupeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBackgroundImageName(user?.vehiclePreference);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _group?.nom ?? 'Groupe',
          overflow: TextOverflow.ellipsis,
        ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _group == null
                    ? const Center(child: Text('Groupe non trouvé'))
                    : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          // TabBar
                          Container(
                            color: Colors.white.withOpacity(0.9),
                            child: TabBar(
                              labelColor: Colors.blue,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.blue,
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.chat),
                                  text: 'Discussion',
                                ),
                                Tab(
                                  icon: Icon(Icons.calendar_today),
                                  text: 'Calendrier',
                                ),
                              ],
                            ),
                          ),
                          // TabBarView
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Onglet Discussion (contenu existant)
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                          // Titre avec background
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _group!.nom,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (_group!.description != null && _group!.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _group!.description!,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      _group!.visibilite == 'publique'
                                          ? Icons.public
                                          : Icons.lock,
                                      size: 20,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _group!.visibilite == 'publique' ? 'Groupe public' : 'Groupe privé',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Section membres avec background
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Membres (${_group!.membres.length + 1})', // +1 pour le créateur
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Afficher le créateur en premier
                                _buildMemberTile(_group!.createur),
                                // Afficher les autres membres (en excluant le créateur pour éviter les doublons)
                                ..._group!.membres
                                    .where((membre) => membre.userId.toString() != _group!.createur.userId.toString())
                                    .map((membre) => _buildMemberTile(membre)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Boutons d'action avec background
                          if (!_isMember && _group!.visibilite == 'publique') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _joinGroup,
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Rejoindre le groupe'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isMember) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => GroupChatScreenV2(
                                              groupId: _group!.id,
                                              groupName: _group!.nom,
                                              memberCount: _group!.membres.length,
                                            ),
                                          ),
                                        );
                                        // Recharger le groupe pour mettre à jour le badge
                                        _loadGroup();
                                      },
                                      icon: const Icon(Icons.chat),
                                      label: const Text('Ouvrir le chat'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  // Bouton pour quitter le groupe (uniquement si l'utilisateur n'est pas le créateur)
                                  if (!_isCreator) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _leaveGroup,
                                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                                        label: const Text(
                                          'Quitter le groupe',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Actions d'admin avec background
                          if (_isAdmin) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Actions administrateur',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Option pour modifier le groupe (créateur et admin)
                                  if (_isCreator || _isAdmin) ...[
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.edit, color: Colors.blue),
                                      title: const Text('Modifier le groupe'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _showEditGroupDialog(),
                                    ),
                                  ],
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_add, color: Colors.blue),
                                    title: const Text('Inviter un membre'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _showInviteMemberDialog(),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_remove, color: Colors.red),
                                    title: const Text('Gérer les membres'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _showManageMembersDialog(),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.block, color: Colors.red),
                                    title: const Text('Utilisateurs bannis'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _showBannedUsersDialog(),
                                  ),
                                  // Supprimer le groupe (créateur uniquement)
                                  if (_isCreator) ...[
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('Supprimer le groupe'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _showDeleteGroupDialog(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (!_isMember && _group!.visibilite == 'privee') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ce groupe est privé. Vous devez être invité pour le rejoindre.',
                                      style: TextStyle(color: Colors.orange.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                                    ],
                                  ),
                                ),
                                // Onglet Calendrier
                                GroupCalendarScreen(groupId: widget.groupId),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      ),
    );
  }

  // Dialog pour inviter un membre
  Future<void> _showInviteMemberDialog() async {
    Map<String, dynamic>? selectedUser;
    bool isLoading = false;
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Inviter un membre'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) async {
                    final query = textEditingValue.text.trim();
                    if (query.length < 2) {
                      setDialogState(() {
                        selectedUser = null;
                      });
                      return const Iterable<Map<String, dynamic>>.empty();
                    }

                    try {
                      setDialogState(() {
                        isLoading = true;
                        selectedUser = null; // Réinitialiser la sélection lors d'une nouvelle recherche
                      });

                      final authService = Provider.of<AuthService>(context, listen: false);
                      final token = await authService.storage.read(key: 'token');
                      _apiService.setToken(token);

                      final results = await _apiService.searchUsers(query, limit: 10);
                      
                      setDialogState(() {
                        isLoading = false;
                      });

                      return results;
                    } catch (e) {
                      setDialogState(() {
                        isLoading = false;
                      });
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                  },
                  displayStringForOption: (option) {
                    final pseudo = option['pseudo'] ?? '';
                    final email = option['email'] ?? '';
                    return '$pseudo ($email)';
                  },
                  onSelected: (option) {
                    setDialogState(() {
                      selectedUser = option;
                    });
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    // Synchroniser le textController avec le textEditingController
                    textEditingController.addListener(() {
                      textController.text = textEditingController.text;
                      // Réinitialiser la sélection si l'utilisateur modifie le texte manuellement
                      if (selectedUser != null && 
                          textEditingController.text != '${selectedUser!['pseudo']} (${selectedUser!['email']})') {
                        setDialogState(() {
                          selectedUser = null;
                        });
                      }
                    });
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Pseudo ou email',
                        hintText: 'Tapez au moins 2 caractères...',
                        suffixIcon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (value) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final pseudo = option['pseudo'] ?? '';
                              final email = option['email'] ?? '';
                              final avatarUrl = option['avatarUrl'];

                              return ListTile(
                                leading: avatarUrl != null
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(ApiConfig.getFileUrl(avatarUrl)),
                                        radius: 20,
                                      )
                                    : const CircleAvatar(
                                        radius: 20,
                                        child: Icon(Icons.person),
                                      ),
                                title: Text(pseudo),
                                subtitle: Text(email),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous pouvez rechercher par pseudo ou email',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final text = textController.text.trim();
                      
                      if (selectedUser != null) {
                        // Utilisateur sélectionné depuis l'autocomplétion
                        Navigator.pop(context);
                        await _inviteMember(
                          userId: selectedUser!['id'],
                          pseudo: selectedUser!['pseudo'],
                          email: selectedUser!['email'],
                        );
                      } else if (text.isNotEmpty) {
                        // Texte saisi manuellement
                        Navigator.pop(context);
                        String? userId;
                        String? pseudo;
                        String? email;

                        if (text.contains('@')) {
                          email = text;
                        } else {
                          pseudo = text;
                        }

                        await _inviteMember(userId: userId, pseudo: pseudo, email: email);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Veuillez sélectionner un utilisateur ou entrer un pseudo/email'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
              child: const Text('Inviter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteMember({
    String? userId,
    String? pseudo,
    String? email,
  }) async {
    if (_group == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      await _apiService.addMemberToGroup(
        _group!.id,
        userId: userId,
        pseudo: pseudo,
        email: email,
      );

      // Recharger les informations du groupe
      await _loadGroup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membre invité avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Dialog pour modifier le groupe
  Future<void> _showEditGroupDialog() async {
    if (_group == null) return;

    final nomController = TextEditingController(text: _group!.nom);
    final descriptionController = TextEditingController(text: _group!.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le groupe'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du groupe',
                    hintText: 'Entrez le nom du groupe',
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Entrez la description du groupe',
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNom = nomController.text.trim();
              final newDescription = descriptionController.text.trim();

              if (newNom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le nom du groupe est requis'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updateGroup(nom: newNom, description: newDescription.isEmpty ? null : newDescription);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // Mettre à jour le groupe
  Future<void> _updateGroup({String? nom, String? description}) async {
    if (_group == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      await _apiService.updateGroup(
        widget.groupId,
        nom: nom,
        description: description,
      );

      // Recharger les informations du groupe
      await _loadGroup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Groupe modifié avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Dialog pour gérer les membres
  Future<void> _showManageMembersDialog() async {
    if (_group == null) return;

    final allMembers = [
      _group!.createur,
      ..._group!.membres.where((m) => m.userId.toString() != _group!.createur.userId.toString()),
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gérer les membres'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allMembers.length,
            itemBuilder: (context, index) {
              final membre = allMembers[index];
              final isCreator = membre.userId.toString() == _group!.createur.userId.toString();
              
              return ListTile(
                leading: _buildMemberAvatar(membre),
                title: Text(membre.pseudo ?? 'Utilisateur'),
                subtitle: Text(_getRoleDisplayName(membre.role, isCreator)),
                trailing: isCreator
                    ? const Text('Créateur', style: TextStyle(color: Colors.orange))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Option pour modifier le rôle (créateur uniquement)
                          if (_isCreator) ...[
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.blue),
                              tooltip: 'Modifier le rôle',
                              onSelected: (role) => _updateMemberRole(membre.userId, role),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'admin',
                                  child: Text('Promouvoir en Admin'),
                                ),
                                const PopupMenuItem(
                                  value: 'moderateur',
                                  child: Text('Promouvoir en Modérateur'),
                                ),
                                const PopupMenuItem(
                                  value: 'membre',
                                  child: Text('Rétrograder en Membre'),
                                ),
                              ],
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.block, color: Colors.red),
                            tooltip: 'Bannir',
                            onPressed: () => _banMember(membre.userId, membre.pseudo ?? 'Utilisateur'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Retirer',
                            onPressed: () => _removeMember(membre.userId),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Helper pour obtenir le nom d'affichage du rôle
  String _getRoleDisplayName(String role, bool isCreator) {
    if (isCreator) return 'Créateur';
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'moderateur':
        return 'Modérateur';
      case 'membre':
        return 'Membre';
      default:
        return role;
    }
  }

  // Mettre à jour le rôle d'un membre
  Future<void> _updateMemberRole(String userId, String role) async {
    if (_group == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      await _apiService.updateMemberRole(
        widget.groupId,
        userId,
        role: role,
      );

      // Recharger les informations du groupe
      await _loadGroup();

      if (!mounted) return;

      final roleName = _getRoleDisplayName(role, false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rôle modifié avec succès : $roleName'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Fermer le dialog de gestion
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Retirer un membre
  Future<void> _removeMember(String userId) async {
    if (_group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: const Text('Êtes-vous sûr de vouloir retirer ce membre du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _apiService.setToken(token);

        await _apiService.removeMemberFromGroup(widget.groupId, userId);
        await _loadGroup();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membre retiré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Fermer le dialog de gestion
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Dialog pour supprimer le groupe
  Future<void> _showDeleteGroupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce groupe ? Cette action est irréversible et supprimera tous les messages associés.',
        ),
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

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _apiService.setToken(token);

        await _apiService.deleteGroup(widget.groupId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Retourner à l'écran précédent
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Dialog pour afficher les utilisateurs bannis
  Future<void> _showBannedUsersDialog() async {
    if (_group == null) return;

    final bannedUsers = _group!.bannedUsers ?? [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Utilisateurs bannis (${bannedUsers.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: bannedUsers.isEmpty
              ? const Text('Aucun utilisateur banni')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: bannedUsers.length,
                  itemBuilder: (context, index) {
                    final banned = bannedUsers[index];
                    String? avatarUrl;
                    if (banned.avatarUrl != null && banned.avatarUrl!.isNotEmpty) {
                      if (banned.avatarUrl!.startsWith('http')) {
                        avatarUrl = banned.avatarUrl;
                      } else if (banned.avatarUrl!.startsWith('/uploads')) {
                        avatarUrl = ApiConfig.getFileUrl(banned.avatarUrl);
                      }
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                (banned.pseudo ?? banned.userId.substring(0, 2)).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              )
                            : null,
                      ),
                      title: Text(banned.pseudo ?? 'Utilisateur'),
                      subtitle: banned.reason != null && banned.reason!.isNotEmpty
                          ? Text('Raison: ${banned.reason}')
                          : const Text('Aucune raison spécifiée'),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: 'Débannir',
                        onPressed: () => _unbanUser(banned.userId),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Débannir un utilisateur
  Future<void> _unbanUser(String userId) async {
    if (_group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Débannir l\'utilisateur'),
        content: const Text('Êtes-vous sûr de vouloir débannir cet utilisateur ? Il pourra à nouveau rejoindre le groupe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Débannir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _apiService.setToken(token);

        await _apiService.unbanUserFromGroup(widget.groupId, userId);
        await _loadGroup();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Utilisateur débanni avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Fermer le dialog de gestion
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Bannir un membre
  Future<void> _banMember(String userId, String pseudo) async {
    if (_group == null) return;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bannir $pseudo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cet utilisateur sera retiré du groupe et ne pourra plus le rejoindre.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnelle)',
                hintText: 'Pourquoi cet utilisateur est banni ?',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _apiService.setToken(token);

        await _apiService.banUserFromGroup(
          widget.groupId,
          userId,
          reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
        );
        await _loadGroup();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Utilisateur banni avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Fermer le dialog de gestion
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper pour construire un avatar de membre (pour les dialogs)
  Widget _buildMemberAvatar(GroupMember membre) {
    String? avatarUrl;
    if (membre.avatarUrl != null && membre.avatarUrl!.isNotEmpty) {
      if (membre.avatarUrl!.startsWith('http')) {
        avatarUrl = membre.avatarUrl;
      } else if (membre.avatarUrl!.startsWith('/uploads')) {
        avatarUrl = ApiConfig.getFileUrl(membre.avatarUrl);
      }
    }
    
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).primaryColor,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              (membre.pseudo ?? membre.userId.substring(0, 2)).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            )
          : null,
    );
  }

  // Helper pour construire une tile de membre avec avatar
  Widget _buildMemberTile(GroupMember membre) {
    // Construire l'URL complète de l'avatar si nécessaire
    String? avatarUrl;
    if (membre.avatarUrl != null && membre.avatarUrl!.isNotEmpty) {
      if (membre.avatarUrl!.startsWith('http')) {
        avatarUrl = membre.avatarUrl;
      } else if (membre.avatarUrl!.startsWith('/uploads')) {
        avatarUrl = ApiConfig.getFileUrl(membre.avatarUrl);
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).primaryColor,
          backgroundImage: avatarUrl != null
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null
              ? Text(
                  (membre.pseudo ?? membre.userId.substring(0, 2)).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              : null,
        ),
        title: Text(
          membre.pseudo ?? 'Utilisateur ${membre.userId.substring(0, 8)}',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          _getRoleDisplayName(
            membre.role,
            membre.userId.toString() == _group!.createur.userId.toString(),
          ),
          style: TextStyle(
            color: membre.userId.toString() == _group!.createur.userId.toString()
                ? Colors.orange
                : membre.role == 'admin'
                    ? Colors.orange
                    : membre.role == 'moderateur'
                        ? Colors.blue
                        : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

