import 'package:flutter/material.dart';
import 'star_rating.dart';

/// Widget pour afficher la note moyenne avec style moderne
class AverageRatingDisplay extends StatelessWidget {
  final double averageRating;
  final int totalRatings;
  final bool showDetails;

  const AverageRatingDisplay({
    super.key,
    required this.averageRating,
    required this.totalRatings,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    if (averageRating == 0 && totalRatings == 0) {
      return const SizedBox.shrink();
    }

    final filledStars = averageRating.floor();
    final hasHalfStar = (averageRating - filledStars) >= 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.amber.shade100.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône étoile
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_rounded,
              color: Colors.amber.shade800,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Note moyenne et étoiles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ 5',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StarRating(
                      rating: filledStars + (hasHalfStar ? 1 : 0),
                      size: 18,
                      color: Colors.amber,
                    ),
                    if (showDetails && totalRatings > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($totalRatings ${totalRatings > 1 ? 'notes' : 'note'})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Barre de progression visuelle
          if (showDetails) ...[
            const SizedBox(width: 16),
            Container(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: averageRating / 5,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber.shade700,
                      ),
                    ),
                  ),
                  Text(
                    '${(averageRating / 5 * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}



