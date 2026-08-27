import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/perno.dart';

class ApiServicePernos {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Perno>> fetchPernos(String token) async {
    try {
      final response = await http.get(
  Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pernosEndpoint}'),
  headers: {
    'Authorization': 'Bearer $token',
  },
);

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<Perno> lista = responseData
            .map((data) => Perno.fromJson(data))
            .toList();

        await _dbHelper.deleteAll('pernos');
        await saveToLocalDB(lista);

        return lista;
      } else {
        throw Exception('Error al cargar Pernos: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  Future<void> saveToLocalDB(List<Perno> lista) async {
    for (var item in lista) {
      Map<String, dynamic> data = item.toMap();
      data.remove('id');

      await _dbHelper.insert('pernos', data);
    }
  }
}