import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/core/transfer/production_report.dart';
import 'package:i_miner/core/transfer/received_summary.dart';

ReceivedOperation operation(
  String type,
  List<Map<String, dynamic>> records, {
  String equipment = 'E1',
  bool encode = false,
}) => ReceivedOperation(
  {'type': type, 'direction': 'inbox'},
  {'n_equipo': equipment, 'registros': encode ? jsonEncode(records) : records},
);

Map<String, dynamic> record(
  Map<String, dynamic> data, {
  String state = 'OPERATIVO',
  String code = '101',
  String start = '23:00',
  String end = '01:00',
}) => {
  'estado': state,
  'codigo': code,
  'hora_inicio': start,
  'hora_final': end,
  'operacion': data,
};

void main() {
  test(
    'scoop groups by equipment/labor/destination/material, allows only selected codes',
    () {
      final a = {
        'labor_inicio': 'L1',
        'ubicacion_destino': 'D1',
        'material': 'MINERAL',
        'n_cucharas': '4',
      };
      final report = ProductionReport.build('carguio', [
        operation('carguio', [
          record(a),
          record({...a, 'n_cucharas': 6}, code: '108'),
          record(a, code: '111'),
          record({...a, 'n_cucharas': -4}),
        ], encode: true),
        operation('carguio', [record(a)], equipment: 'E2'),
        operation('dumper', [record(a)]),
      ]);
      expect(report.rows.length, 2);
      expect(report.rows.first.last, 10);
      expect(report.totals['Cucharas'], 14);
      expect(report.omitted, 1);
      expect(report.totals.containsKey('Toneladas'), isFalse);
    },
  );

  test(
    'horizontal calculates feet to meters, groups counts and handles midnight',
    () {
      final data = {
        'labor': 'L1',
        'tipo_perforacion': 'FRENTE',
        'material': 'ROCA',
        'tal_prod': '2',
        'tal_rimados': 1,
        'tal_alivio': 1,
        'long_barras': '10',
      };
      final report = ProductionReport.build('tal_horizontal', [
        operation('tal_horizontal', [
          record(data),
          record(data),
          record({...data, 'n_barras': 2}),
          record(data, state: 'DEMORA'),
          record(data, end: '23:00'),
          record({...data, 'labor': ''}),
          record({...data, 'n_barras': 0}),
        ]),
      ]);
      expect(report.rows.length, 2);
      expect(report.rows.first[6], 4);
      expect(report.totals['Metros perforados'], closeTo(48.768, .00001));
      expect(report.totals['Taladros'], 12);
      expect(report.omitted, 3);
      expect(ProductionReport.durationMinutes('23:30', '01:00'), 90);
      expect(ProductionReport.durationMinutes('06:00', '06:00'), 0);
      expect(ProductionReport.durationMinutes('25:00', '06:00'), 0);
      expect(ProductionReport.durationMinutes('', ''), 0);
    },
  );

  test(
    'long drill uses registered length once, including bars without state filtering',
    () {
      final report = ProductionReport.build('tal_largo', [
        operation('tal_largo', [
          record({
            'labor': 'L1',
            'barras': [
              {
                'n_fila': 1,
                'tipo_perforacion': 'PRODUCCIÓN',
                'n_barras': 4,
                'n_taladro': 7,
                'longitud_perforacion': 12,
              },
              {'n_fila': 2, 'tipo_perforacion': '', 'longitud_perforacion': 8},
              {'n_fila': 0, 'longitud_perforacion': '2,5'},
              {'n_fila': 1, 'tipo_perforacion': 'X', 'longitud_perforacion': 0},
            ],
          }, state: 'DEMORA'),
        ]),
      ]);
      expect(report.rows.length, 2);
      expect(report.totals['Metros perforados'], 14.5);
      expect(report.totals['Barras'], 4);
      expect(report.omitted, 2);
    },
  );

  test(
    'scalamin keeps area and linear meters separate and excludes downtime',
    () {
      final data = {
        'labor': 'L1',
        'area_m2': '12.5',
        'metros_lineales': 3,
        'tipo_labor_texto': 'FRENTE',
      };
      final report = ProductionReport.build('scalamin', [
        operation('scalamin', [
          record(data),
          record(data, state: 'MANTENIMIENTO'),
          record({}),
        ]),
      ]);
      expect(report.rows.length, 1);
      expect(report.totals['Área (m²)'], 12.5);
      expect(report.totals['Metros lineales'], 3);
      expect(report.omitted, 1);
    },
  );

  test(
    'sostenimiento aligns unequal lists without multiplying totals and supports legacy maps',
    () {
      final report = ProductionReport.build('empernador', [
        operation('empernador', [
          record({
            'labor': 'L1',
            'tipo_perforacion': 'FRENTE',
            'perno': [
              {
                'tipo_pernos': 'Helicoidal',
                'log_pernos': '7',
                'n_pernos_instalados': 10,
              },
            ],
            'malla': [
              {'tipo_malla': 'M1', 'mt52_malla': 2},
              {'tipo_malla': 'M2', 'mt52_malla': 3},
            ],
            'perforacion': [
              {'n_taladros': 4, 'longitud_perforacion': 5},
            ],
          }),
          record({
            'labor': 'L2',
            'perno': {
              'tipo_pernos': 'Otro',
              'log_pernos': 2,
              'n_pernos_instalados': 1,
            },
          }),
          record({
            'perno': [
              {'n_pernos_instalados': 100},
            ],
          }, state: 'DEMORA'),
        ], encode: true),
      ]);
      expect(report.rows.length, 3);
      expect(report.rows[1][4], isNull);
      expect(report.rows[0][10], 'FRENTE');
      expect(report.totals['Pernos'], 11);
      expect(report.totals['Metros de pernos'], closeTo(21.9456, .00001));
      expect(report.totals['Malla MT52'], 5);
      expect(report.totals['Taladros'], 4);
    },
  );

  test('malformed or empty records do not crash reports', () {
    for (final type in ProductionReport.supported) {
      final report = ProductionReport.build(type, [
        ReceivedOperation({'type': type}, {'registros': 'invalid'}),
      ]);
      expect(report.rows, isEmpty);
    }
    expect(ProductionReport.number('NaN'), 0);
    expect(ProductionReport.number('Infinity'), 0);
  });
}
