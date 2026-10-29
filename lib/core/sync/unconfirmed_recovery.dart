import '../transfer/transfer_content.dart';
import 'operation_sync_engine.dart';

/// Recupera por identidad sin utilizar POST de creación ni PUT de actualización.
class UnconfirmedRecovery {
  UnconfirmedRecovery({
    required this.type,
    required this.store,
    required this.prepare,
    required this.lookup,
    this.shouldStop,
  });
  final String type;
  final OperationSyncStore store;
  final Future<List<OperationPayload>> Function(
    Set<int>,
    List<OperationPayload>,
  )
  prepare;
  final Future<Map<String, dynamic>> Function(String, OperationPayload, String)
  lookup;
  final bool Function()? shouldStop;
  final conflicts = <int>{};

  Future<OperationSyncResult> run({Set<int>? ids}) async {
    final result = OperationSyncResult();
    conflicts.clear();
    final rows = (await store.load(ids)).where(
      (row) =>
          [2.0, 3.0].contains(OperationSyncEngine.state(row['envio'])) &&
          OperationSyncEngine.integer(row['idNube']) == 0 &&
          OperationSyncEngine.integer(row['sync_retry_safe']) != 1 &&
          OperationSyncEngine.hasIdentity(row),
    );
    for (final row in rows) {
      if (shouldStop?.call() == true) {
        result.interrupted = true;
        break;
      }
      final id = OperationSyncEngine.integer(row['id']);
      final currentState = OperationSyncEngine.state(row['envio']);
      try {
        final payload = (await prepare({id}, [row])).single;
        final hash = TransferContent.fingerprint(type, payload);
        final answer = await lookup(type, payload, hash);
        if (answer['sync_uuid'] != row['sync_uuid'] || answer['hash'] != hash) {
          throw StateError('La consulta no coincide con la operación local');
        }
        if (answer['status'] == 'confirmed' &&
            OperationSyncEngine.integer(answer['server_id']) > 0) {
          await store.confirm(
            id,
            OperationSyncEngine.integer(answer['server_id']),
            OperationSyncEngine.finalState(row),
            cloudHash: answer['cloud_hash'] is String
                ? answer['cloud_hash'] as String
                : null,
          );
          result.recovered++;
        } else if (answer['status'] == 'conflict' &&
            answer['remote_state'] == 'activo' &&
            answer['identity_matches'] == true &&
            OperationSyncEngine.integer(answer['server_id']) > 0) {
          // La nube conserva la creación activa, pero el operador siguió
          // trabajando o cerró localmente. Recuperar ID; el PUT habitual envía
          // su versión actual. Nunca marcarla enviada antes de ese PUT.
          await store.confirm(
            id,
            OperationSyncEngine.integer(answer['server_id']),
            0.5,
            cloudHash: answer['cloud_hash'] is String
                ? answer['cloud_hash'] as String
                : null,
          );
          result.recovered++;
        } else if (answer['status'] == 'conflict') {
          conflicts.add(id);
          final message =
              'Existe en nube con ID ${answer['server_id']}, pero su contenido es diferente. No se modificó.';
          // Se deja constancia en el registro y se espacian las consultas.
          await store.mark(id, currentState, reason: message, penalize: true);
          result.errors.add('Registro local $id: $message');
        } else if (answer['status'] == 'missing') {
          const message =
              'No se encontró su UUID en nube. Revisa también posibles copias sin UUID antes de recuperarlo.';
          await store.mark(id, currentState, reason: message, penalize: true);
          result.errors.add('Registro local $id: $message');
        } else {
          throw StateError('La nube no confirmó la consulta');
        }
      } catch (error) {
        result.errors.add('Recuperación sin escrituras en nube: $error');
        // Sin red no tiene sentido esperar otro timeout por cada registro.
        // Un error propio de este registro no debe frenar a los demás.
        if (isNetworkError(error)) {
          result.networkFailed = true;
          break;
        }
      }
    }
    return result;
  }
}
