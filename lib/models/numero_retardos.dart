class NumeroRetardos {
  final int? id;
  final String mes;
  final int anio;
  final int cantidad;

  NumeroRetardos({
    this.id,
    required this.mes,
    required this.anio,
    required this.cantidad,
  });

  factory NumeroRetardos.fromJson(Map<String, dynamic> json) {
    return NumeroRetardos(
      id: json['id'],
      mes: json['mes'],
      anio: json['anio'],
      cantidad: json['cantidad'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mes': mes,
      'anio': anio,
      'cantidad': cantidad,
    };
  }
}