import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'transfer_coordinator.dart';

class LocalTransferClient {
  int cloudConfirmed = 0;
  int deliveredToMaster = 0;
  int pendingReview = 0;
  int failed = 0;
  final problems = <String>[];

  /// Mismo límite que acepta la maestra; se avisa sin intentar el envío.
  static const maxPacketBytes = 2 * 1024 * 1024;

  static bool privateAddress(String host) {
    final address = InternetAddress.tryParse(host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return false;
    }
    final bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31);
  }

  /// Respuestas que afectan a toda la sesión (código incorrecto, bloqueo
  /// temporal o maestra saturada): no tiene sentido seguir con más paquetes.
  static bool _sessionStatus(int code) =>
      code == 403 || code == 429 || code == 503;

  Future<int> send(
    TransferCoordinator coordinator,
    String source,
    String host,
    String code, {
    int port = 47831,
    bool allowLoopback = false,
  }) async {
    cloudConfirmed = 0;
    deliveredToMaster = 0;
    pendingReview = 0;
    failed = 0;
    problems.clear();
    if ((!privateAddress(host) && !(allowLoopback && host == '127.0.0.1')) ||
        !RegExp(r'^\d{8}$').hasMatch(code)) {
      throw FormatException(
        'Introduce la IP local y el código de ocho dígitos de la maestra.',
      );
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    var delivered = 0;
    try {
      for (final packet in await coordinator.prepare(source)) {
        final label = '${packet['type']} ${packet['payload']?['fecha'] ?? ''}'
            .trim();
        final body = utf8.encode(jsonEncode(packet));
        if (body.length > maxPacketBytes) {
          failed++;
          problems.add(
            '$label: la operación supera 2 MB y la maestra no la acepta. Súbela con internet.',
          );
          continue;
        }
        final int status;
        final String text;
        try {
          final request = await client.postUrl(
            Uri(scheme: 'http', host: host, port: port, path: '/transfer'),
          );
          request.headers.contentType = ContentType.json;
          request.headers.set('X-Transfer-Code', code);
          request.add(body);
          final response = await request.close().timeout(
            const Duration(seconds: 30),
          );
          status = response.statusCode;
          text = await utf8.decoder
              .bind(response)
              .join()
              .timeout(const Duration(seconds: 30));
        } on Object catch (error) {
          if (error is TimeoutException || error is IOException) {
            // La maestra dejó de responder: detener, lo enviado queda guardado.
            throw StateError(
              'Se perdió la conexión con la maestra. ${_summary(delivered)} Puedes reintentar.',
            );
          }
          rethrow;
        }
        if (_sessionStatus(status)) {
          throw StateError(
            'La maestra no confirmó la recepción ($status). '
            '${status == 403 ? 'Revisa el código. ' : ''}${_summary(delivered)} Puedes reintentar.',
          );
        }
        try {
          if (status != 200) {
            throw StateError('La maestra no aceptó la operación ($status).');
          }
          final decoded = jsonDecode(text) as Map;
          if (decoded['ok'] != true || decoded['receipt'] is! Map) {
            throw StateError('Respuesta local inválida');
          }
          final receipt = Map<String, dynamic>.from(decoded['receipt']);
          final applied = await coordinator.applyReceipt(packet, receipt);
          if (applied == 'cloud') cloudConfirmed++;
          if (applied == 'delivered') deliveredToMaster++;
          if (applied == 'review') pendingReview++;
          delivered++;
        } on Object catch (error) {
          // Un paquete con problemas no debe impedir la entrega de los demás.
          failed++;
          problems.add('$label: ${'$error'.replaceFirst('Bad state: ', '')}');
        }
      }
      if (problems.isNotEmpty) {
        throw StateError(
          '${_summary(delivered)}\n${problems.join('\n')}',
        );
      }
      return delivered;
    } finally {
      client.close(force: true);
    }
  }

  String _summary(int delivered) =>
      'Entregadas: $delivered · Con problemas: $failed.';
}
