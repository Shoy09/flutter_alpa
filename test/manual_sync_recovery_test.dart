import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/Envio%20a%20nube/manual_sync_recovery.dart';

void main() {
  testWidgets(
    'retry stays disabled until explicit cloud verification and can be cancelled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => recoverVerifiedMissingOperation(
                  context,
                  type: 'empernador',
                  rows: [
                    {
                      'id': 10,
                      'fecha': '2026-10-24',
                      'operador': 'PRUEBA',
                      'sync_uuid': 'uuid',
                    },
                  ],
                  refresh: () async {},
                ),
                child: const Text('Recuperar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Recuperar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ID local 10'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar ID local 10'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
