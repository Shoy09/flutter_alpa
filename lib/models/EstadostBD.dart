class EstadostBD {
  int? id;
  String estadoPrincipal;
  String codigo;
  String tipoEstado;
  String categoria;
  String proceso;

  EstadostBD({
    this.id,
    required this.estadoPrincipal,
    required this.codigo,
    required this.tipoEstado,
    required this.categoria,
    required this.proceso,
  });

  // Convertir de Map (SQLite)
  factory EstadostBD.fromMap(Map<String, dynamic> map) {
    return EstadostBD(
      id: map['id'],
      estadoPrincipal: map['estado_principal'],
      codigo: map['codigo'],
      tipoEstado: map['tipo_estado'],
      categoria: map['categoria'],
      proceso: map['proceso'],
    );
  }

  // Convertir a Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estado_principal': estadoPrincipal,
      'codigo': codigo,
      'tipo_estado': tipoEstado,
      'categoria': categoria,
      'proceso': proceso,
    };
  }

  // Convertir de JSON (API)
  factory EstadostBD.fromJson(Map<String, dynamic> json) {
    return EstadostBD(
      id: json['id'], // puede venir de la API
      estadoPrincipal: json['estado_principal'],
      codigo: json['codigo'],
      tipoEstado: json['tipo_estado'],
      categoria: json['categoria'],
      proceso: json['proceso'],
    );
  }
}