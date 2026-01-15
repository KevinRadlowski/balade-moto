import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_extended.dart';
import '../../config/api_config.dart';
import 'reply_preview_bar.dart';
import 'reaction_bar.dart';
import 'ride_preview_card.dart';
import 'mention_text.dart';

class MessageBubble extends StatelessWidget {
  final MessageExtended message;
  final bool isOwnMessage;
  final String currentUserId;
  final Color? senderColor;
  final VoidCallback? onLongPress;
  final Function(String emoji)? onReactionTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onThreadTap; // Pour ouvrir le thread
  final VoidCallback? onRestore;
  final Function(int optionIndex)? onPollVote;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.currentUserId,
    this.senderColor,
    this.onLongPress,
    this.onReactionTap,
    this.onReplyTap,
    this.onThreadTap,
    this.onRestore,
    this.onPollVote,
  });

  Color _getSenderColor() {
    if (senderColor != null) return senderColor!;
    // Générer une couleur basée sur le pseudo (style WhatsApp)
    final hash = message.auteurPseudo?.hashCode ?? message.auteurId.hashCode;
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
    return colors[hash.abs() % colors.length];
  }

  // Construire l'URL complète de l'avatar si nécessaire
  String _buildAvatarUrl(String avatarUrl) {
    // Utiliser ApiConfig.getFileUrl() qui gère le remplacement de localhost
    return ApiConfig.getFileUrl(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDeletedForMe = message.isDeletedForUser(currentUserId);
    
    if (message.isDeleted) {
      return _buildDeletedMessage(context);
    }
    
    if (isDeletedForMe) {
      return _buildDeletedForMeMessage(context);
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwnMessage) ...[
              _buildAvatar(context),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isOwnMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        message.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getSenderColor(),
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isOwnMessage
                          ? Theme.of(context).primaryColor.withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                        bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Afficher le replyPreview seulement si le message a un replyToMessageId
                        if (message.replyToMessageId != null && message.replyPreview != null)
                          GestureDetector(
                            onTap: onReplyTap,
                            child: ReplyPreviewBar(
                              replyPreview: message.replyPreview!,
                              onCancel: () {},
                            ),
                          ),
                        if (message.replyToMessageId != null && message.replyPreview != null)
                          const SizedBox(height: 8),
                        // Afficher l'aperçu de la balade si c'est un message de type 'ride'
                        if (message.type == MessageType.ride && message.proposedRideId != null)
                          RidePreviewCard(
                            rideId: message.proposedRideId!,
                            isOwnMessage: isOwnMessage,
                          ),
                        // Afficher le sondage si présent et valide (avec question et options)
                        if (message.pollData != null && 
                            message.pollData!.question.isNotEmpty && 
                            message.pollData!.options.isNotEmpty)
                          _buildPoll(context),
                        // Afficher le fichier/image si présent
                        if (message.metadata != null && message.metadata!.url != null)
                          _buildFileAttachment(context, message.metadata!, message.type),
                        // Afficher le contenu seulement s'il n'est pas vide ou s'il n'y a pas de fichier ou de sondage valide
                        if (message.contenu.isNotEmpty && 
                            (message.pollData == null || 
                             message.pollData!.question.isEmpty || 
                             message.pollData!.options.isEmpty) && 
                            (message.metadata == null || message.metadata!.url == null))
                          MentionText(
                            text: message.contenu,
                            style: TextStyle(
                              fontSize: 14,
                              color: isOwnMessage ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w400,
                            ),
                            mentionColor: isOwnMessage 
                                ? Colors.white.withOpacity(0.9)
                                : Colors.blue.shade700,
                            onMentionTap: (username) {
                              // TODO: Ouvrir le profil de l'utilisateur mentionné
                              // Pour l'instant, juste un debug
                              debugPrint('Mention tapée: @$username');
                            },
                          ),
                        if (message.contenu.isNotEmpty && message.metadata != null && message.metadata!.url != null)
                          const SizedBox(height: 4),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (message.edited) ...[
                              const SizedBox(width: 4),
                              Text(
                                'Modifié',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            if (isOwnMessage) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ReactionBar(
                    reactionsSummary: message.reactionsSummary,
                    onReactionTap: onReactionTap,
                  ),
                  // Afficher le compteur de réponses si > 0
                  if (message.threadReplyCount > 0 && message.parentMessageId == null)
                    GestureDetector(
                      onTap: onThreadTap,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: isOwnMessage ? Colors.white70 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${message.threadReplyCount} ${message.threadReplyCount == 1 ? 'réponse' : 'réponses'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOwnMessage ? Colors.white70 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isOwnMessage) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    // Si le message a une URL d'avatar, l'utiliser
    if (message.senderAvatarUrl != null && message.senderAvatarUrl!.isNotEmpty) {
      final avatarUrl = _buildAvatarUrl(message.senderAvatarUrl!);
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // En cas d'erreur de chargement, utiliser l'icône par défaut
        },
        child: message.senderAvatarUrl == null || message.senderAvatarUrl!.isEmpty
            ? const Icon(Icons.person, size: 16, color: Colors.white)
            : null,
      );
    }

    // Sinon, utiliser une icône par défaut
    final color = _getSenderColor();
    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: const Icon(
        Icons.person,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ce message a été supprimé',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context, MessageMetadata metadata, MessageType type) {
    final fileUrl = metadata.url ?? '';
    final fileName = metadata.fileName ?? 'Fichier';
    final mimeType = metadata.mimeType ?? '';

    // Si c'est une image
    if (type == MessageType.image || mimeType.startsWith('image/')) {
      return GestureDetector(
        onTap: () async {
          // Ouvrir l'image en plein écran
          if (await canLaunchUrl(Uri.parse(fileUrl))) {
            await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fileUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Pour les autres types de fichiers (PDF, Word, etc.)
    return GestureDetector(
      onTap: () async {
        // Ouvrir/télécharger le fichier
        if (await canLaunchUrl(Uri.parse(fileUrl))) {
          await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(mimeType, fileName),
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metadata.size != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(metadata.size!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.download,
              size: 20,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String mimeType, String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    if (mimeType.contains('pdf') || extension == 'pdf') {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || extension == 'doc' || extension == 'docx') {
      return Icons.description;
    } else if (mimeType.contains('excel') || extension == 'xls' || extension == 'xlsx') {
      return Icons.table_chart;
    } else if (mimeType.contains('powerpoint') || extension == 'ppt' || extension == 'pptx') {
      return Icons.slideshow;
    } else if (mimeType.contains('zip') || extension == 'zip' || extension == 'rar') {
      return Icons.folder_zip;
    } else if (mimeType.contains('video') || extension == 'mp4' || extension == 'mov') {
      return Icons.video_file;
    } else if (mimeType.contains('audio') || extension == 'mp3' || extension == 'wav') {
      return Icons.audio_file;
    } else {
      return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Widget _buildDeletedForMeMessage(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwnMessage) ...[
              _buildAvatar(context),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isOwnMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        message.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getSenderColor(),
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300.withOpacity(0.5),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                        bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                      ),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ce message a été supprimé',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (onRestore != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: onRestore,
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restaurer'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isOwnMessage) ...[
              const SizedBox(width: 8),
              _buildAvatar(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoll(BuildContext context) {
    if (message.pollData == null) return const SizedBox.shrink();

    final poll = message.pollData!;
    final totalVotes = poll.totalVotes;
    final hasVoted = poll.options.any((option) =>
        option.votes.any((vote) => vote.userId == currentUserId));

    print('🔵 _buildPoll - onPollVote: ${onPollVote != null}, hasVoted: $hasVoted, multipleChoice: ${poll.multipleChoice}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isOwnMessage ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...poll.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final optionVotes = option.votes.length;
            final percentage = totalVotes > 0 ? (optionVotes / totalVotes) : 0.0;
            final hasUserVoted = option.votes.any((vote) => vote.userId == currentUserId);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                print('🔵 Vote cliqué - optionIndex: $index, onPollVote: ${onPollVote != null}');
                if (onPollVote != null) {
                  onPollVote!(index);
                } else {
                  print('❌ onPollVote est null!');
                }
              },
              child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isOwnMessage ? Colors.white : Colors.grey[200])?.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasUserVoted
                          ? (isOwnMessage ? Colors.white : Theme.of(context).primaryColor)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: hasUserVoted ? FontWeight.bold : FontWeight.normal,
                                      color: isOwnMessage ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '${(percentage * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOwnMessage ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            if (hasVoted && totalVotes > 0) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: (isOwnMessage ? Colors.white : Colors.grey[300])?.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  hasUserVoted
                                      ? (isOwnMessage ? Colors.white : Theme.of(context).primaryColor)
                                      : (isOwnMessage ? Colors.white70 : Colors.grey[600]!),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasUserVoted)
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: isOwnMessage ? Colors.white : Theme.of(context).primaryColor,
                        ),
                    ],
                  ),
                ),
            );
          }),
          if (totalVotes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$totalVotes vote${totalVotes > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: isOwnMessage ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

