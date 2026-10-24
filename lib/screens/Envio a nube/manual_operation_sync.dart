import 'package:flutter/material.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/sync_service.dart';
import 'package:i_miner/screens/widgets/envio%20nube/carga_dialog.dart';

final _sendingScreens = <BuildContext>{};

Future<void> sendManualOperations(
  BuildContext context, {
  required String type,
  required List<Map<String, dynamic>> preview,
  required Future<void> Function() refresh,
}) async {
  if (!context.mounted || !_sendingScreens.add(context)) return;
  final Object screenKey = context;
  final navigator = Navigator.of(context, rootNavigator: true);
  final loading = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: CargaDialog(mensaje: 'Sincronizando operaciones...'),
    ),
  );
  navigator.push(loading);
  String title;
  String message;
  try {
    final ids = preview
        .map((row) => OperationSyncEngine.integer(row['local_id']))
        .toSet();
    if (ids.contains(0)) {
      throw StateError('La selección contiene un registro sin ID local.');
    }
    final result = await SyncService().syncSelected(type, ids);
    title =
        result.errors.isNotEmpty || result.uncertain > 0 || result.retryable > 0
        ? 'Envío con pendientes'
        : 'Sincronización completada';
    message = result.message;
  } catch (error) {
    title = 'No se completó el envío';
    message = '$error';
  } finally {
    if (loading.isActive) navigator.removeRoute(loading);
    _sendingScreens.remove(screenKey);
  }
  if (!context.mounted) return;
  await refresh();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
