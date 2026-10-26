import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/core/sync/unconfirmed_recovery.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _UpdatesOnly implements OperationSyncApi {
  bool created = false;
  @override
  Future<bool> supportsIdempotentCreates() async => true;
  @override
  Future<List<dynamic>?> crearParciales(String type, dynamic data) async {
    created = true;
    throw StateError('No debe crear otra fila');
  }

  @override
  Future<List<dynamic>> actualizarMasivoResultados(
    String type,
    List<dynamic> data,
  ) async {
    expect(data.single['idNube'], 800);
    expect(data.single['estado'], 'cerrado');
    return [
      {'idNube': 800, 'actualizado': true},
    ];
  }
}

void main() {
  late Database db;
  const uuid = 'c734e68b-9fad-4f42-9711-920cc2d4b84e';
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE operations (id INTEGER PRIMARY KEY, idNube INTEGER, envio REAL, '
      'estado TEXT, sync_uuid TEXT, sync_retry_safe INTEGER, registros TEXT)',
    );
    await db.insert('operations', {
      'id': 1,
      'idNube': 0,
      'envio': 3,
      'estado': 'cerrado',
      'sync_uuid': uuid,
      'sync_retry_safe': 0,
      'registros': '[]',
    });
  });
  tearDown(() => db.close());
  Future<Map<String, Object?>> row() async =>
      (await db.query('operations')).single;
  UnconfirmedRecovery recovery(
    Future<Map<String, dynamic>> Function(String, OperationPayload, String)
    lookup,
  ) => UnconfirmedRecovery(
    type: 'empernador',
    store: SqliteOperationSyncStore(db, 'operations'),
    prepare: (ids, rows) async => [
      for (final row in rows)
        {
          for (final field in TransferContent.fields('empernador'))
            field:
                row[field] ??
                (TransferContent.jsonFields.contains(field) ? '{}' : ''),
          'local_id': row['id'],
          'sync_uuid': row['sync_uuid'],
        },
    ],
    lookup: lookup,
  );

  test(
    'new blocked row already in cloud recovers ID and closed confirmation without POST',
    () async {
      var calls = 0;
      final result = await recovery((type, payload, hash) async {
        calls++;
        expect(type, 'empernador');
        expect(payload['sync_uuid'], uuid);
        return {
          'sync_uuid': uuid,
          'hash': hash,
          'status': 'confirmed',
          'server_id': 800,
        };
      }).run(ids: {1});
      expect(calls, 1);
      expect(result.recovered, 1);
      expect((await row())['idNube'], 800);
      expect((await row())['envio'], 1);
    },
  );

  test('missing UUID never resets or creates the blocked operation', () async {
    final result = await recovery(
      (_, _, hash) async => {
        'sync_uuid': uuid,
        'hash': hash,
        'status': 'missing',
        'server_id': null,
      },
    ).run();
    expect(result.recovered, 0);
    expect((await row())['envio'], 3);
    expect((await row())['idNube'], 0);
    expect((await row())['sync_uuid'], uuid);
  });

  test(
    'matching active cloud identity recovers ID but still requires final PUT',
    () async {
      final check = recovery(
        (_, _, hash) async => {
          'sync_uuid': uuid,
          'hash': hash,
          'status': 'conflict',
          'server_id': 800,
          'remote_state': 'activo',
          'identity_matches': true,
        },
      );
      final result = await check.run();
      expect(result.recovered, 1);
      expect((await row())['idNube'], 800);
      expect((await row())['envio'], 0.5);
      expect((await row())['estado'], 'cerrado');
      final api = _UpdatesOnly();
      final synced = await OperationSyncEngine(
        store: SqliteOperationSyncStore(db, 'operations'),
        api: api,
        prepare: check.prepare,
        idempotentCreates: true,
      ).sync('empernador');
      expect(synced.updated, 1);
      expect(api.created, isFalse);
      expect((await row())['envio'], 1);
    },
  );

  test(
    'different remote content stays blocked and is identified for review',
    () async {
      final check = recovery(
        (_, _, hash) async => {
          'sync_uuid': uuid,
          'hash': hash,
          'status': 'conflict',
          'server_id': 800,
        },
      );
      final result = await check.run();
      expect(check.conflicts, {1});
      expect(result.recovered, 0);
      expect((await row())['envio'], 3);
      expect((await row())['idNube'], 0);
    },
  );

  test('API unavailable or wrong identity never confirms local data', () async {
    await recovery((_, _, _) async => throw StateError('HTTP 404')).run();
    expect((await row())['envio'], 3);
    await recovery(
      (_, _, hash) async => {
        'sync_uuid': 'wrong',
        'hash': hash,
        'status': 'confirmed',
        'server_id': 800,
      },
    ).run();
    expect((await row())['envio'], 3);
    expect((await row())['idNube'], 0);
  });

  test('local edits during lookup remain pending after recovered ID', () async {
    await recovery((_, _, hash) async {
      await db.update('operations', {
        'registros': '[{"nuevo":true}]',
      }, where: 'id = 1');
      return {
        'sync_uuid': uuid,
        'hash': hash,
        'status': 'confirmed',
        'server_id': 800,
      };
    }).run();
    expect((await row())['idNube'], 800);
    expect((await row())['envio'], 0.5);
    expect((await row())['registros'], '[{"nuevo":true}]');
  });
}
