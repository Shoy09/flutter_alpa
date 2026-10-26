import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Contrato compartido con el backend: solo contenido de negocio, sin IDs,
/// estados de transporte, aprobaciones ni hora del último envío.
class TransferContent {
  static const tables = {
    'tal_largo': 'Operacion_tal_largo',
    'tal_horizontal': 'Operacion_tal_horizontal',
    'empernador': 'Operacion_empernador',
    'carguio': 'Operacion_carguio',
    'rompebanco': 'Operacion_rompebanco',
    'scissor': 'Operacion_scissor',
    'anfochanger': 'Operacion_anfochanger',
    'scalamin': 'Operacion_Scalamin',
    'dumper': 'Operacion_Dumper',
    'volquetes': 'Operacion_volquetes',
  };
  static const common = [
    'fecha',
    'turno',
    'operador',
    'jefe_guardia',
    'estado',
  ];
  static const equipment = [
    'equipo',
    'n_equipo',
    'registros',
    'horometros',
    'condiciones_equipo',
    'check_list',
    'control_llantas',
  ];
  static const extras = {
    'tal_largo': ['seccion', 'modelo_equipo'],
    'tal_horizontal': ['seccion', 'modelo_equipo'],
    'empernador': ['seccion', 'tipo_equipo'],
    'carguio': ['seccion', 'capacidad', 'tipo_equipo', 'programa_trabajo'],
    'dumper': ['seccion', 'capacidad', 'tipo_equipo', 'programa_trabajo'],
    'rompebanco': <String>[],
    'anfochanger': <String>[],
    'scissor': ['guardia'],
    'scalamin': ['guardia'],
    'volquetes': [
      'guardia',
      'n_volquete',
      'empresa',
      'registros',
      'horometros',
    ],
  };
  static const jsonFields = {
    'registros',
    'horometros',
    'condiciones_equipo',
    'check_list',
    'control_llantas',
    'programa_trabajo',
  };

  static List<String> fields(String type) {
    if (!tables.containsKey(type)) {
      throw FormatException('Operación no soportada');
    }
    return [...common, if (type != 'volquetes') ...equipment, ...extras[type]!];
  }

  static dynamic normalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: normalize(value[key])};
    }
    if (value is List) return value.map(normalize).toList();
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return value;
  }

  static Map<String, dynamic> content(
    String type,
    Map<String, dynamic> payload,
  ) {
    final result = <String, dynamic>{};
    for (final key in fields(type)) {
      if (!payload.containsKey(key)) {
        throw FormatException('Falta el campo $key');
      }
      var value = payload[key];
      if (jsonFields.contains(key)) {
        if (value is String) value = jsonDecode(value);
        if (value is! Map && value is! List) {
          throw FormatException('JSON inválido: $key');
        }
        result[key] = normalize(value);
      } else {
        result[key] = value?.toString() ?? '';
      }
    }
    return Map<String, dynamic>.from(normalize(result));
  }

  static String fingerprint(String type, Map<String, dynamic> payload) => sha256
      .convert(utf8.encode(jsonEncode(content(type, payload))))
      .toString();
}
