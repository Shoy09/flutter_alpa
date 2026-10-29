import 'package:sqflite/sqflite.dart';
import 'operation_sync_engine.dart';
import '../transfer/transfer_content.dart';
import 'sync_attempts.dart';

class SqliteOperationSyncStore implements OperationSyncStore {
  SqliteOperationSyncStore(
    this.database,
    this.table, {
    this.excludeTransferType,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final String? excludeTransferType;
  final Database database;
  final String table;
  final DateTime Function() _now;
  final _snapshots = <int, OperationPayload>{};
  Set<String>? _columns;
  int _deferred = 0;

  /// Columnas de seguimiento de fallos (no forman parte del contenido).
  static const failureColumns = {
    'sync_failures',
    'sync_last_error',
    'sync_next_attempt',
  };

  /// Espera antes del siguiente intento automático según fallos seguidos.
  /// Los dos primeros fallos se reintentan en el ciclo normal.
  static int backoffMs(int failures) => switch (failures) {
    <= 2 => 0,
    3 => 5 * 60 * 1000,
    4 => 10 * 60 * 1000,
    5 => 20 * 60 * 1000,
    _ => 60 * 60 * 1000,
  };

  @override
  int get deferred => _deferred;

  Future<bool> _tracksFailures() async {
    _columns ??= {
      for (final column in await database.rawQuery(
        'PRAGMA table_info($table)',
      ))
        '${column['name']}',
    };
    return _columns!.containsAll(failureColumns);
  }

  @override
  Future<List<String>> attemptedHashes(String uuid) async {
    final types = TransferContent.tables.entries.where(
      (entry) => entry.value == table,
    );
    return types.isEmpty
        ? []
        : SyncAttempts.hashes(database, types.single.key, uuid);
  }

  /// Solo para la acción manual que confirma haber verificado ausencia en nube.
  /// No se llama desde sincronización automática ni cambia el UUID original.
  Future<void> releaseVerifiedAbsent(int id, String expectedUuid) async {
    if (!OperationSyncEngine.hasIdentity({'sync_uuid': expectedUuid})) {
      throw StateError('Clave de sincronización inválida');
    }
    final tracks = await _tracksFailures();
    await database.transaction((txn) async {
      if (excludeTransferType != null) {
        final copies = await txn.query(
          'LocalTransfers',
          columns: ['uuid'],
          where: 'direction = ? AND type = ? AND uuid = ?',
          whereArgs: ['outbox', excludeTransferType, expectedUuid],
        );
        if (copies.isNotEmpty) {
          throw StateError(
            'La operación ya está en una transferencia. Revisa esa copia.',
          );
        }
      }
      final changed = await txn.update(
        table,
        {
          'envio': 0,
          'sync_retry_safe': 1,
          if (tracks) 'sync_next_attempt': null,
        },
        where:
            'id = ? AND envio IN (2, 3) AND COALESCE(idNube, 0) = 0 AND sync_uuid = ?',
        whereArgs: [id, expectedUuid],
      );
      if (changed != 1) {
        throw StateError(
          'El registro cambió o ya tiene ID de nube. Actualiza la lista.',
        );
      }
    });
  }

  @override
  Future<List<OperationPayload>> load(Set<int>? ids) async {
    _deferred = 0;
    if (ids != null && ids.isEmpty) return [];
    final excludeTransfers = excludeTransferType == null
        ? ''
        : ' AND NOT EXISTS (SELECT 1 FROM LocalTransfers t WHERE t.direction = ? AND t.type = ? AND t.uuid = $table.sync_uuid)';
    final transferArgs = [
      if (excludeTransferType != null) ...['outbox', excludeTransferType],
    ];
    // La selección manual siempre intenta; el ciclo automático respeta la
    // espera de los registros que fallaron varias veces seguidas.
    final applyBackoff = ids == null && await _tracksFailures();
    final now = _now().millisecondsSinceEpoch;
    const automatic = "COALESCE(NULLIF(envio, ''), 0) IN (0, 0.5, 2, 3)";
    final rows = await database.query(
      table,
      where:
          (ids == null
              ? automatic
              : 'id IN (${List.filled(ids.length, '?').join(',')})') +
          excludeTransfers +
          (applyBackoff
              ? ' AND (sync_next_attempt IS NULL OR sync_next_attempt <= ?)'
              : ''),
      whereArgs: [
        if (ids != null) ...ids,
        ...transferArgs,
        if (applyBackoff) now,
      ],
    );
    if (applyBackoff) {
      _deferred =
          Sqflite.firstIntValue(
            await database.rawQuery(
              'SELECT COUNT(*) FROM $table WHERE $automatic$excludeTransfers '
              'AND sync_next_attempt > ?',
              [...transferArgs, now],
            ),
          ) ??
          0;
    }
    for (final row in rows) {
      _snapshots[OperationSyncEngine.integer(row['id'])] = row;
    }
    return rows;
  }

  @override
  Future<void> claim(
    List<OperationPayload> rows, {
    bool idempotentCreates = false,
  }) async {
    await database.transaction((transaction) async {
      for (final row in rows) {
        final id = OperationSyncEngine.integer(row['local_id']);
        final snapshot = _snapshots[id];
        if (snapshot == null) throw StateError('Falta el registro local $id.');
        final changed = await transaction.update(
          table,
          {
            'envio': 2,
            if (idempotentCreates &&
                OperationSyncEngine.integer(row['idNube']) == 0)
              'sync_retry_safe': 1,
          },
          where: 'id = ? AND envio IS ? AND idNube IS ?',
          whereArgs: [id, snapshot['envio'], snapshot['idNube']],
        );
        if (changed != 1) {
          throw StateError(
            'El registro $id cambió; actualiza la lista antes de enviar.',
          );
        }
        final types = TransferContent.tables.entries.where(
          (entry) => entry.value == table,
        );
        if (types.isNotEmpty) {
          await SyncAttempts.record(transaction, types.single.key, row);
        }
      }
    });
  }

  @override
  Future<void> mark(
    int id,
    double state, {
    String? reason,
    bool penalize = false,
  }) async {
    if (!await _tracksFailures()) {
      await database.update(
        table,
        {'envio': state},
        where: 'id = ?',
        whereArgs: [id],
      );
      return;
    }
    final text = reason == null
        ? null
        : reason.length > 300
        ? reason.substring(0, 300)
        : reason;
    final now = _now().millisecondsSinceEpoch;
    // En UPDATE, sync_failures del lado derecho es el valor anterior.
    await database.rawUpdate(
      'UPDATE $table SET envio = ?, '
      'sync_failures = COALESCE(sync_failures, 0) + 1, '
      'sync_last_error = COALESCE(?, sync_last_error), '
      'sync_next_attempt = CASE WHEN ? = 0 THEN NULL ELSE ? + CASE '
      'WHEN COALESCE(sync_failures, 0) + 1 <= 2 THEN 0 '
      'WHEN COALESCE(sync_failures, 0) + 1 = 3 THEN ${backoffMs(3)} '
      'WHEN COALESCE(sync_failures, 0) + 1 = 4 THEN ${backoffMs(4)} '
      'WHEN COALESCE(sync_failures, 0) + 1 = 5 THEN ${backoffMs(5)} '
      'ELSE ${backoffMs(6)} END END '
      'WHERE id = ?',
      [state, text, penalize ? 1 : 0, now, id],
    );
  }

  @override
  Future<void> confirm(
    int id,
    int cloudId,
    double state, {
    String? cloudHash,
  }) async {
    final tracks = await _tracksFailures();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('El registro local $id ya no existe.');
      final snapshot = _snapshots[id];
      final current = rows.single;
      final changed =
          snapshot != null &&
          snapshot.keys
              .where(
                (key) =>
                    key != 'envio' &&
                    key != 'idNube' &&
                    key != 'sync_retry_safe' &&
                    key != 'sync_cloud_hash' &&
                    !failureColumns.contains(key),
              )
              .any((key) => current[key] != snapshot[key]);
      await transaction.update(
        table,
        {
          'idNube': cloudId,
          'envio': changed ? 0.5 : state,
          if (TransferContent.tables.containsValue(table))
            'sync_cloud_hash':
                cloudHash != null &&
                    RegExp(r'^[0-9a-f]{64}$').hasMatch(cloudHash)
                ? cloudHash
                : null,
          if (tracks) ...{
            'sync_failures': 0,
            'sync_last_error': null,
            'sync_next_attempt': null,
          },
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (cloudHash != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(cloudHash)) {
        final types = TransferContent.tables.entries.where(
          (entry) => entry.value == table,
        );
        if (types.isNotEmpty) {
          await transaction.delete(
            'SyncAttempts',
            where: 'type = ? AND uuid = ? AND hash != ?',
            whereArgs: [types.single.key, current['sync_uuid'], cloudHash],
          );
        }
      }
    });
  }
}
