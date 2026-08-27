// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/services/api_service.dart';


class UserService {
  final ApiService _apiService = ApiService();
  final String baseUrl = ApiConfig.baseUrl;

  Future<String> login(String codigoDni, String password) async {
    return await _apiService.login(codigoDni, password);
  }

  Future<Map<String, dynamic>> getUserProfile(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/usuarios/perfil'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Tiempo de espera agotado al obtener el perfil'),
        );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Error ${response.statusCode} al obtener el perfil del usuario',
      );
    }
  }

  /// Decodifica el payload del JWT sin verificar firma.
  /// Útil como fallback cuando la API no responde pero el token es válido localmente.
  Map<String, dynamic> decodeTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException('Token JWT inválido');

      // Base64 URL decode (sin padding)
      String payload = parts[1];
      // Añadir padding necesario
      final remainder = payload.length % 4;
      if (remainder != 0) {
        payload = payload.padRight(payload.length + (4 - remainder), '=');
      }
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');

      final decoded = utf8.decode(base64Decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      print('Error decodificando token JWT: $e');
      return {};
    }
  }
}

