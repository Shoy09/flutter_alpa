import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/core/sync/unconfirmed_recovery.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const type = 'tal_horizontal';

String uuidFor(int id) =>
    '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';

class _Api implements OperationSyncApi {
  final creates = <List<OperationPayload>>[];
  final updates = <List<OperationPayload>>[];
  Future<List<dynamic>?> Function(List<OperationPayload>)? onCreate;

  @override
  Future<bool> supportsIdempotentCreates() async => true;

  @override
  Future<List<dynamic>?> crearParciales(String type, dynamic data) async {
    final rows = List<OperationPayload>.from(data as List);
    creates.add(rows);
    if (onCreate != null) return onCreate!(rows);
    return [
      for (final row in rows)
        {
          'local_id': row['local_id'],
          'server_id': 1000 + (row['local_id'] as int),
          'sync_uuid': row['sync_uuid'],
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
    return [
      for (final row in rows) {'idNube': row['idNube'], 'actualizado': true},
    ];
  }
}

Future<List<OperationPayload>> prepare(
  Set<int> _,
  List<OperationPayload> rows,
) async => [
  for (final row in rows)
    {
      for (final field in TransferContent.fields(type))
        field:
            row[field] ??
            (TransferContent.jsonFields.contains(field) ? '{}' : ''),
      'local_id': row['id'],
      'idNube': row['idNube'] ?? 0,
      'sync_uuid': row['sync_uuid'],
      'envio': row['envio'] ?? 0,
    },
];

void main() {
  late Database db;
  late _Api api;
  var now = DateTime(2026, 10, 26, 8);

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final fields = TransferContent.fields(type).toSet()..remove('estado');
    await db.execute(
      'CREATE TABLE operations (id INTEGER PRIMARY KEY, idNube INTEGER DEFAULT 0, '
      'envio REAL DEFAULT 0, estado TEXT, sync_uuid TEXT, '
      'sync_retry_safe INTEGER NOT NULL DEFAULT 0, sync_cloud_hash TEXT, '
      'sync_failures INTEGER NOT NULL DEFAULT 0, sync_last_error TEXT, '
      'sync_next_attempt INTEGER, '
      '${fields.map((field) => '$field TEXT').join(', ')})',
    );
    api = _Api();
    now = DateTime(2026, 10, 26, 8);
  });
  tearDown(() => db.close());

  Future<void> insert(
    int id, {
    double envio = 0,
    int cloud = 0,
    String estado = 'cerrado',
    int safe = 0,
    String registros = '[]',
  }) => db.insert('operations', {
    'id': id,
    'idNube': cloud,
    'envio': envio,
    'estado': estado,
    'sync_uuid': uuidFor(id),
    'sync_retry_safe': safe,
    'registros': registros,
    'operador': 'OPERADOR $id',
  });

  Future<Map<String, Object?>> row(int id) async =>
      (await db.query('operations', where: 'id = ?', whereArgs: [id])).single;

  SqliteOperationSyncStore store() =>
      SqliteOperationSyncStore(db, 'operations', now: () => now);

  OperationSyncEngine engine({bool Function()? shouldStop}) =>
      OperationSyncEngine(
        store: store(),
        api: api,
        prepare: prepare,
        idempotentCreates: true,
        batchSize: 25,
        shouldStop: shouldStop,
      );

  test('large queues are sent in batches and one failed batch does not block the rest', () async {
    for (var id = 1; id <= 60; id++) {
      await insert(id);
    }
    var call = 0;
    api.onCreate = (rows) async {
      call++;
      if (call == 1) throw StateError('Creación HTTP 413: payload too large');
      return [
        for (final row in rows)
          {
            'local_id': row['local_id'],
            'server_id': 1000 + (row['local_id'] as int),
            'sync_uuid': row['sync_uuid'],
            'creado': true,
          },
      ];
    };
    final result = await engine().sync(type);
    expect(api.creates.map((batch) => batch.length), [25, 25, 10]);
    expect(result.created, 35);
    expect(result.retryable, 25);
    expect((await row(1))['envio'], 3);
    expect((await row(1))['sync_failures'], 1);
    expect('${(await row(1))['sync_last_error']}', contains('413'));
    // Un fallo del lote completo no aplica espera progresiva.
    expect((await row(1))['sync_next_attempt'], isNull);
    expect((await row(60))['envio'], 1);
    expect((await row(60))['idNube'], 1060);
  });

  test('a network failure stops the remaining batches of the cycle', () async {
    for (var id = 1; id <= 30; id++) {
      await insert(id);
    }
    api.onCreate = (_) async => throw const SocketException('offline');
    final result = await engine().sync(type);
    expect(api.creates.length, 1);
    expect(result.networkFailed, isTrue);
    expect((await row(30))['envio'], 0);
  });

  test('automatic sync yields between batches when someone is waiting', () async {
    for (var id = 1; id <= 30; id++) {
      await insert(id);
    }
    var waiting = false;
    api.onCreate = (rows) async {
      waiting = true;
      return [
        for (final row in rows)
          {
            'local_id': row['local_id'],
            'server_id': 1000 + (row['local_id'] as int),
            'sync_uuid': row['sync_uuid'],
            'creado': true,
          },
      ];
    };
    final result = await engine(shouldStop: () => waiting).sync(type);
    expect(api.creates.length, 1);
    expect(result.interrupted, isTrue);
    expect((await row(30))['envio'], 0);
  });

  test('repeated row rejections back off automatically but manual send still tries', () async {
    await insert(1);
    await insert(2);
    api.onCreate = (rows) async => [
      for (final row in rows)
        row['local_id'] == 1
            ? {'local_id': 1, 'creado': false, 'error': 'Dato fuera de rango'}
            : {
                'local_id': row['local_id'],
                'server_id': 900,
                'sync_uuid': row['sync_uuid'],
                'creado': true,
              },
    ];
    for (var attempt = 0; attempt < 3; attempt++) {
      await engine().sync(type);
    }
    expect(api.creates.length, 3);
    expect((await row(1))['sync_failures'], 3);
    expect((await row(1))['sync_last_error'], 'Dato fuera de rango');
    final waiting = await engine().sync(type);
    expect(api.creates.length, 3, reason: 'en espera: no se vuelve a enviar');
    expect(waiting.deferred, 1);
    expect(waiting.message, contains('En espera tras fallos repetidos: 1'));

    api.onCreate = null;
    final manual = await engine().sync(type, ids: {1});
    expect(manual.created, 1);
    expect((await row(1))['sync_failures'], 0);
    expect((await row(1))['sync_last_error'], isNull);
    expect((await row(1))['sync_next_attempt'], isNull);
  });

  test('backoff expires and the automatic cycle retries the row', () async {
    await insert(1);
    api.onCreate = (_) async => [
      {'local_id': 1, 'creado': false, 'error': 'Rechazado'},
    ];
    for (var attempt = 0; attempt < 3; attempt++) {
      await engine().sync(type);
    }
    expect((await engine().sync(type)).deferred, 1);
    now = now.add(const Duration(minutes: 6));
    api.onCreate = null;
    expect((await engine().sync(type)).created, 1);
  });

  test('unchanged active operations are not PUT again every cycle', () async {
    await insert(1, envio: 0.5, cloud: 70, estado: 'activo');
    final payload = (await prepare({1}, [await row(1)])).single
      ..['envio'] = 0.5;
    await db.update('operations', {
      'sync_cloud_hash': TransferContent.fingerprint(type, payload),
    });
    final quiet = await engine().sync(type);
    expect(api.updates, isEmpty);
    expect(quiet.unchanged, 1);

    await db.update('operations', {'registros': '[{"avance":2}]'});
    final changed = await engine().sync(type);
    expect(changed.updated, 1);
    expect(api.updates.single.single['registros'], '[{"avance":2}]');
  });

  test('manual selection explains rows that were not available to send', () async {
    await insert(1);
    final result = await engine().sync(type, ids: {1, 7});
    expect(result.created, 1);
    expect(result.errors.single, contains('Registro local 7'));
    expect(result.errors.single, contains('transferencia'));
  });

  test('one row without identity does not stop the rest of its type', () async {
    await insert(1);
    await insert(2);
    await db.update('operations', {'sync_uuid': 'sin-clave'}, where: 'id = 1');
    final result = await engine().sync(type);
    expect(result.created, 1);
    expect(api.creates.single.single['local_id'], 2);
    expect(result.errors.single, contains('Registro local 1'));
  });

  test('one row over the byte limit is reported and later rows still send', () async {
    final oversized = jsonEncode([
      {'dato': List.filled(5000, 'x').join()},
    ]);
    await insert(1, registros: oversized);
    await insert(2);
    const maxBytes = 2048;
    final result = await OperationSyncEngine(
      store: store(),
      api: api,
      prepare: prepare,
      idempotentCreates: true,
      maxRequestBytes: maxBytes,
    ).sync(type);

    expect(result.created, 1);
    expect(result.errors.join('\n'), contains('Registro local 1'));
    expect(api.creates.expand((batch) => batch).map((r) => r['local_id']), [
      2,
    ]);
    for (final batch in api.creates) {
      expect(
        utf8.encode(jsonEncode({'tipo': type, 'data': batch})).length,
        lessThanOrEqualTo(maxBytes),
      );
    }
    expect((await row(1))['envio'], 0);
    expect((await row(1))['sync_failures'], 1);
    expect('${(await row(1))['sync_last_error']}', contains('supera'));
    expect((await row(2))['envio'], 1);
  });

  group('unconfirmed recovery', () {
    UnconfirmedRecovery recovery(
      Future<Map<String, dynamic>> Function(String, OperationPayload, String)
      lookup,
    ) => UnconfirmedRecovery(
      type: type,
      store: store(),
      prepare: prepare,
      lookup: lookup,
    );

    test('a failing record does not block recovery of the next ones', () async {
      await insert(1, envio: 3);
      await insert(2, envio: 3);
      final result = await recovery((_, payload, hash) async {
        if (payload['sync_uuid'] == uuidFor(1)) {
          throw StateError('HTTP 500');
        }
        return {
          'sync_uuid': payload['sync_uuid'],
          'hash': hash,
          'status': 'confirmed',
          'server_id': 802,
        };
      }).run();
      expect(result.recovered, 1);
      expect((await row(2))['idNube'], 802);
      expect((await row(1))['envio'], 3);
    });

    test('a network failure stops the remaining lookups', () async {
      await insert(1, envio: 3);
      await insert(2, envio: 3);
      var calls = 0;
      final result = await recovery((_, _, _) async {
        calls++;
        throw TimeoutException('sin red');
      }).run();
      expect(calls, 1);
      expect(result.networkFailed, isTrue);
    });

    test('conflict and missing answers are recorded on the row', () async {
      await insert(1, envio: 3);
      await recovery(
        (_, payload, hash) async => {
          'sync_uuid': payload['sync_uuid'],
          'hash': hash,
          'status': 'missing',
        },
      ).run();
      expect((await row(1))['envio'], 3);
      expect((await row(1))['sync_failures'], 1);
      expect('${(await row(1))['sync_last_error']}', contains('UUID'));
    });
  });

  test('gate reports waiters so automatic work can yield', () async {
    final gate = OperationSyncGate();
    final release = Completer<void>();
    final started = Completer<void>();
    var sawWaiter = false;
    final first = gate.run(() async {
      started.complete();
      await release.future;
      sawWaiter = gate.hasWaiters;
    });
    await started.future;
    expect(gate.hasWaiters, isFalse);
    final second = gate.run(() async => gate.hasWaiters);
    release.complete();
    await first;
    expect(sawWaiter, isTrue);
    expect(await second, isFalse);
  });
}
