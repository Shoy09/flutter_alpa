import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/config/data/operation_sync_identity.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/core/transfer/local_transfer_client.dart';
import 'package:i_miner/core/transfer/local_transfer_server.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';
import 'package:i_miner/core/transfer/transfer_coordinator.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';
import 'local_transfer_test.dart' as fixture;

void main() {
  test(
    'v5 migration keeps existing identity, cloud ID and state; baseline starts unknown',
    () async {
      final db = await fixture.database();
      addTearDown(db.close);
      for (final table in TransferContent.tables.values) {
        await db.execute('ALTER TABLE $table DROP COLUMN sync_cloud_hash');
      }
      await fixture.insert(db);
      final original = await fixture.row(db);
      await OperationSyncIdentity.migrate(db);
      await OperationSyncIdentity.migrate(db);
      final upgraded = await fixture.row(db);
      expect(upgraded['sync_uuid'], original['sync_uuid']);
      expect(upgraded['envio'], original['envio']);
      expect(upgraded['idNube'], original['idNube']);
      expect(upgraded.containsKey('sync_cloud_hash'), isTrue);
      expect(upgraded['sync_cloud_hash'], isNull);
    },
  );

  for (final loss in ['none', 'post', 'put']) {
    test(
      'real Flutter/Node HTTP: $loss response lost, new edit, master closure and offline receipt',
      () async {
        final backend = Directory.fromUri(
          Directory.current.parent.parent.uri.resolve('Api-Node/Backend/'),
        ).path;
        final process = await Process.start(
          'node',
          ['test/fixtures/active_close_server.js'],
          environment: {'SYNC_BACKEND_ROOT': backend},
        );
        addTearDown(() async {
          process.kill();
          await process.exitCode;
        });
        final port = int.parse(
          await process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(const Duration(seconds: 10)),
        );
        final source = await fixture.database();
        final master = await fixture.database();
        addTearDown(source.close);
        addTearDown(master.close);
        const table = 'Operacion_scissor';
        await source.insert(table, {
          'id': 1,
          'fecha': '2026-10-25',
          'turno': 'DÍA',
          'operador': 'PRUEBA',
          'equipo': 'SCISSOR',
          'n_equipo': 'SC2',
          'guardia': 'C',
          'estado': 'activo',
          'registros': '[{"avance":1}]',
        });
        final exporter = ExportarScissorService(DatabaseHelper());
        Future<List<OperationPayload>> export(
          String _,
          List<OperationPayload> rows,
        ) => exporter.prepararDatosParaExportar(
          rows.map((r) => r['id'] as int).toSet(),
          rows,
        );
        final network = http.Client();
        addTearDown(network.close);
        var mutateDuringCreate = true;
        var losePost = loss == 'post';
        var losePut = loss == 'put';
        final client = MockClient((request) async {
          final response = await network.post(
            Uri.parse('http://127.0.0.1:$port${request.url.path}'),
            headers: request.headers,
            body: request.body,
          );
          if (mutateDuringCreate && request.url.path.endsWith('/crear')) {
            mutateDuringCreate = false;
            await source.update(table, {
              'registros': '[{"avance":2}]',
            }, where: 'id=1');
          }
          if (losePost && request.url.path.endsWith('/crear')) {
            losePost = false;
            throw const SocketException('POST committed, response lost');
          }
          if (losePut && request.url.path.endsWith('/update-masivo')) {
            losePut = false;
            throw const SocketException('PUT committed, response lost');
          }
          return response;
        });
        addTearDown(client.close);
        final api = OperacionesService(client: client);
        final initial = await OperationSyncEngine(
          store: SqliteOperationSyncStore(source, table),
          api: api,
          idempotentCreates: true,
          prepare: (_, rows) => export('scissor', rows),
        ).sync('scissor');
        expect(initial.created, loss == 'post' ? 0 : 1);
        if (loss == 'put') {
          final update = await OperationSyncEngine(
            store: SqliteOperationSyncStore(source, table),
            api: api,
            idempotentCreates: true,
            prepare: (_, rows) => export('scissor', rows),
          ).sync('scissor');
          expect(update.updated, 0);
        }
        final active = (await source.query(table)).single;
        expect(active['idNube'], loss == 'post' ? 0 : 1);
        if (loss != 'post')
          expect(active['sync_cloud_hash'], matches(RegExp(r'^[a-f0-9]{64}$')));
        final remoteBefore = jsonDecode(
          (await network.get(Uri.parse('http://127.0.0.1:$port/inspect'))).body,
        )['data'].single;
        if (loss == 'none')
          expect(
            active['sync_cloud_hash'],
            TransferContent.fingerprint(
              'scissor',
              Map<String, dynamic>.from(remoteBefore),
            ),
          );
        expect(
          remoteBefore['registros'],
          loss == 'put' ? '[{"avance":2}]' : '[{"avance":1}]',
        );
        // Final work is newer than the active payload actually confirmed online.
        await source.update(table, {
          'estado': 'cerrado',
          'envio': 0.5,
          'registros': '[{"avance":3}]',
        }, where: 'id=1');
        final origin = TransferCoordinator(
          source,
          export,
          (_, _, _) async => throw const SocketException('operator offline'),
        );
        final receiver = TransferCoordinator(
          master,
          export,
          api.confirmClosedTransfer,
        );
        final server = LocalTransferServer(TransferStore(master));
        await server.start(address: InternetAddress.loopbackIPv4, port: 0);
        addTearDown(server.close);
        final localClient = LocalTransferClient();
        Future<int> transfer() => localClient.send(
          origin,
          'operador',
          '127.0.0.1',
          server.code,
          port: server.port,
          allowLoopback: true,
        );
        expect(await transfer(), 1);
        final packet = (await origin.packets()).single;
        expect(
          packet['payload']['attempted_hashes'],
          contains(
            TransferContent.fingerprint(
              'scissor',
              Map<String, dynamic>.from(remoteBefore),
            ),
          ),
        );
        expect(packet['payload']['base_cloud_hash'], active['sync_cloud_hash']);
        final uploaded = await receiver.sync();
        expect(uploaded.errors, isEmpty);
        expect(uploaded.recovered, 1);
        final remote =
            jsonDecode(
                  (await network.get(
                    Uri.parse('http://127.0.0.1:$port/inspect'),
                  )).body,
                )['data']
                as List;
        expect(remote.length, 1);
        expect(remote.single['id'], 1);
        expect(remote.single['estado'], 'cerrado');
        expect(remote.single['registros'], '[{"avance":3}]');
        expect(await transfer(), 1);
        expect(localClient.cloudConfirmed, 1);
        final finalSource = (await source.query(table)).single;
        expect(finalSource['idNube'], 1);
        expect(finalSource['envio'], 1);
        expect(finalSource['sync_cloud_hash'], packet['hash']);
        expect(await transfer(), 0);
        // Editing an already transferred snapshot can be resolved from the app,
        // rather than remaining excluded from normal sync forever.
        await source.update(table, {
          'registros': '[{"avance":4}]',
          'envio': 0.5,
        }, where: 'id=1');
        await origin.prepare('operador');
        final conflicted = (await origin.store.list(
          direction: 'outbox',
        )).single;
        expect(conflicted['status'], 'conflict');
        final reviewCoordinator = TransferCoordinator(
          source,
          export,
          api.confirmClosedTransfer,
          lookup: api.lookupSync,
          resolve: api.resolveClosedTransfer,
        );
        final plan = await reviewCoordinator.inspectForReview(conflicted);
        expect(plan['remote']['status'], 'conflict');
        await reviewCoordinator.applyReviewed(plan, verifiedAbsent: true);
        final resolved = (await source.query(table)).single;
        expect(resolved['envio'], 1);
        expect(resolved['idNube'], 1);
        expect(
          (await origin.store.list(direction: 'outbox')).single['status'],
          'cloud',
        );
        final audit = (await source.query('SyncReviewHistory')).single;
        expect(
          jsonDecode(
            jsonDecode(audit['remote_payload'] as String)['registros'],
          ).single['avance'],
          3,
        );
        expect(
          jsonDecode(
            jsonDecode(audit['local_payload'] as String)['registros'],
          ).single['avance'],
          4,
        );
      },
    );
  }
}
