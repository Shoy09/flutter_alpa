import 'package:sqflite/sqflite.dart';
import '../transfer/transfer_content.dart';

class SyncAttempts {
  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS SyncAttempts (
      type TEXT NOT NULL, uuid TEXT NOT NULL, hash TEXT NOT NULL,
      PRIMARY KEY(type, uuid, hash))''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS SyncReviewHistory (
      id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, uuid TEXT NOT NULL,
      local_payload TEXT NOT NULL, remote_payload TEXT, created_at TEXT NOT NULL)''',
    );
  }

  static Future<void> record(
    DatabaseExecutor db,
    String type,
    Map<String, dynamic> payload,
  ) async {
    await db.insert('SyncAttempts', {
      'type': type,
      'uuid': payload['sync_uuid'],
      'hash': TransferContent.fingerprint(type, payload),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<List<String>> hashes(
    DatabaseExecutor db,
    String type,
    String uuid,
  ) async => (await db.query(
    'SyncAttempts',
    columns: ['hash'],
    where: 'type = ? AND uuid = ?',
    whereArgs: [type, uuid],
  )).map((r) => r['hash'] as String).toList();
}
