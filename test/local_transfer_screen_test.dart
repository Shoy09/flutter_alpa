import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:i_miner/screens/transfer/local_transfer_screen.dart';

class _Database extends Fake implements Database {
  _Database({this.closed = false});
  final bool closed;
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
  }) async {
    if (table != 'LocalTransfers') {
      return table == 'Operacion_tal_horizontal' && closed
          ? [
              {
                'id': 7,
                'fecha': '2026-10-24',
                'turno': 'DÍA',
                'operador': 'OPERADOR NUEVO',
                'sync_uuid': 'e734e68b-9fad-4f42-9711-920cc2d4b84e',
                'envio': 0,
                'idNube': 0,
                'sync_retry_safe': 0,
                'estado': 'cerrado',
              },
            ]
          : [];
    }
    return [
      {
        'direction': 'inbox',
        'type': 'tal_horizontal',
        'uuid': 'c734e68b-9fad-4f42-9711-920cc2d4b84e',
        'source': 'OPERADOR DE PRUEBA',
        'status': 'received',
        'cloud_id': 0,
        'payload':
            '{"operador":"OPERADOR DE PRUEBA","estado":"cerrado","registros":[{"horas":3}]}',
      },
    ];
  }
}

void main() {
  testWidgets(
    'closed local operation is visible before any transfer is prepared',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: LocalTransferScreen(
            source: 'operador',
            canReceive: false,
            store: TransferStore(_Database(closed: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Operaciones cerradas disponibles'), findsOneWidget);
      expect(find.text('Perforación horizontal · ID 7'), findsOneWidget);
      expect(find.text('Lista para transferir'), findsOneWidget);
      expect(find.text('Historial de transferencias'), findsOneWidget);
      expect(find.byTooltip('Actualizar listas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_TRANSFER_PREVIEW')) {
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
    }
  });
  testWidgets('operator can send locally but cannot start master receiver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LocalTransferScreen(
          source: 'operador',
          canReceive: false,
          store: TransferStore(_Database()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Iniciar recepción'), findsNothing);
    expect(find.text('IP local de la maestra'), findsOneWidget);
    expect(find.text('Código de ocho dígitos'), findsOneWidget);
    expect(find.text('Enviar y recoger confirmaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'master sees receiver action and can inspect complete received copy',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: const bool.fromEnvironment('CAPTURE_TRANSFER_PREVIEW')
                ? 'PreviewUI'
                : null,
          ),
          home: LocalTransferScreen(
            source: 'maestra',
            canReceive: true,
            store: TransferStore(_Database()),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_TRANSFER_PREVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/transfer_master_preview.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('Iniciar recepción'), findsOneWidget);
      expect(find.text('Enviar a la maestra'), findsNothing);
      expect(find.text('Enviar y recoger confirmaciones'), findsNothing);
      expect(find.text('Operaciones cerradas disponibles'), findsNothing);
      expect(find.text('Disponibles'), findsNothing);
      final tile = find.text('Perforación horizontal');
      await tester.scrollUntilVisible(
        tile,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Copia completa de la operación'), findsOneWidget);
      expect(find.textContaining('"horas": 3'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Copia completa de la operación'), findsNothing);
    },
  );
}
