import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Empresa.dart';

class ApiServiceEmpresa {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener empresas desde la API y guardarlas localmente
  Future<List<Empresa>> fetchEmpresas(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.EmpresaEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<Empresa> empresas = responseData
            .map((data) => Empresa.fromJson(data))
            .toList();

        // Eliminar datos antiguos
        await _dbHelper.deleteAllShared('Empresa');

        // Guardar en DB local
        await saveEmpresasToLocalDB(empresas);

        return empresas;
      } else {
        throw Exception(
          'Error al cargar las empresas. Código: ${response.statusCode}',
        );
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar empresas en base de datos local
  Future<void> saveEmpresasToLocalDB(List<Empresa> empresas) async {
    for (var empresa in empresas) {
      Map<String, dynamic> empresaData = empresa.toMap();

      empresaData.remove('id'); // evitar conflicto con id autoincrement

      await _dbHelper.insertShared('Empresa', empresaData);
    }
  }
}