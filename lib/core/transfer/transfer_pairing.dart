import 'dart:convert';
import 'local_transfer_client.dart';

/// Connection data only; never contains operation data or joins Wi-Fi.
class TransferPairing {
  const TransferPairing(this.host, this.code);
  final String host;
  final String code;

  String encode() => jsonEncode({
    'app': 'i_miner_transfer',
    'version': 1,
    'host': host,
    'port': 47831,
    'code': code,
  });

  static TransferPairing parse(String raw) {
    const error = FormatException('QR de conexión no válido para I-MINER.');
    if (raw.length > 1024) throw error;
    final dynamic value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      throw error;
    }
    if (value is! Map ||
        value['app'] != 'i_miner_transfer' ||
        value['version'] != 1 ||
        value['port'] != 47831 ||
        value['host'] is! String ||
        value['code'] is! String) {
      throw error;
    }
    final host = value['host'] as String;
    final code = value['code'] as String;
    if (!LocalTransferClient.privateAddress(host) ||
        !RegExp(r'^\d{8}$').hasMatch(code)) {
      throw error;
    }
    return TransferPairing(host, code);
  }
}
