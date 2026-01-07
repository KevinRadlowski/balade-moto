class Achievement {
  final String id;
  final String userId;
  final String type; // Type de badge: first_ride, ten_rides, etc.
  final String name;
  final String description;
  final int progress;
  final int target;
  final DateTime? earnedAt;

  Achievement({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.description,
    required this.progress,
    required this.target,
    this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['_id'] ?? json['userId']['id'] ?? '').toString()
          : json['userId']?.toString() ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      progress: json['progress'] ?? 0,
      target: json['target'] ?? 0,
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'progress': progress,
      'target': target,
      if (earnedAt != null) 'earnedAt': earnedAt!.toIso8601String(),
    };
  }

  bool get isEarned => earnedAt != null;
  
  double get progressPercentage {
    if (target == 0) return 0.0;
    return (progress / target * 100).clamp(0.0, 100.0);
  }
}






