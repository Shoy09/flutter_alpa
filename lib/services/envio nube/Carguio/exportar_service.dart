import 'dart:convert';
import 'package:i_miner/config/data/database_helper.dart';

class ExportarCarguioService {
  final DatabaseHelper dbHelper;

  ExportarCarguioService(this.dbHelper);

  String _getHoraActual() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> prepararDatosParaExportar(
    Set<int> selectedItems,
    List<Map<String, dynamic>> operacionData,
  ) async {

    final List<Map<String, dynamic>> jsonDataList = [];

    /// 🔹 Helpers seguros (como hiciste en largo)
    List<Map<String, dynamic>> parseList(String? value) {
      try {
        final decoded = jsonDecode(value ?? '[]');
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
      return [];
    }

    Map<String, dynamic> parseMap(String? value) {
      try {
        final decoded = jsonDecode(value ?? '{}');
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      return {};
    }

    for (var id in selectedItems) {

      final operacion = operacionData.firstWhere(
        (op) => op['id'] == id,
        orElse: () => {},
      );

      if (operacion.isEmpty) continue;

      /// 🔹 Decodificación
      final registros = parseList(operacion['registros']);
      final horometros = parseMap(operacion['horometros']);
      final checklist = parseList(operacion['check_list']);
      final checklistTelemando = parseList(operacion['check_list_telemando']);
      final condiciones = parseMap(operacion['condiciones_equipo']);
      final controlLlantas = parseMap(operacion['control_llantas']);
      final programaTrabajo = parseMap(operacion['programa_trabajo']);
      final tipoEquipo = parseMap(operacion['tipo_equipo']);

final horaActual = _getHoraActual();
      /// 🔥 OBJETO FINAL (PLANO como Sequelize)
      jsonDataList.add({
        "local_id": id,
        "idNube": operacion['idNube'] ?? 0,
        "fecha": operacion['fecha'] ?? "",
        "turno": operacion['turno'] ?? "",
        "seccion": operacion['seccion'] ?? "",
        "operador": operacion['operador'] ?? "",
        "jefe_guardia": operacion['jefe_guardia'] ?? "",
        "equipo": operacion['equipo'] ?? "",
        "n_equipo": operacion['n_equipo'] ?? "",
        "capacidad": operacion['capacidad'] ?? "",

        /// 🔥 IMPORTANTE → STRING
        "tipo_equipo": jsonEncode(tipoEquipo),

        "estado": operacion['estado'] ?? "activo",
        "envio": operacion['envio'] ?? 0,
        "Hora_envio": horaActual,

        /// 🔥 TODOS STRING
        "registros": jsonEncode(registros),
        "horometros": jsonEncode(horometros),
        "condiciones_equipo": jsonEncode(condiciones),
        "check_list": jsonEncode(checklist),
        "check_list_telemando": jsonEncode(checklistTelemando),
        "control_llantas": jsonEncode(controlLlantas),
        "programa_trabajo": jsonEncode(programaTrabajo),
      });
    }

    return jsonDataList;
  }

  String formatearJson(List<Map<String, dynamic>> jsonData) {
    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }
}