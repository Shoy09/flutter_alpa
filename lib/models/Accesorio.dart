class Accesorio {
  int? id;
  String tipoAccesorio;
  double costo;
  String unidadMedida; // Nuevo campo

  Accesorio({
    this.id,
    required this.tipoAccesorio,
    required this.costo,
    required this.unidadMedida, // Requerido
  });

  // Convertir de JSON a Objeto
  factory Accesorio.fromJson(Map<String, dynamic> json) {
    return Accesorio(
      id: json['id'],
      tipoAccesorio: json['tipo_accesorio'],
      costo: json['costo'].toDouble(),
      unidadMedida: json['unidad_medida'], // Nuevo campo
    );
  }

  // Convertir de Objeto a Map (para BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_accesorio': tipoAccesorio,
      'costo': costo,
      'unidad_medida': unidadMedida, // Nuevo campo
    };
  }
}
