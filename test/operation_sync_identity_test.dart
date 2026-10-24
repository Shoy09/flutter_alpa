import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/config/data/operation_sync_identity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final table in OperationSyncIdentity.tables) {
      await db.execute(
        'CREATE TABLE $table (id INTEGER PRIMARY KEY, idNube INTEGER, '
        'envio REAL, estado TEXT)',
      );
      await db.insert(table, {
        'id': 1,
        'idNube': 70,
        'envio': 0.5,
        'estado': 'activo',
      });
      await db.insert(table, {
        'id': 2,
        'idNube': 0,
        'envio': 3,
        'estado': 'cerrado',
      });
    }
  });
  tearDown(() async => db.close());

  test(
    'Migration preserves cloud IDs and uncertain states in all tables',
    () async {
      await db.transaction((txn) => OperationSyncIdentity.migrate(txn));
      final keys = <String>{};
      for (final table in OperationSyncIdentity.tables) {
        final rows = await db.query(table, orderBy: 'id');
        expect(rows.first['idNube'], 70);
        expect(rows.first['envio'], 0.5);
        expect(rows.last['idNube'], 0);
        expect(rows.last['envio'], 3);
        expect(rows.last['sync_retry_safe'], 0);
        for (final row in rows) {
          final key = row['sync_uuid'] as String;
          expect(key, matches(uuidPattern));
          expect(keys.add(key), isTrue);
        }
        await db.insert(table, {'id': 3, 'idNube': 0, 'envio': 0});
        final inserted = (await db.query(table, where: 'id = 3')).single;
        expect(inserted['sync_uuid'], matches(uuidPattern));
        expect(keys.add(inserted['sync_uuid'] as String), isTrue);
      }
    },
  );

  test(
    'Identity survives edits and repeated migration, and rejects duplicates',
    () async {
      await OperationSyncIdentity.migrate(db);
      final table = OperationSyncIdentity.tables.first;
      final before = (await db.query(table, where: 'id = 1')).single;
      await db.update(table, {
        'estado': 'cerrado',
        'envio': 1,
      }, where: 'id = 1');
      await OperationSyncIdentity.migrate(db);
      final after = (await db.query(table, where: 'id = 1')).single;
      expect(after['sync_uuid'], before['sync_uuid']);
      await expectLater(
        db.update(table, {'sync_uuid': 'otra-clave'}, where: 'id = 1'),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.insert(table, {'id': 3, 'sync_uuid': before['sync_uuid']}),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
}
