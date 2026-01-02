class VpicModel {
  final String modelId;
  final String modelName;
  final String makeId;
  final String makeName;

  VpicModel({
    required this.modelId,
    required this.modelName,
    required this.makeId,
    required this.makeName,
  });

  factory VpicModel.fromJson(Map<String, dynamic> json) {
    // Accepter modelId comme int ou String
    final modelIdValue = json['modelId'];
    final modelIdString = modelIdValue is String
        ? modelIdValue
        : modelIdValue is int
            ? modelIdValue.toString()
            : modelIdValue?.toString() ?? '';
    
    // Accepter makeId comme int ou String
    final makeIdValue = json['makeId'];
    final makeIdString = makeIdValue is String
        ? makeIdValue
        : makeIdValue is int
            ? makeIdValue.toString()
            : makeIdValue?.toString() ?? '';
    
    // Accepter différents noms de clés pour modelName
    final modelNameValue = json['modelName'] ?? 
        json['model_name'] ?? 
        json['model_display'] ?? 
        json['model'] ?? 
        json['model_make_display'] ?? 
        '';
    
    // Accepter différents noms de clés pour makeName
    final makeNameValue = json['makeName'] ?? 
        json['make_name'] ?? 
        json['make_display'] ?? 
        json['make'] ?? 
        '';
    
    return VpicModel(
      modelId: modelIdString,
      modelName: modelNameValue is String ? modelNameValue : modelNameValue.toString(),
      makeId: makeIdString,
      makeName: makeNameValue is String ? makeNameValue : makeNameValue.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelId': modelId,
      'modelName': modelName,
      'makeId': makeId,
      'makeName': makeName,
    };
  }

  @override
  String toString() => modelName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpicModel &&
          runtimeType == other.runtimeType &&
          modelId == other.modelId;

  @override
  int get hashCode => modelId.hashCode;
}

