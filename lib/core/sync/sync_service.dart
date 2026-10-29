import 'unconfirmed_recovery.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
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
  Future<OperationSyncResult>? _automatic;

  /// Tipo por el que continúa el siguiente ciclo si el anterior se pausó,
  /// para que los últimos tipos no esperen siempre a los primeros.
  int _nextType = 0;

  /// Resultado del último ciclo automático (para mostrarlo si hace falta).
  OperationSyncResult? lastAutomatic;

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
        _transferCoordinator(db),
      );
    });
  }

  /// Transferencias LAN no esperan a que termine una petición a Azure.
  /// SQLite y las comprobaciones de snapshot protegen escrituras concurrentes.
  Future<T> withLocalTransfers<T>(
    Future<T> Function(TransferCoordinator) action,
  ) async {
    final user = await _dbHelper.getCurrentUserDni();
    if (user == null || user != await _dbHelper.getCurrentUserDni()) {
      throw StateError('La sesión cambió. Abre nuevamente Transferencias.');
    }
    final db = await _dbHelper.database;
    return action(_transferCoordinator(db));
  }

  TransferCoordinator _transferCoordinator(Database db) => TransferCoordinator(
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
  );

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

  /// Envío automático de todos los tipos. Si ya hay uno en curso, devuelve
  /// ese mismo resultado en lugar de terminar sin hacer nada.
  Future<OperationSyncResult> syncData() =>
      _automatic ??= _runAutomatic().whenComplete(() => _automatic = null);

  Future<OperationSyncResult> _runAutomatic() async {
    final total = OperationSyncResult();
    final user = await _dbHelper.getCurrentUserDni();
    if (user == null) return total;
    await _gate.run(() async {
      if (user != await _dbHelper.getCurrentUserDni()) return;
      final idempotentCreates = await _api.supportsIdempotentCreates();
      if (!idempotentCreates && _api.lastCapabilityNetworkError) {
        // Sin conexión estable: no recorrer los 10 tipos sumando timeouts.
        total.networkFailed = true;
        total.errors.add(
          'Sin conexión estable con la nube. ${_api.lastCapabilityProblem}',
        );
        return;
      }
      final types = _processes.keys.toList();
      for (var step = 0; step < types.length; step++) {
        final index = (_nextType + step) % types.length;
        final type = types[index];
        if (_gate.hasWaiters) {
          // Hay un envío manual o una transferencia esperando: ceder el turno.
          _nextType = index;
          total.interrupted = true;
          break;
        }
        if (user != await _dbHelper.getCurrentUserDni()) return;
        try {
          final result = await _syncType(
            type,
            idempotentCreates: idempotentCreates,
            shouldStop: () => _gate.hasWaiters,
          );
          total.absorb(result);
          debugPrint('Sync $type: ${result.message}');
          if (result.networkFailed || result.interrupted) {
            _nextType = index;
            break;
          }
        } catch (error) {
          total.errors.add('No se pudo sincronizar $type: $error');
          debugPrint('No se pudo sincronizar $type: $error');
        }
        if (step == types.length - 1) _nextType = 0;
      }
    });
    lastAutomatic = total;
    return total;
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

  Future<Map<String, dynamic>> inspectSyncConflict(
    String type,
    int id,
  ) async {
    final user = await _dbHelper.getCurrentUserDni();
    return _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Abre nuevamente la operación.');
      }
      return _inspectSyncConflict(type, id);
    });
  }

  Future<Map<String, dynamic>> _inspectSyncConflict(String type, int id) async {
    final process = _processes[type];
    if (process == null) throw ArgumentError('Operación no soportada');
    final db = await _dbHelper.database;
    final rows = await db.query(
      process.$1,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('No se encontró la operación local.');
    final row = Map<String, dynamic>.from(rows.single);
    if (!OperationSyncEngine.hasIdentity(row)) {
      throw StateError('La operación no tiene un UUID válido para conciliar.');
    }
    final payload = Map<String, dynamic>.from(
      (await process.$2.prepararDatosParaExportar({id}, [row])).single,
    )
      ..['idNube'] = OperationSyncEngine.integer(row['idNube'])
      ..['envio'] = OperationSyncEngine.finalState(row);
    final hash = TransferContent.fingerprint(type, payload);
    final remote = await _api.lookupSync(type, payload, hash);
    if (remote['sync_uuid'] != row['sync_uuid'] ||
        remote['hash'] != hash ||
        !['confirmed', 'conflict', 'missing'].contains(remote['status'])) {
      throw StateError('La consulta de nube no corresponde a esta operación.');
    }
    if (remote['status'] != 'missing' &&
        (remote['cloud_hash'] is! String ||
            remote['remote_payload'] is! Map)) {
      throw StateError('La API no devolvió la versión remota para revisar.');
    }
    return {
      'type': type,
      'id': id,
      'uuid': row['sync_uuid'],
      'payload': payload,
      'hash': hash,
      'remote': remote,
    };
  }

  Future<void> resolveSyncConflict(
    Map<String, dynamic> plan, {
    required bool verifiedAbsent,
  }) async {
    final type = '${plan['type']}';
    final id = OperationSyncEngine.integer(plan['id']);
    final user = await _dbHelper.getCurrentUserDni();
    await _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Abre nuevamente la operación.');
      }
      final fresh = await _inspectSyncConflict(type, id);
      if (fresh['hash'] != plan['hash']) {
        throw StateError('La operación local cambió. Consulta nuevamente.');
      }
      final remote = Map<String, dynamic>.from(fresh['remote'] as Map);
      final reviewedRemote = Map<String, dynamic>.from(plan['remote'] as Map);
      if (remote['status'] != reviewedRemote['status'] ||
          remote['cloud_hash'] != reviewedRemote['cloud_hash']) {
        throw StateError('La nube cambió. Compara nuevamente las versiones.');
      }
      if (remote['status'] == 'missing' && !verifiedAbsent) {
        throw StateError('Verifica primero la ausencia en nube.');
      }
      final db = await _dbHelper.database;
      final process = _processes[type]!;
      final store = SqliteOperationSyncStore(db, process.$1);
      final rows = await store.load({id});
      if (rows.length != 1 || rows.single['sync_uuid'] != fresh['uuid']) {
        throw StateError('La operación cambió. Actualiza la lista.');
      }
      await db.insert('SyncReviewHistory', {
        'type': type,
        'uuid': fresh['uuid'],
        'local_payload': jsonEncode(fresh['payload']),
        'remote_payload': remote['remote_payload'] == null
            ? null
            : jsonEncode(remote['remote_payload']),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final answer = await _api.resolveSyncConflict(
        type,
        Map<String, dynamic>.from(fresh['payload'] as Map),
        fresh['hash'] as String,
        remote['cloud_hash'] as String?,
        verifiedAbsent,
      );
      if (answer['status'] != 'confirmed' ||
          answer['sync_uuid'] != fresh['uuid'] ||
          answer['hash'] != fresh['hash'] ||
          OperationSyncEngine.integer(answer['server_id']) <= 0) {
        throw StateError(
          'La nube no confirmó la conciliación${answer['reason'] == null ? '' : ': ${answer['reason']}'}. '
          'No se marcó el registro como enviado.',
        );
      }
      await store.confirm(
        id,
        OperationSyncEngine.integer(answer['server_id']),
        OperationSyncEngine.finalState(rows.single),
        cloudHash: answer['cloud_hash'] is String
            ? answer['cloud_hash'] as String
            : fresh['hash'] as String,
      );
    });
  }

  Future<OperationSyncResult> _syncType(
    String type, {
    Set<int>? ids,
    bool idempotentCreates = false,
    bool Function()? shouldStop,
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
    final transferResult = await transfers.sync(
      type: type,
      shouldStop: shouldStop,
    );
    if (transferResult.networkFailed || transferResult.interrupted) {
      return transferResult;
    }
    final recovery = UnconfirmedRecovery(
      shouldStop: shouldStop,
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
    if (recovered.networkFailed || recovered.interrupted) {
      recovered.absorb(transferResult);
      return recovered;
    }
    final result = await OperationSyncEngine(
      shouldStop: shouldStop,
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
