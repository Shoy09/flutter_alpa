import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/guardia.dart';

class ApiServiceGuardia {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener guardias desde la API y guardarlas localmente
  Future<List<Guardia>> fetchGuardias(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/guardias'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<Guardia> guardias = responseData
            .map((data) => Guardia.fromJson(data))
            .toList();

        // Eliminar datos antiguos
        await _dbHelper.deleteAll('Guardia');

        // Guardar nuevos datos
        await saveGuardiasToLocalDB(guardias);

        return guardias;
      } else {
        throw Exception(
          'Error al cargar guardias. Código: ${response.statusCode}'
        );
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar guardias en SQLite
  Future<void> saveGuardiasToLocalDB(List<Guardia> guardias) async {
    for (var guardia in guardias) {
      Map<String, dynamic> guardiaData = guardia.toMap();

      // Evitar conflictos con autoincrement local
      guardiaData.remove('id');

      await _dbHelper.insert('Guardia', guardiaData);
    }
  }
}