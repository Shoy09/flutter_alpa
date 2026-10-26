import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:i_miner/core/transfer/received_summary.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:i_miner/screens/transfer/received_summary_screen.dart';

class _Db extends Fake implements Database {
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => [
    for (final shift in ['DÍA', 'NOCHE'])
      {
        'direction': 'inbox',
        'type': 'empernador',
        'status': 'received',
        'payload': jsonEncode({
          'fecha': '2026-10-24',
          'turno': shift,
          'operador': 'OPERADOR $shift',
        }),
      },
  ];
}

void main() {
  test('shift boundaries and night operational date across month/year', () {
    for (final example in [
      (DateTime(2026, 10, 25, 5, 59), '2026-10-24', 'NOCHE'),
      (DateTime(2026, 10, 25, 6), '2026-10-25', 'DIA'),
      (DateTime(2026, 10, 25, 17, 59), '2026-10-25', 'DIA'),
      (DateTime(2026, 10, 25, 18), '2026-10-25', 'NOCHE'),
      (DateTime(2027, 1, 1, 0), '2026-12-31', 'NOCHE'),
    ]) {
      final result = OperationShift.at(example.$1);
      expect(OperationShift.dateKey(result.date), example.$2);
      expect(result.shift, example.$3);
    }
  });
  test(
    'filters business date and normalizes shift, excluding outbox and malformed copies',
    () {
      final row = <String, Object?>{
        'direction': 'inbox',
        'updated_at': '2026-10-25',
        'payload': jsonEncode({'fecha': '2026-10-24', 'turno': ' día '}),
      };
      final op = ReceivedOperation.read(row)!;
      expect(op.matches(DateTime(2026, 10, 24), 'DIA'), isTrue);
      expect(op.matches(DateTime(2026, 10, 24), 'TODOS'), isTrue);
      expect(op.matches(DateTime(2026, 10, 25), 'DIA'), isFalse);
      expect(op.matches(DateTime(2026, 10, 24), 'NOCHE'), isFalse);
      expect(ReceivedOperation.read({...row, 'direction': 'outbox'}), isNull);
      expect(ReceivedOperation.read({...row, 'payload': 'invalid'}), isNull);
    },
  );
  testWidgets(
    'summary defaults to current night and previous date before 6am',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceivedSummaryScreen(
            store: TransferStore(_Db()),
            now: DateTime(2026, 10, 25, 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026-10-24'), findsOneWidget);
      expect(find.text('Recibidas'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Mostrando 1 de 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Mostrando 1 de 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('OPERADOR NOCHE'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('OPERADOR NOCHE'), findsOneWidget);
      expect(find.textContaining('OPERADOR DÍA'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
