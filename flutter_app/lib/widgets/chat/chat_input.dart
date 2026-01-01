import 'package:flutter/material.dart';
import 'reply_preview_bar.dart';
import '../../models/message_extended.dart';
import 'attachment_menu.dart';
import 'emoji_picker.dart';

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
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isExpanded = false;
  bool _showEmojiPicker = false;

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
              final text = widget.controller.text;
              final selection = widget.controller.selection;
              final newText = text.replaceRange(
                selection.start,
                selection.end,
                emoji,
              );
              widget.controller.text = newText;
              widget.controller.selection = TextSelection.collapsed(
                offset: selection.start + emoji.length,
              );
              if (widget.onEmojiSelected != null) {
                widget.onEmojiSelected!(emoji);
              }
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
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: widget.isEnabled &&
                        widget.controller.text.trim().isNotEmpty
                    ? widget.onSend
                    : null,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}



