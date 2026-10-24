import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/services/envio%20nube/AnfoChanger/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Carguio/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Dumper/ExportarDumperService.dart';
import 'package:i_miner/services/envio%20nube/Rompebancos/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Scalamin/ExportarScalaminService.dart';
import 'package:i_miner/services/envio%20nube/Sostenimiento/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/horizontal/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/largo/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/operaciones_service.dart';

import 'package:flutter/foundation.dart';
import 'package:i_miner/services/envio%20nube/Volquetes/exportar_service.dart';
import 'operation_sync_engine.dart';
import 'operation_sync_store.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  final _dbHelper = DatabaseHelper();
  final _api = OperacionesService();
  final _gate = OperationSyncGate();
  bool _automaticRunning = false;

  Map<String, (String, dynamic)> get _processes => {
    'tal_largo': ('Operacion_tal_largo', ExportarService(_dbHelper)),
    'tal_horizontal': (
      'Operacion_tal_horizontal',
      ExportarHorizontalService(_dbHelper),
    ),
    'empernador': (
      'Operacion_empernador',
      ExportarEmpernadorService(_dbHelper),
    ),
    'scissor': ('Operacion_scissor', ExportarScissorService(_dbHelper)),
    'anfochanger': (
      'Operacion_anfochanger',
      ExportarAnfoChangerService(_dbHelper),
    ),
    'rompebanco': (
      'Operacion_rompebanco',
      ExportarRompebancoService(_dbHelper),
    ),
    'carguio': ('Operacion_carguio', ExportarCarguioService(_dbHelper)),
    'dumper': ('Operacion_Dumper', ExportarDumperService(_dbHelper)),
    'scalamin': ('Operacion_Scalamin', ExportarScalaminService(_dbHelper)),
    'volquetes': ('Operacion_volquetes', ExportarVolquetesService(_dbHelper)),
  };

  Future<void> syncData() async {
    if (_automaticRunning) return;
    _automaticRunning = true;
    final user = await _dbHelper.getCurrentUserDni();
    try {
      if (user == null) return;
      await _gate.run(() async {
        if (user != await _dbHelper.getCurrentUserDni()) return;
        final idempotentCreates = await _api.supportsIdempotentCreates();
        for (final type in _processes.keys) {
          if (user != await _dbHelper.getCurrentUserDni()) return;
          try {
            final result = await _syncType(
              type,
              idempotentCreates: idempotentCreates,
            );
            debugPrint('Sync $type: ${result.message}');
          } catch (error) {
            debugPrint('No se pudo sincronizar $type: $error');
          }
        }
      });
    } finally {
      _automaticRunning = false;
    }
  }

  Future<OperationSyncResult> syncSelected(String type, Set<int> ids) async {
    final selected = Set<int>.of(ids);
    final user = await _dbHelper.getCurrentUserDni();
    return _gate.run(() async {
      if (user == null || user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Vuelve a abrir la lista.');
      }
      final idempotentCreates = await _api.supportsIdempotentCreates();
      if (user != await _dbHelper.getCurrentUserDni()) {
        throw StateError('La sesión cambió. Vuelve a abrir la lista.');
      }
      return _syncType(
        type,
        ids: selected,
        idempotentCreates: idempotentCreates,
      );
    });
  }

  Future<OperationSyncResult> _syncType(
    String type, {
    Set<int>? ids,
    bool idempotentCreates = false,
  }) async {
    final process = _processes[type];
    if (process == null) {
      throw ArgumentError('Tipo de operación no soportado: $type');
    }
    final database = await _dbHelper.database;
    final exporter = process.$2;
    return OperationSyncEngine(
      store: SqliteOperationSyncStore(database, process.$1),
      api: _api,
      idempotentCreates: idempotentCreates,
      prepare: (selected, rows) async => List<Map<String, dynamic>>.from(
        await exporter.prepararDatosParaExportar(selected, rows),
      ),
    ).sync(type, ids: ids);
  }
}
