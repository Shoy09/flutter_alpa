import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/longitud_barras.dart';

class ApiServiceLongitudBarras {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener desde API y guardar localmente
  Future<List<LongitudBarras>> fetchLongitudBarras(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.longitudBarrasEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<LongitudBarras> lista = responseData
            .map((data) => LongitudBarras.fromJson(data))
            .toList();

        // Limpiar tabla
        await _dbHelper.deleteAll('longitud_barras');

        // Guardar
        await saveToLocalDB(lista);

        return lista;
      } else {
        throw Exception('Error al cargar Longitud Barras: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar en SQLite
  Future<void> saveToLocalDB(List<LongitudBarras> lista) async {
    for (var item in lista) {
      Map<String, dynamic> data = item.toMap();
      data.remove('id');

      await _dbHelper.insert('longitud_barras', data);
    }
  }
}