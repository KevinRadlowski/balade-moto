import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_extended.dart';

class ChatSearchScreen extends StatefulWidget {
  final String groupId;

  const ChatSearchScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<MessageExtended> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Charger tous les messages du groupe
      final messagesData = await _apiService.getGroupMessages(widget.groupId, page: 1, limit: 1000);
      final messages = messagesData['data']['messages'] as List;

      // Filtrer les messages selon la recherche
      final queryLower = query.toLowerCase();
      final results = messages
          .where((msg) {
            final content = (msg['contenu'] ?? '').toString().toLowerCase();
            final auteurPseudo = (msg['auteur']?['pseudo'] ?? '').toString().toLowerCase();
            return content.contains(queryLower) || auteurPseudo.contains(queryLower);
          })
          .map((m) => MessageExtended.fromJson(m))
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher dans le chat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rechercher un message...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.trim().isNotEmpty) {
                  _searchMessages(value);
                } else {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),
          if (_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun résultat trouvé'),
              ),
            )
          else if (_searchResults.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tapez pour rechercher dans les messages'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final message = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        message.auteurPseudo?[0].toUpperCase() ?? 'U',
                      ),
                    ),
                    title: Text(message.auteurPseudo ?? 'Utilisateur'),
                    subtitle: Text(
                      message.contenu,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatDate(message.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context, message);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

