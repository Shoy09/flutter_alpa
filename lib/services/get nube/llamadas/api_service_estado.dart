import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/EstadostBD.dart';

class ApiServiceEstado {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Obtener estados desde la API
  Future<List<EstadostBD>> fetchEstados(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.estadosEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {

        final List<dynamic> responseData = json.decode(response.body);

        List<EstadostBD> estados =
            responseData.map((data) => EstadostBD.fromJson(data)).toList();

        /// 🔹 Limpiar tabla antes de insertar
        await _dbHelper.deleteAll('EstadostBD');

        /// 🔹 Guardar estados
        await saveEstadosToLocalDB(estados);

        return estados;

      } else {
        throw Exception(
          'Error al cargar los estados. Código: ${response.statusCode}',
        );
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  // Guardar estados en la BD local
  Future<void> saveEstadosToLocalDB(List<EstadostBD> estados) async {
    for (var estado in estados) {

      Map<String, dynamic> estadoData = estado.toMap();
      estadoData.remove('id'); // SQLite autogenera

      await _dbHelper.insert('EstadostBD', estadoData);

    }
  }
}