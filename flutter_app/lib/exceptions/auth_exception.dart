/// Exception personnalisée pour les erreurs d'authentification
/// Permet de gérer les erreurs de manière structurée avec un code et un message
class AuthException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  AuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;

  /// Codes d'erreur possibles
  static const String emailNotVerified = 'EMAIL_NOT_VERIFIED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String accountLocked = 'ACCOUNT_LOCKED';
  static const String accountBanned = 'ACCOUNT_BANNED';
  static const String twoFactorRequired = 'TWO_FACTOR_REQUIRED';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String unknown = 'UNKNOWN';
}





