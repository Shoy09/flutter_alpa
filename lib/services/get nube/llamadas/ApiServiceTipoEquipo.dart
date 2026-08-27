import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/TipoEquipo.dart';

class ApiServiceTipoEquipo {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener todos los tipos de equipo desde la API y guardarlos localmente
  Future<List<TipoEquipo>> fetchTiposEquipo(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.TipoEquipoEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<TipoEquipo> tipos = responseData
            .map((data) => TipoEquipo.fromJson(data))
            .toList();

        // Eliminar datos antiguos
        await _dbHelper.deleteAll('TipoEquipo');

        // Guardar en DB local
        await saveTiposToLocalDB(tipos);

        return tipos;
      } else {
        throw Exception(
            'Error al cargar los tipos de equipo. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar tipos de equipo en la base de datos local
  Future<void> saveTiposToLocalDB(List<TipoEquipo> tipos) async {
    for (var tipo in tipos) {
      Map<String, dynamic> tipoData = tipo.toMap();

      tipoData.remove('id'); // evitar conflicto con id autoincrement

      await _dbHelper.insert('TipoEquipo', tipoData);
    }
  }
}