import 'package:sqflite/sqflite.dart';
import '../../core/sync/sync_attempts.dart';

/// Identidad persistente de las operaciones, independiente del ID de cada tablet.
class OperationSyncIdentity {
  static const tables = [
    'Operacion_tal_largo',
    'Operacion_tal_horizontal',
    'Operacion_empernador',
    'Operacion_carguio',
    'Operacion_volquetes',
    'Operacion_Dumper',
    'Operacion_rompebanco',
    'Operacion_Scalamin',
    'Operacion_scissor',
    'Operacion_anfochanger',
  ];

  // UUID v4 generado por SQLite: funciona también en inserciones existentes
  // que todavía no incluyen la columna sync_uuid.
  static const _uuid =
      "lower(hex(randomblob(4)) || '-' || "
      "hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || "
      "substr('89ab', (random() & 3) + 1, 1) || "
      "substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))";

  /// Se ejecuta dentro de la transacción de creación o migración de sqflite.
  static Future<void> migrate(DatabaseExecutor db) async {
    await SyncAttempts.migrate(db);
    for (final table in tables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      if (!columns.any((column) => column['name'] == 'sync_uuid')) {
        await db.execute('ALTER TABLE $table ADD COLUMN sync_uuid TEXT');
      }
      if (!columns.any((column) => column['name'] == 'sync_retry_safe')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN sync_retry_safe INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!columns.any((column) => column['name'] == 'sync_cloud_hash')) {
        await db.execute('ALTER TABLE $table ADD COLUMN sync_cloud_hash TEXT');
      }
      // Conserva idNube, envio y todas las claves ya asignadas.
      await db.execute(
        "UPDATE $table SET sync_uuid = $_uuid "
        "WHERE sync_uuid IS NULL OR trim(sync_uuid) = ''",
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_sync_uuid '
        'ON $table(sync_uuid)',
      );
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_sync_uuid_insert
        AFTER INSERT ON $table
        WHEN NEW.sync_uuid IS NULL OR trim(NEW.sync_uuid) = ''
        BEGIN
          UPDATE $table SET sync_uuid = $_uuid WHERE id = NEW.id;
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_sync_uuid_immutable
        BEFORE UPDATE OF sync_uuid ON $table
        WHEN OLD.sync_uuid IS NOT NULL AND trim(OLD.sync_uuid) != ''
          AND NEW.sync_uuid IS NOT OLD.sync_uuid
        BEGIN
          SELECT RAISE(ABORT, 'sync_uuid no se puede cambiar');
        END
      ''');
    }
  }
}
