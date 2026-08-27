class PlanProduccion {
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

  // Valores numéricos de producción
  double? anchoVeta;
  double? anchoMinadoSem;
  double? anchoMinadoMes;
  double? agGr;
  double? porcentajeCu;
  double? porcentajePb;
  double? porcentajeZn;
  double? vptAct;
  double? vptFinal;
  double? cutOff1;
  double? cutOff2;
  String programado;

  // Columnas dinámicas 1A-28B
  Map<String, String?> columnas;

  DateTime createdAt;
  DateTime updatedAt;

  PlanProduccion({
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
    this.agGr,
    this.porcentajeCu,
    this.porcentajePb,
    this.porcentajeZn,
    this.vptAct,
    this.vptFinal,
    this.cutOff1,
    this.cutOff2,
    required this.programado,
    required this.columnas,
    required this.createdAt,
    required this.updatedAt,
  });

  // Método para convertir un JSON a un objeto PlanProduccion
  factory PlanProduccion.fromJson(Map<String, dynamic> json) {
    Map<String, String?> columnas = {};
    for (int i = 1; i <= 28; i++) {
      columnas["columna_${i}A"] = json["columna_${i}A"];
      columnas["columna_${i}B"] = json["columna_${i}B"];
    }

    return PlanProduccion(
      anio: json["anio"],
      mes: json["mes"],
      semana: json["semana"],
      mina: json["mina"],
      zona: json["zona"],
      area: json["area"],
      fase: json["fase"],
      minadoTipo: json["minado_tipo"],
      tipoLabor: json["tipo_labor"],
      tipoMineral: json["tipo_mineral"],
      estructuraVeta: json["estructura_veta"],
      nivel: json["nivel"],
      block: json["block"],
      labor: json["labor"],
      ala: json["ala"],
      anchoVeta: json["ancho_veta"]?.toDouble(),
      anchoMinadoSem: json["ancho_minado_sem"]?.toDouble(),
      anchoMinadoMes: json["ancho_minado_mes"]?.toDouble(),
      agGr: json["ag_gr"]?.toDouble(),
      porcentajeCu: json["porcentaje_cu"]?.toDouble(),
      porcentajePb: json["porcentaje_pb"]?.toDouble(),
      porcentajeZn: json["porcentaje_zn"]?.toDouble(),
      vptAct: json["vpt_act"]?.toDouble(),
      vptFinal: json["vpt_final"]?.toDouble(),
      cutOff1: json["cut_off_1"]?.toDouble(),
      cutOff2: json["cut_off_2"]?.toDouble(),
      programado: json["programado"],
      columnas: columnas,
      createdAt: DateTime.parse(json["createdAt"]),
      updatedAt: DateTime.parse(json["updatedAt"]),
    );
  }

  // Método para convertir el objeto PlanProduccion a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      "anio": anio,
      "mes": mes,
      "semana": semana,
      "mina": mina,
      "zona": zona,
      "area": area,
      "fase": fase,
      "minado_tipo": minadoTipo,
      "tipo_labor": tipoLabor,
      "tipo_mineral": tipoMineral,
      "estructura_veta": estructuraVeta,
      "nivel": nivel,
      "block": block,
      "labor": labor,
      "ala": ala,
      "ancho_veta": anchoVeta,
      "ancho_minado_sem": anchoMinadoSem,
      "ancho_minado_mes": anchoMinadoMes,
      "ag_gr": agGr,
      "porcentaje_cu": porcentajeCu,
      "porcentaje_pb": porcentajePb,
      "porcentaje_zn": porcentajeZn,
      "vpt_act": vptAct,
      "vpt_final": vptFinal,
      "cut_off_1": cutOff1,
      "cut_off_2": cutOff2,
      "programado": programado,
      "createdAt": createdAt.toIso8601String(),
      "updatedAt": updatedAt.toIso8601String(),
    };

    for (int i = 1; i <= 28; i++) {
      data["columna_${i}A"] = columnas["columna_${i}A"];
      data["columna_${i}B"] = columnas["columna_${i}B"];
    }

    return data;
  }

  // Método para convertir el objeto PlanProduccion a un Map<String, String?>
  Map<String, String?> toMap() {
    final Map<String, String?> map = {
      'anio': anio?.toString(),
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
      'ancho_veta': anchoVeta?.toString(),
      'ancho_minado_sem': anchoMinadoSem?.toString(),
      'ancho_minado_mes': anchoMinadoMes?.toString(),
      'ag_gr': agGr?.toString(),
      'porcentaje_cu': porcentajeCu?.toString(),
      'porcentaje_pb': porcentajePb?.toString(),
      'porcentaje_zn': porcentajeZn?.toString(),
      'vpt_act': vptAct?.toString(),
      'vpt_final': vptFinal?.toString(),
      'cut_off_1': cutOff1?.toString(),
      'cut_off_2': cutOff2?.toString(),
      'programado': programado,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };

    // Añadir las columnas
    for (int i = 1; i <= 28; i++) {
      map["columna_${i}A"] = columnas["columna_${i}A"];
      map["columna_${i}B"] = columnas["columna_${i}B"];
    }

    return map;
  }
}
