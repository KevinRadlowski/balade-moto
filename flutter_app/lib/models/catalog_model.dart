class CatalogModel {
  final String id;
  final String name;
  final String makeName;

  CatalogModel({
    required this.id,
    required this.name,
    this.makeName = '',
  });

  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    // Accepter id comme int ou String
    final idValue = json['id'] ?? json['modelId'];
    final idString = idValue is String
        ? idValue
        : idValue is int
            ? idValue.toString()
            : idValue?.toString() ?? '';
    
    // Accepter différents noms de clés pour name
    final nameValue = json['name'] ?? 
        json['modelName'] ?? 
        json['model_name'] ?? 
        json['model_display'] ?? 
        json['model'] ?? 
        '';
    
    // Accepter makeName
    final makeNameValue = json['makeName'] ?? 
        json['make_name'] ?? 
        json['make'] ?? 
        '';
    
    return CatalogModel(
      id: idString,
      name: nameValue is String ? nameValue : nameValue.toString(),
      makeName: makeNameValue is String ? makeNameValue : makeNameValue.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'makeName': makeName,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}




