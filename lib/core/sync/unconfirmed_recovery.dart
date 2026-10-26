import '../transfer/transfer_content.dart';
import 'operation_sync_engine.dart';

/// Recupera por identidad sin utilizar POST de creación ni PUT de actualización.
class UnconfirmedRecovery {
  UnconfirmedRecovery({
    required this.type,
    required this.store,
    required this.prepare,
    required this.lookup,
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
      try {
        final id = OperationSyncEngine.integer(row['id']);
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
          result.errors.add(
            'Registro local $id: existe en nube con ID ${answer['server_id']}, pero su contenido es diferente. No se modificó.',
          );
        } else if (answer['status'] == 'missing') {
          result.errors.add(
            'Registro local $id: no se encontró su UUID en nube. Revisa también posibles copias sin UUID antes de recuperarlo.',
          );
        } else {
          throw StateError('La nube no confirmó la consulta');
        }
      } catch (error) {
        result.errors.add('Recuperación sin escrituras en nube: $error');
        break;
      }
    }
    return result;
  }
}
