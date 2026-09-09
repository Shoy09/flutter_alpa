// lib/services/ApiServiceUsuario.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/UsuarioMaestro.dart';

class ApiServiceUsuario {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 📥 Obtener todos los usuarios desde la API
  Future<List<UsuarioMaestro>> fetchUsuarios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usuariosEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        
        List<UsuarioMaestro> usuarios = responseData
            .map((data) => UsuarioMaestro.fromJson(data))
            .toList();

        print('✅ ${usuarios.length} usuarios obtenidos de la API');

        // 💾 Guardar en la base de datos local
        await saveUsuariosToLocalDB(usuarios);

        return usuarios;
      } else {
        throw Exception(
          'Error al cargar usuarios. Código: ${response.statusCode}',
        );
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }


  // 💾 Guardar usuarios en la base de datos local (compartida)
 Future<void> saveUsuariosToLocalDB(List<UsuarioMaestro> usuarios) async {
  try {
    final rows = usuarios.map((u) {
      final map = u.toMap();
      map.remove('id'); // SQLite autogenera
      return map;
    }).toList();

    await _dbHelper.replaceAllShared('UsuariosMaestros', rows);

    print('✅ ${usuarios.length} usuarios guardados en DB local');
  } catch (e) {
    print('❌ Error guardando usuarios en DB local: $e');
    rethrow;
  }
}
}