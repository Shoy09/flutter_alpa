// models/TipoLabor.dart
class TipoLabor {
  int? id;
  String nombre;
  String? proceso;

  TipoLabor({
    this.id,
    required this.nombre,
    this.proceso,
  });

  // Convertir de JSON a objeto
  factory TipoLabor.fromJson(Map<String, dynamic> json) {
    return TipoLabor(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      proceso: json['proceso'],
    );
  }

  // Convertir a Map para insertar en la BD local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'proceso': proceso,
    };
  }

  // Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'proceso': proceso,
    };
  }

  // Copiar con cambios
  TipoLabor copyWith({
    int? id,
    String? nombre,
    String? proceso,
  }) {
    return TipoLabor(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      proceso: proceso ?? this.proceso,
    );
  }

  @override
  String toString() {
    return 'TipoLabor{id: $id, nombre: $nombre, proceso: $proceso}';
  }
}