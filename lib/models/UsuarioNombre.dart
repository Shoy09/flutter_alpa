// models/UsuarioNombre.dart
class UsuarioNombre {
  final int id;          // ID local
  final int usuarioId;   // ID del usuario en backend
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String createdAt;
  final String updatedAt;

  UsuarioNombre({
    required this.id,
    required this.usuarioId,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UsuarioNombre.fromJson(Map<String, dynamic> json) {
    return UsuarioNombre(
      id: json['id'] ?? 0,
      usuarioId: json['usuario_id'] ?? 0,
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      nombreCompleto: json['nombreCompleto'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario_id': usuarioId,
      'nombres': nombres,
      'apellidos': apellidos,
      'nombre_completo': nombreCompleto,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}