import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/core/transfer/transfer_pairing.dart';

void main() {
  test('QR preserves private address and leading zeros in session code', () {
    final value = TransferPairing.parse(
      const TransferPairing('192.168.43.1', '00123456').encode(),
    );
    expect(value.host, '192.168.43.1');
    expect(value.code, '00123456');
  });
  test('rejects foreign QR, public hosts, unsupported ports and versions', () {
    final original =
        jsonDecode(const TransferPairing('10.0.0.1', '12345678').encode())
            as Map<String, dynamic>;
    for (final change in [
      {'app': 'other'},
      {'version': 2},
      {'port': 80},
      {'host': '8.8.8.8'},
      {'host': 'https://example.com'},
      {'code': 12345678},
      {'code': '123'},
      {'host': '192.168.1.999'},
    ]) {
      expect(
        () => TransferPairing.parse(jsonEncode({...original, ...change})),
        throwsFormatException,
      );
    }
    expect(() => TransferPairing.parse('not json'), throwsFormatException);
    expect(() => TransferPairing.parse('x' * 1025), throwsFormatException);
  });
}
