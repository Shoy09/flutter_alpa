import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/OrigenDestino.dart';

class ApiServiceOrigenDestino {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 🔹 Obtener desde API y guardar local
  Future<List<OrigenDestino>> fetchOrigenDestino(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.OrigenDestinoEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<OrigenDestino> lista = responseData
            .map((data) => OrigenDestino.fromJson(data))
            .toList();

        /// 🔹 Limpiar tabla local
        await _dbHelper.deleteAll('origen_destino');

        /// 🔹 Guardar en SQLite
        await saveToLocalDB(lista);

        return lista;
      } else {
        throw Exception(
            'Error al cargar origen_destino. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// 🔹 Guardar en SQLite
  Future<void> saveToLocalDB(List<OrigenDestino> lista) async {
    for (var item in lista) {
      Map<String, dynamic> data = item.toMap();

      data.remove('id'); // evitar conflicto con autoincrement

      await _dbHelper.insert('origen_destino', data);
    }
  }
}