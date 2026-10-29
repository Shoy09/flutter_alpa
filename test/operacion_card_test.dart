import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/widgets/envio nube/operacion_card.dart';

void main() {
  Widget buildCard(String lastError) => MaterialApp(
    home: Scaffold(
      body: OperacionCard(
        operacion: {
          'id': 1,
          'estado': 'cerrado',
          'fecha': '2026-10-26',
          'turno': 'Día',
          'operador': 'Operador',
          'jefe_guardia': 'Jefe',
          'n_equipo': 'EQ-1',
          'modelo_equipo': 'Modelo',
          'seccion': 'Sección',
          'sync_uuid': '00000000-0000-4000-8000-000000000001',
          'sync_failures': 1,
          'sync_last_error': lastError,
        },
        isSelected: false,
        isEnviado: false,
        onTap: () {},
        syncType: 'tal_largo',
      ),
    ),
  );

  testWidgets(
    'network failures are identified and do not offer version review',
    (tester) async {
      await tester.pumpWidget(
        buildCard(
          'TimeoutException after 0:00:30.000000: Future not completed',
        ),
      );

      expect(
        find.textContaining('No se subió: problema de conexión'),
        findsOneWidget,
      );
      expect(
        find.textContaining('se reintentará cuando haya conexión'),
        findsOneWidget,
      );
      expect(find.text('Revisar versiones con la nube'), findsNothing);
    },
  );

  testWidgets('version conflicts are identified and offer version review', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard('La nube contiene cambios posteriores'));

    expect(
      find.textContaining('No se subió: conflicto de versión'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Compara las versiones con la nube'),
      findsOneWidget,
    );
    expect(find.text('Revisar versiones con la nube'), findsOneWidget);
  });

  testWidgets('other errors are not mislabeled as version conflicts', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard('La operación ocupa 9000000 bytes y supera el límite seguro'),
    );

    expect(
      find.textContaining('No se pudo completar la sincronización'),
      findsOneWidget,
    );
    expect(find.text('Revisar versiones con la nube'), findsNothing);
  });
}
