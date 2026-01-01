import 'package:flutter/material.dart';

class QuickReactionPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const QuickReactionPicker({
    super.key,
    required this.onEmojiSelected,
  });

  static const List<String> quickEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                emoji,
                style: const TextStyle(
                  fontSize: 24,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

