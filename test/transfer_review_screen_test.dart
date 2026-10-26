import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/screens/transfer/transfer_review_screen.dart';

void main() {
  for (final width in [390.0, 1366.0]) {
    for (final missing in [true, false]) {
      testWidgets(
        'review requires explicit choice at $width, missing=$missing',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var commits = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: TransferReviewScreen(
                selected: const {},
                inspect: () async => {
                  'payload': {'fecha': '2026-10-25', 'estado': 'cerrado'},
                  'remote': {
                    'status': missing ? 'missing' : 'conflict',
                    'server_id': 7,
                    'remote_payload': {
                      'fecha': '2026-10-25',
                      'estado': 'activo',
                    },
                  },
                },
                commit: (_, approved) async {
                  expect(approved, isTrue);
                  commits++;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          final checkbox = find.byType(CheckboxListTile);
          await tester.scrollUntilVisible(
            checkbox,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(commits, 1);
          expect(
            find.textContaining('Conciliación confirmada'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
