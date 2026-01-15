import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_extended.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/chat/message_bubble.dart';

/// Écran pour afficher la liste des messages épinglés d'un groupe
class PinnedMessagesScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const PinnedMessagesScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<PinnedMessagesScreen> createState() => _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends State<PinnedMessagesScreen> {
  final ChatService _chatService = ChatService();
  List<MessageExtended> _pinnedMessages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPinnedMessages();
  }

  Future<void> _loadPinnedMessages() async {
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

      final response = await _chatService.getPinnedMessages(widget.groupId);
      
      if (response['success'] == true && response['data'] != null) {
        final messagesJson = response['data']['messages'] as List? ?? [];

        setState(() {
          _pinnedMessages = messagesJson
              .map((json) => MessageExtended.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement des messages épinglés';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages épinglés'),
        elevation: 0,
      ),
      body: _isLoading
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
                        onPressed: _loadPinnedMessages,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _pinnedMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.push_pin_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun message épinglé',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPinnedMessages,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _pinnedMessages.length,
                        itemBuilder: (context, index) {
                          final message = _pinnedMessages[index];
                          return MessageBubble(
                            message: message,
                            isOwnMessage: message.auteurId == widget.currentUserId,
                            currentUserId: widget.currentUserId,
                          );
                        },
                      ),
                    ),
    );
  }
}

