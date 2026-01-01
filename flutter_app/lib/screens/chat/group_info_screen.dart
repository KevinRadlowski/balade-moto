import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/group.dart';
import '../../models/message_extended.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../config/api_config.dart';
import 'chat_search_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ApiService _apiService = ApiService();
  Group? _group;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _mediaMessages = [];
  List<Map<String, dynamic>> _linkMessages = [];
  List<Map<String, dynamic>> _documentMessages = [];
  bool _isLoadingMedia = false;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    _loadMediaMessages();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final groupData = await _apiService.getGroupById(widget.groupId);
      final groupJson = groupData['data']['group'];
      
      setState(() {
        _group = Group.fromJson(groupJson);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMediaMessages() async {
    setState(() {
      _isLoadingMedia = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Charger tous les messages du groupe
      final messagesData = await _apiService.getGroupMessages(widget.groupId, page: 1, limit: 1000);
      final messages = messagesData['data']['messages'] as List;

      // Filtrer les médias, liens et documents
      final media = <Map<String, dynamic>>[];
      final links = <Map<String, dynamic>>[];
      final documents = <Map<String, dynamic>>[];

      for (final msg in messages) {
        final messageType = msg['messageType'] ?? 'text';
        final content = msg['contenu'] ?? '';

        if (messageType == 'image' || messageType == 'video' || messageType == 'audio') {
          media.add(msg);
        } else if (messageType == 'file') {
          documents.add(msg);
        } else if (content.toString().contains(RegExp(r'https?://'))) {
          // Détecter les liens dans le texte
          final linkRegex = RegExp(r'https?://[^\s]+');
          final matches = linkRegex.allMatches(content);
          for (final match in matches) {
            links.add({
              ...msg,
              'link': match.group(0),
            });
          }
        }
      }

      setState(() {
        _mediaMessages = media;
        _linkMessages = links;
        _documentMessages = documents;
        _isLoadingMedia = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMedia = false;
      });
    }
  }

  void _showSearchDialog() async {
    final selectedMessage = await Navigator.of(context).push<MessageExtended>(
      MaterialPageRoute(
        builder: (_) => ChatSearchScreen(
          groupId: widget.groupId,
        ),
      ),
    );
    
    if (selectedMessage != null) {
      // Retourner au chat et passer le message pour scroller
      Navigator.pop(context, selectedMessage);
    }
  }

  void _showMembersList() {
    // Filtrer les membres pour exclure le créateur (qui est déjà dans la liste des membres)
    final createurId = _group!.createur.userId;
    final membresSansCreateur = _group!.membres.where((m) => m.userId != createurId).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Membres du groupe'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: membresSansCreateur.length + 1, // +1 pour le créateur
            itemBuilder: (context, index) {
              if (index == 0) {
                // Afficher le créateur en premier
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage: _group!.createur.avatarUrl != null
                        ? NetworkImage(ApiConfig.getFileUrl(_group!.createur.avatarUrl!))
                        : null,
                    child: _group!.createur.avatarUrl == null
                        ? Text(
                            (_group!.createur.pseudo ?? 'U')[0].toUpperCase(),
                            style: TextStyle(color: Colors.orange.shade700),
                          )
                        : null,
                  ),
                  title: Text(_group!.createur.pseudo ?? 'Utilisateur'),
                  subtitle: const Text('Créateur'),
                  trailing: Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                );
              }
              final membre = membresSansCreateur[index - 1];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: membre.avatarUrl != null
                      ? NetworkImage(ApiConfig.getFileUrl(membre.avatarUrl!))
                      : null,
                  child: membre.avatarUrl == null
                      ? Text(
                          membre.pseudo?[0].toUpperCase() ?? 'U',
                          style: TextStyle(color: Colors.blue.shade700),
                        )
                      : null,
                ),
                title: Text(membre.pseudo ?? 'Utilisateur'),
                subtitle: Text(membre.role),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infos du groupe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _group == null
                  ? const Center(child: Text('Groupe non trouvé'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête avec nom et avatar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    _group!.nom[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 40,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _group!.nom,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_group!.description != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _group!.description!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Divider(),
                          
                          // Actions
                          ListTile(
                            leading: const Icon(Icons.person_add),
                            title: const Text('Inviter des membres'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(groupId: widget.groupId),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.search),
                            title: const Text('Rechercher dans le chat'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showSearchDialog,
                          ),
                          const Divider(),
                          
                          // Informations
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Informations',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Créé par'),
                            subtitle: Text(_group!.createur.pseudo ?? 'Utilisateur'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.group),
                            title: const Text('Membres'),
                            subtitle: Text('${_group!.membres.length} membres'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showMembersList(),
                          ),
                          const Divider(),
                          
                          // Médias, liens et documents
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Médias, liens et documents',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_isLoadingMedia)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ))
                          else ...[
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Médias'),
                              subtitle: Text('${_mediaMessages.length} éléments'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: Afficher la galerie de médias
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Galerie de médias - À implémenter'),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.link),
                              title: const Text('Liens'),
                              subtitle: Text('${_linkMessages.length} liens'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: Afficher la liste des liens
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Liste des liens - À implémenter'),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: const Text('Documents'),
                              subtitle: Text('${_documentMessages.length} documents'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: Afficher la liste des documents
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Liste des documents - À implémenter'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

