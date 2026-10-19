import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import 'local_pdf_file.dart';

typedef PdfRendererLoader = Future<PdfPageRenderer> Function(String path);

abstract class PdfPageRenderer {
  int get pageCount;
  ui.Size pageSize(int pageNumber);
  Future<ui.Image> renderPage(
    int pageNumber, {
    required int width,
    required int height,
  });
  Future<ui.Image> renderRegion(int pageNumber, PdfRenderRegion region);
  Future<void> dispose();
}

class PdfRenderRegion {
  const PdfRenderRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fullWidth,
    required this.fullHeight,
    required this.displayRect,
  });
  final int x, y, width, height;
  final double fullWidth, fullHeight;
  final ui.Rect displayRect;
}

/// Redibuja desde el PDF original la parte visible, no amplía el bitmap inicial.
PdfRenderRegion? pdfVisibleRegion(
  ui.Size page,
  ui.Size viewport,
  ui.Rect visibleScene,
  double zoom,
  double pixelRatio,
) {
  final fit = math.min(
    viewport.width / page.width,
    viewport.height / page.height,
  );
  final pageRect = ui.Rect.fromLTWH(
    (viewport.width - page.width * fit) / 2,
    (viewport.height - page.height * fit) / 2,
    page.width * fit,
    page.height * fit,
  );
  final visible = pageRect.intersect(visibleScene);
  if (visible.isEmpty) return null;
  final dimensions = pdfRenderDimensions(
    visible.size,
    visible.size * zoom,
    pixelRatio,
  );
  final density = math.min(
    dimensions.width / visible.width,
    dimensions.height / visible.height,
  );
  final fullWidth = pageRect.width * density;
  final fullHeight = pageRect.height * density;
  final x = math.max(0, ((visible.left - pageRect.left) * density).floor());
  final y = math.max(0, ((visible.top - pageRect.top) * density).floor());
  final width = math.max(1, math.min(dimensions.width, fullWidth.floor() - x));
  final height = math.max(
    1,
    math.min(dimensions.height, fullHeight.floor() - y),
  );
  return PdfRenderRegion(
    x: x,
    y: y,
    width: width,
    height: height,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
    displayRect: ui.Rect.fromLTWH(
      pageRect.left + x / density,
      pageRect.top + y / density,
      width / density,
      height / density,
    ),
  );
}

/// Presupuesto por página: máximo 2 MP (~8 MB de píxeles), incluso en pantallas 4K.
({int width, int height}) pdfRenderDimensions(
  ui.Size page,
  ui.Size viewport,
  double pixelRatio,
) {
  if (!page.width.isFinite ||
      !page.height.isFinite ||
      page.width <= 0 ||
      page.height <= 0 ||
      !viewport.width.isFinite ||
      !viewport.height.isFinite ||
      viewport.width <= 0 ||
      viewport.height <= 0 ||
      !pixelRatio.isFinite ||
      pixelRatio <= 0) {
    throw const LocalPdfException('La página tiene un tamaño inválido.');
  }
  final fit = math.min(
    viewport.width / page.width,
    viewport.height / page.height,
  );
  final desiredWidth = page.width * fit * pixelRatio.clamp(1.0, 2.0);
  final desiredHeight = page.height * fit * pixelRatio.clamp(1.0, 2.0);
  final reduction = math.min(
    1.0,
    math.min(
      2048 / math.max(desiredWidth, desiredHeight),
      math.sqrt(2000000 / (desiredWidth * desiredHeight)),
    ),
  );
  return (
    width: math.max(1, (desiredWidth * reduction).floor()),
    height: math.max(1, (desiredHeight * reduction).floor()),
  );
}

/// Await explícito del codec: sus fallos llegan al visor, no quedan sin manejar.
Future<ui.Image> decodePdfPixels(
  Uint8List pixels,
  int width,
  int height,
) async {
  if (width <= 0 ||
      height <= 0 ||
      width > 2048 ||
      height > 2048 ||
      width * height > 2000000 ||
      pixels.length != width * height * 4) {
    throw const LocalPdfException(
      'No se pudo generar la imagen de esta página.',
    );
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      rowBytes: width * 4,
      pixelFormat: ui.PixelFormat.bgra8888,
    );
    codec = await descriptor.instantiateCodec();
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

Future<PdfPageRenderer> openPdfRenderer(String path) async {
  final file = await prepareLocalPdf(path);
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openFile(file.path);
  if (document.pages.isEmpty) {
    await document.dispose();
    throw const LocalPdfException('El PDF no contiene páginas.');
  }
  return _NativePdfRenderer(document);
}

class _NativePdfRenderer implements PdfPageRenderer {
  _NativePdfRenderer(this.document);
  final PdfDocument document;
  final _pending = <Future<ui.Image>>{};
  bool _closed = false;
  @override
  int get pageCount => document.pages.length;
  @override
  ui.Size pageSize(int pageNumber) => document.pages[pageNumber - 1].size;

  @override
  Future<ui.Image> renderPage(
    int pageNumber, {
    required int width,
    required int height,
  }) {
    if (_closed) return Future.error(StateError('Visor cerrado'));
    return _track(_render(pageNumber, width, height));
  }

  Future<ui.Image> _track(Future<ui.Image> operation) {
    _pending.add(operation);
    operation.then<void>(
      (_) => _pending.remove(operation),
      onError: (Object error, StackTrace stack) {
        _pending.remove(operation);
      },
    );
    return operation;
  }

  @override
  Future<ui.Image> renderRegion(int pageNumber, PdfRenderRegion region) {
    if (_closed) return Future.error(StateError('Visor cerrado'));
    return _track(
      _render(pageNumber, region.width, region.height, region: region),
    );
  }

  Future<ui.Image> _render(
    int pageNumber,
    int width,
    int height, {
    PdfRenderRegion? region,
  }) async {
    final image = await document.pages[pageNumber - 1].render(
      width: width,
      height: height,
      x: region?.x ?? 0,
      y: region?.y ?? 0,
      fullWidth: region?.fullWidth ?? width.toDouble(),
      fullHeight: region?.fullHeight ?? height.toDouble(),
      backgroundColor: 0xFFFFFFFF,
      flags: PdfPageRenderFlags.limitedImageCache,
    );
    if (image == null) {
      throw const LocalPdfException('No se pudo dibujar esta página.');
    }
    try {
      return await decodePdfPixels(image.pixels, image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    // El documento nativo debe vivir hasta terminar la operación en curso.
    try {
      await Future.wait(_pending.toList());
    } catch (_) {
      /* El visor ya muestra el error. */
    }
    await document.dispose();
  }
}
