class VpicMake {
  final String makeId;
  final String makeName;

  VpicMake({
    required this.makeId,
    required this.makeName,
  });

  factory VpicMake.fromJson(Map<String, dynamic> json) {
    // Accepter makeId comme int ou String
    final makeIdValue = json['makeId'];
    final makeIdString = makeIdValue is String
        ? makeIdValue
        : makeIdValue is int
            ? makeIdValue.toString()
            : makeIdValue?.toString() ?? '';
    
    // Accepter différents noms de clés pour makeName
    final makeNameValue = json['makeName'] ?? 
        json['make_name'] ?? 
        json['make_display'] ?? 
        json['make'] ?? 
        '';
    
    return VpicMake(
      makeId: makeIdString,
      makeName: makeNameValue is String ? makeNameValue : makeNameValue.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'makeId': makeId,
      'makeName': makeName,
    };
  }

  @override
  String toString() => makeName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpicMake &&
          runtimeType == other.runtimeType &&
          makeId == other.makeId;

  @override
  int get hashCode => makeId.hashCode;
}

