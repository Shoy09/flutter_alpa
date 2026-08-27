import 'dart:convert';
import 'package:i_miner/config/data/database_helper.dart';

class ExportarVolquetesService {
  final DatabaseHelper dbHelper;

  ExportarVolquetesService(this.dbHelper);

  String _getHoraActual() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

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
          return decoded
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
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

      /// Decodificación
      final registros = parseList(operacion['registros']);
      final horometros = parseMap(operacion['horometros']);
final horaActual = _getHoraActual();
      /// Objeto final
      jsonDataList.add({
        "local_id": id,
        "idNube": operacion['idNube'] ?? 0,
        "fecha": operacion['fecha'] ?? "",
        "turno": operacion['turno'] ?? "",
        "guardia": operacion['guardia'] ?? "",
        "n_volquete": operacion['n_volquete'] ?? "",
        "operador": operacion['operador'] ?? "",
        "empresa": operacion['empresa'] ?? "",
        "jefe_guardia": operacion['jefe_guardia'] ?? "",
        "estado": operacion['estado'] ?? "activo",
        "envio": operacion['envio'] ?? 0,
        "Hora_envio": horaActual,

        /// JSON como STRING para Sequelize
        "registros": jsonEncode(registros),
        "horometros": jsonEncode(horometros),
      });
    }

    return jsonDataList;
  }

  String formatearJson(List<Map<String, dynamic>> jsonData) {
    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }
}