import 'checklist_equipo.dart';

class CheckListItem {
  int? id;
  String proceso;
  String categoria;
  String nombre;
  bool aplicaTodosEquipos;
  List<ChecklistEquipo> equipos;

  CheckListItem({
    this.id,
    required this.proceso,
    required this.categoria,
    required this.nombre,
    this.aplicaTodosEquipos = true,
    this.equipos = const [],
  });

  factory CheckListItem.fromJson(Map<String, dynamic> json) {
    final asignaciones = json['equipos'];
    final ids = json['equipo_ids'];
    if (asignaciones != null && asignaciones is! List ||
        ids != null && ids is! List) {
      throw const FormatException('Asignaciones de checklist inválidas.');
    }
    final tieneAsignaciones =
        json.containsKey('equipos') || json.containsKey('equipo_ids');
    final flag = json['aplica_todos_equipos'];
    final bool todos;
    if (flag == null && !json.containsKey('aplica_todos_equipos')) {
      // Compatibilidad con el catálogo antiguo, que no tenía asignaciones.
      todos = !tieneAsignaciones;
    } else if (flag == true || flag == 1 || flag == '1' || flag == 'true') {
      todos = true;
    } else if (flag == false || flag == 0 || flag == '0' || flag == 'false') {
      todos = false;
    } else {
      throw const FormatException('Alcance de checklist inválido.');
    }
    final equiposJson = <Map<String, dynamic>>[];
    for (final equipo in (asignaciones as List? ?? const [])) {
      if (equipo is! Map<String, dynamic>) {
        throw const FormatException('Equipo de checklist inválido.');
      }
      equiposJson.add(equipo);
    }
    if (!todos && ids is List && ids.isNotEmpty) {
      final expandidos = equiposJson
          .map((equipo) => equipo['id'].toString())
          .toSet();
      if (ids.any((id) => !expandidos.contains(id.toString()))) {
        throw const FormatException(
          'La API debe enviar código y proceso de todos los equipos asignados, no solo equipo_ids.',
        );
      }
    }
    if (todos && (equiposJson.isNotEmpty || ids is List && ids.isNotEmpty)) {
      throw const FormatException(
        'El alcance general no debe contener asignaciones específicas.',
      );
    }
    final item = CheckListItem(
      id: json['id'] == null ? null : int.parse(json['id'].toString()),
      proceso: _texto(json['proceso'], 'proceso'),
      categoria: _texto(json['categoria'], 'categoría'),
      nombre: _texto(json['nombre'], 'nombre'),
      aplicaTodosEquipos: todos,
      equipos: equiposJson.map(ChecklistEquipo.fromJson).toList(),
    );
    item.validar();
    return item;
  }

  static String _texto(dynamic value, String campo) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El checklist necesita $campo.');
    }
    return value.trim();
  }

  void validar() {
    _texto(proceso, 'proceso');
    _texto(categoria, 'categoría');
    _texto(nombre, 'nombre');
    if (aplicaTodosEquipos && equipos.isNotEmpty) {
      throw const FormatException(
        'El alcance general no debe contener asignaciones específicas.',
      );
    }
    for (final equipo in equipos) {
      _texto(equipo.codigo, 'código de equipo');
      if (normalizarClaveChecklist(equipo.proceso) !=
          normalizarClaveChecklist(proceso)) {
        throw const FormatException(
          'El equipo asignado pertenece a otro proceso.',
        );
      }
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'proceso': proceso,
    'categoria': categoria,
    'nombre': nombre,
    'aplica_todos_equipos': aplicaTodosEquipos ? 1 : 0,
  };
}
