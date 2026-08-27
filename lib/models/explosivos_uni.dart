class ExplosivosUni {
  final int id;
  final double dato;
  final String tipo; // Nuevo campo agregado

  ExplosivosUni({
    required this.id,
    required this.dato,
    required this.tipo, // Agregamos este campo en el constructor
  });

  factory ExplosivosUni.fromJson(Map<String, dynamic> json) {
    return ExplosivosUni(
      id: json['id'],
      dato: (json['dato'] as num).toDouble(), // Aseguramos que sea un double
      tipo: json['tipo'], // Cargamos el nuevo campo
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dato': dato,
      'tipo': tipo, // Incluimos el nuevo campo en la conversión a JSON
    };
  }
}
