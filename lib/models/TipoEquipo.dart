class TipoEquipo {
  int? id;
  String nombre;

  TipoEquipo({
    this.id,
    required this.nombre,
  });

  // Convertir de JSON a objeto
  factory TipoEquipo.fromJson(Map<String, dynamic> json) {
    return TipoEquipo(
      id: json['id'],
      nombre: json['nombre'],
    );
  }

  // Convertir a Map para insertar en la BD local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}