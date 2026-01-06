class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? pseudo;
  final String? vehiclePreference;
  final String role;
  final List<String> roles;
  final bool emailVerified;
  final String? phone; // Rétrocompatibilité
  final String? phoneE164; // Nouveau champ obligatoire
  final bool phoneVerified;
  final bool isTwoFactorEnabled;
  final String? twoFactorMethod;
  final String? avatarUrl;
  final Map<String, String?>? customBackgrounds;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.pseudo,
    this.vehiclePreference,
    required this.role,
    required this.roles,
    required this.emailVerified,
    this.phone,
    this.phoneE164,
    this.phoneVerified = false,
    required this.isTwoFactorEnabled,
    this.twoFactorMethod,
    this.avatarUrl,
    this.customBackgrounds,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      pseudo: json['pseudo'],
      vehiclePreference: json['vehiclePreference'],
      role: json['role'] ?? 'MEMBER',
      roles: json['roles'] != null ? List<String>.from(json['roles']) : ['MEMBER'],
      emailVerified: json['emailVerified'] ?? false,
      phone: json['phone'] ?? json['phoneE164'], // Rétrocompatibilité
      phoneE164: json['phoneE164'] ?? json['phone'], // Utiliser phoneE164 en priorité
      phoneVerified: json['phoneVerified'] ?? false,
      isTwoFactorEnabled: json['isTwoFactorEnabled'] ?? false,
      twoFactorMethod: json['twoFactorMethod'],
      avatarUrl: json['avatarUrl'],
      customBackgrounds: json['customBackgrounds'] != null
          ? Map<String, String?>.from(json['customBackgrounds'])
          : null,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (pseudo != null) {
      return pseudo!;
    }
    return email;
  }
}

