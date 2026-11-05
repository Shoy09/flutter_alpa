import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/models/photo_draft.dart';
import 'package:i_miner/models/photo_proceso.dart';

class PhotoImportException implements Exception {
  final String message;
  const PhotoImportException(this.message);
  @override
  String toString() => message;
}

/// El teléfono nunca recibe ni almacena la clave de Gemini.
class PhotoService {
  /// PHOTO_IMPORT_BASE permite apuntar a otra API al compilar.
  static const baseUrl = String.fromEnvironment(
    'PHOTO_IMPORT_BASE',
    defaultValue: ApiConfig.baseUrl,
  );
  static String urlPara(PhotoProceso proceso) =>
      '$baseUrl/${proceso.ruta}/preview';

  final http.Client _client;
  final PhotoProceso proceso;

  /// Solo para pruebas: reemplaza la URL del proceso.
  final String? url;
  PhotoService({
    this.proceso = PhotoProceso.talLargo,
    http.Client? client,
    this.url,
  }) : _client = client ?? http.Client();

  Future<PhotoDraft> read({
    required Uint8List bytes,
    required String mimeType,
    required String token,
    required List<Map<String, String>> catalogo,
  }) async {
    final uri = Uri.tryParse(url ?? urlPara(proceso));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const PhotoImportException(
        'La lectura con Gemini aún no está configurada. Puedes completar '
        'la vista previa manualmente usando la foto.',
      );
    }
    if (token.isEmpty || token == 'offline') {
      throw const PhotoImportException(
        'Inicia sesión con internet para leer la foto.',
      );
    }
    if (bytes.length > 8 * 1024 * 1024) {
      throw const PhotoImportException(
        'La foto supera 8 MB. Selecciona una foto más pequeña.',
      );
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'mimeType': mimeType,
              'image': base64Encode(bytes),
              'catalogo': catalogo,
            }),
          )
          .timeout(const Duration(seconds: 100));
      if (response.statusCode != 200) {
        // El servidor explica el motivo (ej. "Gemini respondió con error 503").
        String? motivo;
        try {
          motivo = (jsonDecode(response.body) as Map)['error']?.toString();
        } catch (_) {}
        if (kDebugMode) {
          debugPrint('[FOTO] HTTP ${response.statusCode}: ${response.body}');
        }
        throw PhotoImportException(switch (response.statusCode) {
          401 => 'La sesión expiró. Inicia sesión nuevamente.',
          403 => 'Solo un usuario master puede leer registros por foto.',
          413 => 'La foto es demasiado grande.',
          429 => motivo == null || motivo.isEmpty
              ? 'Se alcanzó el límite de lecturas. Intenta más tarde.'
              : motivo,
          404 || 503 =>
            'La lectura de fotos con Gemini todavía no está habilitada en el servidor.',
          _ =>
            'No se pudo leer la foto (error ${response.statusCode}'
                '${motivo == null || motivo.isEmpty ? '' : ': $motivo'}). '
                'Puedes reintentar o completar los datos manualmente.',
        });
      }
      if (kDebugMode) {
        // TEMPORAL: respuesta cruda de Gemini para revisar la lectura.
        final data = jsonDecode(response.body) as Map;
        for (final (i, a) in (data['actividades'] as List).indexed) {
          // Todos los campos con valor (observaciones, metros, viajes…).
          final campos = (a as Map).entries
              .where((e) => e.value != null && e.value != '' && e.value is! List)
              .map((e) => '${e.key}=${e.value}')
              .join(' ');
          final listas = a.entries
              .where((e) => e.value is List && (e.value as List).isNotEmpty)
              .map((e) => '${e.key}=${jsonEncode(e.value)}')
              .join(' ');
          debugPrint('[FOTO] Gemini actividad ${i + 1}: $campos $listas');
        }
        debugPrint('[FOTO] Gemini horometros: ${jsonEncode(data['horometros'])}');
        debugPrint('[FOTO] Gemini advertencias: ${data['advertencias']}');
      }
      return PhotoDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
        proceso: proceso,
      );
    } on PhotoImportException {
      rethrow;
    } on TimeoutException {
      throw const PhotoImportException(
        'La lectura tardó demasiado. Intenta nuevamente.',
      );
    } on FormatException {
      throw const PhotoImportException(
        'La lectura devolvió datos incompletos. Revisa la foto manualmente.',
      );
    } on TypeError {
      throw const PhotoImportException(
        'La lectura devolvió un formato inválido. Intenta nuevamente.',
      );
    } on http.ClientException {
      throw const PhotoImportException(
        'No hay conexión con el servicio de lectura.',
      );
    }
  }

  void close() => _client.close();
}
