class ReferencePoint {
  final String id;
  final String name;
  final String photoPath;
  final DateTime createdAt;

  ReferencePoint({
    required this.id,
    required this.name,
    required this.photoPath,
    required this.createdAt,
  });

  ReferencePoint copyWith({
    String? id,
    String? name,
    String? photoPath,
    DateTime? createdAt,
  }) {
    return ReferencePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoPath': photoPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReferencePoint.fromJson(Map<String, dynamic> json) {
    return ReferencePoint(
      id: json['id'] as String,
      name: json['name'] as String,
      photoPath: json['photoPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoPath': photoPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReferencePoint.fromMap(Map<String, dynamic> map) {
    return ReferencePoint(
      id: map['id'] as String,
      name: map['name'] as String,
      photoPath: map['photoPath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
