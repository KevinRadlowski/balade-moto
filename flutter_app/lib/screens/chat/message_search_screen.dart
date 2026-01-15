import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_extended.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/chat/message_bubble.dart';
import 'package:intl/intl.dart';

/// Écran de recherche avancée de messages dans un groupe
class MessageSearchScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const MessageSearchScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<MessageExtended> _results = [];
  bool _isLoading = false;
  String? _error;
  String? _nextCursor;
  bool _hasMore = false;
  
  // Filtres
  bool? _filterMedia;
  bool? _filterPoll;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce : attendre 500ms après la dernière frappe avant de rechercher
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch();
      } else {
        setState(() {
          _results = [];
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch({bool loadMore = false}) async {
    if (_isLoading) return;
    
    final query = _searchController.text.trim();
    
    // Si pas de query et pas de filtres, ne rien faire
    if (query.isEmpty && _filterMedia == null && _filterPoll == null && _filterFrom == null && _filterTo == null) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      if (!loadMore) {
        _results = [];
        _nextCursor = null;
      }
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _chatService.setToken(token);
      }

      final response = await _chatService.searchMessages(
        groupId: widget.groupId,
        query: query.isEmpty ? null : query,
        media: _filterMedia,
        poll: _filterPoll,
        from: _filterFrom,
        to: _filterTo,
        cursor: loadMore ? _nextCursor : null,
        limit: 20,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final messagesJson = data['messages'] as List? ?? [];
        final pageInfo = data['pageInfo'] as Map<String, dynamic>? ?? {};

        final newMessages = messagesJson
            .map((json) => MessageExtended.fromJson(json))
            .toList();

        setState(() {
          if (loadMore) {
            _results.addAll(newMessages);
          } else {
            _results = newMessages;
          }
          _hasMore = pageInfo['hasNextPage'] ?? false;
          _nextCursor = pageInfo['nextCursor'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors de la recherche';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_hasMore && !_isLoading) {
      await _performSearch(loadMore: true);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterFrom != null && _filterTo != null
          ? DateTimeRange(start: _filterFrom!, end: _filterTo!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterFrom = picked.start;
        _filterTo = picked.end;
      });
      _performSearch();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Champ de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans les messages...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Filtres
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filtre Médias
                      FilterChip(
                        label: const Text('Médias'),
                        selected: _filterMedia == true,
                        onSelected: (selected) {
                          setState(() {
                            _filterMedia = selected ? true : null;
                          });
                          _performSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      // Filtre Sondages
                      FilterChip(
                        label: const Text('Sondages'),
                        selected: _filterPoll == true,
                        onSelected: (selected) {
                          setState(() {
                            _filterPoll = selected ? true : null;
                          });
                          _performSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      // Filtre Période
                      if (_filterFrom != null && _filterTo != null)
                        FilterChip(
                          label: Text(
                            '${DateFormat('dd/MM/yyyy').format(_filterFrom!)} - ${DateFormat('dd/MM/yyyy').format(_filterTo!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: true,
                          onSelected: (selected) {
                            if (!selected) {
                              _clearDateFilter();
                            }
                          },
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: _clearDateFilter,
                        )
                      else
                        FilterChip(
                          label: const Text('Période'),
                          selected: false,
                          onSelected: (selected) {
                            if (selected) {
                              _selectDateRange();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Résultats
          Expanded(
            child: _isLoading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _performSearch(),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun résultat',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Essayez avec d\'autres mots-clés ou filtres',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _results.length) {
                                // Bouton "Charger plus"
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _isLoading
                                        ? const CircularProgressIndicator()
                                        : ElevatedButton(
                                            onPressed: _loadMore,
                                            child: const Text('Charger plus'),
                                          ),
                                  ),
                                );
                              }
                              
                              final message = _results[index];
                              return InkWell(
                                onTap: () {
                                  // Retourner au chat avec le messageId pour navigation
                                  Navigator.pop(context, message.id);
                                },
                                child: MessageBubble(
                                  message: message,
                                  isOwnMessage: message.auteurId == widget.currentUserId,
                                  currentUserId: widget.currentUserId,
                                  onThreadTap: message.threadReplyCount > 0
                                      ? () {
                                          // TODO: Ouvrir le thread
                                        }
                                      : null,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

