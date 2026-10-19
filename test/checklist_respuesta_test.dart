import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/models/checklist_respuesta.dart';
import 'package:i_miner/screens/checklist/checklist_screen.dart';

void main() {
  test('los ítems nuevos comienzan pendientes y con los campos de la hoja', () {
    final json = ChecklistRespuesta.desdeCatalogo({
      'nombre': 'Aceite',
      'categoria': 'Motor',
    }).toMap();
    expect(json, {
      'descripcion': 'Aceite',
      'categoria': 'Motor',
      'estado_inicio': null,
      'estado_final': null,
      'no_aplica': false,
      'observacion': '',
    });
    expect(json.containsKey('decision'), isFalse);
  });

  test(
    'la respuesta anterior conserva la decisión en inicio sin inventar el final',
    () {
      for (final decision in [0, 1]) {
        final json = ChecklistRespuesta.fromMap({
          'descripcion': 'Aceite',
          'categoria': 'Motor',
          'decision': decision,
          'observacion': 'Observación anterior',
          'extra': 'conservar',
        }).toMap();
        expect(json['estado_inicio'], decision == 1 ? 'bueno' : 'malo');
        expect(json['estado_final'], isNull);
        expect(json['observacion'], 'Observación anterior');
        expect(json['extra'], 'conservar');
      }
    },
  );

  test(
    'no aplica corresponde al ítem completo y no mezcla estados incompatibles',
    () {
      final respuesta = ChecklistRespuesta(
        descripcion: 'Aceite',
        categoria: 'Motor',
        inicio: EstadoChecklist.malo,
        finalizacion: EstadoChecklist.bueno,
        noAplica: true,
      );
      final json = respuesta.toMap();
      expect(json['estado_inicio'], isNull);
      expect(json['estado_final'], isNull);
      expect(ChecklistRespuesta.fromMap(json).noAplica, isTrue);
    },
  );

  test('un inicio pendiente moderno no hereda una decisión antigua', () {
    final respuesta = ChecklistRespuesta.fromMap({
      'descripcion': 'Aceite',
      'categoria': 'Motor',
      'decision': 0,
      'estado_inicio': null,
      'estado_final': 'bueno',
      'no_aplica': false,
    });
    expect(respuesta.inicio, isNull);
    expect(respuesta.finalizacion, EstadoChecklist.bueno);
    expect(
      ChecklistRespuesta.fromMap(
        jsonDecode(jsonEncode(respuesta.toMap())),
      ).finalizacion,
      EstadoChecklist.bueno,
    );
  });

  Future<void> open(
    WidgetTester tester, {
    required List<Map<String, dynamic>> data,
    required Future<bool> Function(List<Map<String, dynamic>>) guardar,
    bool editable = true,
  }) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChecklistScreen(
          checklistData: data,
          equipo: 'J-99',
          editable: editable,
          onGuardar: guardar,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> item(String nombre, String categoria) =>
      ChecklistRespuesta.desdeCatalogo({
        'nombre': nombre,
        'categoria': categoria,
      }).toMap();

  Future<void> mark(WidgetTester tester, String nombre, String mark) async {
    final finder = find.byKey(ValueKey('mark-$nombre-$mark'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'usa la data real y guarda momentos, N/A y observación en el orden original',
    (tester) async {
      final data = [
        item('Aceite', 'Motor'),
        item('Frenos', 'Seguridad'),
        item('Filtros', 'Motor'),
      ];
      List<Map<String, dynamic>>? guardado;
      await open(
        tester,
        data: data,
        guardar: (rows) async {
          guardado = rows;
          return true;
        },
      );
      expect(find.text('DEMO'), findsNothing);
      expect(find.text('Checklist · J-99'), findsOneWidget);
      expect(find.text('Inicio: 0/3 · Final: 0/3'), findsOneWidget);
      expect(find.text('Cono de 90 cm (2)'), findsNothing);
      await mark(tester, 'Aceite', 'inicio-good');
      await mark(tester, 'Aceite', 'final-bad');
      await mark(tester, 'Filtros', 'inicio-na');
      final note = find.byKey(const ValueKey('note-Aceite'));
      await tester.ensureVisible(note);
      await tester.tap(note);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Revisar al final');
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(guardado!.map((e) => e['descripcion']), [
        'Aceite',
        'Frenos',
        'Filtros',
      ]);
      expect(guardado![0]['estado_inicio'], 'bueno');
      expect(guardado![0]['estado_final'], 'malo');
      expect(guardado![0]['observacion'], 'Revisar al final');
      expect(guardado![2]['no_aplica'], isTrue);
      expect(data[0]['estado_inicio'], isNull);
      expect(find.text('Checklist guardado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('una operación cerrada permite leer pero no alterar respuestas', (
    tester,
  ) async {
    var llamadas = 0;
    await open(
      tester,
      data: [item('Aceite', 'Motor')],
      editable: false,
      guardar: (_) async {
        llamadas++;
        return true;
      },
    );
    await mark(tester, 'Aceite', 'inicio-good');
    expect(find.text('Inicio: 0/1 · Final: 0/1'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Guardar'),
          )
          .onPressed,
      isNull,
    );
    expect(llamadas, 0);
  });

  testWidgets(
    'un error de guardado conserva las respuestas y permite reintentar',
    (tester) async {
      var llamadas = 0;
      await open(
        tester,
        data: [item('Aceite', 'Motor')],
        guardar: (_) async {
          llamadas++;
          return llamadas > 1;
        },
      );
      await mark(tester, 'Aceite', 'inicio-good');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo guardar el checklist'),
        findsOneWidget,
      );
      expect(find.text('Inicio: 1/1 · Final: 0/1'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(llamadas, 2);
      expect(find.text('Checklist guardado'), findsOneWidget);
    },
  );

  testWidgets('un checklist vacío real no introduce filas de demostración', (
    tester,
  ) async {
    await open(tester, data: [], guardar: (_) async => true);
    expect(find.text('Inicio: 0/0 · Final: 0/0'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Guardar'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('el diálogo devuelve guardado y se cierra después de persistir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? resultado;
    List<Map<String, dynamic>>? guardado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await ChecklistScreen.show(
                  context,
                  checklistData: [item('Aceite', 'Motor')],
                  equipo: 'J-99',
                  onGuardar: (rows) async {
                    guardado = rows;
                    return true;
                  },
                );
              },
              child: const Text('Abrir operación'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir operación'));
    await tester.pumpAndSettle();
    await mark(tester, 'Aceite', 'final-good');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(guardado!.single['estado_final'], 'bueno');
    expect(resultado, isTrue);
    expect(find.byType(ChecklistScreen), findsNothing);
  });
}
