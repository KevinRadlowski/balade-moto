import 'package:flutter/material.dart';

/// Widget réutilisable pour le bouton "J'aime" avec animation
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int totalLikes;
  final Function(bool) onTap;
  final bool showText;
  final double size;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.totalLikes,
    required this.onTap,
    this.showText = true,
    this.size = 24.0,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    // Animation de zoom
    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        setState(() {
          _isAnimating = false;
        });
      });
    });

    // Haptic feedback (vibration)
    // HapticFeedback.lightImpact(); // Décommenter si vous ajoutez le package

    // Appeler la callback
    widget.onTap(!widget.isLiked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isAnimating ? _scaleAnimation.value : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked ? Colors.red : Colors.grey.shade600,
                  size: widget.size,
                ),
                if (widget.showText) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.totalLikes.toString(),
                    style: TextStyle(
                      fontSize: widget.size * 0.7,
                      fontWeight: FontWeight.w600,
                      color: widget.isLiked
                          ? Colors.red
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}



