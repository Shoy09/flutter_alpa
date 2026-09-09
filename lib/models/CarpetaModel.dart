class CarpetaModel {
  final int id;
  final String nombre;
  final DateTime createdAt;
  final DateTime updatedAt;

  CarpetaModel({
    required this.id,
    required this.nombre,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CarpetaModel.fromJson(Map<String, dynamic> json) {
    return CarpetaModel(
      id: json['id'],
      nombre: json['nombre'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  factory CarpetaModel.fromMap(Map<String, dynamic> map) {
    return CarpetaModel(
      id: map['id'],
      nombre: map['nombre'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
