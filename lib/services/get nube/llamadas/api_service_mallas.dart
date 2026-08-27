import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/malla.dart';

class ApiServiceMallas {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Malla>> fetchMallas(String token) async {
    try {
      final response = await http.get(
  Uri.parse('${ApiConfig.baseUrl}${ApiConfig.mallasEndpoint}'),
  headers: {
    'Authorization': 'Bearer $token',
  },
);

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<Malla> lista = responseData
            .map((data) => Malla.fromJson(data))
            .toList();

        await _dbHelper.deleteAll('mallas');
        await saveToLocalDB(lista);

        return lista;
      } else {
        throw Exception('Error al cargar Mallas: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  Future<void> saveToLocalDB(List<Malla> lista) async {
    for (var item in lista) {
      Map<String, dynamic> data = item.toMap();
      data.remove('id');

      await _dbHelper.insert('mallas', data);
    }
  }
}