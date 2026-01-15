class AdminGeneratePromoCodesRequest {
  final String type; // 'DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'
  final int count;
  final int? discountPercent;
  final int? premiumMonths;
  final int? usageLimit;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final Map<String, dynamic>? metadata;

  AdminGeneratePromoCodesRequest({
    required this.type,
    required this.count,
    this.discountPercent,
    this.premiumMonths,
    this.usageLimit,
    this.validFrom,
    this.validUntil,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'count': count,
    };

    if (discountPercent != null) {
      json['discountPercent'] = discountPercent;
    }
    if (premiumMonths != null) {
      json['premiumMonths'] = premiumMonths;
    }
    if (usageLimit != null) {
      json['usageLimit'] = usageLimit;
    }
    if (validFrom != null) {
      json['validFrom'] = validFrom!.toIso8601String();
    }
    if (validUntil != null) {
      json['validUntil'] = validUntil!.toIso8601String();
    }
    if (metadata != null) {
      json['metadata'] = metadata;
    }

    return json;
  }
}

class GeneratedPromoCode {
  final String id;
  final String code;
  final String prefix;

  GeneratedPromoCode({
    required this.id,
    required this.code,
    required this.prefix,
  });

  factory GeneratedPromoCode.fromJson(Map<String, dynamic> json) {
    return GeneratedPromoCode(
      id: json['id'] ?? json['_id'] ?? '',
      code: json['code'] ?? '',
      prefix: json['prefix'] ?? '',
    );
  }
}

class PromoCodeListItem {
  final String id;
  final String codePrefix;
  final String type; // 'DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'
  final bool isActive;
  final int usedCount;
  final int usageLimit;
  final DateTime? validUntil;
  final int? discountPercent;
  final int? premiumMonths;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PromoCodeListItem({
    required this.id,
    required this.codePrefix,
    required this.type,
    required this.isActive,
    required this.usedCount,
    required this.usageLimit,
    this.validUntil,
    this.discountPercent,
    this.premiumMonths,
    this.createdAt,
    this.updatedAt,
  });

  factory PromoCodeListItem.fromJson(Map<String, dynamic> json) {
    return PromoCodeListItem(
      id: json['_id'] ?? json['id'] ?? '',
      codePrefix: json['codePrefix'] ?? '',
      type: json['type'] ?? '',
      isActive: json['isActive'] ?? true,
      usedCount: json['usedCount'] ?? 0,
      usageLimit: json['usageLimit'] ?? 1,
      validUntil: json['validUntil'] != null
          ? DateTime.parse(json['validUntil'])
          : null,
      discountPercent: json['discountPercent'],
      premiumMonths: json['premiumMonths'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'DISCOUNT_PERCENT':
        return 'Réduction ${discountPercent ?? 0}%';
      case 'GRANT_PREMIUM_MONTHS':
        return 'Premium ${premiumMonths ?? 0} mois';
      case 'GRANT_PREMIUM_PERMANENT':
        return 'Premium illimité';
      default:
        return type;
    }
  }
}

class PromoCodesPage {
  final List<PromoCodeListItem> items;
  final int total;

  PromoCodesPage({
    required this.items,
    required this.total,
  });

  factory PromoCodesPage.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((item) => PromoCodeListItem.fromJson(item))
            .toList() ??
        [];

    return PromoCodesPage(
      items: itemsList,
      total: json['total'] ?? 0,
    );
  }
}







