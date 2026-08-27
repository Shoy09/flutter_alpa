class TipoPerforacion {
  int? id;
  String nombre;
  String? proceso; // Campo opcional
  int permitidoMedicion; // Nuevo campo, no opcional (default 0 si no se pasa)

  TipoPerforacion({
    this.id,
    required this.nombre,
    this.proceso,
    this.permitidoMedicion = 0, // Valor por defecto 0
  });

  // Convertir de JSON a Objeto
  factory TipoPerforacion.fromJson(Map<String, dynamic> json) {
    return TipoPerforacion(
      id: json['id'],
      nombre: json['nombre'],
      proceso: json['proceso'],
      permitidoMedicion: json['permitido_medicion'] ?? 0, // Maneja null como 0
    );
  }

  // Convertir de Objeto a Map (para BD o API)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'proceso': proceso,
      'permitido_medicion': permitidoMedicion,
    };
  }
}
