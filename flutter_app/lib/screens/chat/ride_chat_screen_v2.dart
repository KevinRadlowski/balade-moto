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
import '../../screens/ride/ride_detail_screen.dart';
import '../../widgets/chat/create_poll_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RideChatScreenV2 extends StatefulWidget {
  final String rideId;
  final String rideTitle;
  final int? participantCount;

  const RideChatScreenV2({
    super.key,
    required this.rideId,
    required this.rideTitle,
    this.participantCount,
  });

  @override
  State<RideChatScreenV2> createState() => _RideChatScreenV2State();
}

class _RideChatScreenV2State extends State<RideChatScreenV2> {
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
  String? _replyingToMessageId;
  MessageExtended? _editingMessage;
  String? _typingUser;
  bool _isTyping = false;
  DateTime? _lastTypingTime;

  final Map<String, Color> _senderColors = {};
  
  bool _isSilentMode = false;
  bool _isFavorite = false;
  bool _isSelectingMessages = false;
  final Set<String> _selectedMessageIds = {};
  
  String? _rideOrganizerId;

  @override
  void initState() {
    super.initState();
    _replyPreview = null;
    _replyingToMessageId = null;
    _initializeChat();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _socketService.stopTyping(widget.rideId, 'ride');
    _socketService.leaveRideRoom(widget.rideId);
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
        if (mounted) {
          setState(() {
            _errorMessage = 'Token d\'authentification manquant';
            _isLoading = false;
          });
        }
        return;
      }

      _chatService.setToken(token);
      _currentUser = authService.user;

      await _loadRideInfo();

      await _socketService.connect(token);

      _setupSocketListeners();

      _socketService.joinRideRoom(widget.rideId);

      await _loadMessages();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRideInfo() async {
    try {
      final apiService = ApiService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);
      
      final ride = await apiService.getRideById(widget.rideId);
      
      if (mounted) {
        setState(() {
          // Extraire l'ID de l'organisateur depuis l'objet Ride
          _rideOrganizerId = ride.organisateur.id;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des informations de la balade: $e');
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
            final existingIndex = _messages.indexWhere((m) => m.id == message.id);
            if (existingIndex >= 0) {
              _messages[existingIndex] = message;
              _assignSenderColor(message);
            } else if (isOwnMessage) {
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
                _messages[tempIndex] = message;
              } else {
                _messages.add(message);
              }
              _assignSenderColor(message);
            } else {
              _messages.add(message);
              _assignSenderColor(message);
            }
          });
        }
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    _socketService.onPreviousMessages((data) {
      final messagesData = data['messages'] as List?;
      if (messagesData != null && mounted) {
        setState(() {
          _messages = messagesData
              .map((m) => MessageExtended.fromJson(m))
              .toList();
          for (final msg in _messages) {
            _assignSenderColor(msg);
          }
          _isLoading = false;
        });
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    _socketService.onMessageUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == (messageData['id'] ?? messageData['_id']));
          if (index >= 0) {
            final updatedMessage = MessageExtended.fromJson(messageData);
            _messages[index] = updatedMessage;
          }
        });
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
            if (messageData != null) {
              final updatedMessage = MessageExtended.fromJson(messageData);
              _messages[index] = updatedMessage;
              _assignSenderColor(updatedMessage);
            } else {
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
            final pinnedMessage = MessageExtended.fromJson(messageData);
            _messages[index] = pinnedMessage;
            _assignSenderColor(pinnedMessage);
          }
        });
      }
    });

    _socketService.onPollUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == (messageData['id'] ?? messageData['_id']));
          if (index >= 0) {
            final updatedMessage = MessageExtended.fromJson(messageData);
            _messages[index] = updatedMessage;
            _assignSenderColor(updatedMessage);
          }
        });
      }
    });

    _socketService.onReactionUpdated((data) {
      if (!mounted) return;
      final messageData = data['message'];
      if (messageData != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == (messageData['id'] ?? messageData['_id']));
          if (index >= 0) {
            final updatedMessage = MessageExtended.fromJson(messageData);
            _messages[index] = updatedMessage;
          }
        });
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
      _socketService.startTyping(widget.rideId, 'ride');
    }
    _lastTypingTime = DateTime.now();

    Future.delayed(const Duration(seconds: 3), () {
      if (_lastTypingTime != null &&
          DateTime.now().difference(_lastTypingTime!) >=
              const Duration(seconds: 3)) {
        _isTyping = false;
        _socketService.stopTyping(widget.rideId, 'ride');
      }
    });
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (loadMore && (!_hasMoreMessages || _isLoadingMore)) return;

    if (mounted) {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      final response = await _chatService.getMessages(
        conversationId: widget.rideId,
        type: 'ride',
        cursor: loadMore ? _nextCursor : null,
      );

      final messagesData = response['data']['messages'] as List;
      final pagination = response['data']['pagination'];

      final newMessages = messagesData
          .map((m) => MessageExtended.fromJson(m))
          .toList();

      if (mounted) {
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
      }

      if (!loadMore) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _scrollToBottom() {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion en cours, veuillez patienter...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _isTyping = false;
    _socketService.stopTyping(widget.rideId, 'ride');

    final replyToId = _replyingToMessageId;

    final optimisticMessage = MessageExtended(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      auteurId: _currentUser!.id,
      auteurPseudo: _currentUser!.pseudo,
      contenu: trimmedMessage,
      date: DateTime.now(),
      idBalade: widget.rideId,
      replyPreview: _replyPreview,
      replyToMessageId: replyToId,
      status: MessageStatus.sending,
    );

    if (mounted) {
      setState(() {
        _messages.add(optimisticMessage);
        _messageController.clear();
        _replyPreview = null;
        _replyingToMessageId = null;
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      _socketService.sendRideMessageWithReply(
        widget.rideId,
        trimmedMessage,
        replyToMessageId: replyToId,
      );
    } catch (e) {
      if (mounted) {
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
  }

  void _showMessageContextMenu(MessageExtended message, Offset position) {
    final isOwnMessage = message.auteurId == _currentUser?.id;
    final isOrganizer = _currentUser?.id == _rideOrganizerId;

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message copié'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        onPin: isOrganizer
            ? () {
                Navigator.pop(context);
                _togglePin(message);
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
      
      await _chatService.togglePin(messageId: message.id);
      
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
    if (mounted) {
      setState(() {
        _replyPreview = ReplyPreview(
          senderPseudo: message.displayName,
          content: message.contenu.length > 50 
              ? '${message.contenu.substring(0, 50)}...' 
              : message.contenu,
          type: message.type.toString().split('.').last,
        );
        _replyingToMessageId = message.id;
      });
    }
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
    if (!_socketService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion en cours, veuillez patienter...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    if (message.id.isEmpty || emoji.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: données invalides'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      _socketService.toggleReaction(message.id, emoji);
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

  void _editMessage(MessageExtended message) {
    if (mounted) {
      setState(() {
        _editingMessage = message;
        _messageController.text = message.contenu;
        _replyPreview = null;
        _replyingToMessageId = null;
      });
    }
  }

  void _cancelEdit() {
    if (mounted) {
      setState(() {
        _editingMessage = null;
        _messageController.clear();
        _replyPreview = null;
        _replyingToMessageId = null;
      });
    }
  }

  Future<void> _saveEdit() async {
    if (_editingMessage == null) return;
    final newContent = _messageController.text;
    if (!_hasValidContent(newContent)) return;
    final trimmedContent = newContent.trim();

    try {
      _socketService.editMessage(_editingMessage!.id, trimmedContent);
      if (mounted) {
        setState(() {
          _editingMessage = null;
          _messageController.clear();
          _replyPreview = null;
          _replyingToMessageId = null;
        });
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

  Future<void> _handleDocument() async {
    try {
      final filePicker = FilePicker.platform;
      final result = await filePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
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
          conversationId: widget.rideId,
          type: 'ride',
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

  Future<void> _uploadAndSendFile(dynamic file, String type) async {
    try {
      if (!mounted) return;

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

      if (kIsWeb) {
        if (file is PlatformFile) {
          if (file.bytes == null) {
            throw Exception('Impossible de lire le fichier (bytes null)');
          }
        } else if (file is! XFile) {
          throw Exception('Type de fichier non supporté: ${file.runtimeType}');
        }

        await _chatService.uploadFile(
          conversationId: widget.rideId,
          type: 'ride',
          file: file,
          messageType: type,
          replyToMessageId: _replyingToMessageId,
        );
      } else {
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

        await _chatService.sendMessageWithFile(
          conversationId: widget.rideId,
          type: 'ride',
          filePath: filePath,
          fileType: type,
          content: '',
          replyToMessageId: _replyingToMessageId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
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
      _socketService.restoreMessage(message.id);
      
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

        if (mounted) {
          setState(() {
            _isSelectingMessages = false;
            _selectedMessageIds.clear();
          });
        }

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

    final pinnedMessages = _messages.where((m) => m.pinned).toList();
    final normalMessages = _messages.where((m) => !m.pinned).toList();

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

    for (int i = 0; i < normalMessages.length; i++) {
      final message = normalMessages[i];
      
      final messageDate = DateTime(
        message.date.year,
        message.date.month,
        message.date.day,
      );

      if (lastDate == null || messageDate != lastDate) {
        widgets.add(DateSeparator(date: message.date));
        lastDate = messageDate;
      }

      final isSelected = _selectedMessageIds.contains(message.id);
      
      widgets.add(
        GestureDetector(
          onLongPress: _isSelectingMessages
              ? null
              : () => _showMessageContextMenu(message, Offset.zero),
          onTap: _isSelectingMessages
              ? () {
                  if (mounted) {
                    setState(() {
                      if (isSelected) {
                        _selectedMessageIds.remove(message.id);
                      } else {
                        _selectedMessageIds.add(message.id);
                      }
                    });
                  }
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
                        if (mounted) {
                          setState(() {
                            if (value == true) {
                              _selectedMessageIds.add(message.id);
                            } else {
                              _selectedMessageIds.remove(message.id);
                            }
                          });
                        }
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
                            if (!_scrollController.hasClients) return;
                            final index = _messages.indexWhere((m) => m.id == message.replyToMessageId);
                            if (index >= 0) {
                              try {
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
                if (mounted) {
                  setState(() {
                    if (isSelected) {
                      _selectedMessageIds.remove(message.id);
                    } else {
                      _selectedMessageIds.add(message.id);
                    }
                  });
                }
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
                      if (mounted) {
                        setState(() {
                          if (value == true) {
                            _selectedMessageIds.add(message.id);
                          } else {
                            _selectedMessageIds.remove(message.id);
                          }
                        });
                      }
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
                          if (!_scrollController.hasClients) return;
                          final index = _messages.indexWhere((m) => m.id == message.replyToMessageId);
                          if (index >= 0) {
                            try {
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

  void _showRideMenu() {
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
                title: const Text('Détails de la balade'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideDetailScreen(rideId: widget.rideId),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outline_blank),
                title: const Text('Sélectionner des messages'),
                onTap: () {
                  Navigator.pop(context);
                  if (mounted) {
                    setState(() {
                      _isSelectingMessages = true;
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(_isSilentMode ? Icons.notifications_off : Icons.notifications),
                title: Text(_isSilentMode ? 'Désactiver le mode silencieux' : 'Mode silencieux'),
                onTap: () {
                  Navigator.pop(context);
                  if (mounted) {
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
                  }
                },
              ),
              ListTile(
                leading: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                title: Text(_isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'),
                onTap: () {
                  Navigator.pop(context);
                  if (mounted) {
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
                  }
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    final customBaladeBackground = user?.customBackgrounds?['balade'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customBaladeBackground != null && customBaladeBackground.isNotEmpty)
        ? customBaladeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBaladeBackgroundImageName(user?.vehiclePreference);
    
    return Scaffold(
      appBar: ChatHeader(
        title: widget.rideTitle,
        subtitle: widget.participantCount != null
            ? '${widget.participantCount} participant${widget.participantCount! > 1 ? 's' : ''}'
            : null,
        onBack: () {
          if (_isSelectingMessages) {
            if (mounted) {
              setState(() {
                _isSelectingMessages = false;
                _selectedMessageIds.clear();
              });
            }
          } else {
            Navigator.of(context).pop();
          }
        },
        onMenu: () => _showRideMenu(),
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
                        if (mounted) {
                          setState(() {
                            _isSelectingMessages = false;
                            _selectedMessageIds.clear();
                          });
                        }
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
                              reverse: false,
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
                if (mounted) {
                  setState(() {
                    _replyPreview = null;
                    _replyingToMessageId = null;
                  });
                }
              },
              onDocument: () => _handleDocument(),
              onPhotoVideo: () => _handlePhotoVideo(),
              onCamera: () => _handleCamera(),
              onAudio: () => _handleAudio(),
              onPoll: () => _handlePoll(),
            ),
          ],
        ),
      ),
    );
  }
}

