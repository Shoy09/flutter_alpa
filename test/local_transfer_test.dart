import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/config/data/operation_sync_identity.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/core/transfer/local_transfer_client.dart';
import 'package:i_miner/core/transfer/local_transfer_server.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';
import 'package:i_miner/core/transfer/transfer_coordinator.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const type = 'tal_horizontal';
const table = 'Operacion_tal_horizontal';

Future<Database> database() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  for (final entry in TransferContent.tables.entries) {
    final fields = TransferContent.fields(entry.key).toSet();
    await db.execute(
      'CREATE TABLE ${entry.value} (id INTEGER PRIMARY KEY, '
      'idNube INTEGER DEFAULT 0, envio REAL DEFAULT 0, '
      '${fields.map((field) => '$field TEXT').join(', ')})',
    );
  }
  await OperationSyncIdentity.migrate(db);
  await TransferStore.migrate(db);
  return db;
}

Future<List<Map<String, dynamic>>> export(
  String type,
  List<Map<String, dynamic>> rows,
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
      'Hora_envio': '12:34',
    },
];

class Cloud {
  final rows = <String, Map<String, dynamic>>{};
  int calls = 0;
  Future<Map<String, dynamic>> confirm(
    String type,
    Map<String, dynamic> payload,
    String hash,
  ) async {
    calls++;
    final key = '$type/${payload['sync_uuid']}';
    final previous = rows.putIfAbsent(
      key,
      () => {
        'hash': hash,
        'id': rows.length + 1,
        'payload': Map<String, dynamic>.from(payload),
      },
    );
    return {
      'sync_uuid': payload['sync_uuid'],
      'hash': hash,
      'server_id': previous['id'],
      'status': previous['hash'] == hash ? 'confirmed' : 'conflict',
    };
  }
}

Future<void> insert(
  Database db, {
  String state = 'cerrado',
  int envio = 0,
  int safe = 0,
}) async {
  await db.insert(table, {
    'id': 1,
    'estado': state,
    'envio': envio,
    'operador': 'OPERADOR DE PRUEBA',
    'registros': '[{"horas":1.0,"2":"dos","10":"diez"}]',
  });
  if (safe != 0) {
    await db.update(table, {'sync_retry_safe': safe}, where: 'id = 1');
  }
}

Future<Map<String, Object?>> row(Database db) async =>
    (await db.query(table)).single;

void main() {
  test(
    'confirmed closed cloud copy travels by HTTP and master never calls cloud API',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      await insert(source);
      await source.update(table, {
        'envio': 1,
        'idNube': 88,
        'fecha': '2026-10-26',
        'turno': 'DÍA',
      });
      expect(
        (await TransferStore(source).available()).single['cloud_confirmed'],
        isTrue,
      );
      var apiCalls = 0;
      Future<Map<String, dynamic>> noUpload(
        String _,
        Map<String, dynamic> __,
        String ___,
      ) async {
        apiCalls++;
        throw StateError('A confirmed copy must never be uploaded');
      }

      final origin = TransferCoordinator(source, export, noUpload);
      final receiver = TransferCoordinator(master, export, noUpload);
      final server = LocalTransferServer(receiver.store);
      await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      addTearDown(server.close);
      final client = LocalTransferClient();
      expect(
        await client.send(
          origin,
          'operador',
          '127.0.0.1',
          server.code,
          port: server.port,
          allowLoopback: true,
        ),
        1,
      );
      final copy = (await receiver.store.list(direction: 'inbox')).single;
      expect(copy['status'], 'cloud');
      expect(copy['cloud_id'], 88);
      final payload = jsonDecode(copy['payload'] as String);
      expect(payload['shared_as_cloud_copy'], isTrue);
      expect(payload['fecha'], '2026-10-26');
      expect(payload['turno'], 'DÍA');
      await receiver.sync();
      await origin.sync();
      expect(apiCalls, 0);
      expect((await row(source))['idNube'], 88);
      expect((await row(source))['envio'], 1);
      final savedPacket = {
        'type': type,
        'uuid': copy['uuid'],
        'hash': copy['hash'],
        'payload': payload,
        'needs_review': false,
        'source': 'operador',
      };
      expect((await receiver.store.receive(savedPacket))['status'], 'cloud');
      expect((await receiver.store.list()).length, 1);
    },
  );

  test(
    'known-ID pending operation remains uploadable, and inconsistent confirmation is not trusted',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      await insert(source);
      await source.update(table, {'envio': 0.5, 'idNube': 88});
      final origin = TransferCoordinator(source, export, Cloud().confirm);
      final packet = (await origin.prepare('operador')).single;
      expect(packet['payload']['shared_as_cloud_copy'], isNull);
      expect(
        (await TransferStore(master).receive(packet))['status'],
        'received',
      );
      await expectLater(
        TransferStore(master).receive({
          ...packet,
          'payload': {
            ...packet['payload'] as Map,
            'shared_as_cloud_copy': true,
          },
        }),
        throwsFormatException,
      );
    },
  );
  test('wrong-code cooldown expires without restarting the master', () async {
    final db = await database();
    addTearDown(db.close);
    await insert(db);
    final packet = (await TransferCoordinator(
      db,
      export,
      Cloud().confirm,
    ).prepare('operador')).single;
    var now = DateTime(2026, 10, 25);
    final server = LocalTransferServer(TransferStore(db), now: () => now);
    await server.start(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(server.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<int> post(String code) async {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/transfer'),
      );
      request.headers.set('X-Transfer-Code', code);
      request.write(jsonEncode(packet));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    for (var i = 0; i < 10; i++) {
      expect(await post('incorrect'), 403);
    }
    expect(await post(server.code), 429);
    now = now.add(const Duration(seconds: 31));
    expect(await post(server.code), 200);
  });
  for (final initialState in [0, 3, 1]) {
    test(
      'SCISSOR HTTP second meeting applies cloud receipt from state $initialState while preserving snapshot',
      () async {
        final source = await database();
        final master = await database();
        addTearDown(source.close);
        addTearDown(master.close);
        final exporter = ExportarScissorService(DatabaseHelper());
        Future<List<Map<String, dynamic>>> actualExport(
          String type,
          List<Map<String, dynamic>> rows,
        ) => exporter.prepararDatosParaExportar(
          rows.map((r) => r['id'] as int).toSet(),
          rows,
        );
        await source.insert('Operacion_scissor', {
          'id': 1,
          'sync_uuid': '9300ad6d-d577-4416-8307-996f21ac60e3',
          'fecha': '2026-10-25',
          'turno': 'DÍA',
          'operador': 'OPERADOR DE PRUEBA',
          'equipo': 'SCISSOR',
          'n_equipo': 'SC2',
          'guardia': 'C',
          'estado': 'cerrado',
          'envio': initialState,
          'idNube': 0,
          'registros':
              '[{"estado":"OPERATIVO","codigo":"101","hora_inicio":"10:10","hora_final":"11:40","operacion":{"tipo_labor_id":null}}]',
          'horometros': '{"diesel":{"inicio":1.0,"final":2.0}}',
        });
        final cloud = Cloud();
        final origin = TransferCoordinator(
          source,
          actualExport,
          (_, _, _) async => throw const SocketException('offline'),
        );
        final receiver = TransferCoordinator(
          master,
          actualExport,
          cloud.confirm,
        );
        final server = LocalTransferServer(TransferStore(master));
        await server.start(address: InternetAddress.loopbackIPv4, port: 0);
        addTearDown(server.close);
        final client = LocalTransferClient();
        Future<int> send() => client.send(
          origin,
          'operador',
          '127.0.0.1',
          server.code,
          port: server.port,
          allowLoopback: true,
        );
        expect(await send(), 1);
        expect(client.cloudConfirmed, 0);
        if (initialState == 0) {
          await receiver.sync();
        } else {
          // Simulates a separately verified cloud confirmation of the identical
          // snapshot. An unverified legacy copy is never uploaded automatically.
          final saved = (await receiver.store.list(direction: 'inbox')).single;
          await receiver.store.status(saved, 'cloud', cloudId: 99);
        }
        await server.close();
        await server.start(address: InternetAddress.loopbackIPv4, port: 0);
        expect(await send(), 1);
        expect(client.cloudConfirmed, 1);
        final current = (await source.query('Operacion_scissor')).single;
        expect(current['envio'], 1);
        expect(current['idNube'], greaterThan(0));
        final saved = (await origin.store.list(direction: 'outbox')).single;
        expect(saved['status'], 'cloud');
        expect(saved['needs_review'], 0);
        final snapshot = jsonDecode(saved['payload'] as String) as Map;
        expect(snapshot['envio'], initialState);
        expect(snapshot['idNube'], 0);
        expect(await send(), 0);
      },
    );
  }
  test(
    'manual recovery cannot reset an operation already copied for transfer',
    () async {
      final db = await database();
      addTearDown(db.close);
      await insert(db, envio: 3);
      await TransferCoordinator(
        db,
        export,
        Cloud().confirm,
      ).prepare('operador');
      final uuid = (await row(db))['sync_uuid'] as String;
      await expectLater(
        SqliteOperationSyncStore(
          db,
          table,
          excludeTransferType: type,
        ).releaseVerifiedAbsent(1, uuid),
        throwsStateError,
      );
      expect((await row(db))['envio'], 3);
      expect((await TransferStore(db).list()).length, 1);
    },
  );
  test(
    'available list includes confirmed closed copies and excludes active and already prepared rows',
    () async {
      final db = await database();
      addTearDown(db.close);
      await insert(db);
      await db.insert(table, {'id': 2, 'estado': 'activo', 'envio': 0});
      await db.insert(table, {
        'id': 3,
        'estado': 'cerrado',
        'envio': 1,
        'idNube': 8,
      });
      await db.insert(table, {
        'id': 4,
        'estado': 'cerrado',
        'envio': 3,
        'idNube': 0,
      });
      final store = TransferStore(db);
      final available = await store.available();
      expect(available.map((row) => row['id']).toSet(), {1, 3, 4});
      expect(
        available.singleWhere((row) => row['id'] == 4)['needs_review'],
        isTrue,
      );
      expect(await store.list(), isEmpty);
      expect((await db.query(table, where: 'id = 1')).single['envio'], 0);
      await TransferCoordinator(
        db,
        export,
        Cloud().confirm,
      ).prepare('operador');
      expect(await store.available(), isEmpty);
    },
  );

  test(
    'sync queue skips old cloud confirmations but keeps changed originals',
    () async {
      final db = await database();
      addTearDown(db.close);
      await insert(db, envio: 1);
      await db.update(table, {'idNube': 88}, where: 'id = 1');
      final uuid = '${(await row(db))['sync_uuid']}';
      await db.insert('LocalTransfers', {
        'direction': 'outbox',
        'type': type,
        'uuid': uuid,
        'hash': List.filled(64, 'a').join(),
        'payload': '{}',
        'local_id': 1,
        'source': 'operador',
        'status': 'cloud',
        'cloud_id': 88,
        'needs_review': 0,
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      final store = TransferStore(db);
      final recent = DateTime.utc(2026, 10, 26);
      expect(await store.syncQueue(recheckSince: recent), isEmpty);

      await db.update(table, {'envio': 0.5}, where: 'id = 1');
      expect(await store.syncQueue(recheckSince: recent), hasLength(1));
    },
  );

  test('telemando does not affect transferred content', () {
    final vector =
        (jsonDecode(
                  File(
                    'test/fixtures/transfer_vectors.json',
                  ).readAsStringSync(),
                )
                as List)
            .firstWhere((row) => row['type'] == 'carguio');
    final payload = Map<String, dynamic>.from(vector['payload'] as Map);
    expect(
      TransferContent.fingerprint('carguio', {
        ...payload,
        'check_list_telemando': 'obsoleto',
      }),
      vector['hash'],
    );
  });
  test(
    'Dart and Node use exactly the same content fingerprint for all ten types',
    () {
      final vectors =
          jsonDecode(
                File('test/fixtures/transfer_vectors.json').readAsStringSync(),
              )
              as List;
      for (final raw in vectors) {
        expect(
          TransferContent.fingerprint(
            raw['type'] as String,
            Map<String, dynamic>.from(raw['payload'] as Map),
          ),
          raw['hash'],
        );
      }
    },
  );
  test(
    'master uploads then origin confirms online without creating another version',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, cloud.confirm);
      final receiver = TransferCoordinator(master, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      final ack = await receiver.store.receive(packet);
      await origin.applyReceipt(packet, ack);
      expect((await row(source))['envio'], 0);
      expect((await origin.store.list()).single['status'], 'delivered');
      expect(
        (await SqliteOperationSyncStore(
          source,
          table,
          excludeTransferType: type,
        ).load(null)),
        isEmpty,
      );
      await receiver.sync();
      await origin.sync();
      expect(cloud.rows.length, 1);
      expect((await row(source))['envio'], 1);
      expect((await row(source))['idNube'], 1);
      expect((await origin.packets()), isEmpty);
      final calls = cloud.calls;
      await origin.sync();
      expect(cloud.calls, calls);
    },
  );

  test(
    'origin uploads first and master later confirms same closed content',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, cloud.confirm);
      final receiver = TransferCoordinator(master, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      await receiver.store.receive(packet);
      await origin.sync();
      await receiver.sync();
      expect(cloud.rows.length, 1);
      expect((await receiver.store.list()).single['status'], 'cloud');
    },
  );

  test(
    'next-day local receipt confirms origin without origin internet',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(
        source,
        export,
        (_, _, _) async => throw const SocketException('offline'),
      );
      final receiver = TransferCoordinator(master, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      await receiver.store.receive(packet);
      await receiver.sync();
      await origin.applyReceipt(packet, await receiver.store.receive(packet));
      expect((await row(source))['envio'], 1);
      expect(cloud.rows.length, 1);
    },
  );

  test('cloud outage retains both copies and the pending status', () async {
    final source = await database();
    addTearDown(source.close);
    final origin = TransferCoordinator(
      source,
      export,
      (_, _, _) async => throw const SocketException('offline'),
    );
    await insert(source);
    await origin.prepare('operador-1');
    expect((await origin.sync()).retryable, 1);
    expect((await row(source))['envio'], 0);
    expect((await origin.store.list()).single['status'], 'prepared');
  });

  test(
    'modified source blocks stale automatic PUT without destroying either copy',
    () async {
      final source = await database();
      addTearDown(source.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      await source.update(table, {
        'registros': '[{"cambio":true}]',
      }, where: 'id = 1');
      await origin.sync();
      expect(cloud.calls, 0);
      final stored = (await origin.store.list()).single;
      expect(stored['status'], 'conflict');
      expect(
        jsonDecode(stored['payload'] as String)['registros'],
        packet['payload']['registros'],
      );
      expect((await row(source))['registros'], '[{"cambio":true}]');
      expect(
        await SqliteOperationSyncStore(
          source,
          table,
          excludeTransferType: type,
        ).load({1}),
        isEmpty,
      );
    },
  );

  test(
    'edits while cloud request is in flight cannot mark different data as sent',
    () async {
      final source = await database();
      addTearDown(source.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, (
        type,
        payload,
        hash,
      ) async {
        await source.update(table, {
          'registros': '[{"durante":true}]',
        }, where: 'id = 1');
        return cloud.confirm(type, payload, hash);
      });
      await insert(source);
      await origin.prepare('operador-1');
      await origin.sync();
      expect((await row(source))['envio'], 0);
      expect((await origin.store.list()).single['status'], 'conflict');
    },
  );

  test(
    'different remote hash becomes conflict and never overwrites remote content',
    () async {
      final source = await database();
      addTearDown(source.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      cloud.rows['$type/${packet['uuid']}'] = {'hash': 'otra-version', 'id': 9};
      await origin.sync();
      expect((await origin.store.list()).single['status'], 'conflict');
      expect(cloud.rows.values.single['hash'], 'otra-version');
      expect((await row(source))['envio'], 0);
    },
  );

  test(
    'bad hash, wrong receipt and conflicting duplicate cannot confirm or replace',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      final cloud = Cloud();
      final origin = TransferCoordinator(source, export, cloud.confirm);
      await insert(source);
      final packet = (await origin.prepare('operador-1')).single;
      final store = TransferStore(master);
      await expectLater(
        store.receive({...packet, 'hash': 'alterado'}),
        throwsA(isA<FormatException>()),
      );
      final first = await store.receive(packet);
      expect((await store.receive(packet))['hash'], first['hash']);
      expect((await store.list()).length, 1);
      final changedPayload = {
        ...packet['payload'] as Map,
        'registros': '[{"otro":1}]',
      };
      final other = {
        ...packet,
        'payload': changedPayload,
        'hash': TransferContent.fingerprint(
          type,
          Map<String, dynamic>.from(changedPayload),
        ),
      };
      expect((await store.receive(other))['status'], 'conflict');
      expect((await store.list()).single['hash'], packet['hash']);
      await expectLater(
        origin.applyReceipt(packet, {
          'uuid': packet['uuid'],
          'hash': 'incorrecto',
          'status': 'cloud',
          'cloud_id': 100,
        }),
        throwsStateError,
      );
      await expectLater(
        origin.applyReceipt(packet, {
          'uuid': packet['uuid'],
          'hash': packet['hash'],
          'status': 'cloud',
          'cloud_id': 0,
        }),
        throwsStateError,
      );
      await expectLater(
        origin.applyReceipt(packet, {
          'uuid': packet['uuid'],
          'hash': packet['hash'],
          'status': 'unknown',
        }),
        throwsStateError,
      );
      expect((await row(source))['envio'], 0);
    },
  );

  test(
    'active rows are excluded; legacy rows are copied but never uploaded automatically',
    () async {
      for (final scenario in [
        ('activo', 0),
        ('cerrado', 3),
        ('cerrado', 2),
        ('cerrado', 1),
      ]) {
        final db = await database();
        try {
          await insert(db, state: scenario.$1, envio: scenario.$2);
          final cloud = Cloud();
          final coordinator = TransferCoordinator(db, export, cloud.confirm);
          final packets = await coordinator.prepare('operador');
          if (scenario.$1 == 'activo') {
            expect(packets, isEmpty);
          } else {
            expect(packets.length, 1);
            expect(packets.single['needs_review'], isTrue);
            final master = await database();
            try {
              final receiver = TransferCoordinator(
                master,
                export,
                cloud.confirm,
              );
              final acknowledgement = await receiver.store.receive(
                packets.single,
              );
              expect(acknowledgement['status'], 'review');
              await coordinator.applyReceipt(packets.single, acknowledgement);
              await receiver.sync();
              await coordinator.sync();
              expect(cloud.calls, 0);
              expect(
                (await coordinator.store.list()).single['status'],
                'review',
              );
              expect((await row(db))['envio'], scenario.$2);
            } finally {
              await master.close();
            }
          }
        } finally {
          await db.close();
        }
      }
    },
  );

  test(
    'real HTTP sockets accept 15 operators without internet and reject wrong code',
    () async {
      final master = await database();
      addTearDown(master.close);
      final server = LocalTransferServer(TransferStore(master));
      await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      addTearDown(server.close);
      final cloud = Cloud();
      final sources = await Future.wait(List.generate(15, (_) => database()));
      for (final db in sources) {
        addTearDown(db.close);
      }
      await Future.wait(
        List.generate(15, (i) async {
          await insert(sources[i]);
          final coordinator = TransferCoordinator(
            sources[i],
            export,
            cloud.confirm,
          );
          expect(
            await LocalTransferClient().send(
              coordinator,
              'operador-$i',
              '127.0.0.1',
              server.code,
              port: server.port,
              allowLoopback: true,
            ),
            1,
          );
        }),
      );
      expect((await TransferStore(master).list(direction: 'inbox')).length, 15);
      final bad = TransferCoordinator(sources.first, export, cloud.confirm);
      await expectLater(
        LocalTransferClient().send(
          bad,
          'operador-0',
          '127.0.0.1',
          server.code == '00000000' ? '11111111' : '00000000',
          port: server.port,
          allowLoopback: true,
        ),
        throwsStateError,
      );
      expect((await TransferStore(master).list()).length, 15);
    },
  );

  test(
    'one oversized packet is reported and the rest are still delivered',
    () async {
      final source = await database();
      final master = await database();
      addTearDown(source.close);
      addTearDown(master.close);
      await insert(source);
      await source.insert('Operacion_carguio', {
        'id': 2,
        'estado': 'cerrado',
        'operador': 'OPERADOR DE PRUEBA',
        'registros': '[{"nota":"${'a' * (3 * 1024 * 1024)}"}]',
      });
      final server = LocalTransferServer(TransferStore(master));
      await server.start(address: InternetAddress.loopbackIPv4, port: 0);
      addTearDown(server.close);
      final client = LocalTransferClient();
      await expectLater(
        client.send(
          TransferCoordinator(source, export, Cloud().confirm),
          'operador',
          '127.0.0.1',
          server.code,
          port: server.port,
          allowLoopback: true,
        ),
        throwsA(
          predicate(
            (error) =>
                '$error'.contains('Entregadas: 1') && '$error'.contains('2 MB'),
          ),
        ),
      );
      expect(client.deliveredToMaster, 1);
      expect(client.failed, 1);
      expect((await TransferStore(master).list(direction: 'inbox')).length, 1);
    },
  );

  test('master upload stops at the first network failure', () async {
    final source = await database();
    final master = await database();
    addTearDown(source.close);
    addTearDown(master.close);
    await insert(source);
    await source.insert('Operacion_carguio', {
      'id': 2,
      'estado': 'cerrado',
      'operador': 'OPERADOR DE PRUEBA',
      'registros': '[]',
    });
    final packets = await TransferCoordinator(
      source,
      export,
      Cloud().confirm,
    ).prepare('operador');
    expect(packets.length, 2);
    for (final packet in packets) {
      await TransferStore(master).receive(packet);
    }
    var calls = 0;
    final result = await TransferCoordinator(master, export, (_, _, _) async {
      calls++;
      throw const SocketException('sin internet');
    }).sync();
    expect(calls, 1);
    expect(result.networkFailed, isTrue);
  });

  test('only private addresses are accepted for operator transfer', () {
    for (final host in ['192.168.43.1', '10.0.0.1', '172.20.10.1']) {
      expect(LocalTransferClient.privateAddress(host), isTrue);
    }
    for (final host in ['8.8.8.8', 'example.com', '127.0.0.1', '172.32.0.1']) {
      expect(LocalTransferClient.privateAddress(host), isFalse);
    }
  });

  test(
    'lost local acknowledgement can be retried after reopening the master database',
    () async {
      sqfliteFfiInit();
      final path =
          'build/transfer-persistence-${DateTime.now().microsecondsSinceEpoch}.db';
      var master = await databaseFactoryFfi.openDatabase(path);
      final source = await database();
      addTearDown(source.close);
      final origin = TransferCoordinator(source, export, Cloud().confirm);
      try {
        await TransferStore.migrate(master);
        await insert(source);
        final packet = (await origin.prepare('operador')).single;
        await TransferStore(
          master,
        ).receive(packet); // Guardado; el origen no recibió ACK.
        await master.close();
        master = await databaseFactoryFfi.openDatabase(path);
        final acknowledgement = await TransferStore(master).receive(packet);
        await origin.applyReceipt(packet, acknowledgement);
        expect((await TransferStore(master).list()).length, 1);
        expect((await origin.store.list()).single['status'], 'delivered');
      } finally {
        await master.close();
        await databaseFactoryFfi.deleteDatabase(path);
      }
    },
  );

  test('failed database write never returns a successful receipt', () async {
    final source = await database();
    final master = await database();
    addTearDown(source.close);
    addTearDown(master.close);
    await insert(source);
    final origin = TransferCoordinator(source, export, Cloud().confirm);
    final packet = (await origin.prepare('operador')).single;
    await master.execute(
      "CREATE TRIGGER fail_transfer BEFORE INSERT ON LocalTransfers BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(
      TransferStore(master).receive(packet),
      throwsA(isA<DatabaseException>()),
    );
    expect((await TransferStore(master).list()), isEmpty);
    expect((await origin.store.list()).single['status'], 'prepared');
  });
}
