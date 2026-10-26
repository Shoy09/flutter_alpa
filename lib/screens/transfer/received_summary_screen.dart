import 'package:flutter/material.dart';
import 'package:i_miner/core/transfer/production_report.dart';
import 'package:i_miner/core/transfer/received_summary.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';

class ReceivedSummaryScreen extends StatefulWidget {
  const ReceivedSummaryScreen({super.key, required this.store, this.now});
  final TransferStore store;
  final DateTime? now;
  @override
  State<ReceivedSummaryScreen> createState() => _ReceivedSummaryScreenState();
}

class _ReceivedSummaryScreenState extends State<ReceivedSummaryScreen> {
  static const _primary = Color(0xFF1B5E6B);
  static const _ink = Color(0xFF2C3E50);
  static const _muted = Color(0xFF687888);
  late DateTime _date;
  late String _shift;
  String _type = 'TODAS';
  String _equipment = 'TODOS';
  List<ReceivedOperation> _operations = [];
  bool _loading = true;
  String? _error;
  int _invalid = 0;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    _currentShift();
    _load();
  }

  void _currentShift() {
    final current = OperationShift.at(widget.now ?? DateTime.now());
    _date = current.date;
    _shift = current.shift;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.store.db.query(
        'LocalTransfers',
        where: 'direction = ?',
        whereArgs: ['inbox'],
        orderBy: 'updated_at DESC',
      );
      final parsed = rows
          .map(ReceivedOperation.read)
          .whereType<ReceivedOperation>()
          .toList();
      if (mounted) {
        setState(() {
          _operations = parsed;
          _invalid = rows.length - parsed.length;
          _loadedAt = DateTime.now();
          _equipment = 'TODOS';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudieron actualizar las copias recibidas. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(ReceivedOperation op) =>
      operationNames[op.row['type']] ?? '${op.row['type']}';
  String _status(ReceivedOperation op) => switch (op.row['status']) {
    'cloud' => 'En nube',
    'review' => 'Por conciliar',
    'conflict' => 'Conflicto',
    _ => 'Pendiente de nube',
  };

  Widget _panel(
    String title,
    Widget child, {
    String? subtitle,
    Widget? action,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E9EE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );

  Widget _tag(String value, {Color color = _primary}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      value,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 235,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDFE6EC)),
        ),
      ),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) changed(value);
      },
    ),
  );

  Widget _header(List<ReceivedOperation> filtered) => LayoutBuilder(
    builder: (context, size) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Control de producción',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Copias recibidas · Sin internet',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _loadedAt == null
                ? 'Cargando copias'
                : 'Actualizado ${TimeOfDay.fromDateTime(_loadedAt!).format(context)}',
            style: const TextStyle(color: _primary, fontSize: 11),
          ),
        ],
      );
      if (size.maxWidth >= 1100) {
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            SizedBox(width: 680, child: _metrics(filtered)),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 12), _metrics(filtered)],
      );
    },
  );

  Widget _filters(List<String> equipment) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E9EE)),
    ),
    child: Wrap(
      spacing: 14,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(OperationShift.dateKey(_date)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) {
                setState(() {
                  _date = date;
                  _equipment = 'TODOS';
                });
              }
            },
          ),
        ),
        _select(
          'Turno',
          _shift,
          {
            'DIA': 'DÍA · 06:00–18:00',
            'NOCHE': 'NOCHE · 18:00–06:00',
            'TODOS': 'Todos los turnos',
          },
          (value) => setState(() {
            _shift = value;
            _equipment = 'TODOS';
          }),
        ),
        _select(
          'Operación',
          _type,
          {'TODAS': 'Todas las operaciones', ...operationNames},
          (value) => setState(() {
            _type = value;
            _equipment = 'TODOS';
          }),
        ),
        _select('Equipo', _equipment, {
          'TODOS': 'Todos los equipos',
          for (final item in equipment) item: item,
        }, (value) => setState(() => _equipment = value)),
        Tooltip(
          message:
              'DÍA 06:00–17:59 · NOCHE 18:00–05:59. Antes de las 06:00 se usa la fecha del día anterior.',
          child: Icon(Icons.info_outline, size: 20, color: _muted),
        ),
        TextButton.icon(
          onPressed: () => setState(() {
            _currentShift();
            _type = 'TODAS';
            _equipment = 'TODOS';
          }),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restablecer'),
        ),
      ],
    ),
  );

  Widget _metric(String label, int count, IconData icon, Color color) =>
      Container(
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E9EE)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _metrics(List<ReceivedOperation> filtered) {
    final cloud = filtered.where((op) => op.row['status'] == 'cloud').length;
    final review = filtered
        .where((op) => ['review', 'conflict'].contains(op.row['status']))
        .length;
    final cards = [
      _metric(
        'Recibidas',
        filtered.length,
        Icons.inventory_2_outlined,
        _primary,
      ),
      _metric(
        'En nube',
        cloud,
        Icons.cloud_done_outlined,
        const Color(0xFF2E7D32),
      ),
      _metric(
        'Pendientes de nube',
        filtered.length - cloud - review,
        Icons.cloud_upload_outlined,
        const Color(0xFF3579A3),
      ),
      _metric(
        'Por revisar',
        review,
        Icons.fact_check_outlined,
        const Color(0xFFB46916),
      ),
    ];
    return LayoutBuilder(
      builder: (context, size) {
        final columns = size.maxWidth >= 660
            ? 4
            : size.maxWidth >= 300
            ? 2
            : 1;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: (size.maxWidth - 10 * (columns - 1)) / columns,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _distribution(List<ReceivedOperation> filtered) {
    final counts = <String, int>{};
    for (final op in filtered) {
      counts.update(_name(op), (n) => n + 1, ifAbsent: () => 1);
    }
    final groups = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final operators = filtered
        .map((op) => '${op.payload['operador'] ?? op.row['source']}')
        .toSet()
        .length;
    return _panel(
      'Distribución de operaciones',
      groups.isEmpty
          ? _empty()
          : Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                for (final group in groups)
                  SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.key,
                                style: const TextStyle(color: _ink),
                              ),
                            ),
                            Text(
                              '${group.value} · ${(group.value * 100 / filtered.length).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: group.value / filtered.length,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(6),
                          color: _primary,
                          backgroundColor: const Color(0xFFE8F1F3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      subtitle:
          '$operators operadores · ${filtered.map(equipmentOf).toSet().length} equipos en la selección. El gráfico cuenta operaciones, no unidades de producción.',
    );
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Icon(Icons.search_off_outlined, color: _muted),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No hay datos para los filtros seleccionados.',
            style: TextStyle(color: _muted),
          ),
        ),
      ],
    ),
  );

  Widget _production(ProductionReport report) => _panel(
    report.title,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.rows.isEmpty)
          _empty()
        else
          ReportTable(
            key: ValueKey('${report.type}:$_date:$_shift:$_equipment'),
            columns: report.columns,
            rows: report.rows,
          ),
        if (report.totals.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in report.totals.entries)
                _tag('${item.key}: ${_format(item.value)}'),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Text(
          report.note,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
        if (report.omitted > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${report.omitted} registros/filas omitidos por datos incompletos o valores sin producción.',
              style: const TextStyle(color: Color(0xFFB46916), fontSize: 12),
            ),
          ),
      ],
    ),
    subtitle:
        '${report.rows.length} filas de producción · totales de la selección actual',
  );

  void _detail(ReceivedOperation op) {
    final type = '${op.row['type']}';
    final report = ProductionReport.supported.contains(type)
        ? ProductionReport.build(type, [op])
        : null;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 1150,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalle · ${_name(op)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _tag('${op.payload['fecha']} · ${op.payload['turno']}'),
                        _tag('Equipo: ${equipmentOf(op)}'),
                        _tag(_status(op)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Operador: ${op.payload['operador'] ?? op.row['source']}\nJefe de guardia: ${op.payload['jefe_guardia'] ?? '—'}',
                      style: const TextStyle(color: _ink, height: 1.8),
                    ),
                    const SizedBox(height: 20),
                    if (report != null)
                      _production(report)
                    else
                      const Text(
                        'Este proceso aún no tiene una tabla de producción específica. Su copia permanece disponible en el historial de transferencias.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFiltered = _operations
        .where((op) => op.matches(_date, _shift))
        .toList();
    final byType = dateFiltered
        .where((op) => _type == 'TODAS' || op.row['type'] == _type)
        .toList();
    final equipment = byType.map(equipmentOf).toSet().toList()..sort();
    final filtered = byType
        .where((op) => _equipment == 'TODOS' || equipmentOf(op) == _equipment)
        .toList();
    final reportTypes = ProductionReport.supported.where(
      (type) => filtered.any((op) => op.row['type'] == type),
    );
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _primary)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Resumen de operaciones recibidas'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Actualizar resumen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _header(filtered),
                const SizedBox(height: 14),
                _filters(equipment),
                const SizedBox(height: 18),
                if (_loading) const LinearProgressIndicator(color: _primary),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_invalid > 0)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '$_invalid copias no pudieron interpretarse; no se incluyen en los totales.',
                    ),
                  ),
                _distribution(filtered),
                const SizedBox(height: 18),
                for (final type in reportTypes) ...[
                  _production(ProductionReport.build(type, filtered)),
                  const SizedBox(height: 18),
                ],
                _panel(
                  'Operaciones recibidas',
                  filtered.isEmpty
                      ? _empty()
                      : ReportTable(
                          key: ValueKey(
                            'operations:$_date:$_shift:$_type:$_equipment',
                          ),
                          columns: const [
                            'Operación',
                            'Fecha',
                            'Turno',
                            'Equipo',
                            'Operador',
                            'Estado',
                            'Detalle',
                          ],
                          rows: [
                            for (final op in filtered)
                              [
                                _name(op),
                                op.payload['fecha'],
                                op.payload['turno'],
                                equipmentOf(op),
                                op.payload['operador'] ?? op.row['source'],
                                _status(op),
                                'Ver detalle',
                              ],
                          ],
                          onSelect: (index) => _detail(filtered[index]),
                        ),
                  subtitle:
                      'Mostrando ${filtered.length} de ${dateFiltered.length} operaciones de la fecha y turno. Selecciona una fila para abrir su detalle.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Los reportes usan la fecha y el turno de la operación, no la fecha de transferencia.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _format(Object? value) {
  if (value == null || '$value'.trim().isEmpty) return '—';
  if (value is num) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
  return '$value';
}

/// Paged rows keep large transfers usable; wide tables scroll horizontally.
class ReportTable extends StatefulWidget {
  const ReportTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onSelect,
  });
  final List<String> columns;
  final List<List<Object?>> rows;
  final ValueChanged<int>? onSelect;
  @override
  State<ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<ReportTable> {
  int _page = 0;
  static const _pageSize = 10;

  @override
  void didUpdateWidget(covariant ReportTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page * _pageSize >= widget.rows.length) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.rows.length);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columns: widget.columns
                      .map(
                        (label) => DataColumn(
                          label: Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF1B5E6B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  showCheckboxColumn: false,
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xFFF0F5F7),
                  ),
                  horizontalMargin: 16,
                  columnSpacing: 28,
                  headingRowHeight: 48,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 56,
                  rows: [
                    for (var index = start; index < end; index++)
                      DataRow.byIndex(
                        index: index,
                        onSelectChanged: widget.onSelect == null
                            ? null
                            : (_) => widget.onSelect!(index),
                        color: WidgetStatePropertyAll(
                          index.isOdd ? const Color(0xFFFAFCFD) : Colors.white,
                        ),
                        cells: [
                          for (final value in widget.rows[index])
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                child: Text(
                                  _format(value),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.rows.isEmpty ? 0 : start + 1}–$end de ${widget.rows.length} filas',
                  style: const TextStyle(
                    color: Color(0xFF687888),
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Página anterior',
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: end >= widget.rows.length
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
