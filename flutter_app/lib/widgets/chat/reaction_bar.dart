import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  final Map<String, int> reactionsSummary;
  final Function(String emoji)? onReactionTap;

  const ReactionBar({
    super.key,
    required this.reactionsSummary,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactionsSummary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: reactionsSummary.entries.map((entry) {
          return GestureDetector(
            onTap: () => onReactionTap?.call(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Apple Color Emoji', // Support emoji sur iOS/Web
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

