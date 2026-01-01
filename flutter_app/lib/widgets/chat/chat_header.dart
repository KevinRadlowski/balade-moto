import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onMenu;
  final Widget? leading;

  const ChatHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onSearch,
    this.onMenu,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading ??
          (onBack != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                )
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
      actions: [
        if (onSearch != null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
        if (onMenu != null)
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: onMenu,
          ),
      ],
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}



