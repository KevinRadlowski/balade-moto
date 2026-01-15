/// Helper pour le formatage des dates et durées
class DateHelper {
  /// Formate une durée en texte lisible (ex: "il y a 5 min", "il y a 2 h")
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return 'il y a ${(difference.inDays / 7).floor()} semaine${(difference.inDays / 7).floor() > 1 ? 's' : ''}';
    }
  }
}















