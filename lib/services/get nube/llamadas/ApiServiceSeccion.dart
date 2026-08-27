import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Seccion.dart';

class ApiServiceSeccion {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener secciones desde la API y guardarlas localmente
  Future<List<Seccion>> fetchSecciones(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.SeccionEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<Seccion> secciones = responseData
            .map((data) => Seccion.fromJson(data))
            .toList();

        // Eliminar datos antiguos
        await _dbHelper.deleteAll('Seccion');

        // Guardar en DB local
        await saveSeccionesToLocalDB(secciones);

        return secciones;
      } else {
        throw Exception(
            'Error al cargar las secciones. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar secciones en base de datos local
  Future<void> saveSeccionesToLocalDB(List<Seccion> secciones) async {
    for (var seccion in secciones) {
      Map<String, dynamic> seccionData = seccion.toMap();

      seccionData.remove('id'); // evitar conflicto con autoincrement

      await _dbHelper.insert('Seccion', seccionData);
    }
  }
}