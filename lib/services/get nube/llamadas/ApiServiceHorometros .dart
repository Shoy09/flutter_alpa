import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';

class ApiServiceHorometros {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> fetchHorometros(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/operaciones/horometros/ultimos'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {

        final Map<String, dynamic> jsonData = json.decode(response.body);

        final Map<String, dynamic> data = jsonData['data'];

        /// 🔥 limpiar tabla antes de insertar
        await _dbHelper.deleteAll('horometros_nube');

        /// 🔥 guardar
        await _guardarHorometros(data);

      } else {
        throw Exception('Error: ${response.statusCode}');
      }

    } catch (e) {
      throw Exception('Error en fetchHorometros: $e');
    }
  }

  // 🔥 lógica clave aquí
  Future<void> _guardarHorometros(Map<String, dynamic> data) async {

    for (var operacionEntry in data.entries) {

      final operacion = operacionEntry.key;
      final horometros = operacionEntry.value;

      if (horometros == null) continue;

      for (var tipoEntry in horometros.entries) {

        final tipo = tipoEntry.key;
        final valores = tipoEntry.value;

        await _dbHelper.insert('horometros_nube', {
          'operacion': operacion,
          'tipo_horometro': tipo,
          'inicio': (valores['inicio'] ?? 0).toDouble(),
          'final': (valores['final'] ?? 0).toDouble(),
          'op': valores['op'] == true ? 1 : 0,
          'inop': valores['inop'] == true ? 1 : 0,
        });

      }
    }
  }
}