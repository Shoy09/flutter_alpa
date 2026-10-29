import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'transfer_content.dart';

class TransferStore {
  TransferStore(this.db);
  final Database db;

  /// Consulta únicamente metadatos. Ver la pantalla no prepara paquetes ni
  /// aparta las operaciones del envío normal a la nube.
  Future<List<Map<String, Object?>>> available() async {
    final result = <Map<String, Object?>>[];
    for (final entry in TransferContent.tables.entries) {
      final rows = await db.query(
        entry.value,
        columns: [
          'id',
          'fecha',
          'turno',
          'operador',
          'sync_uuid',
          'envio',
          'idNube',
          'sync_retry_safe',
        ],
        where:
            "estado = 'cerrado' "
            'AND NOT EXISTS (SELECT 1 FROM LocalTransfers t WHERE t.direction = ? AND t.type = ? AND t.uuid = ${entry.value}.sync_uuid)',
        whereArgs: ['outbox', entry.key],
      );
      for (final row in rows) {
        final cloudId = num.tryParse('${row['idNube']}') ?? 0;
        final state = num.tryParse('${row['envio']}') ?? 0;
        result.add({
          ...row,
          'type': entry.key,
          'cloud_confirmed': state == 1 && cloudId > 0,
          'needs_review':
              cloudId <= 0 &&
              (state == 1 ||
                  ([2, 3].contains(state) && row['sync_retry_safe'] != 1)),
        });
      }
    }
    result.sort((a, b) => '${b['fecha']}'.compareTo('${a['fecha']}'));
    return result;
  }

  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS LocalTransfers (
      direction TEXT NOT NULL, type TEXT NOT NULL, uuid TEXT NOT NULL,
      hash TEXT NOT NULL, payload TEXT NOT NULL, local_id INTEGER,
      source TEXT NOT NULL, status TEXT NOT NULL, cloud_id INTEGER DEFAULT 0,
      needs_review INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      PRIMARY KEY(direction, type, uuid))''');
    final columns = await db.rawQuery('PRAGMA table_info(LocalTransfers)');
    if (!columns.any((column) => column['name'] == 'needs_review')) {
      await db.execute(
        'ALTER TABLE LocalTransfers ADD COLUMN needs_review INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_LocalTransfers_type_status_updated '
      'ON LocalTransfers(type, status, updated_at)',
    );
  }

  static final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static void validate(Map<String, dynamic> item) {
    final payload = Map<String, dynamic>.from(item['payload'] as Map);
    if (payload['shared_as_cloud_copy'] == true &&
        (num.tryParse('${payload['envio']}') != 1 ||
            (num.tryParse('${payload['idNube']}') ?? 0) <= 0 ||
            item['needs_review'] == true ||
            (payload['base_cloud_hash'] != null &&
                payload['base_cloud_hash'] != item['hash']))) {
      throw const FormatException(
        'La copia no tiene una confirmación de nube coherente',
      );
    }
    if (payload['base_cloud_hash'] != null &&
        (payload['base_cloud_hash'] is! String ||
            !RegExp(
              r'^[0-9a-f]{64}$',
            ).hasMatch(payload['base_cloud_hash'] as String))) {
      throw const FormatException('Huella de versión base inválida');
    }
    if (!TransferContent.tables.containsKey(item['type']) ||
        !uuidPattern.hasMatch('${item['uuid']}') ||
        payload['sync_uuid'] != item['uuid'] ||
        payload['estado'] != 'cerrado' ||
        item['needs_review'] is! bool ||
        item['hash'] !=
            TransferContent.fingerprint(item['type'] as String, payload) ||
        item['source'] is! String ||
        (item['source'] as String).isEmpty ||
        '${item['source']}'.length > 100) {
      throw FormatException('Transferencia incompleta o alterada');
    }
  }

  Future<List<Map<String, Object?>>> list({
    String? type,
    String? direction,
  }) => db.query(
    'LocalTransfers',
    where:
        '1=1${type == null ? '' : ' AND type = ?'}${direction == null ? '' : ' AND direction = ?'}',
    whereArgs: [?type, ?direction],
    orderBy: 'updated_at DESC',
  );

  Future<List<Map<String, Object?>>> syncQueue({
    String? type,
    required DateTime recheckSince,
  }) async {
    final result = <Map<String, Object?>>[];
    for (final entry in TransferContent.tables.entries) {
      if (type != null && entry.key != type) continue;
      final rows = await db.query(
        'LocalTransfers',
        where:
            'type = ? AND (status != ? OR (direction = ? AND '
            '(updated_at >= ? OR NOT EXISTS (SELECT 1 FROM ${entry.value} source '
            'WHERE source.id = LocalTransfers.local_id '
            'AND source.sync_uuid = LocalTransfers.uuid '
            'AND COALESCE(source.envio, 0) = 1 '
            'AND COALESCE(source.idNube, 0) = LocalTransfers.cloud_id))))',
        whereArgs: [
          entry.key,
          'cloud',
          'outbox',
          recheckSince.toUtc().toIso8601String(),
        ],
        orderBy: 'updated_at ASC',
      );
      result.addAll(rows);
    }
    return result;
  }

  Future<Map<String, dynamic>> receive(Map<String, dynamic> item) async {
    validate(item);
    final payload = Map<String, dynamic>.from(item['payload'] as Map);
    final alreadyCloud = payload['shared_as_cloud_copy'] == true;
    final cloudId = alreadyCloud
        ? num.parse('${payload['idNube']}').toInt()
        : 0;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'LocalTransfers',
        where: 'direction = ? AND type = ? AND uuid = ?',
        whereArgs: ['inbox', item['type'], item['uuid']],
      );
      if (rows.isNotEmpty) {
        final existing = rows.single;
        if (existing['hash'] != item['hash']) {
          return {
            'uuid': item['uuid'],
            'hash': item['hash'],
            'status': 'conflict',
            'message': 'La maestra ya conserva otra versión. No se reemplazó.',
          };
        }
        if (alreadyCloud) {
          if ((num.tryParse('${existing['cloud_id']}') ?? 0) > 0 &&
              existing['cloud_id'] != cloudId) {
            return {...receipt(existing), 'status': 'conflict'};
          }
          await txn.update(
            'LocalTransfers',
            {'status': 'cloud', 'cloud_id': cloudId, 'needs_review': 0},
            where: 'direction = ? AND type = ? AND uuid = ?',
            whereArgs: ['inbox', item['type'], item['uuid']],
          );
          return {...receipt(existing), 'status': 'cloud', 'cloud_id': cloudId};
        }
        if (item['needs_review'] == true && existing['status'] != 'cloud') {
          await txn.update(
            'LocalTransfers',
            {'needs_review': 1, 'status': 'review'},
            where: 'direction = ? AND type = ? AND uuid = ?',
            whereArgs: ['inbox', item['type'], item['uuid']],
          );
          return {...receipt(existing), 'status': 'review'};
        }
        return receipt(existing);
      }
      await txn.insert('LocalTransfers', {
        'direction': 'inbox',
        'type': item['type'],
        'uuid': item['uuid'],
        'hash': item['hash'],
        'payload': jsonEncode(item['payload']),
        'source': item['source'],
        'status': alreadyCloud
            ? 'cloud'
            : item['needs_review'] == true
            ? 'review'
            : 'received',
        'needs_review': item['needs_review'] == true ? 1 : 0,
        'cloud_id': cloudId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return {
        'uuid': item['uuid'],
        'hash': item['hash'],
        'status': alreadyCloud
            ? 'cloud'
            : item['needs_review'] == true
            ? 'review'
            : 'received',
        'cloud_id': cloudId,
      };
    });
  }

  static Map<String, dynamic> receipt(Map<String, dynamic> row) => {
    'uuid': row['uuid'],
    'hash': row['hash'],
    'status': row['status'],
    'cloud_id': row['cloud_id'],
  };

  Future<void> status(
    Map<String, dynamic> row,
    String state, {
    int cloudId = 0,
  }) => db
      .update(
        'LocalTransfers',
        {
          'status': state,
          if (state == 'review') 'needs_review': 1,
          'cloud_id': cloudId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'direction = ? AND type = ? AND uuid = ? AND hash = ?',
        whereArgs: [row['direction'], row['type'], row['uuid'], row['hash']],
      )
      .then((_) {});
}
