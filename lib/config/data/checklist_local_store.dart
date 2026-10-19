import 'package:i_miner/models/checklist_equipo.dart';
import 'package:i_miner/models/checklist_item.dart';
import 'package:sqflite/sqflite.dart';

/// Catálogo compartido. Las asignaciones dependen de código + proceso,
/// no de los IDs de Equipo, que cambian al volver a descargar esa tabla.
class ChecklistLocalStore {
  static Future<void> crearOMigrar(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proceso TEXT NOT NULL,
        categoria TEXT NOT NULL,
        nombre TEXT NOT NULL,
        api_id INTEGER,
        aplica_todos_equipos INTEGER NOT NULL DEFAULT 1,
        proceso_clave TEXT NOT NULL DEFAULT ''
      )
    ''');
    final columnas = (await db.rawQuery(
      'PRAGMA table_info(checklist_items)',
    )).map((column) => column['name']).toSet();
    for (final entrada in {
      'api_id': 'INTEGER',
      'aplica_todos_equipos': 'INTEGER NOT NULL DEFAULT 1',
      'proceso_clave': "TEXT NOT NULL DEFAULT ''",
    }.entries) {
      if (!columnas.contains(entrada.key)) {
        await db.execute(
          'ALTER TABLE checklist_items ADD COLUMN ${entrada.key} ${entrada.value}',
        );
      }
    }
    // Mantener disponibles los ítems antiguos hasta la próxima sincronización.
    final anteriores = await db.query(
      'checklist_items',
      columns: ['id', 'proceso'],
      where: "proceso_clave = ''",
    );
    for (final row in anteriores) {
      await db.update(
        'checklist_items',
        {'proceso_clave': normalizarClaveChecklist(row['proceso'] as String)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_item_equipos (
        checklist_item_id INTEGER NOT NULL,
        equipo_codigo TEXT NOT NULL,
        equipo_proceso TEXT NOT NULL,
        codigo_clave TEXT NOT NULL,
        proceso_clave TEXT NOT NULL,
        PRIMARY KEY (checklist_item_id, codigo_clave, proceso_clave),
        FOREIGN KEY (checklist_item_id) REFERENCES checklist_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_proceso ON checklist_items(proceso_clave)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checklist_equipo ON checklist_item_equipos(proceso_clave, codigo_clave)',
    );
  }

  static Future<void> reemplazar(Database db, List<CheckListItem> items) async {
    // Validar todo antes de comenzar: una descarga incompleta no borra la copia offline.
    for (final item in items) {
      item.validar();
    }
    await db.transaction((txn) async {
      await txn.delete('checklist_item_equipos');
      await txn.delete('checklist_items');
      for (final item in items) {
        final datos = item.toMap()..remove('id');
        datos['api_id'] = item.id;
        datos['proceso_clave'] = normalizarClaveChecklist(item.proceso);
        final localId = await txn.insert('checklist_items', datos);
        final vistas = <String>{};
        for (final equipo in item.equipos) {
          final codigo = normalizarClaveChecklist(equipo.codigo);
          final proceso = normalizarClaveChecklist(equipo.proceso);
          if (!vistas.add('$proceso\u0000$codigo')) {
            continue;
          }
          await txn.insert('checklist_item_equipos', {
            'checklist_item_id': localId,
            'equipo_codigo': equipo.codigo.trim(),
            'equipo_proceso': equipo.proceso.trim(),
            'codigo_clave': codigo,
            'proceso_clave': proceso,
          });
        }
      }
    });
  }

  static Future<List<Map<String, dynamic>>> consultar(
    DatabaseExecutor db,
    String proceso, {
    String? codigoEquipo,
  }) async {
    final codigo = normalizarClaveChecklist(codigoEquipo ?? '');
    return db.rawQuery(
      '''
      SELECT ci.* FROM checklist_items ci
      WHERE ci.proceso_clave = ?
        AND (ci.aplica_todos_equipos = 1 OR (? <> '' AND EXISTS (
          SELECT 1 FROM checklist_item_equipos ce
          WHERE ce.checklist_item_id = ci.id
            AND ce.proceso_clave = ci.proceso_clave AND ce.codigo_clave = ?
        )))
      ORDER BY ci.id
    ''',
      [normalizarClaveChecklist(proceso), codigo, codigo],
    );
  }
}
