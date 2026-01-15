class Reputation {
  final String id;
  final String userId;
  final int score; // Score de réputation (0-100)
  final int rideCount;
  final int punctualityScore; // Score de ponctualité (0-100)
  final double cancellationRate; // Taux d'annulation (0-1)
  final int feedbackCount;
  final String level; // bronze, silver, gold, platinum

  Reputation({
    required this.id,
    required this.userId,
    required this.score,
    required this.rideCount,
    required this.punctualityScore,
    required this.cancellationRate,
    required this.feedbackCount,
    required this.level,
  });

  factory Reputation.fromJson(Map<String, dynamic> json) {
    return Reputation(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['_id'] ?? json['userId']['id'] ?? '').toString()
          : json['userId']?.toString() ?? '',
      score: json['score'] ?? 0,
      rideCount: json['rideCount'] ?? 0,
      punctualityScore: json['punctualityScore'] ?? 50,
      cancellationRate: (json['cancellationRate'] ?? 0).toDouble(),
      feedbackCount: json['feedbackCount'] ?? 0,
      level: json['level'] ?? 'bronze',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'rideCount': rideCount,
      'punctualityScore': punctualityScore,
      'cancellationRate': cancellationRate,
      'feedbackCount': feedbackCount,
      'level': level,
    };
  }

  String get levelDisplayName {
    switch (level) {
      case 'bronze':
        return 'Bronze';
      case 'silver':
        return 'Argent';
      case 'gold':
        return 'Or';
      case 'platinum':
        return 'Platine';
      default:
        return 'Bronze';
    }
  }
}












