import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../services/socket_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_extended.dart';
import '../../models/user.dart';
import '../../widgets/chat/chat_header.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/date_separator.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/chat/message_context_menu.dart';
import '../../widgets/chat/quick_reaction_picker.dart';
import '../../services/api_service.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import 'group_info_screen.dart';
import 'select_ride_screen.dart';
import '../../screens/ride/create_ride_with_map_screen.dart';
import '../../models/ride.dart';
import '../../widgets/chat/create_poll_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'thread_screen.dart';
import 'pinned_messages_screen.dart';
import 'message_search_screen.dart';
import 'report_message_screen.dart';

class GroupChatScreenV2 extends StatefulWidget {
  final String groupId;
  final String groupName;
  final int? memberCount;

  const GroupChatScreenV2({
    super.key,
    required this.groupId,
    required this.groupName,
    this.memberCount,
  });

  @override
  State<GroupChatScreenV2> createState() => _GroupChatScreenV2State();
}

class _GroupChatScreenV2State extends State<GroupChatScreenV2> {
  final SocketService _socketService = SocketService();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<MessageExtended> _messages = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _nextCursor;
  String? _errorMessage;
  
  ReplyPreview? _replyPreview;
  String? _replyingToMessageId; // ID du message auquel on répond
  MessageExtended? _editingMessage;
  String? _typingUser;
  bool _isTyping = false;
  DateTime? _lastTypingTime;

  // Map pour stocker les couleurs par auteur
  final Map<String, Color> _senderColors = {};
  
  // État pour le menu
  bool _isSilentMode = false;
  bool _isFavorite = false;
  bool _isSelectingMessages = false;
  final Set<String> _selectedMessageIds = {};
  
  // Informations du groupe
  String? _groupCreatorId;

  @override
  void initState() {
    super.initState();
    // S'assurer que _replyPreview est null au démarrage
    _replyPreview = null;
    _replyingToMessageId = null;
    _initializeChat();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _socketService.stopTyping(widget.groupId, 'group');
    _socketService.leaveGroupRoom(widget.groupId);
    _socketService.off('new-message');
    _socketService.off('previous-messages');
    _socketService.off('message-updated');
    _socketService.off('message-deleted');
    _socketService.off('message-restored');
    _socketService.off('message-pinned');
    _socketService.off('reaction-updated');
    _socketService.off('typing');
    _socketService.off('error');
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      
      if (token == null) {
        setState(() {
          _errorMessage = 'Token d\'authentification manquant';
          _isLoading = false;
        });
        return;
      }

      _chatService.setToken(token);
      _currentUser = authService.user;

      // Charger les informations du groupe pour vérifier si l'utilisateur est le créateur
      await _loadGroupInfo();

      // Connecter Socket.io
      await _socketService.connect(token);

      // Configurer les listeners Socket.io
      _setupSocketListeners();

      // Rejoindre la room
      _socketService.joinGroupRoom(widget.groupId);

      // Charger les messages initiaux
      await _loadMessages();
      
      // Marquer les messages comme lus
      _markMessagesAsRead();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Marquer les messages du groupe comme lus
  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markAsRead(
        conversationId: widget.groupId,
        type: 'group',
      );
    } catch (e) {
      debugPrint('Erreur lors du marquage des messages comme lus: $e');
      // Ne pas bloquer l'utilisateur si ça échoue
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      final apiService = ApiService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);
      
      final groupData = await apiService.getGroupById(widget.groupId);
      final groupJson = groupData['data']['group'];
      
      setState(() {
        // Extraire l'ID du créateur
        if (groupJson['createur'] != null) {
          if (groupJson['createur'] is String) {
            _groupCreatorId = groupJson['createur'];
          } else if (groupJson['createur'] is Map) {
            _groupCreatorId = groupJson['createur']['_id']?.toString() ?? groupJson['createur']['id']?.toString();
          }
        }
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des informations du groupe: $e');
    }
  }

  void _setupSocketListeners() {
    _socketService.onNewMessage((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null) {
        final message = MessageExtended.fromJson(messageData);
        final isOwnMessage = message.auteurId == _currentUser?.id;
        
        if (mounted) {
          setState(() {
          // Vérifier d'abord si le message existe déjà (par ID)
          final existingIndex = _messages.indexWhere((m) => m.id == message.id);
          if (existingIndex >= 0) {
            // Message déjà présent, le mettre à jour
            _messages[existingIndex] = message;
            _assignSenderColor(message);
          } else if (isOwnMessage) {
            // Si c'est notre propre message, remplacer le message optimiste par le message réel
            // Chercher le dernier message optimiste de cet utilisateur avec le même contenu
            int? tempIndex;
            for (int i = _messages.length - 1; i >= 0; i--) {
              final m = _messages[i];
              if (m.id.startsWith('temp-') && 
                  m.auteurId == _currentUser?.id &&
                  m.contenu.trim() == message.contenu.trim()) {
                tempIndex = i;
                break;
              }
            }
            
            if (tempIndex != null && tempIndex >= 0) {
              // Remplacer le message optimiste par le message réel
              _messages[tempIndex] = message;
            } else {
              // Si on ne trouve pas de message optimiste, l'ajouter
              _messages.add(message);
            }
            _assignSenderColor(message);
          } else {
            // Message d'un autre utilisateur, l'ajouter
            _messages.add(message);
            _assignSenderColor(message);
          }
          });
        }
        // Attendre que le widget soit construit avant de scroller
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

             _socketService.onPreviousMessages((data) {
               final messagesData = data['messages'] as List?;
               if (messagesData != null) {
                 setState(() {
                   _messages = messagesData
                       .map((m) => MessageExtended.fromJson(m))
                       .toList();
                   for (final msg in _messages) {
                     _assignSenderColor(msg);
                   }
                   _isLoading = false;
                 });
                 // Attendre que le widget soit construit avant de scroller
                 SchedulerBinding.instance.addPostFrameCallback((_) {
                   _scrollToBottom();
                 });
               }
             });

    // Écouter les nouveaux messages
    _socketService.onNewMessage((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null) {
        final newMessage = MessageExtended.fromJson(messageData);
        if (mounted) {
          setState(() {
            // Vérifier si le message n'existe pas déjà
            if (!_messages.any((m) => m.id == newMessage.id)) {
              _messages.add(newMessage);
              _assignSenderColor(newMessage);
              // Faire défiler vers le bas pour voir le nouveau message
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }
          });
        }
      }
    });

    _socketService.onMessageUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null) {
        final updatedMessage = MessageExtended.fromJson(messageData);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
            if (index >= 0) {
              _messages[index] = updatedMessage;
            }
          });
        }
      }
    });

    _socketService.onMessageDeleted((data) {
      if (!mounted) return;
      final messageId = data['messageId'];
      final scope = data['scope'];
      final messageData = data['message'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index >= 0) {
            // Utiliser les données du serveur si disponibles, sinon utiliser les données locales
            if (messageData != null) {
              // Le serveur envoie le message mis à jour, l'utiliser directement
              final updatedMessage = MessageExtended.fromJson(messageData);
              _messages[index] = updatedMessage;
              _assignSenderColor(updatedMessage);
            } else {
              // Fallback : mettre à jour manuellement si les données du serveur ne sont pas disponibles
              final oldMessage = _messages[index];
              if (scope == 'all') {
                _messages[index] = MessageExtended(
                  id: oldMessage.id,
                  auteurId: oldMessage.auteurId,
                  auteurPseudo: oldMessage.auteurPseudo,
                  auteurEmail: oldMessage.auteurEmail,
                  senderAvatarUrl: oldMessage.senderAvatarUrl,
                  contenu: 'Ce message a été supprimé',
                  date: oldMessage.date,
                  updatedAt: oldMessage.updatedAt,
                  idBalade: oldMessage.idBalade,
                  idGroupe: oldMessage.idGroupe,
                  type: oldMessage.type,
                  metadata: oldMessage.metadata,
                  edited: oldMessage.edited,
                  deletedForAll: true,
                  deletedForUserIds: oldMessage.deletedForUserIds,
                  replyToMessageId: oldMessage.replyToMessageId,
                  replyPreview: oldMessage.replyPreview,
                  reactions: oldMessage.reactions,
                  mentions: oldMessage.mentions,
                  status: oldMessage.status,
                );
              } else {
                // Supprimer pour moi uniquement - ajouter l'utilisateur à deletedForUserIds
                final currentUserId = _currentUser?.id ?? '';
                if (!oldMessage.deletedForUserIds.contains(currentUserId)) {
                  _messages[index] = MessageExtended(
                    id: oldMessage.id,
                    auteurId: oldMessage.auteurId,
                    auteurPseudo: oldMessage.auteurPseudo,
                    auteurEmail: oldMessage.auteurEmail,
                    senderAvatarUrl: oldMessage.senderAvatarUrl,
                    contenu: oldMessage.contenu,
                    date: oldMessage.date,
                    updatedAt: oldMessage.updatedAt,
                    idBalade: oldMessage.idBalade,
                    idGroupe: oldMessage.idGroupe,
                    type: oldMessage.type,
                    metadata: oldMessage.metadata,
                    edited: oldMessage.edited,
                    deletedForAll: oldMessage.deletedForAll,
                    deletedForUserIds: [...oldMessage.deletedForUserIds, currentUserId],
                    replyToMessageId: oldMessage.replyToMessageId,
                    replyPreview: oldMessage.replyPreview,
                    reactions: oldMessage.reactions,
                    mentions: oldMessage.mentions,
                    status: oldMessage.status,
                  );
                }
              }
            }
          }
        });
      }
    });

    _socketService.onMessageRestored((data) {
      if (!mounted) return;
      final messageId = data['messageId'];
      final messageData = data['message'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index >= 0 && messageData != null) {
            // Mettre à jour le message avec les données du serveur
            final restoredMessage = MessageExtended.fromJson(messageData);
            _messages[index] = restoredMessage;
            _assignSenderColor(restoredMessage);
          }
        });
      }
    });

    _socketService.onMessagePinned((data) {
      if (!mounted) return;
      final messageId = data['messageId'];
      final messageData = data['message'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index >= 0 && messageData != null) {
            // Mettre à jour le message avec les données du serveur
            final pinnedMessage = MessageExtended.fromJson(messageData);
            _messages[index] = pinnedMessage;
            _assignSenderColor(pinnedMessage);
          }
        });
      }
    });

    // Écouter les mises à jour de sondages
    _socketService.onPollUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null) {
        final updatedMessage = MessageExtended.fromJson(messageData);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
            if (index >= 0) {
              _messages[index] = updatedMessage;
              _assignSenderColor(updatedMessage);
            }
          });
        }
      }
    });

    _socketService.onReactionUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null) {
        final updatedMessage = MessageExtended.fromJson(messageData);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
            if (index >= 0) {
              _messages[index] = updatedMessage;
            }
          });
        }
      }
    });

    _socketService.onTyping((data) {
      if (!mounted) return;
      final userId = data['userId'];
      final isTyping = data['isTyping'] ?? false;
      final userPseudo = data['userPseudo'] ?? 'Utilisateur';
      
      if (userId != _currentUser?.id && mounted) {
        setState(() {
          _typingUser = isTyping ? userPseudo : null;
        });
      }
    });

    _socketService.onError((data) {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Erreur'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        // Ignorer si le contexte n'est plus valide
        debugPrint('Erreur lors de l\'affichage du SnackBar: $e');
      }
    });
  }

  void _assignSenderColor(MessageExtended message) {
    if (!_senderColors.containsKey(message.auteurId)) {
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.red,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
      ];
      final hash = message.auteurId.hashCode;
      _senderColors[message.auteurId] = colors[hash.abs() % colors.length];
    }
  }

  void _onTextChanged() {
    if (!_isTyping) {
      _isTyping = true;
      _socketService.startTyping(widget.groupId, 'group');
    }
    _lastTypingTime = DateTime.now();

    // Arrêter le typing après 3 secondes d'inactivité
    Future.delayed(const Duration(seconds: 3), () {
      if (_lastTypingTime != null &&
          DateTime.now().difference(_lastTypingTime!) >=
              const Duration(seconds: 3)) {
        _isTyping = false;
        _socketService.stopTyping(widget.groupId, 'group');
      }
    });
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (loadMore && (!_hasMoreMessages || _isLoadingMore)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final response = await _chatService.getMessages(
        conversationId: widget.groupId,
        type: 'group',
        cursor: loadMore ? _nextCursor : null,
      );

      final messagesData = response['data']['messages'] as List;
      final pagination = response['data']['pagination'];

      final newMessages = messagesData
          .map((m) => MessageExtended.fromJson(m))
          .toList();

      setState(() {
        if (loadMore) {
          _messages.insertAll(0, newMessages);
        } else {
          _messages = newMessages;
        }
        for (final msg in newMessages) {
          _assignSenderColor(msg);
        }
        _hasMoreMessages = pagination['hasMore'] ?? false;
        _nextCursor = pagination['nextCursor']?.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!loadMore) {
        // Attendre que le widget soit construit avant de scroller
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _scrollToBottom() {
    // Utiliser SchedulerBinding pour s'assurer que le widget est construit
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll.isFinite && maxScroll >= 0) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        // Ignorer les erreurs de scroll
        debugPrint('Erreur lors du scroll: $e');
      }
    });
  }

  // Helper pour vérifier si le texte contient du contenu valide (y compris les emojis)
  bool _hasValidContent(String text) {
    if (text.isEmpty) return false;
    // Enlever uniquement les espaces blancs (whitespace) en début et fin
    // Les emojis sont des caractères Unicode valides et ne sont pas considérés comme des espaces
    final trimmed = text.trim();
    // Vérifier que le texte trimmé n'est pas vide
    // Cela fonctionne correctement avec les emojis car ils ne sont pas des espaces
    return trimmed.isNotEmpty;
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text;
    if (!_hasValidContent(messageText)) return;
    
    final trimmedMessage = messageText.trim();

    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion en cours, veuillez patienter...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Arrêter le typing
    _isTyping = false;
    _socketService.stopTyping(widget.groupId, 'group');

    // Stocker le replyToMessageId avant de nettoyer
    final replyToId = _replyingToMessageId;

    // Créer un message optimiste
    final optimisticMessage = MessageExtended(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      auteurId: _currentUser!.id,
      auteurPseudo: _currentUser!.pseudo,
      contenu: trimmedMessage,
      date: DateTime.now(),
      idGroupe: widget.groupId,
      replyPreview: _replyPreview,
      replyToMessageId: replyToId,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _messageController.clear();
      _replyPreview = null;
      _replyingToMessageId = null; // Nettoyer l'ID
    });

    // Attendre que le widget soit construit avant de scroller
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Envoyer via Socket.io avec le replyToMessageId
      _socketService.sendGroupMessageWithReply(
        widget.groupId,
        trimmedMessage,
        replyToMessageId: replyToId,
      );
    } catch (e) {
      // Retirer le message optimiste en cas d'erreur
      setState(() {
        _messages.removeWhere((m) => m.id == optimisticMessage.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageContextMenu(MessageExtended message, Offset position) {
    final isOwnMessage = message.auteurId == _currentUser?.id;
    final isCreator = _currentUser?.id == _groupCreatorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageContextMenu(
        isOwnMessage: isOwnMessage,
        onReply: () {
          Navigator.pop(context);
          _replyToMessage(message);
        },
        onReact: () {
          Navigator.pop(context);
          _showReactionPicker(message, position);
        },
        onEdit: isOwnMessage
            ? () {
                Navigator.pop(context);
                _editMessage(message);
              }
            : null,
        onDelete: isOwnMessage
            ? () {
                Navigator.pop(context);
                _deleteMessage(message);
              }
            : null,
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: message.contenu));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copié'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onPin: isCreator // TODO: Vérifier aussi admin/mod
            ? () {
                Navigator.pop(context);
                _togglePin(message);
              }
            : null,
        isPinned: message.pinned,
        onReport: !isOwnMessage
            ? () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportMessageScreen(
                      groupId: widget.groupId,
                      messageId: message.id,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }

  Future<void> _togglePin(MessageExtended message) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _chatService.setToken(token);
      
      final response = await _chatService.togglePin(messageId: message.id);
      
      // Le message sera mis à jour automatiquement via Socket.io (event 'message-pinned')
      // Mais on peut aussi mettre à jour localement pour une meilleure réactivité
      if (mounted && response['data'] != null && response['data']['message'] != null) {
        final updatedMessage = MessageExtended.fromJson(response['data']['message']);
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index >= 0) {
            _messages[index] = updatedMessage;
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.pinned ? 'Message désépinglé' : 'Message épinglé'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _votePoll(MessageExtended message, int optionIndex) async {
    try {
      if (!mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _chatService.setToken(token);

      await _chatService.votePoll(
        messageId: message.id,
        optionIndex: optionIndex,
      );

      // Le message sera automatiquement mis à jour via Socket.io
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du vote: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _replyToMessage(MessageExtended message) {
    setState(() {
      // Créer le replyPreview à partir du message
      _replyPreview = ReplyPreview(
        senderPseudo: message.displayName,
        content: message.contenu.length > 50 
            ? '${message.contenu.substring(0, 50)}...' 
            : message.contenu,
        type: message.type.toString().split('.').last,
      );
      // Stocker l'ID du message auquel on répond pour l'envoyer plus tard
      _replyingToMessageId = message.id;
    });
    // Focus sur l'input pour que l'utilisateur puisse taper directement
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _showReactionPicker(MessageExtended message, Offset position) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickReactionPicker(
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          _toggleReaction(message, emoji);
        },
      ),
    );
  }

  void _toggleReaction(MessageExtended message, String emoji) {
    print('🔵 _toggleReaction appelé - messageId: ${message.id}, emoji: $emoji');
    print('🔵 Socket connecté: ${_socketService.isConnected}');
    
    if (!_socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion en cours, veuillez patienter...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (message.id.isEmpty) {
      print('❌ Message ID vide');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: ID du message invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (emoji.isEmpty) {
      print('❌ Emoji vide');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Emoji invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      print('🔵 Envoi de la réaction via Socket.io...');
      _socketService.toggleReaction(message.id, emoji);
      print('✅ Réaction envoyée avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de la réaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editMessage(MessageExtended message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.contenu;
      // Réinitialiser le reply preview quand on commence à éditer
      _replyPreview = null;
      _replyingToMessageId = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
      // Réinitialiser le reply preview quand on annule l'édition
      _replyPreview = null;
      _replyingToMessageId = null;
    });
  }

  Future<void> _saveEdit() async {
    if (_editingMessage == null) return;
    final newContent = _messageController.text;
    if (!_hasValidContent(newContent)) return;
    final trimmedContent = newContent.trim();

    try {
      _socketService.editMessage(_editingMessage!.id, trimmedContent);
      setState(() {
        _editingMessage = null;
        _messageController.clear();
        // Réinitialiser le reply preview après la sauvegarde
        _replyPreview = null;
        _replyingToMessageId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMessage(MessageExtended message) async {
    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Voulez-vous supprimer ce message pour vous ou pour tout le monde ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'me'),
            child: const Text('Pour moi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Pour tout le monde'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (scope != null) {
      // Utiliser l'API HTTP au lieu de Socket pour garantir le bon scope
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _chatService.setToken(token);
        await _chatService.deleteMessage(messageId: message.id, scope: scope);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Gérer les différents types d'attachements
  Future<void> _handleDocument() async {
    try {
      final filePicker = FilePicker.platform;
      final result = await filePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb, // Sur le web, charger les bytes directement
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        // Sur le web, on vérifie bytes au lieu de path
        if (kIsWeb) {
          if (file.bytes != null && file.bytes!.isNotEmpty) {
            await _uploadAndSendFile(file, 'file');
          } else {
            throw Exception('Impossible de lire le fichier (bytes vides ou null)');
          }
        } else {
          if (file.path != null && file.path!.isNotEmpty) {
            await _uploadAndSendFile(file, 'file');
          } else {
            throw Exception('Chemin de fichier introuvable');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePhotoVideo() async {
    try {
      final imagePicker = ImagePicker();
      final result = await imagePicker.pickMedia(
        imageQuality: 85,
      );

      if (result != null) {
        // Sur le web, XFile a un nom qui peut indiquer le type
        // Sur mobile, on peut utiliser path
        String? extension;
        if (kIsWeb) {
          extension = result.name.split('.').last.toLowerCase();
        } else {
          extension = result.path.split('.').last.toLowerCase();
        }
        
        if (extension == 'mp4' || extension == 'mov' || extension == 'avi' || extension == 'mkv' || extension == 'webm') {
          await _uploadAndSendFile(result, 'video');
        } else {
          await _uploadAndSendFile(result, 'image');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCamera() async {
    try {
      final imagePicker = ImagePicker();
      final result = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (result != null) {
        await _uploadAndSendFile(result, 'image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAudio() async {
    // TODO: Implémenter l'enregistrement audio
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement audio - À implémenter'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handlePoll() async {
    try {
      final pollData = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const CreatePollDialog(),
      );

      if (pollData != null && mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _chatService.setToken(token);

        // Envoyer le sondage via l'API
        await _chatService.sendMessage(
          conversationId: widget.groupId,
          type: 'group',
          content: pollData['question'] as String,
          messageType: 'poll',
          pollData: pollData,
          replyToMessageId: _replyingToMessageId,
        );

        // Le message sera automatiquement ajouté via Socket.io
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sondage créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Réinitialiser la réponse si nécessaire
          if (_replyingToMessageId != null) {
            setState(() {
              _replyingToMessageId = null;
              _replyPreview = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du sondage: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRide() async {
    // Afficher un dialog pour organiser ou sélectionner une balade
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proposer une balade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Organiser une nouvelle balade'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Sélectionner une balade existante'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (result == 'create') {
      // Naviguer vers la création de balade avec le groupId
      final createdRide = await Navigator.push<Ride>(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRideWithMapScreen(groupId: widget.groupId),
        ),
      );

      if (createdRide != null && mounted) {
        // Proposer la balade créée dans le groupe
        await _proposeRide(createdRide);
      }
    } else if (result == 'select') {
      // Afficher la liste des balades pour sélection
      final selectedRide = await Navigator.push<Ride>(
        context,
        MaterialPageRoute(
          builder: (context) => SelectRideScreen(
            groupId: widget.groupId,
          ),
        ),
      );

      if (selectedRide != null && mounted) {
        // Proposer la balade sélectionnée dans le groupe
        await _proposeRide(selectedRide);
      }
    }
  }

  Future<void> _proposeRide(Ride ride) async {
    try {
      if (!mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _chatService.setToken(token);

      // Associer la balade au groupe pour qu'elle apparaisse dans le calendrier
      bool associationReussie = false;
      try {
        final apiService = ApiService();
        apiService.setToken(token);
        await apiService.associateRideToGroup(ride.id, widget.groupId);
        associationReussie = true;
        debugPrint('✅ Balade ${ride.id} associée au groupe ${widget.groupId}');
      } catch (e) {
        // Si l'association échoue, on continue quand même pour proposer la balade
        // mais on log l'erreur pour debug
        debugPrint('⚠️ Erreur association balade au groupe: $e');
        // Si l'erreur indique que l'utilisateur n'est pas l'organisateur, on informe l'utilisateur
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('organisateur') || errorMessage.contains('forbidden')) {
          // L'utilisateur n'est pas l'organisateur, on continue quand même mais sans association
          debugPrint('ℹ️ Balade non associée: l\'utilisateur n\'est pas l\'organisateur');
        }
      }

      await _chatService.proposeRide(
        conversationId: widget.groupId,
        type: 'group',
        rideId: ride.id,
        content: 'Je propose cette balade : ${ride.titre}',
      );

      // Le message sera automatiquement ajouté via Socket.io
      if (mounted) {
        String message = 'Balade proposée avec succès !';
        if (associationReussie) {
          message += ' Elle apparaîtra dans le calendrier du groupe.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la proposition de la balade: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendFile(dynamic file, String type) async {
    try {
      if (!mounted) return;

      // Afficher un indicateur de chargement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Envoi de $type...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _chatService.setToken(token);

      // Gérer différents types de fichiers selon la plateforme
      if (kIsWeb) {
        // Sur le web, utiliser bytes
        // Vérifier que le fichier peut être lu
        if (file is PlatformFile) {
          if (file.bytes == null) {
            throw Exception('Impossible de lire le fichier (bytes null)');
          }
        } else if (file is! XFile) {
          throw Exception('Type de fichier non supporté: ${file.runtimeType}');
        }

        // Envoyer le fichier avec bytes
        await _chatService.uploadFile(
          conversationId: widget.groupId,
          type: 'group',
          file: file,
          messageType: type,
          replyToMessageId: _replyingToMessageId,
        );
      } else {
        // Sur les autres plateformes, utiliser path
        String? filePath;
        
        if (file is XFile) {
          filePath = file.path;
        } else if (file is PlatformFile) {
          filePath = file.path;
        } else {
          throw Exception('Type de fichier non supporté: ${file.runtimeType}');
        }

        if (filePath == null || filePath.isEmpty) {
          throw Exception('Chemin de fichier introuvable');
        }

        // Envoyer le fichier avec path
        await _chatService.sendMessageWithFile(
          conversationId: widget.groupId,
          type: 'group',
          filePath: filePath,
          fileType: type,
          content: '', // Optionnel : ajouter un texte avec le fichier
          replyToMessageId: _replyingToMessageId,
        );
      }

      // Le message sera automatiquement ajouté via Socket.io
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Réinitialiser la réponse si nécessaire
        if (_replyingToMessageId != null) {
          setState(() {
            _replyingToMessageId = null;
            _replyPreview = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreMessage(MessageExtended message) async {
    try {
      // Utiliser Socket pour une mise à jour en temps réel
      _socketService.restoreMessage(message.id);
      
      // Aussi utiliser l'API HTTP pour garantir la persistance
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _chatService.setToken(token);
      
      await _chatService.restoreMessage(messageId: message.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message restauré'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer les messages'),
        content: Text(
          'Voulez-vous supprimer ${_selectedMessageIds.length} message(s) pour vous ou pour tout le monde ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'me'),
            child: const Text('Pour moi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Pour tout le monde'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (scope != null) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _chatService.setToken(token);

        // Supprimer chaque message sélectionné
        int successCount = 0;
        int errorCount = 0;

        for (final messageId in _selectedMessageIds) {
          try {
            await _chatService.deleteMessage(messageId: messageId, scope: scope);
            successCount++;
          } catch (e) {
            errorCount++;
          }
        }

        setState(() {
          _isSelectingMessages = false;
          _selectedMessageIds.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorCount > 0
                    ? '$successCount message(s) supprimé(s), $errorCount erreur(s)'
                    : '$successCount message(s) supprimé(s)',
              ),
              backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  List<Widget> _buildMessageList() {
    if (_messages.isEmpty) {
      return [];
    }

    final widgets = <Widget>[];
    DateTime? lastDate;

    // Séparer les messages épinglés des messages normaux
    final pinnedMessages = _messages.where((m) => m.pinned).toList();
    final normalMessages = _messages.where((m) => !m.pinned).toList();

    // Afficher les messages épinglés en haut
    if (pinnedMessages.isNotEmpty) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.amber.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Messages épinglés',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );

      for (final message in pinnedMessages) {
        widgets.add(_buildMessageWidget(message, lastDate));
        lastDate = DateTime(
          message.date.year,
          message.date.month,
          message.date.day,
        );
      }

      // Ajouter un séparateur entre les messages épinglés et les messages normaux
      widgets.add(
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
        ),
      );
    }

    // Parcourir les messages normaux dans l'ordre chronologique (du plus ancien au plus récent)
    for (int i = 0; i < normalMessages.length; i++) {
      final message = normalMessages[i];
      
      // Ne pas filtrer les messages supprimés "pour moi" - on les affichera avec un style différent
      final messageDate = DateTime(
        message.date.year,
        message.date.month,
        message.date.day,
      );

      // Ajouter un séparateur de date si nécessaire
      if (lastDate == null || messageDate != lastDate) {
        widgets.add(DateSeparator(date: message.date));
        lastDate = messageDate;
      }

      // Note: On pourrait optimiser l'affichage des avatars en fonction
      // de si c'est le dernier message du même auteur

      final isSelected = _selectedMessageIds.contains(message.id);
      
      widgets.add(
        GestureDetector(
          onLongPress: _isSelectingMessages
              ? null
              : () => _showMessageContextMenu(message, Offset.zero),
          onTap: _isSelectingMessages
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedMessageIds.remove(message.id);
                    } else {
                      _selectedMessageIds.add(message.id);
                    }
                  });
                }
              : null,
          child: Container(
            color: isSelected ? Colors.blue.shade50 : Colors.transparent,
            child: Row(
              children: [
                if (_isSelectingMessages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedMessageIds.add(message.id);
                          } else {
                            _selectedMessageIds.remove(message.id);
                          }
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: MessageBubble(
                    message: message,
                    isOwnMessage: message.auteurId == _currentUser?.id,
                    currentUserId: _currentUser?.id ?? '',
                    senderColor: _senderColors[message.auteurId],
                    onLongPress: _isSelectingMessages
                        ? null
                        : () => _showMessageContextMenu(message, Offset.zero),
                    onReactionTap: _isSelectingMessages
                        ? null
                        : (emoji) => _toggleReaction(message, emoji),
                    onPollVote: _isSelectingMessages
                        ? null
                        : (optionIndex) => _votePoll(message, optionIndex),
                    onRestore: message.isDeletedForUser(_currentUser?.id ?? '')
                        ? () => _restoreMessage(message)
                        : null,
                    onReplyTap: _isSelectingMessages
                        ? null
                        : () {
                            // Scroll vers le message original
                            if (!_scrollController.hasClients) return;
                            final index = _messages.indexWhere((m) => m.id == message.replyToMessageId);
                            if (index >= 0) {
                              try {
                                // Calculer la position approximative
                                final position = index * 100.0;
                                if (position.isFinite && position >= 0) {
                                  _scrollController.animateTo(
                                    position,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              } catch (e) {
                                debugPrint('Erreur lors du scroll vers le message: $e');
                              }
                            }
                          },
                    onThreadTap: _isSelectingMessages
                        ? null
                        : () {
                            // Ouvrir l'écran thread
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadScreen(
                                  messageId: message.id,
                                  groupId: widget.groupId,
                                  currentUserId: _currentUser?.id ?? '',
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
      );
    }

    return widgets;
  }

  Widget _buildMessageWidget(MessageExtended message, DateTime? lastDate) {
    final messageDate = DateTime(
      message.date.year,
      message.date.month,
      message.date.day,
    );

    final widgets = <Widget>[];

    // Ajouter un séparateur de date si nécessaire
    if (lastDate == null || messageDate != lastDate) {
      widgets.add(DateSeparator(date: message.date));
    }

    final isSelected = _selectedMessageIds.contains(message.id);
    
    widgets.add(
      GestureDetector(
        onLongPress: _isSelectingMessages
            ? null
            : () => _showMessageContextMenu(message, Offset.zero),
        onTap: _isSelectingMessages
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedMessageIds.remove(message.id);
                  } else {
                    _selectedMessageIds.add(message.id);
                  }
                });
              }
            : null,
        child: Container(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          child: Row(
            children: [
              if (_isSelectingMessages)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMessageIds.add(message.id);
                        } else {
                          _selectedMessageIds.remove(message.id);
                        }
                      });
                    },
                  ),
                ),
              Expanded(
                child: MessageBubble(
                  message: message,
                  isOwnMessage: message.auteurId == _currentUser?.id,
                  currentUserId: _currentUser?.id ?? '',
                  senderColor: _senderColors[message.auteurId],
                  onLongPress: _isSelectingMessages
                      ? null
                      : () => _showMessageContextMenu(message, Offset.zero),
                  onReactionTap: _isSelectingMessages
                      ? null
                      : (emoji) => _toggleReaction(message, emoji),
                  onPollVote: _isSelectingMessages
                      ? null
                      : (optionIndex) => _votePoll(message, optionIndex),
                  onRestore: message.isDeletedForUser(_currentUser?.id ?? '')
                      ? () => _restoreMessage(message)
                      : null,
                  onReplyTap: _isSelectingMessages
                      ? null
                      : () {
                          // Scroll vers le message original
                          if (!_scrollController.hasClients) return;
                          final index = _messages.indexWhere((m) => m.id == message.replyToMessageId);
                          if (index >= 0) {
                            try {
                              // Calculer la position approximative
                              final position = index * 100.0;
                              if (position.isFinite && position >= 0) {
                                _scrollController.animateTo(
                                  position,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            } catch (e) {
                              debugPrint('Erreur lors du scroll vers le message: $e');
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(children: widgets);
  }

  // Afficher le menu du groupe
  void _showGroupMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Infos du groupe'),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outline_blank),
                title: const Text('Sélectionner des messages'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSelectingMessages = true;
                  });
                },
              ),
              ListTile(
                leading: Icon(_isSilentMode ? Icons.notifications_off : Icons.notifications),
                title: Text(_isSilentMode ? 'Désactiver le mode silencieux' : 'Mode silencieux'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSilentMode = !_isSilentMode;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isSilentMode 
                        ? 'Mode silencieux activé' 
                        : 'Mode silencieux désactivé'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                title: Text(_isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isFavorite = !_isFavorite;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isFavorite 
                        ? 'Ajouté aux favoris' 
                        : 'Retiré des favoris'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Fermer la discussion'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Quitter le groupe', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveGroupDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Afficher les infos du groupe
  void _showGroupInfo() async {
    final result = await Navigator.of(context).push<MessageExtended>(
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
    
    // Si un message a été sélectionné depuis la recherche, scroller vers lui
    if (result != null) {
      _scrollToMessage(result.id);
    }
  }

  // Scroller vers un message spécifique
  void _scrollToMessage(String messageId) {
    // Attendre que le widget soit construit
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0 && _scrollController.hasClients) {
        try {
          // Calculer la position approximative (chaque message fait environ 100px)
          final position = index * 100.0;
          if (position.isFinite && position >= 0) {
            _scrollController.animateTo(
              position,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        } catch (e) {
          debugPrint('Erreur lors du scroll vers le message: $e');
        }
      }
    });
  }

  // Dialog pour quitter le groupe
  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Êtes-vous sûr de vouloir quitter ce groupe ? Vous ne recevrez plus de messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveGroup();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  // Quitter le groupe
  Future<void> _leaveGroup() async {
    try {
      final apiService = ApiService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);
      
      final currentUser = authService.user;
      await apiService.removeMemberFromGroup(widget.groupId, currentUser!.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez quitté le groupe'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll("Exception: ", "")}'),
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
      appBar: ChatHeader(
        title: widget.groupName,
        subtitle: widget.memberCount != null
            ? '${widget.memberCount} membres'
            : null,
        onBack: () {
          if (_isSelectingMessages) {
            setState(() {
              _isSelectingMessages = false;
              _selectedMessageIds.clear();
            });
          } else {
            Navigator.of(context).pop();
          }
        },
        onPins: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PinnedMessagesScreen(
                groupId: widget.groupId,
                currentUserId: _currentUser?.id ?? '',
              ),
            ),
          );
        },
        onSearch: () async {
          final messageId = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => MessageSearchScreen(
                groupId: widget.groupId,
                currentUserId: _currentUser?.id ?? '',
              ),
            ),
          );
          
          // Si un messageId est retourné, naviguer vers ce message dans le chat
          if (messageId != null && mounted) {
            // TODO: Implémenter la navigation vers le message dans la timeline
            // Pour l'instant, on peut juste afficher un message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Message sélectionné: $messageId'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onMenu: () => _showGroupMenu(),
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
          if (_isSelectingMessages)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSelectingMessages = false;
                        _selectedMessageIds.clear();
                      });
                    },
                    child: const Text('Annuler', style: TextStyle(color: Colors.white)),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedMessageIds.length} sélectionné${_selectedMessageIds.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: _selectedMessageIds.isEmpty
                        ? null
                        : () => _deleteSelectedMessages(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              // Charger plus de messages quand on scroll vers le haut
                              if (_scrollController.hasClients &&
                                  _scrollController.position.pixels <=
                                      _scrollController.position.minScrollExtent + 100) {
                                _loadMessages(loadMore: true);
                              }
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: false, // Messages dans l'ordre chronologique
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _buildMessageList().length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingMore && index == 0) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final actualIndex = _isLoadingMore ? index - 1 : index;
                              final messageList = _buildMessageList();
                              if (actualIndex < 0 || actualIndex >= messageList.length) {
                                return const SizedBox.shrink();
                              }
                              return messageList[actualIndex];
                            },
                          ),
                        ),
          ),
          if (_typingUser != null)
            TypingIndicator(
              userPseudo: _typingUser!,
              isVisible: true,
            ),
          if (_editingMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous modifiez un message',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ChatInput(
            controller: _messageController,
            onSend: _editingMessage != null ? _saveEdit : _sendMessage,
            replyPreview: _replyPreview,
            onCancelReply: () {
              setState(() {
                _replyPreview = null;
                _replyingToMessageId = null;
              });
            },
            onDocument: () => _handleDocument(),
            onPhotoVideo: () => _handlePhotoVideo(),
            onCamera: () => _handleCamera(),
            onAudio: () => _handleAudio(),
            onPoll: () => _handlePoll(),
            onRide: () => _handleRide(),
            groupId: widget.groupId, // Pour l'autocomplete des mentions
          ),
          ],
        ),
      ),
    );
  }
}

