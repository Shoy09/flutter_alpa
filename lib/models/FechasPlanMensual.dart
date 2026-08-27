class FechasPlanMensual {
  final int id; 
  final String mes;
  final int? fechaIngreso; // Opcional

  FechasPlanMensual({
    required this.id,
    required this.mes,
    this.fechaIngreso,
  });

  // Convertir de JSON a objeto Dart
  factory FechasPlanMensual.fromJson(Map<String, dynamic> json) {
    return FechasPlanMensual(
      id: json['id'],
      mes: json['mes'],
      fechaIngreso: json['fecha_ingreso'], // Opcional
    );
  }

  // Convertir objeto Dart a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mes': mes,
      if (fechaIngreso != null) 'fecha_ingreso': fechaIngreso,
    };
  }
}
