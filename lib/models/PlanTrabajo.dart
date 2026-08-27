class PlanTrabajo {
  final String zona;
  final String tipoLabor;
  final String labor;
  final String ala;
  final String estructuraVeta;
  final String nivel;
  final String? empresa; // Hacerlo nullable
 final double? ancho; // Cambiado a double
  final double? alto; 

  PlanTrabajo({
    required this.zona,
    required this.tipoLabor,
    required this.labor,
    required this.ala,
    required this.estructuraVeta,
    required this.nivel,
    this.empresa,
    this.alto, 
    this.ancho,
  });

  // Método para convertir desde un mapa (por ejemplo, si se obtiene de JSON)
  factory PlanTrabajo.fromJson(Map<String, dynamic> json) {
    return PlanTrabajo(
      zona: json['zona'] ?? '',
      tipoLabor: json['tipoLabor'] ?? '',
      labor: json['labor'] ?? '',
      ala: json['ala'] ?? '',
      estructuraVeta: json['estructuraVeta'] ?? '',
      nivel: json['nivel'] ?? '',
    );
  }

  // Método para convertir a un mapa (por ejemplo, si se quiere enviar como JSON)
  Map<String, dynamic> toJson() {
    return {
      'zona': zona,
      'tipoLabor': tipoLabor,
      'labor': labor,
      'ala': ala,
      'estructuraVeta': estructuraVeta,
      'nivel': nivel,
    };
  }
}
