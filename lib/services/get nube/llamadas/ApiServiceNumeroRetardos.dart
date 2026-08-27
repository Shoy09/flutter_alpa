import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/numero_retardos.dart';

class ApiServiceNumeroRetardos {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener SOLO el último registro desde la API
  Future<NumeroRetardos?> fetchUltimo(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/n-retardos/ultimo'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data == null) return null;

        NumeroRetardos registro = NumeroRetardos.fromJson(data);

        // 🔥 Guardar localmente
        await saveToLocalDB(registro);

        return registro;
      } else if (response.statusCode == 404) {
        return null; // no hay registros aún
      } else {
        throw Exception('Error al obtener último registro: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar en SQLite (solo 1 registro, reemplaza el anterior)
  Future<void> saveToLocalDB(NumeroRetardos item) async {
    // 🔥 Limpiar tabla (porque solo quieres el último)
    await _dbHelper.deleteAll('numero_retardos');

    Map<String, dynamic> data = item.toMap();
    data.remove('id'); // opcional si usas autoincrement local

    await _dbHelper.insert('numero_retardos', data);
  }
}