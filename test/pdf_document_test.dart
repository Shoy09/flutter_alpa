import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/Operaciones/pdf/local_pdf_file.dart';
import 'package:i_miner/screens/Operaciones/pdf/pdf_dialog.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('semin_pdf_test_'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test('Rejects missing, empty, and incorrectly downloaded files', () async {
    final file = File('${directory.path}/document.pdf');
    await expectLater(
      prepareLocalPdf(file.path),
      throwsA(isA<LocalPdfException>()),
    );
    await file.writeAsBytes([]);
    await expectLater(
      prepareLocalPdf(file.path),
      throwsA(isA<LocalPdfException>()),
    );
    await file.writeAsString('<html>Download failed</html>');
    await expectLater(
      prepareLocalPdf(file.path),
      throwsA(isA<LocalPdfException>()),
    );
  });

  test('Accepts PDF signature within the first 1024 bytes', () async {
    final file = File('${directory.path}/document.pdf');
    await file.writeAsString('   %PDF-1.7\n');
    expect((await prepareLocalPdf(file.path)).path, file.path);
  });

  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showPdfDialog(
                  context,
                  titulo: 'Documento de prueba',
                  urlPdfLocal: '${directory.path}/missing.pdf',
                );
                showPdfDialog(
                  context,
                  titulo: 'Segundo PDF',
                  urlPdfLocal: '${directory.path}/missing.pdf',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Repeated taps open one viewer; missing files retry and close', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await settleIo(tester);
    expect(find.byType(PdfDocumentDialog), findsOneWidget);
    expect(
      find.textContaining('El archivo no está disponible'),
      findsOneWidget,
    );
    expect(find.text('Segundo PDF'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await settleIo(tester);
    expect(
      find.textContaining('El archivo no está disponible'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar PDF'));
    await tester.pumpAndSettle();
    expect(find.byType(PdfDocumentDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Closing before preparation completes does not update disposed state',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.tap(find.byTooltip('Cerrar PDF'));
      await tester.pumpAndSettle();
      await settleIo(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
