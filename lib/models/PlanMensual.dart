class PlanMensual {
  int? id;
  int anio;
  String mes;
  String minadoTipo;
  String empresa;
  String zona;
  String area;
  String tipoMineral;
  String fase;
  String estructuraVeta;
  String nivel;
  String tipoLabor;
  String labor;
  String ala;
  double avanceM;
  double anchoM;
  double altoM;
  double tms;
  Map<String, dynamic> columnas; // Ahora acepta texto y números

  PlanMensual({
    this.id,
    required this.anio,
    required this.mes,
    required this.minadoTipo,
    required this.empresa,
    required this.zona,
    required this.area,
    required this.tipoMineral,
    required this.fase,
    required this.estructuraVeta,
    required this.nivel,
    required this.tipoLabor,
    required this.labor,
    required this.ala,
    required this.avanceM,
    required this.anchoM,
    required this.altoM,
    required this.tms,
    required this.columnas,
  });

factory PlanMensual.fromJson(Map<String, dynamic> json) {
  return PlanMensual(
    id: json['id'],
    anio: json['anio'] ?? 0, // Valor por defecto si es null
    mes: json['mes'] ?? '', // Valor por defecto si es null
    minadoTipo: json['minado_tipo'] ?? '',
    empresa: json['empresa'] ?? '',
    zona: json['zona'] ?? '',
    area: json['area'] ?? '',
    tipoMineral: json['tipo_mineral'] ?? '',
    fase: json['fase'] ?? '',
    estructuraVeta: json['estructura_veta'] ?? '',
    nivel: json['nivel'] ?? '',
    tipoLabor: json['tipo_labor'] ?? '',
    labor: json['labor'] ?? '',
    ala: json['ala'] ?? '',
    avanceM: (json['avance_m'] is num) ? json['avance_m'].toDouble() : 0.0,
    anchoM: (json['ancho_m'] is num) ? json['ancho_m'].toDouble() : 0.0,
    altoM: (json['alto_m'] is num) ? json['alto_m'].toDouble() : 0.0,
    tms: (json['tms'] is num) ? json['tms'].toDouble() : 0.0,
    columnas: {
      for (int i = 1; i <= 28; i++)
        'col_${i}A': json['col_${i}A'] ?? '', // Valor por defecto
      for (int i = 1; i <= 28; i++)
        'col_${i}B': json['col_${i}B'] ?? '', // Valor por defecto
    },
  );
}

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'anio': anio,
      'mes': mes,
      'minado_tipo': minadoTipo,
      'empresa': empresa,
      'zona': zona,
      'area': area,
      'tipo_mineral': tipoMineral,
      'fase': fase,
      'estructura_veta': estructuraVeta,
      'nivel': nivel,
      'tipo_labor': tipoLabor,
      'labor': labor,
      'ala': ala,
      'avance_m': avanceM,
      'ancho_m': anchoM,
      'alto_m': altoM,
      'tms': tms,
      ...columnas, // Se añaden todas las columnas dinámicas
    };
  }
}
