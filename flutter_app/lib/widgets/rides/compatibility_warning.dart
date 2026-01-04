import 'package:flutter/material.dart';
import '../../models/compatibility.dart';

/// Widget d'avertissement de compatibilité
/// Affiche un warning si la compatibilité est faible
class CompatibilityWarning extends StatelessWidget {
  final Compatibility? compatibility;
  final String? userId;
  final VoidCallback? onTap;
  final bool compact;

  const CompatibilityWarning({
    super.key,
    this.compatibility,
    this.userId,
    this.onTap,
    this.compact = false,
  });

  bool get shouldShowWarning {
    if (compatibility == null) return false;
    return compatibility!.score < 60; // Seuil de compatibilité faible
  }

  String get _warningMessage {
    if (compatibility == null) return '';
    
    final score = compatibility!.score;
    if (score < 40) {
      return 'Compatibilité très faible';
    } else if (score < 60) {
      return 'Compatibilité faible';
    }
    return '';
  }

  String get _warningDescription {
    if (compatibility == null) return '';
    
    final factors = compatibility!.factors;
    final issues = <String>[];
    
    if (!factors.sameVehicleType) {
      issues.add('types de véhicules différents');
    }
    if (!factors.sameRidingStyle) {
      issues.add('styles de conduite différents');
    }
    if (factors.reputationMatch != null && factors.reputationMatch! < 50) {
      issues.add('niveaux de réputation différents');
    }
    
    if (issues.isEmpty) return '';
    return 'Points d\'attention : ${issues.join(', ')}';
  }

  Color get _warningColor {
    if (compatibility == null) return Colors.orange;
    final score = compatibility!.score;
    if (score < 40) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShowWarning) return const SizedBox.shrink();

    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _warningColor.withOpacity(0.1),
            border: Border.all(
              color: _warningColor.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: _warningColor,
              ),
              const SizedBox(width: 6),
              Text(
                _warningMessage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _warningColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _warningColor.withOpacity(0.1),
          border: Border.all(
            color: _warningColor.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: _warningColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _warningMessage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _warningColor,
                    ),
                  ),
                ),
                if (compatibility != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _warningColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${compatibility!.score.toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_warningDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _warningDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: 8),
              Text(
                'Appuyez pour plus de détails',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

