import 'package:flutter/material.dart';

/// Widget d'étoiles cliquables pour la notation
class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final Color? color;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 32.0,
    this.color,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final isFilled = index < rating;
        
        return GestureDetector(
          onTap: interactive && onRatingChanged != null
              ? () => onRatingChanged!(index + 1)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                isFilled ? Icons.star : Icons.star_border,
                size: size,
                color: isFilled ? starColor : Colors.grey.shade400,
              ),
            ),
          ),
        );
      }),
    );
  }
}



