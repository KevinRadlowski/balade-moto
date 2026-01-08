/// Exception personnalisée pour les erreurs de renvoi d'email de vérification
/// Permet de transmettre le nombre de secondes à attendre (retryAfter)
class ResendEmailException implements Exception {
  final String message;
  final int? retryAfter;

  ResendEmailException({
    required this.message,
    this.retryAfter,
  });

  @override
  String toString() => message;
}










