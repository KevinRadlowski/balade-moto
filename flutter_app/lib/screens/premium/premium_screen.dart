import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/plan_provider.dart';
import '../../models/plan/user_plan.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    // Rafraîchir le plan à l'ouverture pour avoir les données à jour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final planProvider = context.read<PlanProvider>();
        // Toujours rafraîchir pour avoir les données les plus récentes
        planProvider.loadPlan(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        elevation: 0,
      ),
      body: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          // Afficher un loader si le plan est en cours de chargement
          if (planProvider.isLoading && planProvider.plan == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final plan = planProvider.plan;
          final isPremium = planProvider.isPremium;
          final isFree = plan == null || plan.isFree;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan actuel
                _buildCurrentPlanCard(plan, isPremium),
                const SizedBox(height: 24),

                // Jauges (toujours affichées, avec "Illimité" pour Premium)
                _buildUsageGauges(plan, planProvider),
                const SizedBox(height: 24),

                // Tableau comparatif
                _buildComparisonTable(context, plan),
                const SizedBox(height: 24),

                // Section "Ce que tu débloques avec Premium"
                _buildPremiumFeaturesSection(context),
                const SizedBox(height: 24),

                // Bouton CTA
                if (isFree) _buildCtaButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Carte affichant le plan actuel
  Widget _buildCurrentPlanCard(UserPlan? plan, bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPremium
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.workspace_premium : Icons.account_circle,
                color: isPremium
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'Plan Premium' : 'Plan Standard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isPremium
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade700,
                      ),
                    ),
                    if (isPremium && plan?.premiumExpiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expire le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(plan!.premiumExpiresAt!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Jauges d'utilisation (affichées pour tous les plans, avec "Illimité" pour Premium)
  Widget _buildUsageGauges(UserPlan? plan, PlanProvider planProvider) {
    if (plan == null) {
      return const SizedBox.shrink();
    }

    final usage = plan.usage;
    final limits = plan.limits;
    final isUnlimited = plan.unlimited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre utilisation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Véhicules (total) - Toujours afficher
        _buildGauge(
          label: 'Véhicules',
          current: usage.vehiclesTotal,
          limit: limits?.maxVehiclesTotal,
          unlimited: isUnlimited,
          subtitle: '${usage.vehiclesByType['moto'] ?? 0} moto(s), ${usage.vehiclesByType['voiture'] ?? 0} voiture(s)',
        ),
        const SizedBox(height: 16),

        // Photos - Toujours afficher
        _buildGauge(
          label: 'Photos',
          current: usage.photosTotal,
          limit: limits?.maxPhotosTotal,
          unlimited: isUnlimited,
          subtitle: 'Total',
        ),
        const SizedBox(height: 16),

        // Groupes privés - Toujours afficher
        _buildGauge(
          label: 'Groupes privés créés',
          current: usage.privateGroupsCreated,
          limit: limits?.maxPrivateGroupsCreated,
          unlimited: isUnlimited,
        ),
        const SizedBox(height: 16),

        // Balades privées ce mois - Toujours afficher
        _buildGauge(
          label: 'Balades privées ce mois',
          current: usage.privateRidesCreatedThisMonth,
          limit: limits?.maxPrivateRidesCreatedPerMonth,
          unlimited: isUnlimited,
        ),
      ],
    );
  }

  /// Widget pour une jauge individuelle
  Widget _buildGauge({
    required String label,
    required int current,
    int? limit,
    required bool unlimited,
    String? subtitle,
  }) {
    // Pour Premium (unlimited), on n'affiche pas de barre de progression
    final effectiveLimit = limit;
    final hasLimit = !unlimited && effectiveLimit != null && effectiveLimit > 0;
    // ignore: unnecessary_null_comparison
    final progress = hasLimit && effectiveLimit != null
        ? (current / effectiveLimit).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                unlimited
                    ? 'Illimité'
                    : hasLimit
                        ? '$current / $limit'
                        : '$current',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: unlimited
                      ? Theme.of(context).primaryColor
                      : hasLimit && progress >= 1.0
                          ? Colors.red
                          : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          // Afficher la barre de progression uniquement si on a une limite (Standard)
          if (hasLimit) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? Colors.red
                    : progress >= 0.8
                        ? Colors.orange
                        : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
  }

  /// Tableau comparatif Free vs Premium
  Widget _buildComparisonTable(BuildContext context, UserPlan? plan) {
    // Si le plan n'est pas chargé, afficher un skeleton
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skeleton pour le titre
            Container(
              height: 20,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            // Skeleton pour les lignes
            ...List.generate(3, (index) => Padding(
              padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 16,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 16,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      );
    }

    final isPremium = plan.unlimited || plan.isPremium;

    // Limites Standard (hardcodées, toujours les mêmes)
    // Ces valeurs correspondent à FREE_LIMITS dans src/config/premium.config.js
    const standardLimits = {
      'maxVehiclesTotal': 2,
      'maxVehiclesByType': {'moto': 1, 'voiture': 1},
      'maxPrivateGroupsCreated': 1,
      'maxPrivateRidesCreatedPerMonth': 2,
    };

    // Formater la valeur du garage pour Standard
    // Toujours afficher les limites Standard, même si l'utilisateur est Premium
    String formatGarageStandard() {
      final total = standardLimits['maxVehiclesTotal'] as int;
      final moto = (standardLimits['maxVehiclesByType'] as Map)['moto'] as int;
      final voiture = (standardLimits['maxVehiclesByType'] as Map)['voiture'] as int;
      
      // Construire le texte : "2 véhicules (1 moto + 1 voiture)"
      String result = '$total véhicule${total > 1 ? 's' : ''}';
      
      // Ajouter les détails par type
      final parts = <String>[];
      if (moto > 0) {
        parts.add('$moto moto${moto > 1 ? 's' : ''}');
      }
      if (voiture > 0) {
        parts.add('$voiture voiture${voiture > 1 ? 's' : ''}');
      }
      if (parts.isNotEmpty) {
        result += ' (${parts.join(' + ')})';
      }
      
      return result;
    }

    // Formater la valeur des groupes privés pour Standard
    String formatPrivateGroupsStandard() {
      final count = standardLimits['maxPrivateGroupsCreated'] as int;
      return '$count';
    }

    // Formater la valeur des balades privées pour Standard
    String formatPrivateRidesStandard() {
      final count = standardLimits['maxPrivateRidesCreatedPerMonth'] as int;
      return '$count/mois';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparaison des plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          // En-tête
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fonctionnalité',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
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
              SizedBox(
                width: 100,
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
            freeValue: formatGarageStandard(),
            premiumValue: 'Illimité',
            isPremium: isPremium,
          ),
          const SizedBox(height: 12),
          // Groupes privés (création)
          _ComparisonRow(
            feature: 'Groupes privés (création)',
            freeValue: formatPrivateGroupsStandard(),
            premiumValue: 'Illimité',
            isPremium: isPremium,
          ),
          const SizedBox(height: 12),
          // Balades privées (création)
          _ComparisonRow(
            feature: 'Balades privées (création)',
            freeValue: formatPrivateRidesStandard(),
            premiumValue: 'Illimité',
            isPremium: isPremium,
          ),
          const SizedBox(height: 16),
          // Texte explicatif
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Les limites Standard concernent la création. Tu peux rejoindre autant de groupes et balades privés que tu veux si tu es invité.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Section "Ce que tu débloques avec Premium"
  Widget _buildPremiumFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ce que tu débloques avec Premium',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        // Confort & visibilité
        _PremiumFeatureExpansionTile(
          title: 'Confort & visibilité',
          icon: Icons.visibility,
          items: [
            _PremiumFeatureItem(
              title: 'Badge "Organisateur Premium"',
              description: 'Mets en avant ton statut Premium',
              icon: Icons.workspace_premium,
            ),
            _PremiumFeatureItem(
              title: 'Mise en avant des balades Premium',
              description: 'Tes balades apparaissent en premier dans les listes',
              icon: Icons.star,
            ),
            _PremiumFeatureItem(
              title: 'Priorité dans les suggestions locales',
              description: 'Tes balades sont suggérées en priorité aux utilisateurs locaux',
              icon: Icons.location_on,
            ),
            _PremiumFeatureItem(
              title: 'Historique illimité',
              description: 'Conserve l\'historique de toutes tes balades (Standard : 3 mois)',
              icon: Icons.history,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Outils organisateur
        _PremiumFeatureExpansionTile(
          title: 'Outils organisateur',
          icon: Icons.tune,
          items: [
            _PremiumFeatureItem(
              title: 'Validation manuelle des participants',
              description: 'Approuve ou refuse les demandes d\'inscription',
              icon: Icons.how_to_reg,
            ),
            _PremiumFeatureItem(
              title: 'Liste d\'attente',
              description: 'Gère automatiquement les participants en attente',
              icon: Icons.queue,
            ),
            _PremiumFeatureItem(
              title: 'Limite de participants + gestion automatique',
              description: 'Définis une limite et laisse le système gérer les inscriptions',
              icon: Icons.people_outline,
            ),
            _PremiumFeatureItem(
              title: 'Message automatique avant la balade',
              description: 'Envoie un rappel automatique aux participants',
              icon: Icons.notifications_active,
            ),
            _PremiumFeatureItem(
              title: 'Balades récurrentes',
              description: 'Crée des balades hebdomadaires ou mensuelles automatiques',
              icon: Icons.repeat,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Fonctions avancées
        _PremiumFeatureExpansionTile(
          title: 'Fonctions avancées',
          icon: Icons.settings,
          items: [
            _PremiumFeatureItem(
              title: 'Export GPX',
              description: 'Télécharge le tracé de tes balades au format GPX',
              icon: Icons.map,
            ),
            _PremiumFeatureItem(
              title: 'Export PDF',
              description: 'Génère un PDF détaillé de tes balades',
              icon: Icons.picture_as_pdf,
            ),
            _PremiumFeatureItem(
              title: 'Partage externe',
              description: 'Partage tes balades sur WhatsApp, Maps et autres apps',
              icon: Icons.share,
            ),
            _PremiumFeatureItem(
              title: 'Mode "balade privée secrète"',
              description: 'Crée des balades invisibles, accessibles uniquement par lien',
              icon: Icons.lock,
            ),
          ],
        ),
      ],
    );
  }

  /// Bouton CTA pour passer en Premium
  Widget _buildCtaButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement bientôt disponible'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Passer en Premium – 3,99€/mois',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Widget ExpansionTile pour une catégorie de fonctionnalités Premium
class _PremiumFeatureExpansionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_PremiumFeatureItem> items;

  const _PremiumFeatureExpansionTile({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          children: items,
        ),
      ),
    );
  }
}

/// Widget pour un item de fonctionnalité Premium
class _PremiumFeatureItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PremiumFeatureItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            feature,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            freeValue,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

