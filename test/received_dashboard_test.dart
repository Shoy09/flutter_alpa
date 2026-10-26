import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:i_miner/screens/transfer/received_summary_screen.dart';

class _Database extends Fake implements Database {
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
    for (final entry in [
      ('carguio', 'SC-01', 12),
      ('carguio', 'SC-02', 8),
      ('scalamin', 'SL-01', 0),
    ])
      {
        'direction': 'inbox',
        'type': entry.$1,
        'status': entry.$2 == 'SC-01' ? 'cloud' : 'received',
        'payload': jsonEncode({
          'fecha': '2026-10-25',
          'turno': 'DÍA',
          'n_equipo': entry.$2,
          'operador': 'OPERADOR ${entry.$2}',
          'registros': [
            {
              'estado': 'OPERATIVO',
              'codigo': '101',
              'operacion': {
                'labor_inicio': 'BP-3754',
                'ubicacion_destino': 'CÁMARA 12',
                'material': 'MINERAL',
                'n_cucharas': entry.$3,
                'labor': 'BP-3754',
                'area_m2': 42,
                'metros_lineales': 18,
              },
            },
          ],
        }),
      },
  ];
}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_RECEIVED_DASHBOARD');
  setUpAll(() async {
    if (!capture) return;
    final text = FontLoader('PreviewUI')
      ..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await text.load();
    await icons.load();
  });

  for (final width in [390.0, 1366.0]) {
    testWidgets('dashboard filters operation and equipment at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width > 1000 ? 1500 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: capture ? 'PreviewUI' : null),
          home: ReceivedSummaryScreen(
            store: TransferStore(_Database()),
            now: DateTime(2026, 10, 25, 8),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (capture && width > 1000) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/received_dashboard_preview.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      final operation = find.byType(DropdownButtonFormField<String>).at(1);
      await tester.ensureVisible(operation);
      await tester.tap(operation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scooptram').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cucharas: 20'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cucharas: 20'), findsOneWidget);
      expect(find.text('Resumen de Scalamin por labor'), findsNothing);
      final equipment = find.byType(DropdownButtonFormField<String>).at(2);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(equipment);
      await tester.pumpAndSettle();
      await tester.tap(equipment);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SC-02').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cucharas: 8'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cucharas: 8'), findsOneWidget);
      expect(find.text('Cucharas: 20'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
