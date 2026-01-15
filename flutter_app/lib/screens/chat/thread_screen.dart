import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_extended.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';

/// Écran pour afficher un thread complet (message racine + réponses)
class ThreadScreen extends StatefulWidget {
  final String messageId;
  final String groupId;
  final String currentUserId;

  const ThreadScreen({
    super.key,
    required this.messageId,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  MessageExtended? _rootMessage;
  List<MessageExtended> _replies = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadThread();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _chatService.setToken(token);
      }

      final response = await _chatService.getThread(widget.messageId);
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final rootJson = data['root'];
        final repliesJson = data['replies'] as List? ?? [];

        setState(() {
          _rootMessage = MessageExtended.fromJson(rootJson);
          _replies = repliesJson
              .map((json) => MessageExtended.fromJson(json))
              .toList();
          _isLoading = false;
        });

        // Scroller vers le bas après un court délai
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement du thread';
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

  void _setupSocketListeners() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    // Écouter les nouveaux messages dans le thread
    socketService.onNewMessage((data) {
      if (data['message'] != null) {
        final message = MessageExtended.fromJson(data['message']);
        // Vérifier si c'est une réponse dans ce thread
        if (message.parentMessageId == widget.messageId || 
            message.threadRootId == widget.messageId) {
          setState(() {
            _replies.add(message);
          });
          // Scroller vers le bas
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  Future<void> _sendReply() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _chatService.setToken(token);
      }

      // Envoyer la réponse dans le thread
      await _chatService.sendMessage(
        conversationId: widget.groupId,
        type: 'group',
        content: content,
        parentMessageId: widget.messageId, // Répondre dans ce thread
      );

      // Réinitialiser le champ de texte
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadThread,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _rootMessage == null
                        ? const Center(child: Text('Message non trouvé'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: 1 + _replies.length, // Root + réponses
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Message racine
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Message original',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      MessageBubble(
                                        message: _rootMessage!,
                                        isOwnMessage: _rootMessage!.auteurId == widget.currentUserId,
                                        currentUserId: widget.currentUserId,
                                      ),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Réponses',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Réponses
                                final reply = _replies[index - 1];
                                return MessageBubble(
                                  message: reply,
                                  isOwnMessage: reply.auteurId == widget.currentUserId,
                                  currentUserId: widget.currentUserId,
                                );
                              }
                            },
                          ),
          ),
          // Input pour répondre dans le thread
          ChatInput(
            controller: _messageController,
            onSend: _sendReply,
            groupId: widget.groupId,
          ),
        ],
      ),
    );
  }
}

