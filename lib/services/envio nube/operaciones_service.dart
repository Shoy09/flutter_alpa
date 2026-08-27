import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'dart:convert';

class OperacionesService {

  static const _timeout = Duration(seconds: 30);

  // ✅ CREAR (uno o varios)
  Future<bool> crear(String tipo, dynamic data) async {
  try {
    final url = Uri.parse('${ApiConfig.baseUrl}/operaciones/crear');

    final body = jsonEncode({
      "tipo": tipo,
      "data": data
    });

    print("📤 URL: $url");
    print("📤 BODY: $body");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(_timeout);

    print("📥 STATUS: ${response.statusCode}");
    print("📥 RESPONSE: ${response.body}");

    return response.statusCode == 200;

  } catch (e) {
    print('❌ Error crear: $e');
    return false;
  }
}

Future<List<dynamic>?> crearParciales(
  String tipo,
  dynamic data,
) async {

  try {

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/operaciones/crear'
    );

    final body = jsonEncode({
      "tipo": tipo,
      "data": data
    });

    print("📤 URL: $url");
    print("📤 BODY: $body");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json'
      },
      body: body,
    ).timeout(_timeout);

    print("📥 STATUS: ${response.statusCode}");
    print("📥 RESPONSE: ${response.body}");

    if (response.statusCode == 200) {

      final jsonData = jsonDecode(response.body);

      return jsonData['data'];

    }

    return null;

  } catch (e) {

    print('❌ Error crearParciales: $e');

    // Re-lanzar para que _syncProceso pueda revertir el estado
    rethrow;

  }

}

// ✅ ACTUALIZAR MASIVO
  Future<bool> actualizarMasivo(
    String tipo,
    List<dynamic> data,
  ) async {

    try {

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/operaciones/update-masivo'
      );

      final body = jsonEncode({
        "tipo": tipo,
        "data": data
      });

      print("📤 URL UPDATE MASIVO: $url");
      print("📤 BODY UPDATE MASIVO: $body");

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json'
        },
        body: body,
      ).timeout(_timeout);

      print("📥 STATUS UPDATE MASIVO: ${response.statusCode}");
      print("📥 RESPONSE UPDATE MASIVO: ${response.body}");

      return response.statusCode == 200;

    } catch (e) {

      print('❌ Error actualizarMasivo: $e');

      // Re-lanzar para que _syncProceso pueda revertir el estado
      rethrow;

    }

  }


  // ✅ GET (con filtros)
  Future<List<dynamic>> obtener(String tipo,
      {String? estado, int limit = 50, int offset = 0}) async {

    try {
      String url =
          '${ApiConfig.baseUrl}/operaciones/$tipo?limit=$limit&offset=$offset';

      if (estado != null) {
        url += '&estado=$estado';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['data'];
      } else {
        return [];
      }

    } catch (e) {
      print('Error obtener: $e');
      return [];
    }
  }

}
