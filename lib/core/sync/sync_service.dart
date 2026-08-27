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

class SyncService {
    static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final OperacionesService _api = OperacionesService();

  bool _isSyncing = false; 

Future<void> syncData() async {

  // 🔥 evitar múltiples sync simultáneos
  if (_isSyncing) {
    print("⚠️ Sincronización ya en progreso");
    return;
  }

  _isSyncing = true;

  print("🚀 Iniciando sincronización...");

  try {
    await _syncProceso(
      tipo: 'tal_largo',
      tabla: 'Operacion_tal_largo',
      getData: _dbHelper.getOperacionesNoEnviadasLargo,
      exportService: ExportarService(_dbHelper),
      marcar: _dbHelper.actualizarEnvio,
    );

    await _syncProceso(
      tipo: 'tal_horizontal',
      tabla: 'Operacion_tal_horizontal',
      getData: _dbHelper.getOperacionesTaladroHorizontalNoEnviadas,
      exportService: ExportarHorizontalService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioHorizontal,
    );

    await _syncProceso(
      tipo: 'empernador',
      tabla: 'Operacion_empernador',
      getData: _dbHelper.getOperacionesEmpernadorNoEnviadas,
      exportService: ExportarEmpernadorService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioEmpernador,
    );

    await _syncProceso(
      tipo: 'scissor',
      tabla: 'Operacion_scissor',
      getData: _dbHelper.getOperacionesScissorNoEnviadas,
      exportService: ExportarScissorService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioscissor,
    );

    await _syncProceso(
      tipo: 'anfochanger',
      tabla: 'Operacion_anfochanger',
      getData: _dbHelper.getOperacionesAnfoChangerNoEnviadas,
      exportService: ExportarAnfoChangerService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioRAnfoChanger,
    );

    await _syncProceso(
      tipo: 'rompebanco',
      tabla: 'Operacion_rompebanco',
      getData: _dbHelper.getOperacionesRompeBancosNoEnviadas,
      exportService: ExportarRompebancoService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioRompeBancos,
    );

    await _syncProceso(
      tipo: 'carguio',
      tabla: 'Operacion_carguio',
      getData: _dbHelper.getOperacionesCarguioNoEnviadas,
      exportService: ExportarCarguioService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioCarguio,
    );

    await _syncProceso(
      tipo: 'dumper',
      tabla: 'Operacion_Dumper',
      getData: _dbHelper.getOperacionesDumperNoEnviadas,
      exportService: ExportarDumperService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioDumper,
    );

    await _syncProceso(
      tipo: 'scalamin',
      tabla: 'Operacion_Scalamin',
      getData: _dbHelper.getOperacionesScalaminNoEnviadas,
      exportService: ExportarScalaminService(_dbHelper),
      marcar: _dbHelper.actualizarEnvioScalamin,
    );

    print("✅ Sincronización completa");
  } catch (e) {
  print("❌ Error en sync: $e");
} finally {

  // 🔥 liberar bloqueo SIEMPRE
  _isSyncing = false;
}
}

  Future<void> _syncProceso({
    required String tipo,
    required String tabla,
    required Future<List<Map<String, dynamic>>> Function() getData,
    required dynamic exportService,
    required Future<void> Function(int, double) marcar,
  }) async {
    print("📦 Sincronizando: $tipo");

    // ─────────────────────────────────────────────────────────────────
    // PASO 1: Consultar pendientes (envio = 0)
    // ─────────────────────────────────────────────────────────────────
    final data = await getData();

    /// 🔥 SEPARAR REGISTROS
    final registrosParaCrear = data.where((e) {
      final envio = (e['envio'] ?? 0).toDouble();
      final idNube = e['idNube'] ?? 0;

      return idNube == 0 || envio == 0;
    }).toList();

    final registrosParaActualizar = data.where((e) {
      final envio = (e['envio'] ?? 0).toDouble();
      final idNube = e['idNube'] ?? 0;

      return idNube > 0 && envio == 0.5;
    }).toList();

    int totalCreados = 0;
    int totalActualizados = 0;

    /// =========================================================
    /// 🔥 1. CREAR REGISTROS NUEVOS
    /// =========================================================
    if (registrosParaCrear.isNotEmpty) {
      print(
        "📝 Creando ${registrosParaCrear.length} registros nuevos para $tipo",
      );

      final idsCrear = registrosParaCrear
          .map<int>((e) => e['id'] as int)
          .toList();

      final jsonDataCrear =
          await exportService.prepararDatosParaExportar(
        idsCrear.toSet(),
        data,
      );

      /// Enviar CON local_id para que el backend lo devuelva en la respuesta
      /// y podamos cruzar server_id ↔ local_id de forma segura (sin depender del orden).
      /// También se calcula el envio correcto para que la nube refleje el estado real.
      final dataParaEnviar = jsonDataCrear.map((item) {
        final copia = Map<String, dynamic>.from(item);
        // Calcular envio final según estado
        final String estado = (copia['estado'] ?? '').toString().toLowerCase();
        copia['envio'] = estado == 'cerrado' ? 1 : 0.5;
        return copia;
      }).toList();

      // ─────────────────────────────────────────────────────────
      // PASO 2: Marcar lote como "en tránsito" (envio = 2)
      // ─────────────────────────────────────────────────────────
      await _dbHelper.actualizarEnvioBatch(tabla, idsCrear, 2);

      List<dynamic>? resultados;
      try {
        // ─────────────────────────────────────────────────────
        // PASO 3: POST con timeout de 30 s
        // ─────────────────────────────────────────────────────
        resultados = await _api.crearParciales(
          tipo,
          dataParaEnviar,
        );
      } catch (e) {
        // ─────────────────────────────────────────────────────
        // PASO 4b: Fallo → revertir a envio = 0
        // ─────────────────────────────────────────────────────
        print("❌ Error POST $tipo → revirtiendo a envio=0: $e");
        await _dbHelper.actualizarEnvioBatch(tabla, idsCrear, 0);
      }

      if (resultados != null) {
        // ───────────────────────────────────────────────────────
        // PASO 4a: Éxito → confirmar como enviado
        // Cruzamos por local_id (devuelto por el backend) para no
        // depender del orden del array de respuesta.
        // ───────────────────────────────────────────────────────

        // Construir mapa local_id → registro original para búsqueda O(1)
        final mapaLocal = {
          for (var r in jsonDataCrear) (r['local_id'] as int): r
        };

        for (final resultado in resultados) {
          final int? localId = resultado['local_id'];
          final int? serverId = resultado['server_id'];

          if (localId == null || serverId == null) {
            print("⚠️ $tipo: resultado sin local_id o server_id — omitiendo");
            continue;
          }

          final registroLocal = mapaLocal[localId];
          if (registroLocal == null) {
            print("⚠️ $tipo: local_id=$localId no encontrado en datos locales");
            continue;
          }

          final String estado = (registroLocal['estado'] ?? '')
              .toString()
              .toLowerCase();

          final double envio = estado == 'cerrado' ? 1.0 : 0.5;

          /// guardar id nube
          await _dbHelper.actualizarIdNube(tabla, localId, serverId);

          /// actualizar envío
          await marcar(localId, envio);

          totalCreados++;
        }

        print("✅ $tipo: $totalCreados registros creados");
      } else if (resultados == null) {
        // Sin excepción pero respuesta nula → revertir
        print("❌ Respuesta nula para $tipo → revirtiendo a envio=0");
        await _dbHelper.actualizarEnvioBatch(tabla, idsCrear, 0);
      }
    }

    /// =========================================================
    /// 🔥 2. ACTUALIZAR REGISTROS EXISTENTES
    /// =========================================================
    if (registrosParaActualizar.isNotEmpty) {
      print(
        "🔄 Actualizando ${registrosParaActualizar.length} registros para $tipo",
      );

      final idsActualizar = registrosParaActualizar
          .map<int>((e) => e['id'] as int)
          .toList();

      final jsonDataActualizar =
          await exportService.prepararDatosParaExportar(
        idsActualizar.toSet(),
        data,
      );

      /// Preparar data para update
      final dataParaActualizar = jsonDataActualizar.map((item) {
        final copia = Map<String, dynamic>.from(item);

        // Remover local_id — no debe ir al backend
        copia.remove('local_id');

        // Calcular el envio final correcto según estado
        // para que la nube también refleje el estado real
        final String estado = (copia['estado'] ?? '').toString().toLowerCase();
        copia['envio'] = estado == 'cerrado' ? 1 : 0.5;

        // idNube ya está — el backend lo usa como WHERE id = idNube
        // y lo elimina del payload antes del UPDATE.

        return copia;
      }).toList();

      // ─────────────────────────────────────────────────────────
      // PASO 2: Marcar lote como "en tránsito" (envio = 2)
      // ─────────────────────────────────────────────────────────
      await _dbHelper.actualizarEnvioBatch(tabla, idsActualizar, 2);

      bool actualizacionExitosa = false;
      try {
        // ─────────────────────────────────────────────────────
        // PASO 3: PUT con timeout de 30 s
        // ─────────────────────────────────────────────────────
        actualizacionExitosa = await _api.actualizarMasivo(
          tipo,
          dataParaActualizar,
        );
      } catch (e) {
        // ─────────────────────────────────────────────────────
        // PASO 4b: Fallo → revertir a envio = 0.5
        // ─────────────────────────────────────────────────────
        print("❌ Error PUT $tipo → revirtiendo a envio=0.5: $e");
        await _dbHelper.actualizarEnvioBatch(tabla, idsActualizar, 0.5);
      }

      if (actualizacionExitosa) {
        // ─────────────────────────────────────────────────────
        // PASO 4a: Éxito → confirmar
        // ─────────────────────────────────────────────────────
        for (var registro in jsonDataActualizar) {
          final int localId = registro['local_id'];

          final String estado = (registro['estado'] ?? '')
              .toString()
              .toLowerCase();

          /// 🔥 definir envío final
          double envio = 0.5;

          if (estado == 'cerrado') {
            envio = 1.0;
          }

          /// 🔥 actualizar estado envío
          await marcar(localId, envio);

          totalActualizados++;
        }

        print(
          "✅ $tipo: $totalActualizados registros actualizados",
        );
      } else if (!actualizacionExitosa) {
        print("❌ Actualización fallida para $tipo → revirtiendo a envio=0.5");
        await _dbHelper.actualizarEnvioBatch(tabla, idsActualizar, 0.5);
      }
    }

    /// =========================================================
    /// 🔥 RESUMEN
    /// =========================================================
    if (totalCreados == 0 && totalActualizados == 0) {
      print("✔️ $tipo sin pendientes");
    } else {
      print(
        "📊 $tipo resumen: "
        "$totalCreados creados, "
        "$totalActualizados actualizados",
      );
    }
  }

  /// 🔥 Helper para obtener tabla
  String _getTableName(String tipo) {
    switch (tipo) {
      case 'tal_largo':
        return 'Operacion_tal_largo';

      case 'tal_horizontal':
        return 'Operacion_tal_horizontal';

      case 'empernador':
        return 'Operacion_empernador';

      case 'scissor':
        return 'Operacion_scissor';

      case 'anfochanger':
        return 'Operacion_anfochanger';

      case 'rompebanco':
        return 'Operacion_rompebanco';

      case 'carguio':
        return 'Operacion_carguio';

      case 'dumper':
        return 'Operacion_Dumper';

      case 'scalamin':
        return 'Operacion_Scalamin';

      default:
        return 'Operacion_$tipo';
    }
  }
}