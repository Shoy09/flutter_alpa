import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_miner/config/data/checklist_local_store.dart';
import 'package:i_miner/models/checklist_item.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_checklist.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> jsonItem({
  int id = 7,
  String proceso = 'PERFORACIÓN HORIZONTAL',
  String nombre = 'Aceite',
  bool todos = false,
  List<Map<String, dynamic>> equipos = const [],
}) => {
  'id': id,
  'proceso': proceso,
  'categoria': 'ANTES',
  'nombre': nombre,
  'aplica_todos_equipos': todos,
  'equipo_ids': equipos.map((e) => e['id']).toList(),
  'equipos': equipos,
};

Map<String, dynamic> equipo(
  int id,
  String codigo, {
  String proceso = 'PERFORACIÓN HORIZONTAL',
}) => {
  'id': id,
  'codigo': codigo,
  'nombre': 'Nombre compartido',
  'proceso': proceso,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Modelo de checklist', () {
    test('el JSON anterior sigue aplicando a todo el proceso', () {
      final item = CheckListItem.fromJson({
        'id': 1,
        'proceso': 'SCALAMIN',
        'categoria': 'ANTES',
        'nombre': 'Aceite',
      });
      expect(item.aplicaTodosEquipos, isTrue);
      expect(item.equipos, isEmpty);
    });

    test(
      'reconoce false numérico o texto sin convertirlo en alcance general',
      () {
        for (final flag in [false, 0, '0', 'false']) {
          final json = jsonItem()..['aplica_todos_equipos'] = flag;
          expect(CheckListItem.fromJson(json).aplicaTodosEquipos, isFalse);
        }
      },
    );

    test(
      'conserva código y proceso del equipo, sin usar el ID para la asignación local',
      () {
        final item = CheckListItem.fromJson(
          jsonItem(equipos: [equipo(9999, 'J-01')]),
        );
        expect(item.equipos.single.codigo, 'J-01');
        expect(item.equipos.single.proceso, 'PERFORACIÓN HORIZONTAL');
      },
    );

    test(
      'rechaza solo IDs o asignaciones incompletas en lugar de ampliar el alcance',
      () {
        final json = jsonItem()..['equipo_ids'] = [5];
        expect(() => CheckListItem.fromJson(json), throwsFormatException);
        expect(
          () => CheckListItem.fromJson(
            jsonItem(
              equipos: [
                {'id': 5, 'proceso': 'PERFORACIÓN HORIZONTAL'},
              ],
            ),
          ),
          throwsFormatException,
        );
        expect(
          () => CheckListItem.fromJson(
            jsonItem(equipos: [equipo(5, 'J-01', proceso: 'SCALAMIN')]),
          ),
          throwsFormatException,
        );
      },
    );

    test('un ítem restringido sin equipos no se vuelve general', () {
      expect(CheckListItem.fromJson(jsonItem()).aplicaTodosEquipos, isFalse);
    });
  });

  group('Catálogo SQLite', () {
    late Database db;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      await ChecklistLocalStore.crearOMigrar(db);
    });
    tearDown(() async => db.close());

    Future<List<String>> nombres(
      String codigo, {
      String proceso = 'PERFORACIÓN HORIZONTAL',
    }) async => (await ChecklistLocalStore.consultar(
      db,
      proceso,
      codigoEquipo: codigo,
    )).map((e) => e['nombre'] as String).toList();

    test('migra una tabla antigua preservando ítems y otras tablas', () async {
      await db.execute('DROP TABLE checklist_item_equipos');
      await db.execute('DROP TABLE checklist_items');
      await db.execute(
        'CREATE TABLE checklist_items (id INTEGER PRIMARY KEY AUTOINCREMENT, proceso TEXT NOT NULL, categoria TEXT NOT NULL, nombre TEXT NOT NULL)',
      );
      await db.insert('checklist_items', {
        'id': 42,
        'proceso': 'PERFORACIÓN HORIZONTAL',
        'categoria': 'ANTES',
        'nombre': 'Anterior',
      });
      await db.execute('CREATE TABLE respuestas_historicas (respuesta TEXT)');
      await db.insert('respuestas_historicas', {'respuesta': 'guardada'});
      await ChecklistLocalStore.crearOMigrar(db);
      await ChecklistLocalStore.crearOMigrar(db);
      final rows = await ChecklistLocalStore.consultar(
        db,
        'perforación horizontal',
        codigoEquipo: 'J-01',
      );
      expect(rows.single['id'], 42);
      expect(rows.single['aplica_todos_equipos'], 1);
      expect(
        (await db.query('respuestas_historicas')).single['respuesta'],
        'guardada',
      );
    });

    test(
      'combina generales y específicos por código + proceso, sin repetir ítems compartidos',
      () async {
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(nombre: 'General', todos: true)),
          CheckListItem.fromJson(
            jsonItem(
              id: 8,
              nombre: 'Compartido',
              equipos: [equipo(10, 'J-01'), equipo(20, 'J-02')],
            ),
          ),
          CheckListItem.fromJson(
            jsonItem(id: 9, nombre: 'Solo J-02', equipos: [equipo(20, 'J-02')]),
          ),
          CheckListItem.fromJson(jsonItem(id: 10, nombre: 'Sin asignaciones')),
          CheckListItem.fromJson(
            jsonItem(
              id: 11,
              proceso: 'SCALAMIN',
              nombre: 'Otro proceso',
              equipos: [equipo(30, 'J-01', proceso: 'SCALAMIN')],
            ),
          ),
        ]);
        expect(await nombres(' j-01 ', proceso: 'perforacion horizontal'), [
          'General',
          'Compartido',
        ]);
        expect(await nombres('J-02'), ['General', 'Compartido', 'Solo J-02']);
        expect(await nombres('J-99'), ['General']);
        expect(await nombres('J-01', proceso: 'SCALAMIN'), ['Otro proceso']);
        expect(
          (await ChecklistLocalStore.consultar(
            db,
            'PERFORACIÓN HORIZONTAL',
          )).map((e) => e['nombre']),
          ['General'],
        );
      },
    );

    test(
      'borrar y recrear Equipo con otros IDs no cambia el checklist',
      () async {
        await db.execute(
          'CREATE TABLE Equipo (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT, proceso TEXT)',
        );
        await db.insert('Equipo', {
          'id': 1,
          'codigo': 'J-01',
          'proceso': 'PERFORACIÓN HORIZONTAL',
        });
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(equipos: [equipo(999, 'J-01')])),
        ]);
        expect(await nombres('J-01'), ['Aceite']);
        await db.delete('Equipo');
        await db.insert('Equipo', {
          'id': 150,
          'codigo': 'J-01',
          'proceso': 'PERFORACIÓN HORIZONTAL',
        });
        expect(await nombres('J-01'), ['Aceite']);
        final asignacion = (await db.query('checklist_item_equipos')).single;
        expect(asignacion['equipo_codigo'], 'J-01');
        expect(asignacion.containsKey('equipo_id'), isFalse);
      },
    );

    test(
      'una inserción fallida revierte el borrado y conserva catálogo y asignaciones',
      () async {
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(equipos: [equipo(1, 'J-01')])),
        ]);
        await db.execute(
          "CREATE TRIGGER fallar_checklist BEFORE INSERT ON checklist_items WHEN NEW.nombre = 'FALLAR' BEGIN SELECT RAISE(ABORT, 'fallo de prueba'); END",
        );
        await expectLater(
          ChecklistLocalStore.reemplazar(db, [
            CheckListItem.fromJson(jsonItem(nombre: 'Primero', todos: true)),
            CheckListItem.fromJson(jsonItem(nombre: 'FALLAR', todos: true)),
          ]),
          throwsA(isA<DatabaseException>()),
        );
        expect(await nombres('J-01'), ['Aceite']);
        expect(await nombres('J-02'), isEmpty);
      },
    );

    test(
      'una nueva sincronización sustituye también las asignaciones eliminadas',
      () async {
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(equipos: [equipo(1, 'J-01')])),
        ]);
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(equipos: [equipo(2, 'J-02')])),
        ]);
        expect(await nombres('J-01'), isEmpty);
        expect(await nombres('J-02'), ['Aceite']);
        await ChecklistLocalStore.reemplazar(db, []);
        expect(await db.query('checklist_items'), isEmpty);
        expect(await db.query('checklist_item_equipos'), isEmpty);
      },
    );

    test(
      'descarga la respuesta nueva y persiste las asignaciones sin depender de Equipo',
      () async {
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-prueba');
          return http.Response(
            jsonEncode([
              jsonItem(equipos: [equipo(99, 'J-01')]),
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final service = ApiServiceCheckList(
          client: client,
          guardarCatalogo: (items) => ChecklistLocalStore.reemplazar(db, items),
        );
        expect((await service.fetchCheckList('token-prueba')).length, 1);
        expect(await nombres('J-01'), ['Aceite']);
        expect(await nombres('J-02'), isEmpty);
        client.close();
      },
    );

    test(
      'errores HTTP o JSON incompleto no borran el catálogo disponible',
      () async {
        await ChecklistLocalStore.reemplazar(db, [
          CheckListItem.fromJson(jsonItem(nombre: 'Conservado', todos: true)),
        ]);
        for (final response in [
          http.Response('Error', 500),
          http.Response('{"error":"sin datos"}', 200),
          http.Response(
            jsonEncode([
              jsonItem()..['equipo_ids'] = [44],
            ]),
            200,
          ),
        ]) {
          final client = MockClient((_) async => response);
          final service = ApiServiceCheckList(
            client: client,
            guardarCatalogo: (items) =>
                ChecklistLocalStore.reemplazar(db, items),
          );
          await expectLater(
            service.fetchCheckList('token-prueba'),
            throwsA(isA<Exception>()),
          );
          expect(await nombres('J-01'), ['Conservado']);
          client.close();
        }
      },
    );
  });
}
