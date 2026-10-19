import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:i_miner/screens/Operaciones/pdf/local_pdf_file.dart';
import 'package:i_miner/screens/Operaciones/pdf/pdf_page_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Native PDFium opens a 20-page file and renders bounded pages',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'semin_pdf_native_',
      );
      PdfPageRenderer? renderer;
      try {
        final fixture = pw.Document();
        for (var i = 0; i < 20; i++) {
          fixture.addPage(
            pw.Page(
              pageFormat: const PdfPageFormat(2384, 3370),
              build: (_) => pw.Column(
                children: [
                  pw.Text('Page ${i + 1}'),
                  for (var j = 0; j < 20; j++)
                    pw.Container(
                      height: 30,
                      margin: const pw.EdgeInsets.all(2),
                      color: PdfColors.teal,
                    ),
                ],
              ),
            ),
          );
        }
        final file = File('${directory.path}/twenty_pages.pdf');
        await file.writeAsBytes(await fixture.save());
        Pdfrx.cacheDirectoryPath = directory.path;
        renderer = await openPdfRenderer(file.path);
        expect(renderer.pageCount, 20);
        for (final page in [1, 10, 20]) {
          final size = pdfRenderDimensions(
            renderer.pageSize(page),
            const ui.Size(3840, 2160),
            3,
          );
          final image = await renderer.renderPage(
            page,
            width: size.width,
            height: size.height,
          );
          expect(image.width * image.height, lessThanOrEqualTo(2000000));
          image.dispose();
        }
        final detail = pdfVisibleRegion(
          renderer.pageSize(20),
          const ui.Size(1000, 700),
          const ui.Rect.fromLTWH(450, 315, 100, 70),
          10,
          2,
        )!;
        final image = await renderer.renderRegion(20, detail);
        expect(detail.fullHeight, greaterThan(7000));
        expect(image.width * image.height, lessThanOrEqualTo(2000000));
        image.dispose();
      } finally {
        await renderer?.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test('Bounds page bitmaps for large pages and high density screens', () {
    for (final page in [
      const ui.Size(595, 842),
      const ui.Size(100000, 100000),
      const ui.Size(100, 10000),
    ]) {
      for (final viewport in [
        const ui.Size(390, 700),
        const ui.Size(7680, 4320),
      ]) {
        final size = pdfRenderDimensions(page, viewport, 4);
        expect(size.width, inInclusiveRange(1, 2048));
        expect(size.height, inInclusiveRange(1, 2048));
        expect(size.width * size.height, lessThanOrEqualTo(2000000));
      }
    }
  });

  test('Rejects invalid page geometry before allocating image memory', () {
    for (final page in [
      ui.Size.zero,
      const ui.Size(double.infinity, 100),
      const ui.Size(double.nan, 1),
    ]) {
      expect(
        () => pdfRenderDimensions(page, const ui.Size(100, 100), 2),
        throwsA(isA<LocalPdfException>()),
      );
    }
  });

  test(
    'Zoom increases source detail while keeping only a bounded visible area',
    () {
      final region = pdfVisibleRegion(
        const ui.Size(10000, 14000),
        const ui.Size(1000, 700),
        const ui.Rect.fromLTWH(450, 315, 100, 70),
        10,
        2,
      )!;
      expect(region.fullHeight, greaterThan(7000));
      expect(region.width * region.height, lessThanOrEqualTo(2000000));
      expect(region.width, greaterThan(1000));
      expect(region.displayRect.width, closeTo(100, 1));
      expect(
        pdfVisibleRegion(
          const ui.Size(100, 100),
          const ui.Size(100, 100),
          const ui.Rect.fromLTWH(200, 200, 10, 10),
          10,
          2,
        ),
        isNull,
      );
    },
  );

  test('Invalid pixel buffers fail through a catchable future', () async {
    await expectLater(
      decodePdfPixels(Uint8List(4), 100, 100),
      throwsA(isA<LocalPdfException>()),
    );
    await expectLater(
      decodePdfPixels(Uint8List(0), 0, 0),
      throwsA(isA<LocalPdfException>()),
    );
    await expectLater(
      decodePdfPixels(Uint8List(4), 100000, 100000),
      throwsA(isA<LocalPdfException>()),
    );
  });
}
