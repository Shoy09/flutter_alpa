import 'dart:convert';
import 'received_summary.dart';

const operationNames = {
  'carguio': 'Scooptram',
  'tal_horizontal': 'Jumbo horizontal',
  'tal_largo': 'Taladro largo',
  'scalamin': 'Scalamin',
  'empernador': 'Sostenimiento',
  'dumper': 'Dumper',
  'volquetes': 'Volquetes',
  'scissor': 'Scissor',
  'rompebanco': 'Rompebanco',
  'anfochanger': 'Anfochanger',
};

String equipmentOf(ReceivedOperation op) {
  for (final field in ['n_equipo', 'n_volquete', 'equipo']) {
    final value = '${op.payload[field] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  return 'Sin equipo';
}

/// Pure calculations shared by table footers and production indicators.
class ProductionReport {
  ProductionReport(this.type, this.title, this.columns, this.note);
  final String type;
  final String title;
  final List<String> columns;
  final String note;
  final List<List<Object?>> rows = [];
  final Map<String, double> totals = {};
  int omitted = 0;

  static const supported = [
    'carguio',
    'tal_horizontal',
    'tal_largo',
    'scalamin',
    'empernador',
  ];

  static dynamic _decode(dynamic value) {
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    final decoded = _decode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    final decoded = _decode(value);
    if (decoded is Map) return [_map(decoded)];
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  static double number(dynamic value) {
    final parsed = num.tryParse('$value'.replaceAll(',', '.'))?.toDouble() ?? 0;
    return parsed.isFinite && parsed >= 0 ? parsed : 0;
  }

  static String text(dynamic value) =>
      value == null || '$value'.trim().isEmpty ? '—' : '$value'.trim();

  static int durationMinutes(dynamic start, dynamic end) {
    int? minutes(dynamic value) {
      final match = RegExp(
        r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
      ).firstMatch('$value');
      if (match == null) return null;
      final h = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      return h < 24 && m < 60 ? h * 60 + m : null;
    }

    final a = minutes(start);
    final b = minutes(end);
    return a == null || b == null ? 0 : (b - a + 1440) % 1440;
  }

  void _sum(String label, double value) =>
      totals.update(label, (n) => n + value, ifAbsent: () => value);

  factory ProductionReport.build(
    String type,
    Iterable<ReceivedOperation> operations,
  ) {
    final report = switch (type) {
      'carguio' => ProductionReport(
        type,
        'Resumen de carguío por labor',
        ['Equipo', 'Labor de inicio', 'Destino', 'Material', 'Cucharas'],
        'Códigos 101, 102, 105, 106 y 108. Agrupado por equipo, labor, destino y material. No se calculan toneladas sin capacidades verificadas.',
      ),
      'tal_horizontal' => ProductionReport(
        type,
        'Resumen de perforación horizontal',
        [
          'Equipo',
          'Labor',
          'Tipo de perforación',
          'Material',
          'Barra (pies)',
          'N.º barras',
          'Producción',
          'Rimados',
          'Alivio',
          'Metraje (m)',
        ],
        'Registros OPERATIVO con duración positiva, labor, tipo y metraje. Metros = (producción + rimados + alivio) × pies × 0,3048 × barras. Sin número de barras se usa 1. Incluye cruces de medianoche.',
      ),
      'tal_largo' => ProductionReport(
        type,
        'Resumen de taladro largo',
        [
          'Equipo',
          'Labor',
          'Fila',
          'Tipo de perforación',
          'N.º barras',
          'N.º taladro',
          'Metraje (m)',
        ],
        'Una fila por elemento de barras válido, sin filtro de estado. El metraje usa longitud_perforacion directamente; no se multiplica por barras.',
      ),
      'scalamin' => ProductionReport(
        type,
        'Resumen de Scalamin por labor',
        [
          'Equipo',
          'Labor',
          'Tipo de labor',
          'Área (m²)',
          'Metros lineales',
          'Observaciones',
        ],
        'Solo registros OPERATIVO. El área y los metros lineales se suman por separado.',
      ),
      _ => ProductionReport(
        type,
        'Resumen de sostenimiento por labor',
        [
          'Equipo',
          'Labor',
          'Tipo de perno',
          'Longitud (pies)',
          'Pernos',
          'Sistemático / puntual',
          'Tipo de malla',
          'MT52',
          'Taladros',
          'Long. perforación (m)',
          'Tipo de perforación',
          'Metros de pernos',
        ],
        'Solo registros OPERATIVO. Listas alineadas por índice; — indica un elemento ausente. Metros de pernos = cantidad × longitud en pies × 0,3048.',
      ),
    };
    final grouped = <String, List<Object?>>{};
    for (final operation in operations.where((op) => op.row['type'] == type)) {
      final equipment = equipmentOf(operation);
      for (final record in _list(operation.payload['registros'])) {
        final data = _map(record['operacion']);
        final active =
            OperationShift.normalize('${record['estado']}') == 'OPERATIVO';
        if (type == 'carguio') {
          if (![
            '101',
            '102',
            '105',
            '106',
            '108',
          ].contains('${record['codigo']}'.trim())) {
            continue;
          }
          final n = number(data['n_cucharas']);
          if (n <= 0) {
            report.omitted++;
            continue;
          }
          final keys = [
            equipment,
            text(data['labor_inicio']),
            text(data['ubicacion_destino']),
            text(data['material']),
          ];
          final key = jsonEncode(keys);
          final row = grouped.putIfAbsent(key, () => [...keys, 0.0]);
          row[4] = (row[4] as double) + n;
          report._sum('Cucharas', n);
        } else if (type == 'tal_horizontal') {
          if (!active) continue;
          final production = number(data['tal_prod']);
          final reamed = number(data['tal_rimados']);
          final relief = number(data['tal_alivio']);
          final feet = number(data['long_barras']);
          final bars =
              data['n_barras'] == null || '${data['n_barras']}'.trim().isEmpty
              ? 1.0
              : number(data['n_barras']);
          final meters = (production + reamed + relief) * feet * .3048 * bars;
          if (meters <= 0 ||
              text(data['labor']) == '—' ||
              text(data['tipo_perforacion']) == '—' ||
              durationMinutes(record['hora_inicio'], record['hora_final']) <=
                  0) {
            report.omitted++;
            continue;
          }
          final keys = [
            equipment,
            text(data['labor']),
            text(data['tipo_perforacion']),
            text(data['material']),
            feet,
            bars,
          ];
          final row = grouped.putIfAbsent(
            jsonEncode(keys),
            () => [...keys, 0.0, 0.0, 0.0, 0.0],
          );
          for (final entry in {
            6: production,
            7: reamed,
            8: relief,
            9: meters,
          }.entries) {
            row[entry.key] = (row[entry.key] as double) + entry.value;
          }
          report._sum('Metros perforados', meters);
          report._sum('Taladros', production + reamed + relief);
        } else if (type == 'tal_largo') {
          for (final bar in _list(data['barras'])) {
            final meters = number(bar['longitud_perforacion']);
            final line = number(bar['n_fila']);
            if (meters <= 0 ||
                (line > 0 && text(bar['tipo_perforacion']) == '—')) {
              report.omitted++;
              continue;
            }
            report.rows.add([
              equipment,
              text(data['labor']),
              bar['n_fila'],
              text(bar['tipo_perforacion']),
              bar['n_barras'],
              bar['n_taladro'],
              meters,
            ]);
            report._sum('Metros perforados', meters);
            report._sum('Barras', number(bar['n_barras']));
          }
        } else if (type == 'scalamin') {
          if (!active) continue;
          final area = number(data['area_m2']);
          final meters = number(data['metros_lineales']);
          if (area == 0 &&
              meters == 0 &&
              text(data['labor']) == '—' &&
              text(data['observaciones']) == '—') {
            report.omitted++;
            continue;
          }
          report.rows.add([
            equipment,
            text(data['labor']),
            text(data['tipo_labor_texto'] ?? data['tipo_labor']),
            area,
            meters,
            text(data['observaciones']),
          ]);
          report._sum('Área (m²)', area);
          report._sum('Metros lineales', meters);
        } else if (type == 'empernador') {
          if (!active) continue;
          final bolts = _list(data['perno']);
          final meshes = _list(data['malla']);
          final drill = _list(data['perforacion']);
          final length = [
            bolts.length,
            meshes.length,
            drill.length,
          ].reduce((a, b) => a > b ? a : b);
          for (var i = 0; i < length; i++) {
            final bolt = i < bolts.length ? bolts[i] : <String, dynamic>{};
            final mesh = i < meshes.length ? meshes[i] : <String, dynamic>{};
            final hole = i < drill.length ? drill[i] : <String, dynamic>{};
            final n = number(bolt['n_pernos_instalados']);
            final feet = number(bolt['log_pernos']);
            final meters = n * feet * .3048;
            if (n == 0 &&
                number(mesh['mt52_malla']) == 0 &&
                number(hole['n_taladros']) == 0 &&
                number(hole['longitud_perforacion']) == 0 &&
                text(bolt['tipo_pernos']) == '—' &&
                text(mesh['tipo_malla']) == '—') {
              continue;
            }
            report.rows.add([
              equipment,
              text(data['labor']),
              text(bolt['tipo_pernos']),
              bolt['log_pernos'],
              bolt['n_pernos_instalados'],
              text(bolt['sistematico_puntual']),
              text(mesh['tipo_malla']),
              mesh['mt52_malla'],
              hole['n_taladros'],
              hole['longitud_perforacion'],
              text(hole['tipo_perforacion'] ?? data['tipo_perforacion']),
              meters,
            ]);
            report._sum('Pernos', n);
            report._sum('Metros de pernos', meters);
            report._sum('Malla MT52', number(mesh['mt52_malla']));
            report._sum('Taladros', number(hole['n_taladros']));
            report._sum(
              'Long. perforación (m)',
              number(hole['longitud_perforacion']),
            );
          }
        }
      }
    }
    report.rows.addAll(grouped.values);
    return report;
  }
}
