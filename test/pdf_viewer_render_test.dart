import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/Operaciones/pdf/pdf_dialog.dart';
import 'package:i_miner/screens/Operaciones/pdf/pdf_page_renderer.dart';

class _TestRenderer implements PdfPageRenderer {
  int detailRenders = 0;
  @override
  Future<ui.Image> renderRegion(int pageNumber, PdfRenderRegion region) async {
    detailRenders++;
    return source!.clone();
  }

  Object? error;
  ui.Image? source;
  Completer<ui.Image>? pending;
  int renders = 0;
  bool disposed = false;
  @override
  int get pageCount => 20;
  @override
  Size pageSize(int pageNumber) => const Size(10000, 14000);
  @override
  Future<ui.Image> renderPage(
    int pageNumber, {
    required int width,
    required int height,
  }) async {
    renders++;
    expect(width * height, lessThanOrEqualTo(2000000));
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return source!.clone();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, _TestRenderer renderer) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PdfDocumentDialog(
                  title: 'PDF de 20 páginas',
                  filePath: 'test.pdf',
                  rendererLoader: (_) async => renderer,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await settleIo(tester);
  }

  testWidgets('Codec failures are shown and retry can recover', (tester) async {
    final renderer = _TestRenderer()
      ..error = Exception('Codec failed to produce an image');
    await open(tester, renderer);
    expect(
      find.textContaining('No se pudo mostrar esta página'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    renderer.error = null;
    renderer.source = await tester.runAsync(
      () => decodePdfPixels(Uint8List.fromList([255, 255, 255, 255]), 1, 1),
    );
    addTearDown(() => renderer.source?.dispose());
    await tester.tap(find.text('Reintentar'));
    await settleIo(tester);
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.text('Página 1 de 20'), findsOneWidget);
    await tester.tap(find.byTooltip('Página siguiente'));
    await settleIo(tester);
    expect(find.text('Página 2 de 20'), findsOneWidget);
    expect(renderer.renders, 3);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final size = tester.getSize(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.identity()
      ..setEntry(0, 0, 8)
      ..setEntry(1, 1, 8)
      ..setEntry(0, 3, -size.width * 3.5)
      ..setEntry(1, 3, -size.height * 3.5);
    await tester.pump(const Duration(milliseconds: 200));
    await settleIo(tester);
    expect(renderer.detailRenders, 1);
    expect(find.byType(RawImage), findsNWidgets(2));
    await tester.tap(find.byTooltip('Restablecer zoom'));
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar PDF'));
    await tester.pumpAndSettle();
    expect(renderer.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Rapid navigation cannot start parallel renders; closing discards the late image',
    (tester) async {
      final renderer = _TestRenderer()..pending = Completer<ui.Image>();
      await open(tester, renderer);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      expect(renderer.renders, 1);
      await tester.tap(find.byTooltip('Cerrar PDF'));
      await tester.pumpAndSettle();
      final image = await tester.runAsync(
        () => decodePdfPixels(Uint8List.fromList([255, 255, 255, 255]), 1, 1),
      );
      renderer.pending!.complete(image!);
      await settleIo(tester);
      expect(renderer.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
