import 'dart:convert';
import 'package:i_miner/config/data/database_helper.dart';

class ExportarScissorService {
  final DatabaseHelper dbHelper;

  ExportarScissorService(this.dbHelper);

  Future<List<Map<String, dynamic>>> prepararDatosParaExportar(
    Set<int> selectedItems,
    List<Map<String, dynamic>> operacionData,
  ) async {

    final List<Map<String, dynamic>> jsonDataList = [];

    /// Helpers seguros
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
      final condiciones = parseMap(operacion['condiciones_equipo']);
      final controlLlantas = parseMap(operacion['control_llantas']);

      /// 🔥 OBJETO FINAL (PLANO para API)
      jsonDataList.add({
        "local_id": id,
        "idNube": operacion['idNube'] ?? 0,

        "fecha": operacion['fecha'] ?? "",
        "turno": operacion['turno'] ?? "",
        "operador": operacion['operador'] ?? "",
        "jefe_guardia": operacion['jefe_guardia'] ?? "",
        "equipo": operacion['equipo'] ?? "",
        "n_equipo": operacion['n_equipo'] ?? "",

        "estado": operacion['estado'] ?? "activo",
        "envio": operacion['envio'] ?? 0,

        /// 🔥 TODO STRING (porque tu API usa TEXT)
        "registros": jsonEncode(registros),
        "horometros": jsonEncode(horometros),
        "condiciones_equipo": jsonEncode(condiciones),
        "check_list": jsonEncode(checklist),
        "control_llantas": jsonEncode(controlLlantas),
      });
    }

    return jsonDataList;
  }

  String formatearJson(List<Map<String, dynamic>> jsonData) {
    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }
}