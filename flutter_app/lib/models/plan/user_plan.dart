import 'plan_limits.dart';
import 'plan_usage.dart';

enum PlanType {
  free,
  premium;

  static PlanType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FREE':
        return PlanType.free;
      case 'PREMIUM':
        return PlanType.premium;
      default:
        return PlanType.free;
    }
  }

  String toJson() {
    return name.toUpperCase();
  }
}

class UserPlan {
  final PlanType plan;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final PlanLimits? limits;
  final PlanUsage usage;

  UserPlan({
    required this.plan,
    required this.isPremium,
    this.premiumExpiresAt,
    this.limits,
    required this.usage,
  });

  factory UserPlan.fromJson(Map<String, dynamic> json) {
    return UserPlan(
      plan: PlanType.fromString(json['plan'] as String?),
      isPremium: json['isPremium'] == true,
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? DateTime.parse(json['premiumExpiresAt'] as String)
          : null,
      limits: json['limits'] != null
          ? PlanLimits.fromJson(json['limits'] as Map<String, dynamic>)
          : null,
      usage: PlanUsage.fromJson(
        json['usage'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan.toJson(),
      'isPremium': isPremium,
      if (premiumExpiresAt != null)
        'premiumExpiresAt': premiumExpiresAt!.toIso8601String(),
      if (limits != null) 'limits': limits!.toJson(),
      'usage': usage.toJson(),
    };
  }

  /// Vérifie si le plan est gratuit
  bool get isFree => !isPremium || plan == PlanType.free;

  /// Vérifie si les limites sont illimitées
  bool get unlimited => limits?.unlimited ?? false;

  /// Calcule le nombre de balades privées restantes ce mois
  int get remainingPrivateRidesThisMonth {
    if (unlimited) {
      return 999999; // Très grand nombre pour représenter l'illimité
    }

    final limit = limits?.maxPrivateRidesCreatedPerMonth;
    if (limit == null) {
      return 999999; // Pas de limite définie = illimité
    }

    final used = usage.privateRidesCreatedThisMonth;
    return (limit - used).clamp(0, limit);
  }

  /// Calcule le nombre de groupes privés restants
  int get remainingPrivateGroups {
    if (unlimited) {
      return 999999;
    }

    final limit = limits?.maxPrivateGroupsCreated;
    if (limit == null) {
      return 999999;
    }

    final used = usage.privateGroupsCreated;
    return (limit - used).clamp(0, limit);
  }

  /// Calcule le nombre total de véhicules restants
  int get remainingVehiclesTotal {
    if (unlimited) {
      return 999999;
    }

    final limit = limits?.maxVehiclesTotal;
    if (limit == null) {
      return 999999;
    }

    final used = usage.vehiclesTotal;
    return (limit - used).clamp(0, limit);
  }

  /// Calcule le nombre de motos restantes
  int get remainingVehiclesMoto {
    if (unlimited) {
      return 999999;
    }

    final limit = limits?.vehiclesMoto;
    if (limit == null) {
      return 999999;
    }

    final used = usage.getVehiclesByType('moto');
    return (limit - used).clamp(0, limit);
  }

  /// Calcule le nombre de voitures restantes
  int get remainingVehiclesVoiture {
    if (unlimited) {
      return 999999;
    }

    final limit = limits?.vehiclesVoiture;
    if (limit == null) {
      return 999999;
    }

    final used = usage.getVehiclesByType('voiture');
    return (limit - used).clamp(0, limit);
  }

  /// Vérifie si le premium est expiré
  bool get isPremiumExpired {
    if (!isPremium || premiumExpiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(premiumExpiresAt!);
  }

  /// Vérifie si le premium est actif (non expiré)
  bool get isPremiumActive => isPremium && !isPremiumExpired;
}

