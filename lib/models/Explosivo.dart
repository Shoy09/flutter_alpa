class Explosivo {
  int? id;
  String tipoExplosivo;
  int cantidadPorCaja;
  double pesoUnitario;
  double costoPorKg;
  String unidadMedida; // Nuevo campo

  Explosivo({
    this.id,
    required this.tipoExplosivo,
    required this.cantidadPorCaja,
    required this.pesoUnitario,
    required this.costoPorKg,
    required this.unidadMedida, // Requerido
  });

  // Convertir de JSON a Objeto
  factory Explosivo.fromJson(Map<String, dynamic> json) {
    return Explosivo(
      id: json['id'],
      tipoExplosivo: json['tipo_explosivo'],
      cantidadPorCaja: json['cantidad_por_caja'],
      pesoUnitario: json['peso_unitario'].toDouble(),
      costoPorKg: json['costo_por_kg'].toDouble(),
      unidadMedida: json['unidad_medida'], // Nuevo campo
    );
  }

  // Convertir de Objeto a Map (para BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_explosivo': tipoExplosivo,
      'cantidad_por_caja': cantidadPorCaja,
      'peso_unitario': pesoUnitario,
      'costo_por_kg': costoPorKg,
      'unidad_medida': unidadMedida, // Nuevo campo
    };
  }
}
