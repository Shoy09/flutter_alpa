enum EstadoChecklist { bueno, malo }

/// Respuesta de un ítem en la copia JSON de una operación.
class ChecklistRespuesta {
  final String descripcion;
  final String categoria;
  EstadoChecklist? inicio;
  EstadoChecklist? finalizacion;
  bool noAplica;
  String observacion;
  final Map<String, dynamic> _original;

  ChecklistRespuesta({
    required this.descripcion,
    required this.categoria,
    this.inicio,
    this.finalizacion,
    this.noAplica = false,
    this.observacion = '',
    Map<String, dynamic> original = const {},
  }) : _original = Map.of(original);

  factory ChecklistRespuesta.desdeCatalogo(Map<String, dynamic> item) =>
      ChecklistRespuesta(
        descripcion: item['nombre'] as String,
        categoria: item['categoria'] as String,
      );

  factory ChecklistRespuesta.fromMap(Map<String, dynamic> json) {
    final moderno =
        json.containsKey('estado_inicio') ||
        json.containsKey('estado_final') ||
        json.containsKey('no_aplica');
    EstadoChecklist? inicio = _estado(json['estado_inicio']);
    if (!moderno) {
      final decision = json['decision'];
      if (decision == 1 || decision == true || decision == '1') {
        inicio = EstadoChecklist.bueno;
      }
      if (decision == 0 || decision == false || decision == '0') {
        inicio = EstadoChecklist.malo;
      }
    }
    return ChecklistRespuesta(
      descripcion: (json['descripcion'] ?? json['nombre'] ?? 'Sin descripción')
          .toString(),
      categoria: (json['categoria'] ?? 'Sin categoría').toString(),
      inicio: inicio,
      finalizacion: _estado(json['estado_final']),
      noAplica: json['no_aplica'] == true || json['no_aplica'] == 1,
      observacion: (json['observacion'] ?? '').toString(),
      original: json,
    );
  }

  static EstadoChecklist? _estado(dynamic value) => switch (value) {
    'bueno' => EstadoChecklist.bueno,
    'malo' => EstadoChecklist.malo,
    null => null,
    _ => throw FormatException('Estado de checklist inválido: $value'),
  };

  Map<String, dynamic> toMap() => {
    ..._original,
    'descripcion': descripcion,
    'categoria': categoria,
    'estado_inicio': noAplica ? null : inicio?.name,
    'estado_final': noAplica ? null : finalizacion?.name,
    'no_aplica': noAplica,
    'observacion': observacion,
  }..remove('decision');
}
