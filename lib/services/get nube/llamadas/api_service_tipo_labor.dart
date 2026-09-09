// services/api_service_tipo_labor.dart
import 'dart:convert';
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/TipoLabor.dart';
import 'package:http/http.dart' as http;

class ApiServiceTipoLabor {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método para obtener los tipos de labor desde la API
  Future<List<TipoLabor>> fetchTiposLabor(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tipoLaborEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token', // Token en la cabecera
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<TipoLabor> tiposLabor = responseData
            .map((data) => TipoLabor.fromJson(data))
            .toList();

        // Eliminar los datos antiguos antes de insertar los nuevos
        await _dbHelper.deleteAllShared('tipo_labor');

        // Guardar los datos en la base de datos local
        await saveTiposToLocalDB(tiposLabor);

        return tiposLabor;
      } else {
        throw Exception('Error al obtener los tipos de labor. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  // Guardar tipos de labor en la base de datos local
  Future<void> saveTiposToLocalDB(List<TipoLabor> tiposLabor) async {
    for (var tipo in tiposLabor) {
      Map<String, dynamic> tipoData = tipo.toMap();
      tipoData.remove('id'); // Asegurar que no se inserte el id para evitar conflictos
      await _dbHelper.insertShared('tipo_labor', tipoData);
    }
  }
}