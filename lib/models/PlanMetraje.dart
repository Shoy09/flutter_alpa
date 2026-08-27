class PlanMetraje {
  int? id;
  int? anio;
  String mes;
  String semana;
  String mina;
  String zona;
  String area;
  String fase;
  String minadoTipo;
  String tipoLabor;
  String tipoMineral;
  String estructuraVeta;
  String? nivel;
  String? block;
  String labor;
  String? ala;
  double? anchoVeta;
  double? anchoMinadoSem;
  double? anchoMinadoMes;
  double? burden;
  double? espaciamiento;
  double? longitudPerforacion;
  String programado;
  Map<String, dynamic> columnas;

  PlanMetraje({
    this.id,
    this.anio,
    required this.mes,
    required this.semana,
    required this.mina,
    required this.zona,
    required this.area,
    required this.fase,
    required this.minadoTipo,
    required this.tipoLabor,
    required this.tipoMineral,
    required this.estructuraVeta,
    this.nivel,
    this.block,
    required this.labor,
    this.ala,
    this.anchoVeta,
    this.anchoMinadoSem,
    this.anchoMinadoMes,
    this.burden,
    this.espaciamiento,
    this.longitudPerforacion,
    required this.programado,
    required this.columnas,
  });

  factory PlanMetraje.fromJson(Map<String, dynamic> json) {
    return PlanMetraje(
      id: json['id'],
      anio: json['anio'],
      mes: json['mes'],
      semana: json['semana'],
      mina: json['mina'],
      zona: json['zona'],
      area: json['area'],
      fase: json['fase'],
      minadoTipo: json['minado_tipo'],
      tipoLabor: json['tipo_labor'],
      tipoMineral: json['tipo_mineral'],
      estructuraVeta: json['estructura_veta'],
      nivel: json['nivel'],
      block: json['block'],
      labor: json['labor'],
      ala: json['ala'],
      anchoVeta: (json['ancho_veta'] is num) ? json['ancho_veta'].toDouble() : null,
      anchoMinadoSem: (json['ancho_minado_sem'] is num) ? json['ancho_minado_sem'].toDouble() : null,
      anchoMinadoMes: (json['ancho_minado_mes'] is num) ? json['ancho_minado_mes'].toDouble() : null,
      burden: (json['burden'] is num) ? json['burden'].toDouble() : null,
      espaciamiento: (json['espaciamiento'] is num) ? json['espaciamiento'].toDouble() : null,
      longitudPerforacion: (json['longitud_perforacion'] is num) ? json['longitud_perforacion'].toDouble() : null,
      programado: json['programado'],
      columnas: {
        for (int i = 1; i <= 28; i++)
          'columna_${i}A': json['columna_${i}A'],
        for (int i = 1; i <= 28; i++)
          'columna_${i}B': json['columna_${i}B'],
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'anio': anio,
      'mes': mes,
      'semana': semana,
      'mina': mina,
      'zona': zona,
      'area': area,
      'fase': fase,
      'minado_tipo': minadoTipo,
      'tipo_labor': tipoLabor,
      'tipo_mineral': tipoMineral,
      'estructura_veta': estructuraVeta,
      'nivel': nivel,
      'block': block,
      'labor': labor,
      'ala': ala,
      'ancho_veta': anchoVeta,
      'ancho_minado_sem': anchoMinadoSem,
      'ancho_minado_mes': anchoMinadoMes,
      'burden': burden,
      'espaciamiento': espaciamiento,
      'longitud_perforacion': longitudPerforacion,
      'programado': programado,
      ...columnas,
    };
  }
}
