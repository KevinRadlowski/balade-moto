import 'package:flutter/material.dart';

/// Widget pour sélectionner le style de conduite (obligatoire)
/// Utilisé dans la création/édition de balade
class RidingStyleChips extends StatelessWidget {
  final String? selectedStyle;
  final Function(String) onStyleSelected;
  final bool isRequired;
  final String? errorText;

  const RidingStyleChips({
    super.key,
    required this.selectedStyle,
    required this.onStyleSelected,
    this.isRequired = true,
    this.errorText,
  });

  static const List<Map<String, dynamic>> styles = [
    {
      'value': 'calme',
      'label': 'Calme',
      'icon': Icons.sentiment_satisfied,
      'color': Colors.green,
      'description': 'Conduite tranquille, respect des limitations',
    },
    {
      'value': 'modere',
      'label': 'Modéré',
      'icon': Icons.sentiment_neutral,
      'color': Colors.orange,
      'description': 'Conduite normale, occasionnellement sportive',
    },
    {
      'value': 'sportif',
      'label': 'Sportif',
      'icon': Icons.speed,
      'color': Colors.red,
      'description': 'Conduite dynamique, virages serrés',
    },
    {
      'value': 'mixte',
      'label': 'Mixte',
      'icon': Icons.swap_horiz,
      'color': Colors.blue,
      'description': 'Adaptation selon le trajet',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Style de conduite',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Indiquez le style de conduite attendu pour cette balade',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: styles.map((style) {
            final isSelected = selectedStyle == style['value'];
            return _RidingStyleChip(
              label: style['label'] as String,
              icon: style['icon'] as IconData,
              color: style['color'] as Color,
              description: style['description'] as String,
              isSelected: isSelected,
              onTap: () => onStyleSelected(style['value'] as String),
            );
          }).toList(),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RidingStyleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RidingStyleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: color,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

