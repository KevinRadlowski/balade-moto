import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/premium/premium_screen.dart';
import '../../providers/plan_provider.dart';

/// Affiche un modal pour promouvoir l'upgrade vers Premium
/// 
/// [reason] : Le texte expliquant pourquoi l'utilisateur doit passer en Premium
/// [details] : Informations supplémentaires optionnelles (non utilisées pour l'instant)
/// [onDismiss] : Callback appelé quand la modale est fermée (bouton "Plus tard" ou en tapant en dehors)
Future<void> showPremiumUpsellModal(
  BuildContext context, {
  required String reason,
  Map<String, dynamic>? details,
  VoidCallback? onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          final plan = planProvider.plan;
          final limits = plan?.limits;
          
          // Valeurs Standard depuis les limites réelles
          String garageValue = '—';
          String groupesValue = '—';
          String baladesValue = '—';
          
          if (limits != null && !limits.unlimited) {
            // Garage : format "2 véhicules (1 moto + 1 voiture)"
            if (limits.maxVehiclesTotal != null) {
              final moto = limits.maxVehiclesByType?['moto'] ?? 0;
              final voiture = limits.maxVehiclesByType?['voiture'] ?? 0;
              if (moto > 0 && voiture > 0) {
                garageValue = '${limits.maxVehiclesTotal} véhicules\n($moto moto + $voiture voiture)';
              } else {
                garageValue = '${limits.maxVehiclesTotal} véhicules';
              }
            }
            
            // Groupes privés
            // Vérifier explicitement si la valeur est définie (y compris 0)
            final maxPrivateGroups = limits.maxPrivateGroupsCreated;
            if (maxPrivateGroups != null) {
              groupesValue = '$maxPrivateGroups';
            }
            
            // Balades privées
            if (limits.maxPrivateRidesCreatedPerMonth != null) {
              baladesValue = '${limits.maxPrivateRidesCreatedPerMonth}/mois';
            }
          }
          
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icône Premium
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Titre
                  Text(
                    'Passe en Premium',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Raison
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Tableau comparatif Standard vs Premium
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // En-tête
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Fonctionnalité',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Standard',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Premium',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // Garage
                        _ComparisonRow(
                          feature: 'Garage',
                          freeValue: garageValue,
                          premiumValue: 'Illimité',
                          isPremium: true,
                        ),
                        const SizedBox(height: 12),
                        // Groupes privés
                        _ComparisonRow(
                          feature: 'Groupes privés',
                          freeValue: groupesValue,
                          premiumValue: 'Illimité',
                          isPremium: true,
                        ),
                        const SizedBox(height: 12),
                        // Balades privées
                        _ComparisonRow(
                          feature: 'Balades privées',
                          freeValue: baladesValue,
                          premiumValue: 'Illimité',
                          isPremium: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Le callback sera appelé automatiquement via .then() quand la modale est fermée
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Plus tard',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PremiumScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Voir Premium',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).then((_) {
    // Appeler le callback quand la modale est fermée (peu importe comment : bouton, barrier, etc.)
    onDismiss?.call();
  });
}

/// Widget pour une ligne du tableau comparatif
class _ComparisonRow extends StatelessWidget {
  final String feature;
  final String freeValue;
  final String premiumValue;
  final bool isPremium;

  const _ComparisonRow({
    required this.feature,
    required this.freeValue,
    required this.premiumValue,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            feature,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            freeValue,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPremium)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
              if (isPremium) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  premiumValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

