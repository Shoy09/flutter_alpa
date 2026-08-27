import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Explosivo.dart';

class ApiServiceExplosivo {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método para obtener los explosivos desde la API
  Future<List<Explosivo>> fetchExplosivos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ExplosivoEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<Explosivo> explosivos = responseData
            .map((data) => Explosivo.fromJson(data))
            .toList();

        // Eliminar datos antiguos antes de insertar nuevos
        await _dbHelper.deleteAll('explosivos');

        // Guardar en la base de datos local
        await saveExplosivosToLocalDB(explosivos);

        return explosivos;
      } else {
        throw Exception('Error al obtener los explosivos. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  } 

  // Guardar explosivos en la base de datos local
  Future<void> saveExplosivosToLocalDB(List<Explosivo> explosivos) async {
    for (var explosivo in explosivos) {
      Map<String, dynamic> explosivoData = explosivo.toMap();
      explosivoData.remove('id'); // Evitar conflictos con el ID
      await _dbHelper.insert('explosivos', explosivoData);
    }
  }
}
