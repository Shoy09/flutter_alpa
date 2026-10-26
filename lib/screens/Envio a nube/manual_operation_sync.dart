import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/sync_service.dart';
import 'package:i_miner/screens/widgets/envio%20nube/carga_dialog.dart';
import 'manual_sync_recovery.dart';

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
  OperationSyncResult? outcome;
  try {
    final ids = preview
        .map((row) => OperationSyncEngine.integer(row['local_id']))
        .toSet();
    if (ids.contains(0)) {
      throw StateError('La selección contiene un registro sin ID local.');
    }
    final result = await SyncService().syncSelected(type, ids);
    outcome = result;
    title = result.apiUnverified
        ? 'No se pudo verificar la API'
        : result.uncertain > 0
        ? 'Registros sin confirmación'
        : result.retryable > 0
        ? 'Pendientes de reintento'
        : result.errors.isNotEmpty
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
  final recoverable =
      outcome?.blocked.where((row) => row['can_recover'] == true).toList() ??
      <OperationPayload>[];
  final recover = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(message)),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: message)),
          child: const Text('Copiar detalle'),
        ),
        if (recoverable.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recuperar registro'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
  if (recover == true && context.mounted) {
    await recoverVerifiedMissingOperation(
      context,
      type: type,
      rows: recoverable,
      refresh: refresh,
    );
  }
}
