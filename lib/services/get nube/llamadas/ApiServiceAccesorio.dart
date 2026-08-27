import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Accesorio.dart';

class ApiServiceAccesorio {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método para obtener los accesorios desde la API
  Future<List<Accesorio>> fetchAccesorios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.AccesorioEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<Accesorio> accesorios = responseData
            .map((data) => Accesorio.fromJson(data))
            .toList();

        // Eliminar datos antiguos antes de insertar nuevos
        await _dbHelper.deleteAll('accesorios');
 
        // Guardar en la base de datos local
        await saveAccesoriosToLocalDB(accesorios);

        return accesorios;
      } else {
        throw Exception('Error al obtener los accesorios. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  // Guardar accesorios en la base de datos local
  Future<void> saveAccesoriosToLocalDB(List<Accesorio> accesorios) async {
    for (var accesorio in accesorios) {
      Map<String, dynamic> accesorioData = accesorio.toMap();
      accesorioData.remove('id'); // Evitar conflictos con el ID
      await _dbHelper.insert('accesorios', accesorioData);
    }
  }
}
