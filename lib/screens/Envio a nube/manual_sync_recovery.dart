import 'package:flutter/material.dart';
import 'package:i_miner/core/sync/operation_sync_engine.dart';
import 'package:i_miner/core/sync/sync_service.dart';

Future<void> recoverVerifiedMissingOperation(
  BuildContext context, {
  required String type,
  required List<OperationPayload> rows,
  required Future<void> Function() refresh,
}) async {
  final selected = await showDialog<OperationPayload>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Elegir registro para recuperar'),
      children: [
        for (final row in rows)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, row),
            child: Text(
              'ID local ${row['id']} · ${row['fecha'] ?? ''}\n${row['operador'] ?? ''}',
            ),
          ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  var verified = false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Recuperar ID local ${selected['id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Fecha: ${selected['fecha'] ?? ''}\nOperador: ${selected['operador'] ?? ''}\n\n'
                'El envío anterior pudo llegar aunque se perdiera la respuesta. '
                'Comprueba el registro en la base de la nube antes de continuar. '
                'Si ya existe, no lo reenvíes: hay que recuperar su ID de nube.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: verified,
                title: const Text(
                  'Verifiqué en la nube que este registro NO existe.',
                ),
                onChanged: (value) => setState(() => verified = value == true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: verified ? () => Navigator.pop(context, true) : null,
            child: const Text('Reintentar este registro'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final loading = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Recuperando registro…')),
          ],
        ),
      ),
    ),
  );
  navigator.push(loading);
  String message;
  try {
    final result = await SyncService().retryVerifiedAbsent(
      type,
      OperationSyncEngine.integer(selected['id']),
      '${selected['sync_uuid']}',
    );
    message = result.message;
  } catch (error) {
    message = '$error';
  } finally {
    if (loading.isActive) navigator.removeRoute(loading);
  }
  if (!context.mounted) return;
  await refresh();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Resultado de recuperación'),
      content: SingleChildScrollView(child: SelectableText(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
