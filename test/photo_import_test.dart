import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/models/photo_draft.dart';
import 'package:i_miner/models/photo_proceso.dart';
import 'package:i_miner/services/photo_service.dart';
import 'package:i_miner/services/photo_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PhotoDraft draft({String turno = 'NOCHE'}) => PhotoDraft(
  cabecera: {
    'fecha': '2026-10-20',
    'turno': turno,
    'seccion': 'B',
    'operador': 'Operador',
    'jefe_guardia': 'Jefe',
    'equipo': 'Simba',
    'n_equipo': '02',
    'modelo_equipo': 'Modelo',
  },
  actividades: [
    PhotoActivity(
      datos: {'codigo': '101', 'hora_inicio': '23:55', 'hora_final': '00:10'},
      barras: [
        {
          'n_fila': '1',
          'n_taladro': '2',
          'n_barras': '3',
          'longitud_perforacion': '10,8',
          'tipo_perforacion': 'Rimado',
        },
      ],
    ),
    PhotoActivity(
      datos: {'codigo': '302', 'hora_inicio': '00:10', 'hora_final': '00:20'},
    ),
  ],
);
const codes = {'101': 'OPERATIVO', '302': 'DEMORA'};

void main() {
  test('each process uses its own route in the existing API', () {
    expect(
      PhotoService.urlPara(PhotoProceso.talLargo),
      '${ApiConfig.baseUrl}/tal-largo/preview',
    );
    expect(
      PhotoService.urlPara(PhotoProceso.talHorizontal),
      '${ApiConfig.baseUrl}/tal-horizontal/preview',
    );
  });
  test('scissor sheet: labor and destino stay per row; tipo saved as tipo_labor', () {
    const estados = {'101': 'OPERATIVO', '105': 'OPERATIVO', '307': 'DEMORA'};
    final d = PhotoDraft.fromJson({
      'cabecera': {'turno': 'DIA', 'fecha': '29/10/26'},
      'actividades': [
        {'codigo': '105', 'hora_inicio': '9.50', 'hora_final': '10.02', 'labor': 'CX 416', 'destino': 'P 16'},
        {
          'codigo': '101',
          'hora_inicio': '10.02',
          'hora_final': '11.12',
          'destino': 'P 19',
          'cable': '30',
          'tipo_perforacion': 'm',
          'observaciones': 'Se recuperó cable eléctrico',
        },
        {'codigo': '307', 'hora_inicio': '12.09', 'hora_final': '1.00'},
      ],
      'horometros': {
        'diesel': {'inicio': '2736.8', 'final': '2742.4'},
      },
    }, proceso: PhotoProceso.scissor)
      ..completarLabores(estados)
      ..reubicarDatos(estados);
    d.idsCatalogo['tipo_perforacion'] = {'MANTENIMIENTO': 4};

    expect(d.horometros.keys, ['diesel']);
    // La labor no se repite: el 101 trabaja en el destino del traslado.
    expect(d.actividades[1].datos['labor'], '');
    expect(d.actividades.first.datos['labor'], 'CX_416');
    final rows = d.registros(estados, firstId: 1);
    final op = rows[1]['operacion'] as Map;
    expect(op['destino'], 'P 19');
    expect(op['cable'], '30');
    expect(op['tipo_labor'], 'MANTENIMIENTO');
    expect(op['tipo_labor_id'], 4);
    expect(op.containsKey('tipo_perforacion'), isFalse);
    expect((rows.last['operacion'] as Map)['destino'], '');
  });
  test('scoop sheet: two trips split the state; cucharas take their material', () {
    const estados = {
      '102': 'OPERATIVO',
      '112': 'OPERATIVO',
      '306': 'DEMORA',
    };
    final d = PhotoDraft.fromJson({
      'cabecera': {'turno': 'DIA', 'fecha': '29/10/2026'},
      'actividades': [
        {'codigo': '306', 'hora_inicio': '7.00', 'hora_final': '7.10', 'viajes': []},
        {
          'codigo': '112',
          'hora_inicio': '7.10',
          'hora_final': '7.25',
          'viajes': [
            {'origen': 'CMP11', 'destino': 'TJ5181'},
          ],
        },
        {
          'codigo': '102',
          'hora_inicio': '7.25',
          'hora_final': '8.40',
          'tipo_labor': 'TL',
          'viajes': [
            {'origen': 'TJ5181', 'destino': 'CM5181', 'mineral': '16'},
            {'origen': 'CM5181', 'destino': 'V01', 'mineral': '15'},
          ],
        },
        {
          'codigo': '102',
          'hora_inicio': '9.50',
          'hora_final': '10.10',
          'viajes': [
            {'origen': 'SN3828', 'destino': 'CM2650', 'desmonte': '05'},
          ],
        },
      ],
      'horometros': {
        'horometro': {'inicio': '41197', 'final': '41285'},
      },
    }, proceso: PhotoProceso.scoop);

    expect(d.cabecera['fecha'], '2026-10-29');
    expect(d.horometros.keys, ['horometro']);
    // 4 actividades de la hoja → 5 estados: el 102 de 7:25 se divide.
    expect(d.actividades, hasLength(5));
    final [primero, segundo] = [d.actividades[2].datos, d.actividades[3].datos];
    expect('${primero['hora_inicio']}-${primero['hora_final']}', '07:25-08:00');
    expect('${segundo['hora_inicio']}-${segundo['hora_final']}', '08:00-08:40');
    expect(primero['labor_inicio'], 'TJ5181');
    expect(segundo['ubicacion_destino'], 'V01');
    expect(primero['n_cucharas'], '16');
    expect(primero['material'], 'MINERAL');
    expect(primero['observaciones'], 'Tipo de labor: TALADROS LARGOS');
    expect(segundo['observaciones'], '');
    expect(d.actividades.last.datos['material'], 'DESMONTE');
    expect(d.advertencias.join(), contains('2 viajes'));
    expect(d.validate(estados).where((e) => e.contains('Actividad')), isEmpty);

    d.idsDestino['CM5181'] = 7;
    final rows = d.registros(estados, firstId: 1);
    final op = rows[2]['operacion'] as Map;
    expect(op['n_cucharas'], 16);
    expect(op['ubicacion_destino_id'], 7);
    expect(op['mineral'], '');
    // 112 (traslado) no lleva datos en el formulario de Scoop.
    expect((rows[1]['operacion'] as Map)['labor_inicio'], '');
    expect(rows.last['hora_final'], isNull);
  });
  test('scalamin sheet: only 101 keeps data, numbers stored as decimals', () {
    expect(PhotoDraft.formatearLabor('TJ5181'), 'TJ_5181');
    expect(PhotoDraft.formatearLabor('P.7 TJ5181'), 'P_7_TJ_5181');
    const estados = {
      '101': 'OPERATIVO',
      '105': 'OPERATIVO',
      '410': 'DEMORA',
    };
    final d = PhotoDraft.fromJson({
      'cabecera': {'turno': 'DIA', 'fecha': '29/10/26'},
      'actividades': [
        {'codigo': '105', 'hora_inicio': '9.40', 'hora_final': '10.00', 'labor': 'P.7 TJ5181'},
        {'codigo': '410', 'hora_inicio': '10.00', 'hora_final': '10.10'},
        {
          'codigo': '101',
          'hora_inicio': '10.10',
          'hora_final': '11.00',
          'labor': 'TJ5181',
          'metros_lineales': '12,5',
          'tipo_labor_texto': 'b',
        },
        {'codigo': '105', 'hora_inicio': '11.00', 'hora_final': '11.20', 'tipo_labor_texto': 'F'},
      ],
      'horometros': {
        'diesel': {'inicio': '1395', 'final': '1401'},
        'percusion': {'inicio': '264.58', 'final': '265.57'},
      },
    }, proceso: PhotoProceso.scalamin)
      ..completarLabores(estados)
      ..reubicarDatos(estados);

    expect(d.horometros.keys, ['diesel', 'percusion']);
    final desatado = d.actividades[2].datos;
    expect(desatado['labor'], 'TJ_5181');
    expect(desatado['tipo_labor_texto'], 'BREASTING');
    final rows = d.registros(estados, firstId: 1);
    final op = rows[2]['operacion'] as Map;
    expect(op['metros_lineales'], 12.5);
    expect(op['area_m2'], 0.0);
    expect(op['tipo_labor_texto'], 'BREASTING');
    // El tipo escrito junto al traslado pasó al 101 (ya tenía uno: se descarta).
    final traslado = rows.last['operacion'] as Map;
    expect(traslado['tipo_labor_texto'], '');
    expect(traslado['metros_lineales'], 0.0);
    expect((rows.first['operacion'] as Map)['labor'], 'P_7_TJ_5181');

    // Una ubicación escrita en metros lineales no es un número: va a
    // observaciones y el campo queda vacío.
    final traslado2 = PhotoDraft.fromJson({
      'cabecera': {'turno': 'DIA'},
      'actividades': [
        {
          'codigo': '105',
          'hora_inicio': '8.50',
          'hora_final': '9.05',
          'labor': '416',
          'metros_lineales': 'P.7',
        },
      ],
      'horometros': {},
    }, proceso: PhotoProceso.scalamin);
    final datos = traslado2.actividades.single.datos;
    expect(datos['metros_lineales'], '');
    expect(datos['observaciones'], 'P.7');
    expect(datos['labor'], '416');
  });
  test('empernador sheet: columns become the form lists perforacion/perno/malla', () {
    const estados = {
      '101': 'OPERATIVO',
      '102': 'OPERATIVO',
      '103': 'OPERATIVO',
      '307': 'DEMORA',
    };
    final d = PhotoDraft.fromJson({
      'cabecera': {'turno': 'DIA'},
      'actividades': [
        {'codigo': '101', 'hora_inicio': '9.30', 'hora_final': '10.20', 'labor': 'TJ 4026'},
        {
          'codigo': '103',
          'hora_inicio': '10.20',
          'hora_final': '10.30',
          'tald_perf': '38',
          'long_perf': '7',
          'sw7': '38',
          'malla_c8': '53.24',
        },
        {'codigo': '307', 'hora_inicio': '11.00', 'hora_final': '12.30'},
        {
          'codigo': '102',
          'hora_inicio': '2.50',
          'hora_final': '3.15',
          'tald_perf': '16',
          'long_perf': '7',
          'ss7': '5',
          'tipo_perforacion': 'NICHO',
        },
      ],
      'horometros': {
        'diesel': {'inicio': '3728.7', 'final': '3730.9'},
      },
    }, proceso: PhotoProceso.empernador)
      ..completarLabores(estados)
      ..reubicarDatos(estados);
    d.catalogoColumnas['sw7'] = {'tipo': 'SWELLEX', 'longitud': '2.1'};

    expect(d.horometros.keys, PhotoProceso.empernador.horometros);
    expect(d.actividades.first.datos['tald_perf'], '38');
    expect(d.actividades[1].datos['sw7'], '');
    expect(d.actividades.last.datos['labor'], 'TJ_4026');

    final rows = d.registros(estados, firstId: 1);
    final op = rows.first['operacion'] as Map;
    expect(op['perforacion'], [
      {'n_taladros': 38, 'longitud_perforacion': 7.0},
    ]);
    expect(op['perno'], [
      {
        'tipo_pernos': 'SWELLEX',
        'log_pernos': '2.1',
        'n_pernos_instalados': 38,
        'sistematico_puntual': '',
      },
    ]);
    expect(op['malla'], [
      {'tipo_malla': 'C-8', 'mt52_malla': '53.24'},
    ]);
    // 102: el formulario solo muestra perforación, sin pernos ni malla.
    final op102 = rows.last['operacion'] as Map;
    expect(op102['perforacion'], hasLength(1));
    expect(op102['perno'], isEmpty);
    expect(op102['tipo_perforacion'], 'NICHO');
    expect((rows[2]['operacion'] as Map)['perforacion'], isEmpty);
  });
  test('horizontal sheet: letters, dashes, brazo and drilling data placement', () {
    const estados = {
      '101': 'OPERATIVO',
      '103': 'OPERATIVO',
      '106': 'OPERATIVO',
      '307': 'DEMORA',
    };
    final d = PhotoDraft.fromJson({
      'cabecera': {'turno': 'Día', 'fecha': '29/10/26'},
      'actividades': [
        {'codigo': '106', 'hora_inicio': '8.35', 'hora_final': '8.45', 'labor': 'CX 730'},
        {'codigo': '101', 'hora_inicio': '9.00', 'hora_final': '11.15'},
        {
          'codigo': '103',
          'hora_inicio': '11.15',
          'hora_final': '11.35',
          'tal_prod': '34',
          'tal_rimados': '6',
          'long_barras': '13',
          'brazo': 'IZQ',
          'material': 'M',
          'tipo_perforacion': 'f',
        },
        {'codigo': '307', 'hora_inicio': '11.35', 'hora_final': '12.40'},
        {
          'codigo': '101',
          'hora_inicio': '3.25',
          'hora_final': '4.00',
          'labor': 'CX 5181',
          'tal_prod': '20',
          'tal_rimados': '-',
          'long_barras': '13',
          'material': 'M',
          'tipo_perforacion': 'B',
          'observaciones': '+4 Recortes',
        },
      ],
      'horometros': {
        'diesel': {'inicio': '222.8', 'final': '224.4'},
        'electrico2': {'inicio': null, 'final': null},
      },
    }, proceso: PhotoProceso.talHorizontal)
      ..completarLabores(estados)
      ..reubicarDatos(estados);

    expect(d.cabecera['fecha'], '2026-10-29');
    expect(d.horometros.keys, PhotoProceso.talHorizontal.horometros);
    expect(d.horometros['diesel']!['final'], '224.4');
    // El 101 toma la labor del traslado y los datos escritos junto al 103.
    final perforacion = d.actividades[1].datos;
    expect(perforacion['labor'], 'CX_730');
    expect(perforacion['tal_prod'], '34');
    expect(perforacion['material'], 'MINERAL');
    expect(perforacion['tipo_perforacion'], 'FRENTE');
    expect(perforacion['observaciones'], 'Brazo IZQ');
    expect(d.actividades[2].datos['tal_prod'], '');
    final ultima = d.actividades.last.datos;
    expect(ultima['hora_inicio'], '15:25');
    expect(ultima['tal_rimados'], '');
    expect(ultima['tipo_perforacion'], 'BREASTING');

    final rows = d.registros(estados, firstId: 1);
    final op = rows[1]['operacion'] as Map;
    expect(op.containsKey('barras'), isFalse);
    expect(op['long_barras'], '13');
    expect((rows[0]['operacion'] as Map)['tal_prod'], '');
    expect(rows.last['hora_final'], isNull);
  });
  test('midnight sequence is valid and taladros keep numeric schema', () {
    final d = draft();
    expect(d.validate(codes), isEmpty);
    final rows = d.registros(codes, firstId: 10);
    expect(rows.map((r) => r['numero']), [1, 2]);
    expect(rows.last['estado'], 'DEMORA');
    expect(rows.first['hora_final'], '00:10');
    final bar = (rows.first['operacion'] as Map)['barras'][0] as Map;
    expect(bar['longitud_perforacion'], 10.8);
    expect(bar['n_fila'], isA<int>());
    expect(bar['n_taladro'], 2);
  });
  test('rejects overlaps, impossible dates, wrong shift and unknown codes', () {
    final d = draft();
    d.actividades.last.datos['hora_inicio'] = '00:05';
    expect(d.validate(codes).join(), contains('superponen'));
    d.cabecera['fecha'] = '2026-02-30';
    expect(d.validate(codes).join(), contains('fecha'));
    d.cabecera['turno'] = 'DÍA';
    expect(d.validate(codes).join(), contains('turno'));
    d.actividades.last.datos['codigo'] = '999';
    expect(d.validate(codes).join(), contains('catálogo'));
  });
  test('read hours are converted to 24 h HH:mm using the shift', () {
    Map<String, dynamic> sheet(String turno, List<List<String>> horas) => {
      'cabecera': {'turno': turno},
      'actividades': [
        for (final h in horas)
          {'codigo': '101', 'hora_inicio': h[0], 'hora_final': h[1]},
      ],
      'horometros': {},
    };
    String horas(PhotoDraft d) => d.actividades
        .map((a) => '${a.datos['hora_inicio']}-${a.datos['hora_final']}')
        .join(' ');

    final dia = PhotoDraft.fromJson(sheet('Dia', [
      ['6:30', '7.15'],
      ['07:15:00', '1130'],
      ['11:30', '1:00'],
      ['1:00 p.m.', '6:30'],
    ]));
    expect(dia.cabecera['turno'], 'DÍA');
    expect(
      horas(dia),
      '06:30-07:15 07:15-11:30 11:30-13:00 13:00-18:30',
    );
    expect(dia.validate(codes).where((e) => e.contains('Actividad')), isEmpty);

    final noche = PhotoDraft.fromJson(sheet('NOCHE', [
      ['6:30', '11:55'],
      ['11:55', '12:10'],
      ['12:10', '6:30'],
    ]));
    expect(
      horas(noche),
      '18:30-23:55 23:55-00:10 00:10-06:30',
    );
  });
  test('01:20 becomes 13:20 even when the shift is missing or reworded', () {
    for (final turno in ['', 'Turno Día', 'DIURNO']) {
      final d = PhotoDraft.fromJson({
        'cabecera': {'turno': turno},
        'actividades': [
          {'codigo': '101', 'hora_inicio': '07:00', 'hora_final': '01:20'},
          {'codigo': '101', 'hora_inicio': '01:20', 'hora_final': '05:45'},
        ],
        'horometros': {},
      });
      expect(d.cabecera['turno'], 'DÍA');
      expect(d.actividades.first.datos['hora_final'], '13:20');
      expect(d.actividades.last.datos['hora_inicio'], '13:20');
      expect(d.actividades.last.datos['hora_final'], '17:45');
    }
    final manual = PhotoDraft(
      cabecera: {'turno': 'NOCHE'},
      actividades: [
        PhotoActivity(datos: {'hora_inicio': '01:20', 'hora_final': '02:00'}),
      ],
    )..normalizarHoras();
    expect(manual.actividades.single.datos['hora_inicio'], '01:20');
    manual.cabecera['turno'] = 'DÍA';
    manual.normalizarHoras();
    expect(manual.actividades.single.datos['hora_inicio'], '13:20');
  });
  test('a labor written once applies to every drilling state, as TJ_493', () {
    expect(PhotoDraft.formatearLabor(' tj 493 '), 'TJ_493');
    expect(PhotoDraft.formatearLabor('Tj-493'), 'TJ_493');
    const estados = {'101': 'OPERATIVO', '302': 'DEMORA', '110': 'OPERATIVO'};
    final d = PhotoDraft(
      actividades: [
        PhotoActivity(datos: {'codigo': '302'}),
        PhotoActivity(datos: {'codigo': '101', 'tipo_labor': 'tj', 'labor': '493'}),
        PhotoActivity(datos: {'codigo': '302'}),
        PhotoActivity(datos: {'codigo': '101'}),
        PhotoActivity(datos: {'codigo': '110'}),
      ],
    )..completarLabores(estados);
    expect(d.actividades.map((a) => a.datos['labor']), [
      '',
      'TJ_493',
      '',
      'TJ_493',
      '',
    ]);
    expect(d.advertencias.single, contains('actividad(es) 4'));

    final enAla = PhotoDraft(
      actividades: [
        PhotoActivity(datos: {'codigo': '101', 'labor': '493', 'ala': 'tj'}),
        PhotoActivity(datos: {'codigo': '101', 'labor': '493', 'ala': 'Norte'}),
      ],
    )..completarLabores(estados);
    expect(enAla.actividades.map((a) => a.datos['labor']), [
      'TJ_493',
      '493',
    ]);
  });
  test('sheet dates DD/MM/AA become AAAA-MM-DD', () {
    String fecha(String leida) => PhotoDraft.fromJson({
      'cabecera': {'fecha': leida},
      'actividades': [],
      'horometros': {},
    }).cabecera['fecha']!;
    expect(fecha('21/10/26'), '2026-10-21');
    expect(fecha('21-10-2026'), '2026-10-21');
    expect(fecha('2026/10/21'), '2026-10-21');
    expect(fecha('2026-10-21'), '2026-10-21');
    expect(fecha('31/02/26'), '31/02/26');
  });
  test('the last state stays open, like a manual record', () {
    final d = draft();
    d.actividades.last.datos['hora_final'] = '';
    expect(d.validate(codes), isEmpty);
    final rows = d.registros(codes, firstId: 1);
    expect(rows.first['hora_final'], '00:10');
    expect(rows.last['hora_final'], isNull);
  });
  test('bars written under a no-bar code move to the previous drilling state', () {
    const estados = {
      '101': 'OPERATIVO',
      '107': 'OPERATIVO',
      '201': 'OPERATIVO',
      '302': 'DEMORA',
    };
    expect(PhotoDraft.llevaBarras('OPERATIVO', '101'), isTrue);
    expect(PhotoDraft.llevaBarras('OPERATIVO', '107'), isFalse);
    expect(PhotoDraft.llevaBarras('OPERATIVO', '201'), isFalse);
    expect(PhotoDraft.llevaBarras('OPERATIVO', '500'), isFalse);
    expect(PhotoDraft.llevaBarras('DEMORA', '101'), isFalse);

    Map<String, String> bar(String n) => {
      'n_fila': '1',
      'n_taladro': n,
      'n_barras': '3',
      'longitud_perforacion': '10',
      'tipo_perforacion': 'Producción',
    };
    final d = draft()
      ..actividades.first.barras
          .replaceRange(0, 1, [bar('1')])
      ..actividades.last.barras.add(bar('2'))
      ..actividades.add(
        PhotoActivity(
          datos: {'codigo': '201', 'hora_inicio': '00:20'},
          barras: [bar('3')],
        ),
      );
    d.reubicarDatos(estados);
    expect(
      d.actividades.first.barras.map((b) => b['n_taladro']),
      ['1', '2', '3'],
    );
    expect(d.actividades[1].barras, isEmpty);
    expect(d.actividades[2].barras, isEmpty);
    expect(d.advertencias, hasLength(2));
    final rows = d.registros(estados, firstId: 1);
    expect((rows[1]['operacion'] as Map)['barras'], isEmpty);
  });
  test('ambiguous times block the save; bar and meter gaps are pending', () {
    final d = draft();
    d.actividades.first.datos['hora_inicio'] = '1:00';
    expect(d.validate(codes).join(), contains('24 h'));
    expect(photoNumber('NaN'), isNull);
  });
  test('incomplete bars and meters are saved as 0 and listed as pending', () {
    final d = draft();
    d.actividades.first.barras.first['n_taladro'] = '';
    d.actividades.first.barras.add({});
    d.horometros['diesel']!['inicio'] = '500';
    expect(d.validate(codes), isEmpty);
    expect(d.pendientes(codes), hasLength(2));
    final bars =
        (d.registros(codes, firstId: 1).first['operacion'] as Map)['barras']
            as List;
    expect(bars, hasLength(1));
    expect((bars.single as Map)['n_taladro'], 0);
  });
  test('unconfigured Gemini reader never calls a network endpoint', () async {
    var called = false;
    final service = PhotoService(
      url: '',
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.read(
        bytes: Uint8List(1),
        mimeType: 'image/jpeg',
        token: 'token',
        catalogo: [],
      ),
      throwsA(isA<PhotoImportException>()),
    );
    expect(called, false);
  });
  test('quota and malformed model response are reviewable errors', () async {
    for (final response in [
      http.Response('{}', 429),
      http.Response('not-json', 200),
      http.Response('{}', 503),
      http.Response('{}', 404),
    ]) {
      final service = PhotoService(
        url: 'https://example.test/preview',
        client: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer token');
          expect(jsonDecode(req.body)['image'], isNotEmpty);
          return response;
        }),
      );
      await expectLater(
        service.read(
          bytes: Uint8List.fromList([1]),
          mimeType: 'image/jpeg',
          token: 'token',
          catalogo: [],
        ),
        throwsA(isA<PhotoImportException>()),
      );
      service.close();
    }
  });

  group('save as master, once per equipo/fecha/turno', () {
    late Database db;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('CREATE TABLE Usuario (codigo_dni TEXT, rol TEXT)');
      await db.insert('Usuario', {'codigo_dni': '123', 'rol': 'Master'});
      await db.execute(
        'CREATE TABLE Operacion_tal_largo ('
        'id INTEGER PRIMARY KEY, fecha TEXT, turno TEXT, seccion TEXT, operador TEXT, '
        'jefe_guardia TEXT, equipo TEXT, n_equipo TEXT, modelo_equipo TEXT, '
        'registros TEXT, horometros TEXT, condiciones_equipo TEXT, check_list TEXT, '
        'control_llantas TEXT, estado TEXT, envio INTEGER)',
      );
    });
    tearDown(() async => db.close());
    Future<int> save({PhotoDraft? sheet}) => PhotoStore.save(
      db,
      dni: '123',
      draft: sheet ?? draft(),
      estadosPorCodigo: codes,
      checklist: [],
      imageHash: 'test-hash',
    );

    test(
      'missing required data writes nothing; a valid sheet is written once',
      () async {
        final invalid = draft()..cabecera['operador'] = '';
        await expectLater(save(sheet: invalid), throwsFormatException);
        expect(await db.query('Operacion_tal_largo'), isEmpty);
        await save();
        final row = (await db.query('Operacion_tal_largo')).single;
        expect(jsonDecode(row['registros'] as String), hasLength(2));
        expect(row['estado'], 'activo');
        await expectLater(save(), throwsStateError);
        expect(await db.query('Operacion_tal_largo'), hasLength(1));
      },
    );
    test('operator is denied even if the UI requests a save', () async {
      await db.update('Usuario', {'rol': 'Operador'});
      await expectLater(save(), throwsStateError);
      expect(await db.query('Operacion_tal_largo'), isEmpty);
    });
  });
}
