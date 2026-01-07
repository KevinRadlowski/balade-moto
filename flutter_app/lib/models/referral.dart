class ReferralInfo {
  final String referralCode;
  final String referralUrl;
  final int referralsCount;
  final int activeReferralsCount;
  final List<ReferralItem> referrals;
  final SubscriptionInfo subscription;

  ReferralInfo({
    required this.referralCode,
    required this.referralUrl,
    required this.referralsCount,
    required this.activeReferralsCount,
    required this.referrals,
    required this.subscription,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      referralCode: json['referralCode'] ?? '',
      referralUrl: json['referralUrl'] ?? '',
      referralsCount: json['referralsCount'] ?? 0,
      activeReferralsCount: json['activeReferralsCount'] ?? 0,
      referrals: (json['referrals'] as List<dynamic>?)
              ?.map((item) => ReferralItem.fromJson(item))
              .toList() ??
          [],
      subscription: SubscriptionInfo.fromJson(json['subscription'] ?? {}),
    );
  }
}

class ReferralItem {
  final String id;
  final ReferredUser? referredUser;
  final bool rewardGranted;
  final DateTime createdAt;

  ReferralItem({
    required this.id,
    this.referredUser,
    required this.rewardGranted,
    required this.createdAt,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: json['id'] ?? '',
      referredUser: json['referredUser'] != null
          ? ReferredUser.fromJson(json['referredUser'])
          : null,
      rewardGranted: json['rewardGranted'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class ReferredUser {
  final String id;
  final String pseudo;
  final String email;
  final DateTime createdAt;

  ReferredUser({
    required this.id,
    required this.pseudo,
    required this.email,
    required this.createdAt,
  });

  factory ReferredUser.fromJson(Map<String, dynamic> json) {
    return ReferredUser(
      id: json['_id'] ?? json['id'] ?? '',
      pseudo: json['pseudo'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class SubscriptionInfo {
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final String? premiumSource;

  SubscriptionInfo({
    required this.isPremium,
    this.premiumExpiresAt,
    this.premiumSource,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      isPremium: json['isPremium'] ?? false,
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? DateTime.parse(json['premiumExpiresAt'])
          : null,
      premiumSource: json['premiumSource'],
    );
  }
}
