import 'package:flutter_test/flutter_test.dart';
import 'package:balades_moto/models/plan/user_plan.dart';
import 'package:balades_moto/models/plan/plan_limits.dart';
import 'package:balades_moto/models/plan/plan_usage.dart';

void main() {
  group('UserPlan Parsing', () {
    test('Parse FREE plan with limits', () {
      final json = {
        'plan': 'FREE',
        'isPremium': false,
        'premiumExpiresAt': null,
        'limits': {
          'unlimited': false,
          'vehiclesTotal': 2,
          'vehiclesMoto': 1,
          'vehiclesVoiture': 1,
          'privateGroupsTotal': 1,
          'privateRidesPerMonth': 3,
        },
        'usage': {
          'vehiclesTotal': 1,
          'vehiclesByType': {'moto': 1, 'voiture': 0},
          'photosTotal': 5,
          'privateGroupsCreated': 0,
          'privateRidesCreatedThisMonth': 1,
        },
      };

      final plan = UserPlan.fromJson(json);

      expect(plan.plan, PlanType.free);
      expect(plan.isPremium, false);
      expect(plan.premiumExpiresAt, isNull);
      expect(plan.isFree, true);
      expect(plan.unlimited, false);
      expect(plan.limits, isNotNull);
      expect(plan.usage.vehiclesTotal, 1);
    });

    test('Parse PREMIUM plan with unlimited', () {
      final json = {
        'plan': 'PREMIUM',
        'isPremium': true,
        'premiumExpiresAt': '2026-12-31T23:59:59.000Z',
        'limits': {
          'unlimited': true,
        },
        'usage': {
          'vehiclesTotal': 5,
          'vehiclesByType': {'moto': 3, 'voiture': 2},
          'photosTotal': 100,
          'privateGroupsCreated': 10,
          'privateRidesCreatedThisMonth': 50,
        },
      };

      final plan = UserPlan.fromJson(json);

      expect(plan.plan, PlanType.premium);
      expect(plan.isPremium, true);
      expect(plan.premiumExpiresAt, isNotNull);
      expect(plan.isFree, false);
      expect(plan.unlimited, true);
      expect(plan.isPremiumActive, true);
    });

    test('Parse with null values', () {
      final json = {
        'plan': 'FREE',
        'isPremium': false,
        'premiumExpiresAt': null,
        'limits': null,
        'usage': {},
      };

      final plan = UserPlan.fromJson(json);

      expect(plan.plan, PlanType.free);
      expect(plan.limits, isNull);
      expect(plan.usage.vehiclesTotal, 0);
      expect(plan.usage.privateRidesCreatedThisMonth, 0);
    });

    test('Parse with missing usage fields', () {
      final json = {
        'plan': 'FREE',
        'isPremium': false,
        'usage': {
          'vehiclesTotal': 1,
        },
      };

      final plan = UserPlan.fromJson(json);

      expect(plan.usage.vehiclesTotal, 1);
      expect(plan.usage.photosTotal, 0);
      expect(plan.usage.privateGroupsCreated, 0);
      expect(plan.usage.privateRidesCreatedThisMonth, 0);
    });
  });

  group('UserPlan Remaining Calculations', () {
    test('Calculate remaining private rides for FREE plan', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          privateRidesPerMonth: 3,
        ),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 1,
        ),
      );

      expect(plan.remainingPrivateRidesThisMonth, 2);
    });

    test('Calculate remaining private rides when limit reached', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          privateRidesPerMonth: 3,
        ),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 3,
        ),
      );

      expect(plan.remainingPrivateRidesThisMonth, 0);
    });

    test('Calculate remaining private rides for unlimited plan', () {
      final plan = UserPlan(
        plan: PlanType.premium,
        isPremium: true,
        limits: PlanLimits(unlimited: true),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 100,
        ),
      );

      expect(plan.remainingPrivateRidesThisMonth, 999999);
    });

    test('Calculate remaining private groups', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          privateGroupsTotal: 1,
        ),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      expect(plan.remainingPrivateGroups, 1);
    });

    test('Calculate remaining vehicles total', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          vehiclesTotal: 2,
        ),
        usage: PlanUsage(
          vehiclesTotal: 1,
          vehiclesByType: {'moto': 1, 'voiture': 0},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      expect(plan.remainingVehiclesTotal, 1);
    });

    test('Calculate remaining vehicles by type', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          vehiclesMoto: 1,
          vehiclesVoiture: 1,
        ),
        usage: PlanUsage(
          vehiclesTotal: 1,
          vehiclesByType: {'moto': 1, 'voiture': 0},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      expect(plan.remainingVehiclesMoto, 0);
      expect(plan.remainingVehiclesVoiture, 1);
    });

    test('Calculate remaining when no limits defined', () {
      final plan = UserPlan(
        plan: PlanType.free,
        isPremium: false,
        limits: PlanLimits(
          unlimited: false,
          // Pas de limites définies
        ),
        usage: PlanUsage(
          vehiclesTotal: 10,
          vehiclesByType: {'moto': 5, 'voiture': 5},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      // Si pas de limite définie, considéré comme illimité
      expect(plan.remainingVehiclesTotal, 999999);
      expect(plan.remainingVehiclesMoto, 999999);
      expect(plan.remainingVehiclesVoiture, 999999);
      expect(plan.remainingPrivateRidesThisMonth, 999999);
    });
  });

  group('UserPlan Premium Expiration', () {
    test('Check premium not expired', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final plan = UserPlan(
        plan: PlanType.premium,
        isPremium: true,
        premiumExpiresAt: futureDate,
        limits: PlanLimits(unlimited: true),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      expect(plan.isPremiumExpired, false);
      expect(plan.isPremiumActive, true);
    });

    test('Check premium expired', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final plan = UserPlan(
        plan: PlanType.premium,
        isPremium: true,
        premiumExpiresAt: pastDate,
        limits: PlanLimits(unlimited: true),
        usage: PlanUsage(
          vehiclesTotal: 0,
          vehiclesByType: {},
          photosTotal: 0,
          privateGroupsCreated: 0,
          privateRidesCreatedThisMonth: 0,
        ),
      );

      expect(plan.isPremiumExpired, true);
      expect(plan.isPremiumActive, false);
    });
  });
}



