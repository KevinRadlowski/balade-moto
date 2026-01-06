class Compatibility {
  final double score;
  final CompatibilityFactors factors;
  final CompatibilitySuggestion? suggestion;

  Compatibility({
    required this.score,
    required this.factors,
    this.suggestion,
  });

  factory Compatibility.fromJson(Map<String, dynamic> json) {
    return Compatibility(
      score: (json['score'] ?? 0.0).toDouble(),
      factors: CompatibilityFactors.fromJson(json['factors'] ?? {}),
      suggestion: json['suggestion'] != null
          ? CompatibilitySuggestion.fromJson(json['suggestion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'factors': factors.toJson(),
      if (suggestion != null) 'suggestion': suggestion!.toJson(),
    };
  }
}

class CompatibilityFactors {
  final bool sameVehicleType;
  final bool sameRidingStyle;
  final double? reputationMatch;
  final bool? hasRiddenTogether;
  final int? commonGroups;

  CompatibilityFactors({
    required this.sameVehicleType,
    required this.sameRidingStyle,
    this.reputationMatch,
    this.hasRiddenTogether,
    this.commonGroups,
  });

  factory CompatibilityFactors.fromJson(Map<String, dynamic> json) {
    return CompatibilityFactors(
      sameVehicleType: json['sameVehicleType'] ?? false,
      sameRidingStyle: json['sameRidingStyle'] ?? false,
      reputationMatch: json['reputationMatch']?.toDouble(),
      hasRiddenTogether: json['hasRiddenTogether'],
      commonGroups: json['commonGroups'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sameVehicleType': sameVehicleType,
      'sameRidingStyle': sameRidingStyle,
      if (reputationMatch != null) 'reputationMatch': reputationMatch,
      if (hasRiddenTogether != null) 'hasRiddenTogether': hasRiddenTogether,
      if (commonGroups != null) 'commonGroups': commonGroups,
    };
  }
}

class CompatibilitySuggestion {
  final String level; // 'high', 'medium', 'low'
  final String message;

  CompatibilitySuggestion({
    required this.level,
    required this.message,
  });

  factory CompatibilitySuggestion.fromJson(Map<String, dynamic> json) {
    return CompatibilitySuggestion(
      level: json['level'] ?? 'medium',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'message': message,
    };
  }
}






