// Opt-in: escribe datos de prueba en el servidor configurado en ApiConfig.
// Requiere autorización y limpieza posterior con tool/verify_live_sync.cjs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/config/data/operation_sync_identity.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/operation_sync_store.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';
import 'package:i_miner/services/envio%20nube/largo/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/horizontal/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Sostenimiento/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Carguio/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Rompebancos/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/AnfoChanger/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Scalamin/ExportarScalaminService.dart';
import 'package:i_miner/services/envio%20nube/Dumper/ExportarDumperService.dart';
import 'package:i_miner/services/envio%20nube/Volquetes/exportar_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _LoseFirstPostResponse extends http.BaseClient {
  final _inner = http.Client();
  bool loseResponse = true;
  int? firstCloudId;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.method == 'POST' && loseResponse) {
      loseResponse = false;
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw StateError('POST de prueba rechazado: ${response.statusCode}');
      }
      final row = (jsonDecode(body)['data'] as List).single as Map;
      firstCloudId = OperationSyncEngine.integer(row['server_id']);
      if (firstCloudId == 0) throw StateError('La API no confirmó la creación');
      // Azure respondió correctamente, pero el motor no recibe esa respuesta.
      throw TimeoutException(
        'Pérdida de respuesta simulada después de guardar',
      );
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

void main() {
  const enabled = bool.fromEnvironment('RUN_AZURE_SYNC_TESTS');
  final helper = DatabaseHelper();
  final processes = <String, (String, dynamic)>{
    'tal_largo': ('Operacion_tal_largo', ExportarService(helper)),
    'tal_horizontal': (
      'Operacion_tal_horizontal',
      ExportarHorizontalService(helper),
    ),
    'empernador': ('Operacion_empernador', ExportarEmpernadorService(helper)),
    'carguio': ('Operacion_carguio', ExportarCarguioService(helper)),
    'rompebanco': ('Operacion_rompebanco', ExportarRompebancoService(helper)),
    'scissor': ('Operacion_scissor', ExportarScissorService(helper)),
    'anfochanger': (
      'Operacion_anfochanger',
      ExportarAnfoChangerService(helper),
    ),
    'scalamin': ('Operacion_Scalamin', ExportarScalaminService(helper)),
    'dumper': ('Operacion_Dumper', ExportarDumperService(helper)),
    'volquetes': ('Operacion_volquetes', ExportarVolquetesService(helper)),
  };
  final marker =
      'CODEX_SYNC_TEST_${DateTime.now().toUtc().millisecondsSinceEpoch}';
  final journal = <Map<String, dynamic>>[];
  final manifest = File('build/sync-live-manifest.json');
  setUpAll(() {
    if (enabled && manifest.existsSync()) {
      final previous = jsonDecode(manifest.readAsStringSync()) as Map;
      if (previous['cleanupComplete'] != true) {
        throw StateError(
          'Hay un manifiesto previo sin limpieza confirmada. Limpiarlo antes de repetir.',
        );
      }
    }
  });
  void saveJournal() {
    manifest.parent.createSync(recursive: true);
    manifest.writeAsStringSync(jsonEncode({'marker': marker, 'rows': journal}));
  }

  for (final entry in processes.entries) {
    test(
      'Azure ${entry.key}: lost response, retry, update, concurrent POST',
      () async {
        final client = _LoseFirstPostResponse();
        addTearDown(client.close);
        final api = OperacionesService(client: client);
        expect(
          await api.supportsIdempotentCreates(),
          isTrue,
          reason: 'La API desplegada debe confirmar el protocolo y los índices',
        );
        sqfliteFfiInit();
        final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        for (final table in OperationSyncIdentity.tables) {
          await db.execute(
            'CREATE TABLE $table (id INTEGER PRIMARY KEY, '
            'idNube INTEGER DEFAULT 0, envio REAL DEFAULT 0, estado TEXT, '
            'operador TEXT, fecha TEXT, registros TEXT, horometros TEXT, '
            'check_list TEXT, condiciones_equipo TEXT, control_llantas TEXT)',
          );
        }
        await OperationSyncIdentity.migrate(db);
        final table = entry.value.$1;
        final exporter = entry.value.$2;
        Future<List<OperationPayload>> prepare(
          Set<int> ids,
          List<OperationPayload> rows,
        ) async => List<OperationPayload>.from(
          await exporter.prepararDatosParaExportar(ids, rows),
        );
        OperationSyncEngine engine() => OperationSyncEngine(
          store: SqliteOperationSyncStore(db, table),
          api: api,
          prepare: prepare,
          idempotentCreates: true,
        );
        Future<Map<String, Object?>> local(int id) async =>
            (await db.query(table, where: 'id = ?', whereArgs: [id])).single;
        Future<Map<String, dynamic>> insert(int id) async {
          await db.insert(table, {
            'id': id,
            'estado': 'activo',
            'operador': marker,
            'fecha': '2026-10-23',
            'registros': '[]',
            'horometros': '{}',
            'check_list': '[]',
            'condiciones_equipo': '{}',
            'control_llantas': '{}',
          });
          final record = {
            'type': entry.key,
            'uuid': (await local(id))['sync_uuid'],
            'cloudId': 0,
          };
          journal.add(record);
          saveJournal(); // Registrar antes de escribir en la nube para poder limpiar aun si falla.
          return record;
        }

        final first = await insert(1);
        final lost = await engine().sync(entry.key, ids: {1});
        expect(lost.retryable, 1);
        expect(client.firstCloudId, greaterThan(0));
        expect((await local(1))['envio'], 3);
        expect((await local(1))['sync_retry_safe'], 1);
        await db.update(table, {
          'estado': 'cerrado',
          'registros': '[{"prueba":"version-local-actual"}]',
        }, where: 'id = 1');
        final recovered = await engine().sync(entry.key);
        expect(recovered.recovered, 1);
        expect((await local(1))['idNube'], client.firstCloudId);
        first['cloudId'] = client.firstCloudId;
        saveJournal();
        expect((await local(1))['envio'], 0.5);
        final updated = await engine().sync(entry.key);
        expect(updated.updated, 1);
        expect((await local(1))['envio'], 1);
        final noop = await engine().sync(entry.key, ids: {1});
        expect(noop.created + noop.updated + noop.recovered, 0);

        final second = await insert(2);
        final payload = await prepare(
          {2},
          [Map<String, dynamic>.from(await local(2))],
        );
        final responses = await Future.wait([
          api.crearParciales(entry.key, payload),
          api.crearParciales(entry.key, payload),
        ]);
        final ids = responses
            .map(
              (response) => OperationSyncEngine.integer(
                (response!.single as Map)['server_id'],
              ),
            )
            .toSet();
        expect(ids.length, 1);
        expect(ids.single, greaterThan(0));
        second['cloudId'] = ids.single;
        saveJournal();
        await db.update(table, {
          'estado': 'cerrado',
          'registros': '[{"prueba":"version-local-actual"}]',
        }, where: 'id = 2');
        expect((await engine().sync(entry.key, ids: {2})).recovered, 1);
        expect((await engine().sync(entry.key)).updated, 1);
        expect((await local(2))['envio'], 1);
      },
      skip: !enabled,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
