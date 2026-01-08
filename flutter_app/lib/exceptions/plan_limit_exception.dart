/// Exception levée lorsqu'une limite de plan est atteinte
class PlanLimitException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  PlanLimitException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Crée une exception depuis un JSON (typiquement depuis une réponse API)
  factory PlanLimitException.fromJson(Map<String, dynamic> json) {
    return PlanLimitException(
      code: json['code'] as String? ?? 'LIMIT_EXCEEDED',
      message: json['message'] as String? ?? 'Limite de plan atteinte',
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  /// Convertit l'exception en JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('PlanLimitException: $code - $message');
    if (details != null && details!.isNotEmpty) {
      buffer.write(' (details: $details)');
    }
    return buffer.toString();
  }
}



