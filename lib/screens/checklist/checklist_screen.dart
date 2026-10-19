import 'package:i_miner/models/checklist_respuesta.dart';
import 'package:flutter/material.dart';

enum _Condition { good, bad, na }

class _InspectionItem {
  _InspectionItem(
    this.name, {
    this.start,
    this.end,
    this.note = '',
    this.respuesta,
  });
  final ChecklistRespuesta? respuesta;
  final String name;
  _Condition? start;
  _Condition? end;
  String note;
  final revision = ValueNotifier<int>(0);
}

class _Section {
  _Section(this.name, this.icon, List<String> names)
    : items = names.map(_InspectionItem.new).toList();
  _Section.fromItems(this.name, this.icon, this.items);
  final String name;
  final IconData icon;
  final List<_InspectionItem> items;
}

/// Hoja de inspección. Recibe las respuestas de la operación y las guarda por callback.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    super.key,
    this.checklistData,
    this.equipo = 'JUM-04',
    this.editable = true,
    this.onGuardar,
  });

  final List<Map<String, dynamic>>? checklistData;
  final String equipo;
  final bool editable;
  final Future<bool> Function(List<Map<String, dynamic>>)? onGuardar;

  static Future<bool?> show(
    BuildContext context, {
    List<Map<String, dynamic>>? checklistData,
    String equipo = 'JUM-04',
    bool editable = true,
    Future<bool> Function(List<Map<String, dynamic>>)? onGuardar,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1180,
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: ChecklistScreen(
          checklistData: checklistData,
          equipo: equipo,
          editable: editable,
          onGuardar: onGuardar,
        ),
      ),
    ),
  );

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  static const _ink = Color(0xFF16343C);
  static const _teal = Color(0xFF1B5E6B);
  static const _green = Color(0xFF238365);
  static const _red = Color(0xFFBD4843);

  late final _demoSections = <_Section>[
    _Section('Implementos de seguridad', Icons.health_and_safety_outlined, [
      'Cono de 90 cm (2)',
      'Paradas de emergencia',
      'Bocina (claxon)',
      'Circulina',
      'Alarma de retroceso',
      'Cinturón de seguridad',
      'Cinta reflectiva',
      'Extintor 6 kg',
      'Supresor de incendio sist. ANSUL',
      'Cadena de arrastre / línea a tierra',
      'Seguro de aros',
      'Indicador de advertencia',
      'Monitor de control de perforación',
      'Cámaras de video',
      'Estado de A/C en cabina',
    ]),
    _Section('Niveles', Icons.water_drop_outlined, [
      'Aceite motor SAE 15W40',
      'Aceite hidráulico',
      'Aceite transmisión',
      'Aceite de lubricación',
      'Aceite de compresor GAR 30',
      'Combustible',
    ]),
    _Section('Estructura', Icons.construction_outlined, [
      'Chasis delantero',
      'Chasis posterior',
      'Limpieza de viga',
      'Limpieza de cabina',
    ]),
    _Section('Motor', Icons.settings_outlined, [
      'Fajas',
      'Filtro de aire primario',
      'Registrar presión de aceite de motor',
      'Registrar temperatura de motor',
    ]),
    _Section('Brazo de perforación', Icons.precision_manufacturing_outlined, [
      'Perforadora',
      'Lubricación',
      'Viga',
      'Estado de carrusel porta barras',
      'Estado de bracitos guiadores de barras',
      'Estado de casquillos / muelitas sujetador de barras',
      'Estado de mordazas en general',
    ]),
    _Section('Sistema eléctrico', Icons.bolt_outlined, [
      'Faros delanteros',
      'Faros posteriores',
      'Luces indicadoras de advertencia',
      'Estado de todos los sensores de angulación',
      'Cable de alimentación',
    ]),
    _Section('Sistema hidráulico', Icons.tune_outlined, [
      'Cilindro de avance de perforadora',
      'Cilindro de levante',
      'Cilindro de movimiento de boom',
      'Unidad de rotación',
      'Cilindro de dirección',
      'Cilindro de divergencia',
      'Cilindros de bracitos porta barras',
      'Mordaza sujetador de barras',
      'Gatas',
      'Mangueras y conectores',
      'Bomba hidráulica',
      'Motor hidráulico',
    ]),
    _Section('Sistema de transmisión', Icons.local_shipping_outlined, [
      'Testeo de freno de servicio',
      'Testeo de freno de emergencia',
      'Llantas delanteras',
      'Llantas posteriores',
      'Tuercas y espárragos',
    ]),
  ];
  bool get _demo => widget.checklistData == null;
  bool _saving = false;
  String? _saveError;
  bool get _canEdit =>
      widget.editable && !_saving && (_demo || widget.onGuardar != null);
  late final _productionItems =
      (widget.checklistData ?? <Map<String, dynamic>>[]).map((json) {
        final respuesta = ChecklistRespuesta.fromMap(json);
        return _InspectionItem(
          respuesta.descripcion,
          start: respuesta.noAplica
              ? _Condition.na
              : _condition(respuesta.inicio),
          end: respuesta.noAplica
              ? _Condition.na
              : _condition(respuesta.finalizacion),
          note: respuesta.observacion,
          respuesta: respuesta,
        );
      }).toList();
  late final List<_Section> _sections = _demo
      ? _demoSections
      : _productionSections();

  _Condition? _condition(EstadoChecklist? estado) => switch (estado) {
    EstadoChecklist.bueno => _Condition.good,
    EstadoChecklist.malo => _Condition.bad,
    null => null,
  };
  EstadoChecklist? _estado(_Condition? condition) => switch (condition) {
    _Condition.good => EstadoChecklist.bueno,
    _Condition.bad => EstadoChecklist.malo,
    _ => null,
  };

  List<_Section> _productionSections() {
    final grupos = <String, List<_InspectionItem>>{};
    for (final item in _productionItems) {
      final categoria = item.respuesta!.categoria;
      grupos.putIfAbsent(categoria, () => []).add(item);
    }
    return grupos.entries
        .map((e) => _Section.fromItems(e.key, Icons.checklist, e.value))
        .toList();
  }

  List<Map<String, dynamic>> _respuestas() => _productionItems.map((item) {
    final respuesta = item.respuesta!;
    respuesta.inicio = _estado(item.start);
    respuesta.finalizacion = _estado(item.end);
    respuesta.noAplica =
        item.start == _Condition.na || item.end == _Condition.na;
    respuesta.observacion = item.note;
    return respuesta.toMap();
  }).toList();

  static const _line = Color(0xFFD2DEE0);
  static const _rowHeight = 64.0;
  static const _sectionHeight = 40.0;
  static const _markWidth = 60.0;
  static const _noteWidth = 260.0;
  static const _marksWidth = _markWidth * 5 + _noteWidth;
  final _headerScroll = ScrollController();
  final _sheetScroll = ScrollController();
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();
  final _editorKey = GlobalKey();
  _InspectionItem? _editingItem;
  bool _showReview = false;
  bool _syncingScroll = false;
  bool _saved = false;
  final _statusRevision = ValueNotifier<int>(0);
  final _heightCache =
      <(String, double, double, double, double, TextDirection), double>{};
  late final List<_InspectionItem> _items = _sections
      .expand((s) => s.items)
      .toList();
  int _done(bool end) =>
      _items.where((i) => (end ? i.end : i.start) != null).length;

  @override
  void initState() {
    super.initState();
    _headerScroll.addListener(() => _syncScroll(_headerScroll, _sheetScroll));
    _sheetScroll.addListener(() => _syncScroll(_sheetScroll, _headerScroll));
    if (!_demo) return;
    for (final item in _sections.first.items.take(7)) {
      item.start = _Condition.good;
    }
    _sections.first.items[3]
      ..start = _Condition.bad
      ..note = 'Luz intermitente. Solicitar revisión a mantenimiento.';
    _sections.first.items.last
      ..start = _Condition.na
      ..end = _Condition.na;
    for (final item in _sections[1].items.take(3)) {
      item.start = _Condition.good;
    }
    _sections[1].items.last
      ..start = _Condition.good
      ..note = 'Nivel de combustible: 85 %.';
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_syncingScroll || !target.hasClients) return;
    _syncingScroll = true;
    target.jumpTo(source.offset.clamp(0.0, target.position.maxScrollExtent));
    _syncingScroll = false;
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _sheetScroll.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    _statusRevision.dispose();
    for (final item in _items) {
      item.revision.dispose();
    }
    super.dispose();
  }

  void _set(_InspectionItem item, _Condition condition, {bool end = false}) {
    if (!_canEdit) return;
    if (condition == _Condition.na) {
      final value = item.start == _Condition.na ? null : _Condition.na;
      item.start = value;
      item.end = value;
    } else {
      // N/A corresponde al elemento completo, como en la hoja de papel.
      if (item.start == _Condition.na) item.start = null;
      if (item.end == _Condition.na) item.end = null;
      if (end) {
        item.end = item.end == condition ? null : condition;
      } else {
        item.start = item.start == condition ? null : condition;
      }
    }
    _saved = false;
    item.revision.value++;
    _statusRevision.value++;
  }

  void _beginNote(_InspectionItem item) {
    if (!_canEdit) return;
    if (_editingItem == item) return;
    setState(() {
      _editingItem = item;
      _noteController.text = item.note;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorContext = _editorKey.currentContext;
      if (editorContext != null) {
        Scrollable.ensureVisible(editorContext, alignment: 0.3);
      }
      _noteFocus.requestFocus();
    });
  }

  void _finishNote() {
    _noteFocus.unfocus();
    setState(() => _editingItem = null);
  }

  Widget _observation(_InspectionItem item) {
    if (_editingItem != item) {
      return InkWell(
        key: ValueKey('note-${item.name}'),
        onTap: _canEdit ? () => _beginNote(item) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                item.note.isEmpty ? Icons.edit_outlined : Icons.notes,
                size: 17,
                color: _teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.note.isEmpty ? 'Escribir observación' : item.note,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: item.note.isEmpty ? const Color(0xFF526A70) : _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      key: _editorKey,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('editor-${item.name}'),
              controller: _noteController,
              focusNode: _noteFocus,
              enabled: _canEdit,
              expands: true,
              minLines: null,
              maxLines: null,
              maxLength: 500,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14, height: 1.3),
              decoration: InputDecoration(
                hintText: 'Describe lo que encontraste…',
                filled: true,
                fillColor: const Color(0xFFF1F7F6),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() {
                item.note = value;
                _saved = false;
              }),
              onTapOutside: (_) => _noteFocus.unfocus(),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _finishNote,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Listo'),
            ),
          ),
        ],
      ),
    );
  }

  String _label(_Condition condition) => switch (condition) {
    _Condition.good => 'Buen estado',
    _Condition.bad => 'Mal estado',
    _Condition.na => 'No aplica',
  };
  bool _selected(_InspectionItem item, _Condition condition, bool end) =>
      (end ? item.end : item.start) == condition;
  double _textHeight(
    String text,
    double width,
    double fontSize,
    double minimum,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final key = (
      text,
      width,
      fontSize,
      minimum,
      scaler.scale(fontSize),
      direction,
    );
    final cached = _heightCache[key];
    if (cached != null) return cached;
    if (_heightCache.length > 512) _heightCache.clear();
    final painter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: width - 20);
    final height = (painter.height + 20).clamp(minimum, double.infinity);
    painter.dispose();
    _heightCache[key] = height;
    return height;
  }

  double _itemHeight(_InspectionItem item, double nameWidth) =>
      _textHeight(item.name, nameWidth, 14, _rowHeight).clamp(
        _editingItem == item
            ? 210.0
            : _textHeight(item.note, _noteWidth, 14, _rowHeight),
        double.infinity,
      );

  Color _color(_Condition condition) => switch (condition) {
    _Condition.good => _green,
    _Condition.bad => _red,
    _Condition.na => _ink,
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _teal),
        scaffoldBackgroundColor: const Color(0xFFF3F6F7),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: _ink, displayColor: _ink),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: ModalRoute.of(context) is DialogRoute
              ? IconButton(
                  tooltip: 'Cerrar checklist',
                  icon: const Icon(Icons.close),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                )
              : null,
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: Text(
            'Checklist · ${widget.equipo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (_demo)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: Chip(
                    label: Text(
                      'DEMO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: Color(0xFFE5F0EF),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;
              final keyboardOpen = View.of(context).viewInsets.bottom > 0;
              final nameWidth = narrow
                  ? constraints.maxWidth * 0.44
                  : (constraints.maxWidth - _marksWidth - 19).clamp(
                      260.0,
                      double.infinity,
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Encabezados fijos; las dos vistas horizontales se desplazan juntas.
                          Row(
                            children: [
                              SizedBox(
                                width: nameWidth,
                                height: 72,
                                child: _cell(
                                  const Center(
                                    child: Text(
                                      'ELEMENTO\nA REVISAR',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  header: true,
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _headerScroll,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: _marksWidth,
                                    height: 72,
                                    child: _tableHeader(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('sheet-vertical'),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: nameWidth,
                                    child: Column(
                                      children: [
                                        for (final section in _sections) ...[
                                          _sectionCell(
                                            section.name,
                                            width: nameWidth,
                                            height: _textHeight(
                                              section.name,
                                              nameWidth,
                                              15,
                                              _sectionHeight,
                                            ),
                                          ),
                                          for (final item in section.items)
                                            SizedBox(
                                              height: _itemHeight(
                                                item,
                                                nameWidth,
                                              ),
                                              child: _cell(
                                                Semantics(
                                                  button: true,
                                                  label:
                                                      'Escribir observación de ${item.name}',
                                                  child: InkWell(
                                                    key: ValueKey(
                                                      'open-${item.name}',
                                                    ),
                                                    onTap: _canEdit
                                                        ? () => _beginNote(item)
                                                        : null,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Text(
                                                          item.name
                                                              .toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                height: 1.2,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _sheetScroll,
                                      thumbVisibility: true,
                                      notificationPredicate: (notification) =>
                                          notification.metrics.axis ==
                                          Axis.horizontal,
                                      child: SingleChildScrollView(
                                        controller: _sheetScroll,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: _marksWidth,
                                          child: Column(
                                            children: [
                                              for (final section
                                                  in _sections) ...[
                                                _sectionCell(
                                                  '',
                                                  width: _marksWidth,
                                                  height: _textHeight(
                                                    section.name,
                                                    nameWidth,
                                                    15,
                                                    _sectionHeight,
                                                  ),
                                                ),
                                                for (final item
                                                    in section.items)
                                                  _tableRow(
                                                    item,
                                                    _itemHeight(
                                                      item,
                                                      nameWidth,
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!keyboardOpen) _footer(),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _cell(Widget child, {bool header = false}) => Container(
    decoration: BoxDecoration(
      color: header ? const Color(0xFFF0F5F5) : Colors.white,
      border: const Border(
        right: BorderSide(color: _line),
        bottom: BorderSide(color: _line),
      ),
    ),
    child: child,
  );

  Widget _sectionCell(
    String name, {
    required double width,
    required double height,
  }) => Container(
    width: width,
    height: height,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: Color(0xFFE5F0EF),
      border: Border(
        top: BorderSide(color: _ink, width: 1),
        bottom: BorderSide(color: _line),
      ),
    ),
    child: Text(
      name.toUpperCase(),
      style: const TextStyle(
        fontSize: 15,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _headingMark(String mark, String label, {Color? color}) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mark,
          style: TextStyle(
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w700,
            color: color ?? _ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, height: 1.1)),
      ],
    ),
  );

  void _bulkGood(bool end, bool select) {
    if (!_canEdit) return;
    setState(() {
      for (final item in _items) {
        if (select) {
          // N/A es compartido: se retira para poder marcar B en este momento.
          if (item.start == _Condition.na) item.start = null;
          if (item.end == _Condition.na) item.end = null;
          if (end) {
            item.end = _Condition.good;
          } else {
            item.start = _Condition.good;
          }
        } else if (end && item.end == _Condition.good) {
          item.end = null;
        } else if (!end && item.start == _Condition.good) {
          item.start = null;
        }
      }
      _saved = false;
    });
  }

  Widget _momentHeader(String label) => Row(
    children: [
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      PopupMenuButton<bool>(
        enabled: _canEdit,
        key: ValueKey('bulk-$label'),
        tooltip: 'Opciones de ${label == "FINAL" ? "final" : "inicio"}',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 240),
        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF607D85)),
        onSelected: (select) => _bulkGood(label == 'FINAL', select),
        itemBuilder: (_) => const [
          PopupMenuItem(value: true, child: Text('Todo en buen estado')),
          PopupMenuItem(value: false, child: Text('Limpiar buen estado')),
        ],
      ),
    ],
  );

  Widget _tableHeader() => Row(
    children: [
      for (final label in ['INICIO', 'FINAL'])
        SizedBox(
          width: _markWidth * 2,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: _cell(_momentHeader(label), header: true),
              ),
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    for (final mark in ['B', 'M'])
                      SizedBox(
                        width: _markWidth,
                        child: _cell(
                          Center(
                            child: _headingMark(
                              mark,
                              mark == 'B' ? 'Bueno' : 'Malo',
                              color: mark == 'B' ? _green : _red,
                            ),
                          ),
                          header: true,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      SizedBox(
        width: _markWidth,
        height: 72,
        child: _cell(
          Center(child: _headingMark('N/A', 'No aplica')),
          header: true,
        ),
      ),
      SizedBox(
        width: _noteWidth,
        height: 72,
        child: _cell(
          const Center(
            child: Text(
              'OBSERVACIÓN',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          header: true,
        ),
      ),
    ],
  );

  Widget _tableRow(_InspectionItem item, double height) =>
      ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, child) => SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final end in [false, true])
                for (final condition in [_Condition.good, _Condition.bad])
                  _markCell(item, condition, end: end),
              _markCell(item, _Condition.na),
              SizedBox(width: _noteWidth, child: _cell(_observation(item))),
            ],
          ),
        ),
      );

  Widget _markCell(
    _InspectionItem item,
    _Condition condition, {
    bool end = false,
  }) {
    final selected = _selected(item, condition, end);
    return SizedBox(
      width: _markWidth,
      child: _cell(
        Semantics(
          label:
              '${item.name}, ${condition == _Condition.na ? "no aplica" : "${end ? 'final' : 'inicio'}, ${_label(condition)}"}',
          selected: selected,
          button: true,
          child: Material(
            color: selected
                ? _color(condition).withValues(alpha: 0.10)
                : Colors.white,
            child: InkWell(
              key: ValueKey(
                'mark-${item.name}-${end ? "final" : "inicio"}-${condition.name}',
              ),
              onTap: _canEdit ? () => _set(item, condition, end: end) : null,
              child: Center(
                child: Container(
                  width: 34,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? _color(condition) : _line,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: selected
                      ? Icon(
                          condition == _Condition.bad
                              ? Icons.close
                              : Icons.check,
                          size: 27,
                          color: _color(condition),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    _finishNote();
    if (_demo) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Demostración: guardado solo mientras esta pantalla esté abierta.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final guardado = await widget.onGuardar!(_respuestas());
      if (!mounted) return;
      if (!guardado) throw StateError('No se pudo guardar');
      setState(() {
        _saving = false;
        _saved = true;
      });
      if (ModalRoute.of(context) is DialogRoute) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'No se pudo guardar el checklist. Tus cambios siguen en pantalla; intenta nuevamente.';
      });
    }
  }

  Widget _footer() => ValueListenableBuilder<int>(
    valueListenable: _statusRevision,
    builder: (context, _, child) => _footerContent(),
  );

  Widget _footerContent() => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _saveError!,
                style: const TextStyle(color: _red, fontSize: 13),
              ),
            ),
          ),
        if (_showReview)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 64,
              child: SingleChildScrollView(
                child: Text(
                  'Revisión de la hoja\nInicio: ${_items.length - _done(false)} pendientes · Final: ${_items.length - _done(true)} pendientes\n'
                  '${_items.where((i) => (i.start == _Condition.bad || i.end == _Condition.bad) && i.note.trim().isEmpty).length} elementos en mal estado sin observación.${_demo ? ' Datos de prueba.' : ''}',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ),
        Text(
          _saved
              ? (_demo ? 'Demo guardada en esta sesión' : 'Checklist guardado')
              : 'Inicio: ${_done(false)}/${_items.length} · Final: ${_done(true)}/${_items.length}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _canEdit && _items.isNotEmpty ? _save : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(112, 44)),
              child: Text(
                _saving ? 'Guardando…' : 'Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              onPressed: () {
                _finishNote();
                setState(() => _showReview = !_showReview);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(132, 44)),
              child: const Text(
                'Revisar hoja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
