import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Api implements OperationSyncApi {
  @override
  Future<bool> supportsIdempotentCreates() async => true;
  final creates = <List<OperationPayload>>[];
  final updates = <List<OperationPayload>>[];
  Future<List<dynamic>?> Function(List<OperationPayload>)? onCreate;
  Future<List<dynamic>> Function(List<OperationPayload>)? onUpdate;
  @override
  Future<List<dynamic>?> crearParciales(String type, dynamic data) async {
    final rows = List<OperationPayload>.from(data as List);
    creates.add(rows);
    return onCreate != null
        ? onCreate!(rows)
        : [
            for (final row in rows)
              {
                'local_id': row['local_id'],
                'server_id': 500 + (row['local_id'] as int),
                'creado': true,
              },
          ];
  }

  @override
  Future<List<dynamic>> actualizarMasivoResultados(
    String type,
    List<dynamic> data,
  ) async {
    final rows = List<OperationPayload>.from(data);
    updates.add(rows);
    return onUpdate != null
        ? onUpdate!(rows)
        : [
            for (final row in rows)
              {'idNube': row['idNube'], 'actualizado': true},
          ];
  }
}

void main() {
  late Database db;
  late _Api api;
  Future<void> insert(
    int id, {
    int cloud = 0,
    double envio = 0,
    String estado = 'cerrado',
  }) => db
      .insert('operations', {
        'id': id,
        'idNube': cloud,
        'envio': envio,
        'estado': estado,
        'registros': '[]',
      })
      .then((_) {});
  Future<Map<String, Object?>> row(int id) async =>
      (await db.query('operations', where: 'id = ?', whereArgs: [id])).single;
  OperationSyncEngine engine({
    OperationSyncApi? service,
    bool idempotent = false,
  }) => OperationSyncEngine(
    store: SqliteOperationSyncStore(db, 'operations'),
    api: service ?? api,
    idempotentCreates: idempotent,
    prepare: (ids, rows) async => [
      for (final row in rows)
        Map<String, dynamic>.from(row)
          ..['local_id'] = row['id']
          ..remove('id'),
    ],
  );

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE operations (id INTEGER PRIMARY KEY, idNube INTEGER, envio REAL, estado TEXT, registros TEXT, sync_uuid TEXT, sync_retry_safe INTEGER NOT NULL DEFAULT 0)',
    );
    api = _Api();
  });
  tearDown(() async => db.close());

  const identity = 'c734e68b-9fad-4f42-9711-920cc2d4b84e';

  Future<void> identified(
    int id, {
    double envio = 0,
    int safe = 0,
    int cloud = 0,
  }) async {
    await insert(id, envio: envio, cloud: cloud);
    await db.update(
      'operations',
      {'sync_uuid': identity, 'sync_retry_safe': safe},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  test(
    'Lost POST response retries same UUID and then updates recovered data',
    () async {
      await identified(1);
      api.onCreate = (_) async => throw TimeoutException('lost response');
      final first = await engine(
        idempotent: true,
      ).sync('tal_horizontal', ids: {1});
      expect(first.retryable, 1);
      expect(first.uncertain, 0);
      expect((await row(1))['sync_retry_safe'], 1);
      expect((await row(1))['envio'], 3);
      api.onCreate = (rows) async => [
        {
          'local_id': 1,
          'server_id': 800,
          'sync_uuid': rows.single['sync_uuid'],
          'creado': true,
          'reutilizado': true,
        },
      ];
      await db.update('operations', {'registros': '[2]'}, where: 'id = 1');
      final retry = await engine(idempotent: true).sync('tal_horizontal');
      expect(retry.recovered, 1);
      expect((await row(1))['idNube'], 800);
      expect((await row(1))['envio'], 0.5);
      expect(api.creates.length, 2);
      expect(
        api.creates.first.single['sync_uuid'],
        api.creates.last.single['sync_uuid'],
      );
      expect(api.creates.last.single.containsKey('sync_retry_safe'), isFalse);
      await engine(idempotent: true).sync('tal_horizontal');
      expect(api.updates.single.single['idNube'], 800);
      expect(api.updates.single.single['registros'], '[2]');
      expect((await row(1))['envio'], 1);
    },
  );

  test(
    'Interrupted protected POST in state 2 can be recovered after restart',
    () async {
      await identified(1, envio: 2, safe: 1);
      api.onCreate = (rows) async => [
        {
          'local_id': 1,
          'server_id': 800,
          'sync_uuid': identity,
          'creado': true,
        },
      ];
      final result = await engine(idempotent: true).sync('tal_horizontal');
      expect(result.created, 1);
      expect((await row(1))['envio'], 1);
    },
  );

  test(
    'Legacy uncertain and interrupted rows stay blocked despite new UUID',
    () async {
      for (final state in [2.0, 3.0]) {
        await identified(1, envio: state);
        final result = await engine(idempotent: true).sync('tal_horizontal');
        expect(result.uncertain, 1);
        expect(api.creates, isEmpty);
        expect((await row(1))['sync_retry_safe'], 0);
        await db.delete('operations');
      }
    },
  );

  test(
    'Protected retries stay blocked when server capability is unavailable',
    () async {
      await identified(1, envio: 3, safe: 1);
      final result = await engine().sync('tal_horizontal', ids: {1});
      expect(result.uncertain, 1);
      expect(api.creates, isEmpty);
    },
  );

  test('Interrupted updates use known cloud ID without another POST', () async {
    await identified(1, envio: 2, cloud: 80);
    final result = await engine().sync('tal_horizontal');
    expect(result.updated, 1);
    expect(api.creates, isEmpty);
    expect(api.updates.single.single['idNube'], 80);
  });

  test(
    'Mismatched UUID acknowledgement never links a wrong remote ID',
    () async {
      await identified(1);
      api.onCreate = (_) async => [
        {'local_id': 1, 'server_id': 800, 'sync_uuid': 'wrong', 'creado': true},
      ];
      final result = await engine(idempotent: true).sync('tal_horizontal');
      expect(result.retryable, 1);
      expect((await row(1))['idNube'], 0);
    },
  );

  test(
    'Capability probe requires a valid affirmative server response',
    () async {
      for (final code in [200, 404, 503]) {
        final client = MockClient((request) async {
          expect(request.url.path, endsWith('/operaciones/sync-capabilities'));
          return http.Response('{"ok":true,"sync_uuid_version":1}', code);
        });
        addTearDown(client.close);
        expect(
          await OperacionesService(client: client).supportsIdempotentCreates(),
          code == 200,
        );
      }
      final client = MockClient((_) async => http.Response('not-json', 200));
      addTearDown(client.close);
      expect(
        await OperacionesService(client: client).supportsIdempotentCreates(),
        isFalse,
      );
    },
  );

  test(
    'Create and update use the persisted identity despite stale previews',
    () async {
      await insert(1);
      const key = 'c734e68b-9fad-4f42-9711-920cc2d4b84e';
      await db.update('operations', {'sync_uuid': key}, where: 'id = 1');
      OperationSyncEngine subject() => OperationSyncEngine(
        store: SqliteOperationSyncStore(db, 'operations'),
        api: api,
        prepare: (ids, rows) async => [
          for (final row in rows)
            {'local_id': row['id'], 'sync_uuid': 'copia-obsoleta'},
        ],
      );
      await subject().sync('tal_horizontal', ids: {1});
      expect(api.creates.single.single['sync_uuid'], key);
      await db.update('operations', {'envio': 0.5}, where: 'id = 1');
      await subject().sync('tal_horizontal');
      expect(api.updates.single.single['sync_uuid'], key);
      expect(api.updates.single.single['idNube'], 501);
      expect(api.creates.length, 1);
      expect((await row(1))['sync_uuid'], key);
    },
  );

  test('A known cloud ID always updates, even when envio is zero', () async {
    await insert(1, cloud: 90);
    await insert(2);
    final result = await engine().sync('carguio');
    expect(result.created, 1);
    expect(result.updated, 1);
    expect(api.creates.single.single['local_id'], 2);
    expect(api.updates.single.single['idNube'], 90);
    expect(api.updates.single.single.containsKey('id'), isFalse);
    expect(api.updates.single.single.containsKey('local_id'), isFalse);
    expect((await row(2))['idNube'], 502);
    expect((await row(2))['envio'], 1);
  });

  test(
    'Creation responses are matched by local_id, never array position',
    () async {
      await insert(1);
      await insert(2, estado: 'activo');
      api.onCreate = (_) async => [
        {'local_id': '2', 'server_id': '902'},
        {'local_id': 1, 'server_id': 901},
      ];
      await engine().sync('tal_largo');
      expect((await row(1))['idNube'], 901);
      expect((await row(1))['envio'], 1);
      expect((await row(2))['idNube'], 902);
      expect((await row(2))['envio'], 0.5);
    },
  );

  test('Unconfirmed POST is not repeated on manual retry', () async {
    await insert(1);
    api.onCreate = (_) async =>
        throw TimeoutException('Simulated lost response');
    final first = await engine().sync('dumper', ids: {1});
    expect(first.uncertain, 1);
    expect((await row(1))['envio'], 3);
    final retry = await engine().sync('dumper', ids: {1});
    expect(retry.uncertain, 1);
    expect(api.creates.length, 1);
  });

  test('Partial creation confirms only returned local identities', () async {
    await insert(1);
    await insert(2);
    api.onCreate = (_) async => [
      {'local_id': 2, 'server_id': 700},
    ];
    final result = await engine().sync('scissor');
    expect(result.created, 1);
    expect(result.uncertain, 1);
    expect((await row(1))['envio'], 3);
    expect((await row(2))['idNube'], 700);
  });

  test(
    'HTTP 200 with per-row errors does not mark failed updates as sent',
    () async {
      await insert(1, cloud: 81);
      await insert(2, cloud: 82);
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, endsWith('/operaciones/update-masivo'));
        expect((jsonDecode(request.body)['data'] as List).first['idNube'], 81);
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': [
              {
                'idNube': 82,
                'actualizado': false,
                'error': 'Registro no encontrado',
              },
              {'idNube': 81, 'actualizado': true},
            ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final result = await engine(
        service: OperacionesService(client: client),
      ).sync('scalamin');
      expect(result.updated, 1);
      expect((await row(1))['envio'], 1);
      expect((await row(2))['envio'], 0.5);
      expect((await row(2))['idNube'], 82);
    },
  );

  test(
    'Automatic and manual requests serialize and re-read persisted IDs',
    () async {
      await insert(1);
      final started = Completer<void>();
      final response = Completer<List<dynamic>>();
      api.onCreate = (_) {
        started.complete();
        return response.future;
      };
      final gate = OperationSyncGate();
      final automatic = gate.run(() => engine().sync('empernador'));
      await started.future;
      final manual = gate.run(() => engine().sync('empernador', ids: {1}));
      response.complete([
        {'local_id': 1, 'server_id': 61},
      ]);
      await automatic;
      final result = await manual;
      expect(api.creates.length, 1);
      expect(result.created, 0);
      expect(result.updated, 0);
    },
  );

  test(
    'Local edits during upload remain pending after confirming remote ID',
    () async {
      await insert(1, estado: 'activo');
      api.onCreate = (_) async {
        await db.update('operations', {
          'estado': 'cerrado',
          'registros': '[1]',
        }, where: 'id = 1');
        return [
          {'local_id': 1, 'server_id': 71},
        ];
      };
      await engine().sync('rompebanco');
      expect((await row(1))['envio'], 0.5);
      await engine().sync('rompebanco');
      expect(api.creates.length, 1);
      expect(api.updates.single.single['registros'], '[1]');
      expect((await row(1))['envio'], 1);
    },
  );

  test(
    'Sent legacy rows without a remote ID are not blindly created again',
    () async {
      await insert(1, envio: 1);
      final result = await engine().sync('volquetes', ids: {1});
      expect(api.creates, isEmpty);
      expect(result.errors.single, contains('conciliación'));
    },
  );

  test(
    'A batch that changed before claiming rolls back without sending',
    () async {
      await insert(1);
      await insert(2);
      final subject = OperationSyncEngine(
        store: SqliteOperationSyncStore(db, 'operations'),
        api: api,
        prepare: (ids, rows) async {
          await db.delete('operations', where: 'id = 2');
          return [
            for (final row in rows)
              Map<String, dynamic>.from(row)
                ..['local_id'] = row['id']
                ..remove('id'),
          ];
        },
      );
      await expectLater(subject.sync('carguio'), throwsStateError);
      expect(api.creates, isEmpty);
      expect((await row(1))['envio'], 0);
    },
  );
}
