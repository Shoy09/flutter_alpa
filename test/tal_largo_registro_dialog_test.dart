import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/Operaciones/Tal%20largo/widgets/registro_operacion_dialog.dart'
    as m0;
import 'package:i_miner/screens/Operaciones/Tal%20horizontal/widgets/registro_operacion_dialog.dart'
    as m1;
import 'package:i_miner/screens/Operaciones/sostenimiento/widgets/registro_operacion_dialog.dart'
    as m2;
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/Scalamin/widgets/registro_operacion_dialog.dart'
    as m3;
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/SCISSOR/widgets/registro_operacion_dialog.dart'
    as m4;
import 'package:i_miner/screens/Operaciones/Carguio/Scoop/widgets/registro_operacion_dialog.dart'
    as m5;

void main() {
  final builders =
      <String, Widget Function(List<Map<String, String>>, int, String)>{
        'Tal largo': (registros, index, turno) => m0.RegistroOperacionDialog(
          codigoOperativos: registros,
          turno: turno,
          selectedState: 'OPERATIVO',
          existingRecord: registros[index],
          datadialog: const {
            'OPERATIVO': [
              {'Código': '101', 'Nombre': 'Trabajo'},
            ],
          },
          onConfirm: (_) {},
        ),
        'Tal horizontal': (registros, index, turno) =>
            m1.RegistroOperacionDialog(
              codigoOperativos: registros,
              turno: turno,
              selectedState: 'OPERATIVO',
              existingRecord: registros[index],
              datadialog: const {
                'OPERATIVO': [
                  {'Código': '101', 'Nombre': 'Trabajo'},
                ],
              },
              onConfirm: (_) {},
            ),
        'sostenimiento': (registros, index, turno) =>
            m2.RegistroOperacionDialog(
              codigoOperativos: registros,
              turno: turno,
              selectedState: 'OPERATIVO',
              existingRecord: registros[index],
              datadialog: const {
                'OPERATIVO': [
                  {'Código': '101', 'Nombre': 'Trabajo'},
                ],
              },
              onConfirm: (_) {},
            ),
        'Servicio Auxiliares/Scalamin': (registros, index, turno) =>
            m3.RegistroOperacionDialog(
              codigoOperativos: registros,
              turno: turno,
              selectedState: 'OPERATIVO',
              existingRecord: registros[index],
              datadialog: const {
                'OPERATIVO': [
                  {'Código': '101', 'Nombre': 'Trabajo'},
                ],
              },
              onConfirm: (_) {},
            ),
        'Servicio Auxiliares/SCISSOR': (registros, index, turno) =>
            m4.RegistroOperacionDialog(
              codigoOperativos: registros,
              turno: turno,
              selectedState: 'OPERATIVO',
              existingRecord: registros[index],
              datadialog: const {
                'OPERATIVO': [
                  {'Código': '101', 'Nombre': 'Trabajo'},
                ],
              },
              onConfirm: (_) {},
            ),
        'Carguio/Scoop': (registros, index, turno) =>
            m5.RegistroOperacionDialog(
              codigoOperativos: registros,
              turno: turno,
              selectedState: 'OPERATIVO',
              existingRecord: registros[index],
              datadialog: const {
                'OPERATIVO': [
                  {'Código': '101', 'Nombre': 'Trabajo'},
                ],
              },
              onConfirm: (_) {},
            ),
      };
  for (final modulo in builders.keys) {
    group(modulo, () {
      Map<String, String> registro(int id, String inicio, String fin) => {
        'id': '$id',
        'numero': '$id',
        'codigo': '101',
        'hora_inicio': inicio,
        'hora_final': fin,
        'estado': id == 2 ? 'DEMORA' : 'OPERATIVO',
      };

      Future<List<String?>> opciones(
        WidgetTester tester,
        List<Map<String, String>> registros,
        int index,
        String turno,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: builders[modulo]!(registros, index, turno)),
          ),
        );
        final dropdowns = tester
            .widgetList<DropdownButton<String>>(
              find.byType(DropdownButton<String>),
            )
            .toList();
        return dropdowns.last.items!.map((item) => item.value).toList();
      }

      testWidgets(
        'El primero permite adelantar su inicio sin cruzar al siguiente',
        (tester) async {
          final horas = await opciones(
            tester,
            [registro(1, '08:00', '10:00'), registro(2, '10:00', '')],
            0,
            'DÍA',
          );
          expect(horas, contains('06:30 AM'));
          expect(horas, contains('09:55 AM'));
          expect(horas, isNot(contains('10:00 AM')));
        },
      );

      testWidgets(
        'El intermedio respeta vecinos de distintos estados y horas con fecha',
        (tester) async {
          final horas = await opciones(
            tester,
            [
              registro(1, '2026-10-20 08:00:00', '10:00'),
              registro(2, '10:00', '12:00'),
              registro(3, '12:00', ''),
            ],
            1,
            'DÍA',
          );
          expect(horas, isNot(contains('08:00 AM')));
          expect(horas, contains('08:05 AM'));
          expect(horas, contains('11:55 AM'));
          expect(horas, isNot(contains('12:00 PM')));
        },
      );

      testWidgets('El turno noche conserva la secuencia al cruzar medianoche', (
        tester,
      ) async {
        final horas = await opciones(
          tester,
          [
            registro(1, '23:00', '00:30'),
            registro(2, '00:30', '02:00'),
            registro(3, '02:00', ''),
          ],
          1,
          'NOCHE',
        );
        expect(horas, contains('11:05 PM'));
        expect(horas, contains('12:00 AM'));
        expect(horas, contains('01:55 AM'));
        expect(horas, isNot(contains('02:00 AM')));
      });

      testWidgets('El ultimo conserva el limite de cierre', (tester) async {
        final horas = await opciones(
          tester,
          [registro(1, '08:00', '12:00')],
          0,
          'DÍA',
        );
        expect(horas, contains('06:30 AM'));
        expect(horas, isNot(contains('12:00 PM')));
      });
    });
  }
}
