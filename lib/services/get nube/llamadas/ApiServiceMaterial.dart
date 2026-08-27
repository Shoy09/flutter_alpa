import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/material.dart';

class ApiServiceMaterial {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método para obtener los materiales desde la API
  Future<List<Material>> fetchMateriales(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.MaterialEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<Material> materiales = responseData
            .map((data) => Material.fromJson(data))
            .toList();

        // Eliminar datos antiguos antes de insertar nuevos
        await _dbHelper.deleteAll('materiales');
 
        // Guardar en la base de datos local
        await saveMaterialesToLocalDB(materiales);

        return materiales;
      } else {
        throw Exception('Error al obtener los materiales. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  // Guardar materiales en la base de datos local
  Future<void> saveMaterialesToLocalDB(List<Material> materiales) async {
    for (var material in materiales) {
      Map<String, dynamic> materialData = material.toMap();
      materialData.remove('id'); // Evitar conflictos con el ID
      await _dbHelper.insert('materiales', materialData);
    }
  }
}