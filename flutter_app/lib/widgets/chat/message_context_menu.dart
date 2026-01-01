import 'package:flutter/material.dart';

class MessageContextMenu extends StatelessWidget {
  final bool isOwnMessage;
  final VoidCallback? onReply;
  final VoidCallback? onReact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onPin;

  const MessageContextMenu({
    super.key,
    required this.isOwnMessage,
    this.onReply,
    this.onReact,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.onForward,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReply != null)
            _MenuItem(
              icon: Icons.reply,
              label: 'Répondre',
              onTap: onReply!,
            ),
          if (onReact != null)
            _MenuItem(
              icon: Icons.add_reaction,
              label: 'Réagir',
              onTap: onReact!,
            ),
          if (onCopy != null)
            _MenuItem(
              icon: Icons.copy,
              label: 'Copier',
              onTap: onCopy!,
            ),
          if (onForward != null)
            _MenuItem(
              icon: Icons.forward,
              label: 'Transférer',
              onTap: onForward!,
            ),
          if (onPin != null)
            _MenuItem(
              icon: Icons.push_pin,
              label: 'Épingler',
              onTap: onPin!,
            ),
          if (isOwnMessage) ...[
            const Divider(height: 1),
            if (onEdit != null)
              _MenuItem(
                icon: Icons.edit,
                label: 'Modifier',
                onTap: onEdit!,
              ),
            if (onDelete != null)
              _MenuItem(
                icon: Icons.delete,
                label: 'Supprimer',
                onTap: onDelete!,
                textColor: Colors.red,
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: textColor ?? Colors.grey.shade700,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

