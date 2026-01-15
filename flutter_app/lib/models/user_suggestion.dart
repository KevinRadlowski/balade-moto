/// Modèle pour les suggestions d'utilisateurs (mentions)
class UserSuggestion {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  UserSuggestion({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory UserSuggestion.fromJson(Map<String, dynamic> json) {
    return UserSuggestion(
      userId: json['userId'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }
}

