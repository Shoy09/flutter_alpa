import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'transfer_coordinator.dart';

class LocalTransferClient {
  int cloudConfirmed = 0;
  int deliveredToMaster = 0;
  int pendingReview = 0;
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
        final request = await client.postUrl(
          Uri(scheme: 'http', host: host, port: port, path: '/transfer'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set('X-Transfer-Code', code);
        request.write(jsonEncode(packet));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        final text = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw StateError(
            'La maestra no confirmó la recepción (${response.statusCode}). Puedes reintentar.',
          );
        }
        final body = jsonDecode(text) as Map;
        if (body['ok'] != true || body['receipt'] is! Map) {
          throw StateError('Respuesta local inválida');
        }
        final receipt = Map<String, dynamic>.from(body['receipt']);
        final applied = await coordinator.applyReceipt(packet, receipt);
        if (applied == 'cloud') cloudConfirmed++;
        if (applied == 'delivered') deliveredToMaster++;
        if (applied == 'review') pendingReview++;
        if (receipt['status'] == 'conflict') {
          throw StateError(
            'La maestra ya tiene otra versión. Se conservan ambas copias para revisión.',
          );
        }
        delivered++;
      }
      return delivered;
    } finally {
      client.close(force: true);
    }
  }
}
