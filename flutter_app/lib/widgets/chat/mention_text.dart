import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Widget pour afficher un texte avec des mentions @username stylisées
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color mentionColor;
  final Function(String username)? onMentionTap;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionColor = Colors.blue,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    // Pattern pour détecter les mentions : @username
    final mentionPattern = RegExp(r'@([a-zA-Z0-9_.-]{2,30})');
    
    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in mentionPattern.allMatches(text)) {
      // Ajouter le texte avant la mention
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      // Ajouter la mention stylisée
      final username = match.group(1) ?? '';
      spans.add(TextSpan(
        text: match.group(0), // "@username"
        style: (style ?? const TextStyle()).copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w600,
        ),
        recognizer: onMentionTap != null
            ? (TapGestureRecognizer()
              ..onTap = () => onMentionTap!(username))
            : null,
      ));

      lastMatchEnd = match.end;
    }

    // Ajouter le texte restant après la dernière mention
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    // Si aucune mention trouvée, retourner un Text simple
    if (spans.isEmpty || (spans.length == 1 && spans[0].recognizer == null)) {
      return Text(text, style: style);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

