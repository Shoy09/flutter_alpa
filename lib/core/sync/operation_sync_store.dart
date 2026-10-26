import 'package:sqflite/sqflite.dart';
import 'operation_sync_engine.dart';
import '../transfer/transfer_content.dart';
import 'sync_attempts.dart';

class SqliteOperationSyncStore implements OperationSyncStore {
  SqliteOperationSyncStore(
    this.database,
    this.table, {
    this.excludeTransferType,
  });
  final String? excludeTransferType;
  final Database database;
  final String table;
  final _snapshots = <int, OperationPayload>{};
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
        {'envio': 0, 'sync_retry_safe': 1},
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
    if (ids != null && ids.isEmpty) return [];
    final rows = await database.query(
      table,
      where:
          (ids == null
              ? "COALESCE(NULLIF(envio, ''), 0) IN (0, 0.5, 2, 3)"
              : 'id IN (${List.filled(ids.length, '?').join(',')})') +
          (excludeTransferType == null
              ? ''
              : ' AND NOT EXISTS (SELECT 1 FROM LocalTransfers t WHERE t.direction = ? AND t.type = ? AND t.uuid = $table.sync_uuid)'),
      whereArgs: [
        if (ids != null) ...ids,
        if (excludeTransferType != null) ...['outbox', excludeTransferType],
      ],
    );
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
  Future<void> mark(int id, double state) async {
    await database.update(
      table,
      {'envio': state},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> confirm(
    int id,
    int cloudId,
    double state, {
    String? cloudHash,
  }) async {
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
                    key != 'sync_retry_safe',
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
