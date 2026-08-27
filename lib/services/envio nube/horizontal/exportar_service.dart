import 'dart:convert';
import 'package:i_miner/config/data/database_helper.dart';

class ExportarHorizontalService {
  final DatabaseHelper dbHelper;

  ExportarHorizontalService(this.dbHelper);

  /// 🔹 Función auxiliar para obtener hora actual en formato HH:MM
  String _getHoraActual() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> prepararDatosParaExportar(
    Set<int> selectedItems,
    List<Map<String, dynamic>> operacionData,
  ) async {

    final List<Map<String, dynamic>> jsonDataList = [];

    for (var id in selectedItems) {

      final operacion = operacionData.firstWhere(
        (op) => op['id'] == id,
        orElse: () => {},
      );

      if (operacion.isEmpty) continue;

      /// 🔹 Helpers seguros
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

      /// 🔹 Decodificación
      final estados = parseList(operacion['registros']);
      final horometros = parseMap(operacion['horometros']);
      final checklist = parseList(operacion['check_list']);
      final condiciones = parseMap(operacion['condiciones_equipo']);
      final controlLlantas = parseMap(operacion['control_llantas']);

      /// 🔥 Obtener hora actual en formato HH:MM
      final horaActual = _getHoraActual();

      /// 🔥 OBJETO FINAL (PLANO + STRING)
      jsonDataList.add({
        "local_id": id, // 🔥 IMPORTANTE
        "idNube": operacion['idNube'] ?? 0,

        // 🔹 Campos planos
        "fecha": operacion['fecha'] ?? "",
        "turno": operacion['turno'] ?? "",
        "seccion": operacion['seccion'] ?? "",
        "operador": operacion['operador'] ?? "",
        "jefe_guardia": operacion['jefe_guardia'] ?? "",
        "equipo": operacion['equipo'] ?? "",
        "n_equipo": operacion['n_equipo'] ?? "",
        "modelo_equipo": operacion['modelo_equipo'] ?? "",
        "estado": operacion['estado'] ?? "activo",
        "envio": operacion['envio'] ?? 0,
        "Hora_envio": horaActual, // 🔥 ASIGNAMOS LA HORA ACTUAL

        // 🔥 STRING (CLAVE PARA SEQUELIZE TEXT)
        "registros": jsonEncode(estados),
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