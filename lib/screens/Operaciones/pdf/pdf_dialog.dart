import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'local_pdf_file.dart';
import 'pdf_page_renderer.dart';

bool _pdfDialogOpen = false;

Future<void> showPdfDialog(
  BuildContext context, {
  required String titulo,
  required String urlPdfLocal,
}) async {
  if (_pdfDialogOpen) return;
  _pdfDialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => PdfDocumentDialog(title: titulo, filePath: urlPdfLocal),
    );
  } finally {
    _pdfDialogOpen = false;
  }
}

class PdfDocumentDialog extends StatefulWidget {
  const PdfDocumentDialog({
    super.key,
    required this.title,
    required this.filePath,
    this.rendererLoader = openPdfRenderer,
  });
  final String title;
  final String filePath;
  final PdfRendererLoader rendererLoader;
  @override
  State<PdfDocumentDialog> createState() => _PdfDocumentDialogState();
}

class _PdfDocumentDialogState extends State<PdfDocumentDialog> {
  static const _teal = Color(0xFF1B5E6B);
  final _transform = TransformationController();
  PdfPageRenderer? _renderer;
  ui.Image? _image;
  ui.Image? _detail;
  Rect? _detailRect;
  Timer? _detailTimer;
  int _detailGeneration = 0;
  bool _detailBusy = false;
  String? _detailError;
  Size _viewport = Size.zero;
  double _pixelRatio = 1;
  int _page = 1;
  bool _opening = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_zoomChanged);
    // El primer frame puede mostrar el indicador antes de iniciar el motor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final renderer = await widget.rendererLoader(widget.filePath);
      if (!mounted) {
        await renderer.dispose();
        return;
      }
      if (renderer.pageCount == 0) {
        await renderer.dispose();
        throw const LocalPdfException('El PDF no contiene páginas.');
      }
      _renderer = renderer;
      await _render();
    } catch (error, stack) {
      _handleError(error, stack);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _clearDetail() {
    _detailGeneration++;
    _detailTimer?.cancel();
    final previous = _detail;
    _detail = null;
    _detailRect = null;
    _detailError = null;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _zoomChanged() {
    if (!mounted) return;
    _detailGeneration++;
    _detailTimer?.cancel();
    if (_transform.value.getMaxScaleOnAxis() <= 1.05) {
      setState(_clearDetail);
      return;
    }
    _detailTimer = Timer(const Duration(milliseconds: 150), _renderDetail);
  }

  Future<void> _renderDetail() async {
    final renderer = _renderer;
    if (!mounted || _busy || _opening || _detailBusy || renderer == null) {
      return;
    }
    final zoom = _transform.value.getMaxScaleOnAxis();
    if (zoom <= 1.05 || _viewport.isEmpty) return;
    final region = pdfVisibleRegion(
      renderer.pageSize(_page),
      _viewport,
      Rect.fromPoints(
        _transform.toScene(Offset.zero),
        _transform.toScene(Offset(_viewport.width, _viewport.height)),
      ),
      zoom,
      _pixelRatio,
    );
    if (region == null) return;
    final generation = _detailGeneration;
    setState(() {
      _detailBusy = true;
      _detailError = null;
    });
    try {
      final image = await renderer.renderRegion(_page, region);
      if (!mounted || generation != _detailGeneration) {
        image.dispose();
        return;
      }
      final previous = _detail;
      setState(() {
        _detail = image;
        _detailRect = region.displayRect;
      });
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } catch (error) {
      if (mounted && generation == _detailGeneration) {
        setState(() => _detailError = 'No se pudo cargar el detalle.');
      }
    } finally {
      if (mounted) {
        setState(() => _detailBusy = false);
        if (generation != _detailGeneration) _zoomChanged();
      }
    }
  }

  void _measure(Size size, double pixelRatio) {
    if (_viewport == size && _pixelRatio == pixelRatio) return;
    _viewport = size;
    _pixelRatio = pixelRatio;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_busy && !_opening && _renderer != null) {
        setState(_clearDetail);
        _render();
      }
    });
  }

  Future<void> _render() async {
    final renderer = _renderer;
    if (!mounted || _busy || renderer == null || _viewport.isEmpty) return;
    final viewport = _viewport;
    final ratio = _pixelRatio;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dimensions = pdfRenderDimensions(
        renderer.pageSize(_page),
        viewport,
        ratio,
      );
      final image = await renderer.renderPage(
        _page,
        width: dimensions.width,
        height: dimensions.height,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      final previous = _image;
      setState(() => _image = image);
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } catch (error, stack) {
      _handleError(error, stack);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        // Rotar o redimensionar durante el render no inicia trabajos paralelos.
        if (viewport != _viewport || ratio != _pixelRatio) {
          unawaited(_render());
        } else if (_transform.value.getMaxScaleOnAxis() > 1.05) {
          _zoomChanged();
        }
      }
    }
  }

  void _handleError(Object error, StackTrace stack) {
    debugPrint('Error al mostrar PDF (${error.runtimeType}): $error\n$stack');
    if (!mounted) return;
    setState(
      () => _error = error is LocalPdfException
          ? error.message
          : 'No se pudo mostrar esta página. Intenta nuevamente o vuelve a sincronizar el PDF.',
    );
  }

  void _changePage(int page) {
    if (_busy ||
        _opening ||
        _detailBusy ||
        page < 1 ||
        page > (_renderer?.pageCount ?? 0)) {
      return;
    }
    _transform.value = Matrix4.identity();
    setState(() => _page = page);
    unawaited(_render());
  }

  Future<void> _closeRenderer(PdfPageRenderer renderer) async {
    try {
      await renderer.dispose();
    } catch (error) {
      debugPrint('Error cerrando PDF: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    _transform.removeListener(_zoomChanged);
    _detail?.dispose();
    _image?.dispose();
    _transform.dispose();
    final renderer = _renderer;
    if (renderer != null) unawaited(_closeRenderer(renderer));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _opening || _busy || (_image == null && _error == null);
    final total = _renderer?.pageCount ?? 0;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1000,
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: _teal,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar PDF',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _measure(
                    constraints.biggest,
                    MediaQuery.devicePixelRatioOf(context),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFF0F3F4)),
                      if (_image != null && _error == null && !loading)
                        InteractiveViewer(
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 20,
                          child: SizedBox.expand(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RawImage(
                                  image: _image,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                if (_detail != null && _detailRect != null)
                                  Positioned.fromRect(
                                    rect: _detailRect!,
                                    child: RawImage(
                                      image: _detail,
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (_detailBusy || _detailError != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _detailBusy
                                    ? 'Cargando detalle…'
                                    : _detailError!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      if (loading)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: _teal),
                              SizedBox(height: 12),
                              Text('Cargando página…'),
                            ],
                          ),
                        ),
                      if (_error != null && !loading)
                        Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  size: 40,
                                  color: _teal,
                                ),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    if (_renderer == null) {
                                      _open();
                                    } else {
                                      _render();
                                    }
                                  },
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: !loading && !_detailBusy && _page > 1
                      ? () => _changePage(_page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  total == 0 ? 'PDF' : 'Página $_page de $total',
                  style: const TextStyle(fontSize: 13),
                ),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: !loading && !_detailBusy && _page < total
                      ? () => _changePage(_page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Restablecer zoom',
                  onPressed: _image != null && !loading
                      ? () => _transform.value = Matrix4.identity()
                      : null,
                  icon: const Icon(Icons.fit_screen, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
