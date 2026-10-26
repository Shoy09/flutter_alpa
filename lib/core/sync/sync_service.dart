import 'unconfirmed_recovery.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/services/envio%20nube/AnfoChanger/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Carguio/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Dumper/ExportarDumperService.dart';
import 'package:i_miner/services/envio%20nube/Rompebancos/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Scalamin/ExportarScalaminService.dart';
import 'package:i_miner/services/envio%20nube/Sostenimiento/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/horizontal/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/largo/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';

import 'package:flutter/foundation.dart';
import 'package:i_miner/services/envio%20nube/Volquetes/exportar_service.dart';
import 'operation_sync_engine.dart';
import 'operation_sync_store.dart';
import '../transfer/transfer_coordinator.dart';
import '../transfer/transfer_store.dart';
import '../transfer/transfer_content.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  final _dbHelper = DatabaseHelper();
  final _api = OperacionesService();
  final _gate = OperationSyncGate();
  bool _automaticRunning = false;

  Future<T> withTransfers<T>(
    Future<T> Function(TransferCoordinator) action,
  ) async {
    final user = await _dbHelper.getCurrentUserDni();
    return _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Abre nuevamente Transferencias.');
      }
      final db = await _dbHelper.database;
      return action(
        TransferCoordinator(
          db,
          (type, rows) async => List<Map<String, dynamic>>.from(
            await _processes[type]!.$2.prepararDatosParaExportar(
              rows.map((row) => OperationSyncEngine.integer(row['id'])).toSet(),
              rows,
            ),
          ),
          _api.confirmClosedTransfer,
          lookup: _api.lookupSync,
          resolve: _api.resolveClosedTransfer,
        ),
      );
    });
  }

  Future<TransferStore> transferStore() async =>
      TransferStore(await _dbHelper.database);

  Map<String, (String, dynamic)> get _processes => {
    'tal_largo': ('Operacion_tal_largo', ExportarService(_dbHelper)),
    'tal_horizontal': (
      'Operacion_tal_horizontal',
      ExportarHorizontalService(_dbHelper),
    ),
    'empernador': (
      'Operacion_empernador',
      ExportarEmpernadorService(_dbHelper),
    ),
    'scissor': ('Operacion_scissor', ExportarScissorService(_dbHelper)),
    'anfochanger': (
      'Operacion_anfochanger',
      ExportarAnfoChangerService(_dbHelper),
    ),
    'rompebanco': (
      'Operacion_rompebanco',
      ExportarRompebancoService(_dbHelper),
    ),
    'carguio': ('Operacion_carguio', ExportarCarguioService(_dbHelper)),
    'dumper': ('Operacion_Dumper', ExportarDumperService(_dbHelper)),
    'scalamin': ('Operacion_Scalamin', ExportarScalaminService(_dbHelper)),
    'volquetes': ('Operacion_volquetes', ExportarVolquetesService(_dbHelper)),
  };

  Future<void> syncData() async {
    if (_automaticRunning) return;
    _automaticRunning = true;
    final user = await _dbHelper.getCurrentUserDni();
    try {
      if (user == null) return;
      await _gate.run(() async {
        if (user != await _dbHelper.getCurrentUserDni()) return;
        final idempotentCreates = await _api.supportsIdempotentCreates();
        for (final type in _processes.keys) {
          if (user != await _dbHelper.getCurrentUserDni()) return;
          try {
            final result = await _syncType(
              type,
              idempotentCreates: idempotentCreates,
            );
            debugPrint('Sync $type: ${result.message}');
          } catch (error) {
            debugPrint('No se pudo sincronizar $type: $error');
          }
        }
      });
    } finally {
      _automaticRunning = false;
    }
  }

  Future<OperationSyncResult> syncSelected(String type, Set<int> ids) async {
    final selected = Set<int>.of(ids);
    final user = await _dbHelper.getCurrentUserDni();
    return _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Vuelve a abrir la lista.');
      }
      final idempotentCreates = await _api.supportsIdempotentCreates();
      if (user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Vuelve a abrir la lista.');
      }
      return _syncType(
        type,
        ids: selected,
        idempotentCreates: idempotentCreates,
      );
    });
  }

  Future<OperationSyncResult> retryVerifiedAbsent(
    String type,
    int id,
    String expectedUuid,
  ) async {
    final user = await _dbHelper.getCurrentUserDni();
    return _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Abre nuevamente la lista.');
      }
      final process = _processes[type];
      if (process == null) throw ArgumentError('Operación no soportada');
      if (!await _api.supportsIdempotentCreates()) {
        throw StateError(
          'No se verificó la API. El registro sigue intacto. ${_api.lastCapabilityProblem}',
        );
      }
      if (user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió.');
      }
      final database = await _dbHelper.database;
      final store = SqliteOperationSyncStore(
        database,
        process.$1,
        excludeTransferType: type,
      );
      final rows = await store.load({id});
      if (rows.length != 1 || rows.single['sync_uuid'] != expectedUuid) {
        throw StateError('El registro cambió. Actualiza la lista.');
      }
      final payload = List<Map<String, dynamic>>.from(
        await process.$2.prepararDatosParaExportar({id}, rows),
      ).single;
      final hash = TransferContent.fingerprint(type, payload);
      final existing = await _api.lookupSync(type, payload, hash);
      if (existing['sync_uuid'] != expectedUuid || existing['hash'] != hash) {
        throw StateError('Consulta de nube inválida');
      }
      if (existing['status'] == 'confirmed' &&
          OperationSyncEngine.integer(existing['server_id']) > 0) {
        await store.confirm(
          id,
          OperationSyncEngine.integer(existing['server_id']),
          OperationSyncEngine.finalState(rows.single),
        );
        return OperationSyncResult()..recovered = 1;
      }
      if (existing['status'] != 'missing') {
        throw StateError(
          'El registro ya existe o no pudo verificarse. No se reenvió.',
        );
      }
      await store.releaseVerifiedAbsent(id, expectedUuid);
      return _syncType(type, ids: {id}, idempotentCreates: true);
    });
  }

  Future<OperationSyncResult> _syncType(
    String type, {
    Set<int>? ids,
    bool idempotentCreates = false,
  }) async {
    final process = _processes[type];
    if (process == null) {
      throw ArgumentError('Tipo de operación no soportado: $type');
    }
    final database = await _dbHelper.database;
    final exporter = process.$2;
    final transfers = TransferCoordinator(
      database,
      (transferType, rows) async => List<Map<String, dynamic>>.from(
        await _processes[transferType]!.$2.prepararDatosParaExportar(
          rows.map((row) => OperationSyncEngine.integer(row['id'])).toSet(),
          rows,
        ),
      ),
      _api.confirmClosedTransfer,
      lookup: _api.lookupSync,
      resolve: _api.resolveClosedTransfer,
    );
    final transferResult = await transfers.sync(type: type);
    final recovery = UnconfirmedRecovery(
      type: type,
      store: SqliteOperationSyncStore(
        database,
        process.$1,
        excludeTransferType: type,
      ),
      prepare: (selected, rows) async => List<Map<String, dynamic>>.from(
        await exporter.prepararDatosParaExportar(selected, rows),
      ),
      lookup: _api.lookupSync,
    );
    final recovered = idempotentCreates
        ? await recovery.run(ids: ids)
        : OperationSyncResult();
    final remoteConflicts = recovery.conflicts;
    final result = await OperationSyncEngine(
      store: SqliteOperationSyncStore(
        database,
        process.$1,
        excludeTransferType: type,
      ),
      api: _api,
      idempotentCreates: idempotentCreates,
      requireIdempotentCreates: true,
      prepare: (selected, rows) async => List<Map<String, dynamic>>.from(
        await exporter.prepararDatosParaExportar(selected, rows),
      ),
    ).sync(type, ids: ids);
    for (final blocked in result.blocked) {
      if (remoteConflicts.contains(
        OperationSyncEngine.integer(blocked['id']),
      )) {
        blocked['can_recover'] = false;
      }
    }
    result.recovered += transferResult.recovered;
    result.recovered += recovered.recovered;
    result.errors.addAll(recovered.errors);
    result.retryable += transferResult.retryable;
    result.uncertain += transferResult.uncertain;
    result.errors.addAll(transferResult.errors);
    if (!idempotentCreates && (result.retryable > 0 || result.uncertain > 0)) {
      result.errors.add('Comprobación de API: ${_api.lastCapabilityProblem}');
    }
    return result;
  }
}
