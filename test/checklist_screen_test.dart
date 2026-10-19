import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/checklist/checklist_screen.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    bool dialog = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: dialog
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => ChecklistScreen.show(context),
                    child: const Text('Abrir'),
                  ),
                ),
              )
            : const ChecklistScreen(),
      ),
    );
    if (dialog) await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> mark(WidgetTester tester, String suffix) async {
    final cell = find.byKey(ValueKey('mark-Cono de 90 cm (2)-$suffix'));
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Bulk actions work per moment, preserve M when clearing, without notifications',
    (tester) async {
      await open(tester, const Size(1440, 1000));
      Future<void> bulk(String label, String action) async {
        await tester.tap(find.byKey(ValueKey('bulk-$label')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await bulk('INICIO', 'Todo en buen estado');
      expect(find.text('Inicio: 58/58 · Final: 0/58'), findsOneWidget);
      await mark(tester, 'inicio-bad');
      await bulk('INICIO', 'Limpiar buen estado');
      expect(find.text('Inicio: 1/58 · Final: 0/58'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await bulk('FINAL', 'Todo en buen estado');
      expect(find.text('Inicio: 1/58 · Final: 58/58'), findsOneWidget);
      await bulk('FINAL', 'Limpiar buen estado');
      expect(find.text('Inicio: 1/58 · Final: 0/58'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, 'Guardar')).width,
        lessThan(200),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Phone marks independent moments directly without dialogs', (
    tester,
  ) async {
    await open(tester, const Size(390, 844));
    await mark(tester, 'final-good');
    expect(find.text('Inicio: 12/58 · Final: 2/58'), findsOneWidget);
    await mark(tester, 'inicio-na');
    await mark(tester, 'inicio-good');
    expect(find.text('Inicio: 12/58 · Final: 1/58'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Checklist in one dialog edits and reviews inline without losing text',
    (tester) async {
      await open(tester, const Size(1440, 1000), dialog: true);
      final note = find.byKey(const ValueKey('note-Cono de 90 cm (2)'));
      await tester.ensureVisible(note);
      await tester.tap(note);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        'Conos completos y visibles.',
      );
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Conos completos y visibles.'), findsOneWidget);
      await tester.tap(note);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Conos completos y visibles.',
      );
      await tester.tap(find.text('Revisar hoja'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Revisión de la hoja'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Small phone with enlarged text edits notes without hiding frozen names',
    (tester) async {
      await open(tester, const Size(360, 800), scale: 1.3);
      final firstRow = find.byKey(const ValueKey('open-Cono de 90 cm (2)'));
      await tester.ensureVisible(firstRow);
      final before = tester.getTopLeft(firstRow);
      await tester.tap(firstRow);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(firstRow).dx, before.dx);
      expect(find.byType(TextField), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Revisado sin daños.');
      await tester.ensureVisible(find.text('Listo'));
      await tester.tap(find.text('Listo'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Revisado sin daños.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
