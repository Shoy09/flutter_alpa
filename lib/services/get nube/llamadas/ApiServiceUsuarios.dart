import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/UsuarioNombre.dart';

class ApiServiceUsuarios {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener nombres de usuarios desde la API y guardarlos localmente
  Future<List<UsuarioNombre>> fetchNombresUsuarios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usuariosNombresEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<UsuarioNombre> usuarios = responseData
            .map((data) => UsuarioNombre.fromJson(data))
            .toList();

        // Eliminar datos antiguos
        await _dbHelper.deleteAllShared('UsuariosModel');

        // Guardar en DB local
        await saveUsuariosToLocalDB(usuarios);

        return usuarios;
      } else {
        throw Exception(
            'Error al cargar los nombres de usuarios. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar usuarios en base de datos local
  Future<void> saveUsuariosToLocalDB(List<UsuarioNombre> usuarios) async {
    for (var usuario in usuarios) {
      Map<String, dynamic> usuarioData = usuario.toMap();

      usuarioData.remove('id'); // evitar conflicto con autoincrement

      await _dbHelper.insertShared('UsuariosModel', usuarioData);
    }
  }
}