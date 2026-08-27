
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:i_miner/config/api/api_config.dart';

class ApiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Realiza una petición POST para iniciar sesión
  Future<String> login(String codigoDni, String password) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'codigo_dni': codigoDni.trim(),
            'password': password.trim(),
          }),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Tiempo de espera agotado al iniciar sesión'),
        );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      final token = responseBody['token'];

      await _secureStorage.write(key: 'auth_token', value: token);

      return token;
    } else {
      final body = _tryParseError(response.body);
      throw Exception(
        'Error ${response.statusCode} al iniciar sesión: $body',
      );
    }
  }

  // Recupera el token almacenado
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  // Elimina el token almacenado (logout)
  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  /// Verifica si la respuesta indica token expirado (401) y lanza excepción descriptiva.
  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Sesión expirada. Vuelva a iniciar sesión.');
    }
  }

  /// Intenta extraer un mensaje de error legible del cuerpo JSON.
  String _tryParseError(String body) {
    try {
      final decoded = json.decode(body);
      return decoded['message'] ?? decoded['error'] ?? body;
    } catch (_) {
      return body;
    }
  }

  // Método POST genérico
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));

    _checkUnauthorized(response);

    if (response.statusCode >= 400) {
      final msg = _tryParseError(response.body);
      throw Exception('Error ${response.statusCode} en POST $endpoint: $msg');
    }

    return response;
  }

  // Método GET genérico
  Future<http.Response> get(String endpoint) async {
    final token = await getToken();
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    _checkUnauthorized(response);

    if (response.statusCode >= 400) {
      final msg = _tryParseError(response.body);
      throw Exception('Error ${response.statusCode} en GET $endpoint: $msg');
    }

    return response;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final response = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));

    _checkUnauthorized(response);

    if (response.statusCode >= 400) {
      final msg = _tryParseError(response.body);
      throw Exception('Error ${response.statusCode} en PUT $endpoint: $msg');
    }

    return response;
  }
}

