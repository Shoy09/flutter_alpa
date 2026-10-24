import 'package:sqflite/sqflite.dart';
import 'operation_sync_engine.dart';

class SqliteOperationSyncStore implements OperationSyncStore {
  SqliteOperationSyncStore(this.database, this.table);
  final Database database;
  final String table;
  final _snapshots = <int, OperationPayload>{};

  @override
  Future<List<OperationPayload>> load(Set<int>? ids) async {
    if (ids != null && ids.isEmpty) return [];
    final rows = await database.query(
      table,
      where: ids == null
          ? 'envio IN (0, 0.5, 2, 3)'
          : 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids?.toList(),
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
  Future<void> confirm(int id, int cloudId, double state) async {
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
        {'idNube': cloudId, 'envio': changed ? 0.5 : state},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
