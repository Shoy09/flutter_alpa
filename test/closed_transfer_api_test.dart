import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';

void main() {
  test(
    'recovery lookup only calls read-only UUID route and has no create fallback',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, endsWith('/operaciones/lookup-sync'));
        final body = jsonDecode(request.body);
        expect(body['hash'], 'huella');
        return http.Response(
          '{"ok":true,"data":{"status":"missing","sync_uuid":"uuid","hash":"huella"}}',
          200,
        );
      });
      addTearDown(client.close);
      final result = await OperacionesService(
        client: client,
      ).lookupSync('empernador', {'sync_uuid': 'uuid'}, 'huella');
      expect(result['status'], 'missing');
      expect(calls, 1);
    },
  );

  test(
    'unavailable recovery route reports error and never falls back to create',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, endsWith('/operaciones/lookup-sync'));
        return http.Response('Cannot POST', 404);
      });
      addTearDown(client.close);
      await expectLater(
        OperacionesService(client: client).lookupSync('empernador', {}, 'hash'),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );
  test(
    'closed transfer sends fingerprint and requires explicit confirmation response',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          endsWith('/operaciones/confirm-closed-transfer'),
        );
        final body = jsonDecode(request.body) as Map;
        expect(body['tipo'], 'tal_horizontal');
        expect(body['hash'], 'huella');
        expect(body['payload']['estado'], 'cerrado');
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'status': 'confirmed',
              'server_id': 42,
              'hash': 'huella',
              'sync_uuid': 'uuid',
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final response = await OperacionesService(client: client)
          .confirmClosedTransfer('tal_horizontal', {
            'estado': 'cerrado',
          }, 'huella');
      expect(response['status'], 'confirmed');
      expect(response['server_id'], 42);
    },
  );

  test(
    'old API or invalid response never produces a cloud confirmation',
    () async {
      for (final response in [
        http.Response('Cannot POST', 404),
        http.Response('{"ok":false}', 200),
        http.Response('invalid', 200),
      ]) {
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        await expectLater(
          OperacionesService(client: client).confirmClosedTransfer(
            'tal_horizontal',
            {'estado': 'cerrado'},
            'huella',
          ),
          throwsA(anything),
        );
      }
    },
  );
}
