import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'reply_preview_bar.dart';
import '../../models/message_extended.dart';
import '../../models/user_suggestion.dart';
import 'attachment_menu.dart';
import 'emoji_picker.dart';
import 'mention_autocomplete.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final ReplyPreview? replyPreview;
  final VoidCallback? onCancelReply;
  final VoidCallback? onDocument;
  final VoidCallback? onPhotoVideo;
  final VoidCallback? onCamera;
  final VoidCallback? onAudio;
  final VoidCallback? onPoll;
  final VoidCallback? onRide;
  final Function(String)? onEmojiSelected;
  final bool isEnabled;
  final String? groupId; // Pour l'autocomplete des mentions

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.replyPreview,
    this.onCancelReply,
    this.onDocument,
    this.onPhotoVideo,
    this.onCamera,
    this.onAudio,
    this.onPoll,
    this.onRide,
    this.onEmojiSelected,
    this.isEnabled = true,
    this.groupId, // Optionnel : seulement pour les groupes
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isExpanded = false;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();
  
  // Gestion de l'autocomplete des mentions
  String? _mentionQuery;
  Timer? _mentionDebounceTimer;

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentMenu(
        onDocument: () {
          Navigator.pop(context);
          widget.onDocument?.call();
        },
        onPhotoVideo: () {
          Navigator.pop(context);
          widget.onPhotoVideo?.call();
        },
        onCamera: () {
          Navigator.pop(context);
          widget.onCamera?.call();
        },
        onAudio: () {
          Navigator.pop(context);
          widget.onAudio?.call();
        },
        onPoll: () {
          Navigator.pop(context);
          widget.onPoll?.call();
        },
        onRide: () {
          Navigator.pop(context);
          widget.onRide?.call();
        },
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    
    // Vérifier que la sélection est valide, sinon utiliser la fin du texte
    int start = selection.isValid && selection.start >= 0 ? selection.start : text.length;
    int end = selection.isValid && selection.end >= 0 ? selection.end : text.length;
    
    // S'assurer que start et end sont dans les limites valides
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (start > text.length) start = text.length;
    if (end > text.length) end = text.length;
    
    final newText = text.replaceRange(
      start,
      end,
      emoji,
    );
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: start + emoji.length,
    );
    if (widget.onEmojiSelected != null) {
      widget.onEmojiSelected!(emoji);
    }
  }

  void _checkForMention(String text) {
    if (widget.groupId == null) {
      setState(() {
        _mentionQuery = null;
      });
      return;
    }

    // Trouver la position du curseur
    final selection = widget.controller.selection;
    final cursorPosition = selection.isValid ? selection.start : text.length;

    // Chercher le dernier "@" avant le curseur
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) {
      // Pas de "@" trouvé
      setState(() {
        _mentionQuery = null;
      });
      return;
    }

    // Vérifier qu'il n'y a pas d'espace entre le "@" et le curseur
    final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
    if (textAfterAt.contains(' ') || textAfterAt.contains('\n')) {
      setState(() {
        _mentionQuery = null;
      });
      return;
    }

    // Extraire la query (texte après le @)
    final query = textAfterAt.trim();
    
    // Débouncer les requêtes
    _mentionDebounceTimer?.cancel();
    _mentionDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _mentionQuery = query.length >= 1 ? query : null;
        });
      }
    });
  }

  void _insertMention(UserSuggestion suggestion) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursorPosition = selection.isValid ? selection.start : text.length;

    // Trouver le dernier "@" avant le curseur
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) return;

    // Remplacer "@query" par "@username "
    final endIndex = cursorPosition;
    
    final newText = text.replaceRange(
      lastAtIndex,
      endIndex,
      '@${suggestion.username} ',
    );

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: lastAtIndex + suggestion.username.length + 2, // +2 pour "@" et " "
    );

    // Masquer l'autocomplete
    setState(() {
      _mentionQuery = null;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _mentionDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyPreview != null)
          ReplyPreviewBar(
            replyPreview: widget.replyPreview!,
            onCancel: widget.onCancelReply ?? () {},
          ),
        if (_showEmojiPicker)
          EmojiPicker(
            onEmojiSelected: (emoji) {
              // S'assurer que le TextField a le focus pour avoir une sélection valide
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
                // Attendre que le focus soit établi avant d'insérer l'emoji
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _insertEmoji(emoji);
                });
              } else {
                _insertEmoji(emoji);
              }
            },
          ),
        // Autocomplete des mentions
        if (_mentionQuery != null && widget.groupId != null)
          MentionAutocomplete(
            groupId: widget.groupId!,
            query: _mentionQuery!,
            onSelect: (suggestion) {
              _insertMention(suggestion);
            },
            onDismiss: () {
              setState(() {
                _mentionQuery = null;
              });
            },
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Bouton +
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard : Icons.add,
                  color: _showEmojiPicker 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade600,
                ),
                onPressed: widget.isEnabled
                    ? (_showEmojiPicker ? _toggleEmojiPicker : _showAttachmentMenu)
                    : null,
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.isEnabled,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Tapez un message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {
                      _isExpanded = text.contains('\n') || text.length > 30;
                    });
                    // Vérifier les mentions
                    _checkForMention(text);
                  },
                  onSubmitted: (_) {
                    if (!_isExpanded) {
                      widget.onSend();
                    }
                  },
                ),
              ),
              // Bouton emoji
              IconButton(
                icon: Icon(
                  _showEmojiPicker 
                      ? Icons.keyboard 
                      : Icons.emoji_emotions_outlined,
                  color: _showEmojiPicker 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade600,
                ),
                onPressed: widget.isEnabled ? _toggleEmojiPicker : null,
              ),
              const SizedBox(width: 4),
              // Bouton envoyer
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, child) {
                  // Helper pour vérifier si le texte contient du contenu valide (y compris les emojis)
                  final hasValidContent = () {
                    final trimmed = value.text.trim();
                    return trimmed.isNotEmpty;
                  };
                  
                  final canSend = widget.isEnabled && hasValidContent();
                  
                  return IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: canSend ? widget.onSend : null,
                    color: Theme.of(context).primaryColor,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}



