class CatalogMake {
  final String id;
  final String name;

  CatalogMake({
    required this.id,
    required this.name,
  });

  factory CatalogMake.fromJson(Map<String, dynamic> json) {
    // Accepter id comme int ou String
    final idValue = json['id'] ?? json['makeId'];
    final idString = idValue is String
        ? idValue
        : idValue is int
            ? idValue.toString()
            : idValue?.toString() ?? '';
    
    // Accepter différents noms de clés pour name
    final nameValue = json['name'] ?? 
        json['makeName'] ?? 
        json['make_name'] ?? 
        json['make_display'] ?? 
        json['make'] ?? 
        '';
    
    return CatalogMake(
      id: idString,
      name: nameValue is String ? nameValue : nameValue.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogMake &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}














