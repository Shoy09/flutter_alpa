import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class OperacionesService implements OperationSyncApi {
  OperacionesService({http.Client? client})
    : _client = client ?? _defaultClient;
  static final http.Client _defaultClient = http.Client();
  final http.Client _client;
  String lastCapabilityProblem = '';

  Future<Map<String, dynamic>> resolveClosedTransfer(
    String type,
    Map<String, dynamic> payload,
    String hash,
    String? remoteHash,
    bool verifiedAbsent,
  ) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/operaciones/confirm-closed-transfer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'tipo': type,
            'payload': payload,
            'hash': hash,
            'review': {
              'expected_remote_hash': remoteHash,
              'verified_absent': verifiedAbsent,
            },
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'La API no confirmó la conciliación (${response.statusCode})',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['ok'] != true || body['data'] is! Map) {
      throw StateError('Respuesta de conciliación inválida');
    }
    return Map<String, dynamic>.from(body['data']);
  }

  Future<Map<String, dynamic>> lookupSync(
    String type,
    Map<String, dynamic> payload,
    String hash,
  ) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/operaciones/lookup-sync'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tipo': type, 'payload': payload, 'hash': hash}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Consulta de recuperación HTTP ${response.statusCode}. No se creó ningún registro.',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['ok'] != true || body['data'] is! Map) {
      throw StateError('Consulta de recuperación inválida');
    }
    return Map<String, dynamic>.from(body['data']);
  }

  Future<Map<String, dynamic>> confirmClosedTransfer(
    String type,
    Map<String, dynamic> payload,
    String hash,
  ) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/operaciones/confirm-closed-transfer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tipo': type, 'payload': payload, 'hash': hash}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('Confirmación de transferencia no disponible');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['ok'] != true || body['data'] is! Map) {
      throw StateError('Confirmación de transferencia inválida');
    }
    return Map<String, dynamic>.from(body['data']);
  }

  @override
  Future<bool> supportsIdempotentCreates() async {
    lastCapabilityProblem = '';
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/operaciones/sync-capabilities'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        lastCapabilityProblem =
            'La comprobación respondió HTTP ${response.statusCode}.';
        return false;
      }
      final body = jsonDecode(response.body);
      final supported =
          body is Map && body['ok'] == true && body['sync_uuid_version'] == 1;
      if (!supported) {
        lastCapabilityProblem = 'La API no confirmó el protocolo UUID.';
      }
      return supported;
    } catch (error) {
      lastCapabilityProblem = 'No se pudo completar la comprobación: $error';
      return false;
    }
  }

  @override
  Future<List<dynamic>> actualizarMasivoResultados(
    String tipo,
    List<dynamic> data,
  ) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.baseUrl}/operaciones/update-masivo'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tipo': tipo, 'data': data}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('No se confirmó la actualización.');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['ok'] != true || body['data'] is! List) {
      throw StateError('Respuesta de actualización inválida.');
    }
    return body['data'] as List<dynamic>;
  }

  static const _timeout = Duration(seconds: 30);

  // ✅ CREAR (uno o varios)
  Future<bool> crear(String tipo, dynamic data) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/operaciones/crear');

      final body = jsonEncode({"tipo": tipo, "data": data});

      debugPrint("📤 URL: $url");

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      debugPrint("📥 STATUS: ${response.statusCode}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error crear: $e');
      return false;
    }
  }

  @override
  Future<List<dynamic>?> crearParciales(String tipo, dynamic data) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/operaciones/crear');

      final body = jsonEncode({"tipo": tipo, "data": data});

      debugPrint("📤 URL: $url");

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      debugPrint("📥 STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is! Map ||
            jsonData['ok'] != true ||
            jsonData['data'] is! List) {
          throw StateError('Respuesta de creación inválida.');
        }
        return jsonData['data'];
      }

      String detail = '';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody['error'] != null) {
          detail = '${errorBody['error']}';
          if (detail.length > 300) detail = detail.substring(0, 300);
        }
      } catch (_) {}
      throw StateError(
        'Creación HTTP ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}',
      );
    } catch (e) {
      debugPrint('❌ Error crearParciales: $e');

      // El motor conserva los POST sin confirmación para evitar duplicarlos.
      rethrow;
    }
  }

  // ✅ ACTUALIZAR MASIVO
  Future<bool> actualizarMasivo(String tipo, List<dynamic> data) async {
    final results = await actualizarMasivoResultados(tipo, data);
    final confirmed = results
        .whereType<Map>()
        .where((row) => row['actualizado'] == true)
        .map((row) => OperationSyncEngine.integer(row['idNube']))
        .toSet();
    return data.every(
      (row) => confirmed.contains(OperationSyncEngine.integer(row['idNube'])),
    );
  }

  // ✅ GET (con filtros)
  Future<List<dynamic>> obtener(
    String tipo, {
    String? estado,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      String url =
          '${ApiConfig.baseUrl}/operaciones/$tipo?limit=$limit&offset=$offset';

      if (estado != null) {
        url += '&estado=$estado';
      }

      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['data'];
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error obtener: $e');
      return [];
    }
  }
}
