import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../sync/operation_sync_engine.dart';
import 'transfer_content.dart';
import 'transfer_store.dart';
import '../sync/sync_attempts.dart';

typedef TransferExporter =
    Future<List<OperationPayload>> Function(
      String type,
      List<OperationPayload> rows,
    );
typedef ClosedConfirmation =
    Future<Map<String, dynamic>> Function(
      String type,
      Map<String, dynamic> payload,
      String hash,
    );

class TransferCoordinator {
  TransferCoordinator(
    this.db,
    this.export,
    this.confirm, {
    this.lookup,
    this.resolve,
  });
  final Database db;
  final TransferExporter export;
  final ClosedConfirmation confirm;
  final ClosedConfirmation? lookup;
  final Future<Map<String, dynamic>> Function(
    String,
    Map<String, dynamic>,
    String,
    String?,
    bool,
  )?
  resolve;
  TransferStore get store => TransferStore(db);

  Future<Map<String, dynamic>> inspectForReview(
    Map<String, Object?> selected,
  ) async {
    if (lookup == null) {
      throw StateError('Consulta de conciliación no disponible');
    }
    final copies = await db.query(
      'LocalTransfers',
      where: 'direction = ? AND type = ? AND uuid = ?',
      whereArgs: [selected['direction'], selected['type'], selected['uuid']],
    );
    if (copies.isEmpty) throw StateError('No se encontró la copia');
    final copy = copies.single;
    var payload = Map<String, dynamic>.from(
      jsonDecode(copy['payload'] as String),
    );
    if (copy['direction'] == 'outbox') {
      final originals = await db.query(
        TransferContent.tables[copy['type']]!,
        where: 'id = ? AND sync_uuid = ?',
        whereArgs: [copy['local_id'], copy['uuid']],
      );
      if (originals.isEmpty) {
        throw StateError('No se encontró el registro original');
      }
      payload = (await export(copy['type'] as String, [
        Map<String, dynamic>.from(originals.single),
      ])).single;
    }
    if (payload['estado'] != 'cerrado') {
      throw StateError('Cierra la operación antes de conciliarla');
    }
    final hash = TransferContent.fingerprint(copy['type'] as String, payload);
    final answer = await lookup!(copy['type'] as String, payload, hash);
    if (answer['sync_uuid'] != copy['uuid'] ||
        answer['hash'] != hash ||
        !['confirmed', 'conflict', 'missing'].contains(answer['status'])) {
      throw StateError('La consulta de nube no corresponde a la copia');
    }
    if (answer['status'] != 'missing' &&
        (answer['cloud_hash'] is! String || answer['remote_payload'] is! Map)) {
      throw StateError('Actualiza la API para consultar y conciliar versiones');
    }
    // Explicit review targets the UUID found by lookup, never a stale local ID.
    payload['idNube'] = answer['status'] == 'missing' ? 0 : answer['server_id'];
    return {'copy': copy, 'payload': payload, 'hash': hash, 'remote': answer};
  }

  Future<void> applyReviewed(
    Map<String, dynamic> plan, {
    required bool verifiedAbsent,
  }) async {
    if (resolve == null) throw StateError('Conciliación no disponible');
    final copy = Map<String, Object?>.from(plan['copy'] as Map);
    final remote = Map<String, dynamic>.from(plan['remote'] as Map);
    final payload = Map<String, dynamic>.from(plan['payload'] as Map);
    if (remote['status'] == 'missing' && !verifiedAbsent) {
      throw StateError('Verifica primero la ausencia en nube');
    }
    if (copy['direction'] == 'outbox') {
      final fresh = await inspectForReview(copy);
      if (fresh['hash'] != plan['hash']) {
        throw StateError('El registro local cambió. Consulta nuevamente.');
      }
    }
    // Keep both reviewed versions even if the network response is lost.
    await db.insert('SyncReviewHistory', {
      'type': copy['type'],
      'uuid': copy['uuid'],
      'local_payload': jsonEncode(payload),
      'remote_payload': jsonEncode(remote['remote_payload']),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    final answer = await resolve!(
      copy['type'] as String,
      payload,
      plan['hash'] as String,
      remote['cloud_hash'] as String?,
      verifiedAbsent,
    );
    if (answer['status'] != 'confirmed' ||
        answer['sync_uuid'] != copy['uuid'] ||
        answer['hash'] != plan['hash'] ||
        OperationSyncEngine.integer(answer['server_id']) <= 0) {
      throw StateError(
        'La nube cambió o no confirmó la conciliación. Consulta de nuevo; no se forzó el reemplazo.',
      );
    }
    final updated = await db.update(
      'LocalTransfers',
      {
        'payload': jsonEncode(payload),
        'hash': plan['hash'],
        'needs_review': 0,
        'status': copy['direction'] == 'outbox' ? 'prepared' : 'cloud',
        'cloud_id': answer['server_id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'direction = ? AND type = ? AND uuid = ? AND hash = ?',
      whereArgs: [copy['direction'], copy['type'], copy['uuid'], copy['hash']],
    );
    if (updated != 1) {
      throw StateError(
        'La copia local cambió. Se conserva la revisión para consultar nuevamente.',
      );
    }
    if (copy['direction'] == 'outbox' &&
        await db.update(
              TransferContent.tables[copy['type']]!,
              {'idNube': answer['server_id']},
              where: 'id = ? AND sync_uuid = ?',
              whereArgs: [copy['local_id'], copy['uuid']],
            ) !=
            1) {
      throw StateError('El registro original cambió. Consulta nuevamente.');
    }
    if (copy['direction'] == 'outbox' &&
        !await _confirmSource({
          ...copy,
          'hash': plan['hash'],
        }, OperationSyncEngine.integer(answer['server_id']))) {
      throw StateError(
        'La nube confirmó la copia, pero el original cambió después. Consulta nuevamente.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> prepare(String source) async {
    for (final entry in TransferContent.tables.entries) {
      // Las copias ya confirmadas en nube cuyo original sigue enviado con el
      // mismo ID no necesitan prepararse otra vez; así el costo de cada envío
      // no crece con el historial. Si el original volvió a pendiente, se revisa.
      final rows = await db.query(
        entry.value,
        where:
            "estado = 'cerrado' AND NOT EXISTS (SELECT 1 FROM LocalTransfers t "
            "WHERE t.direction = 'outbox' AND t.type = ? "
            "AND t.uuid = ${entry.value}.sync_uuid AND t.status = 'cloud' "
            "AND ${entry.value}.envio = 1 AND ${entry.value}.idNube = t.cloud_id)",
        whereArgs: [entry.key],
      );
      for (final row in rows) {
        final cloudId = OperationSyncEngine.integer(row['idNube']);
        final state = OperationSyncEngine.state(row['envio']);
        final needsReview =
            ([2.0, 3.0].contains(state) &&
                cloudId == 0 &&
                row['sync_retry_safe'] != 1) ||
            (state == 1 && cloudId == 0);
        final payload = (await export(entry.key, [
          Map<String, dynamic>.from(row),
        ])).single;
        payload.remove('check_list_telemando');
        if (row['sync_cloud_hash'] is String) {
          payload['base_cloud_hash'] = row['sync_cloud_hash'];
        }
        final attempts = await SyncAttempts.hashes(
          db,
          entry.key,
          '${row['sync_uuid']}',
        );
        if (attempts.isNotEmpty) payload['attempted_hashes'] = attempts;
        final hash = TransferContent.fingerprint(entry.key, payload);
        if (state == 1 &&
            cloudId > 0 &&
            (row['sync_cloud_hash'] == null ||
                row['sync_cloud_hash'] == hash)) {
          payload['shared_as_cloud_copy'] = true;
        }
        final item = {
          'type': entry.key,
          'uuid': payload['sync_uuid'],
          'hash': TransferContent.fingerprint(entry.key, payload),
          'payload': payload,
          'source': source,
          'needs_review': needsReview,
        };
        TransferStore.validate(item);
        await db.transaction((txn) async {
          final previous = await txn.query(
            'LocalTransfers',
            where: 'direction = ? AND type = ? AND uuid = ?',
            whereArgs: ['outbox', entry.key, item['uuid']],
          );
          if (previous.isNotEmpty) {
            if (previous.single['hash'] != item['hash']) {
              await txn.update(
                'LocalTransfers',
                {'status': 'conflict'},
                where: 'direction = ? AND type = ? AND uuid = ?',
                whereArgs: ['outbox', entry.key, item['uuid']],
              );
            } else if (payload['shared_as_cloud_copy'] == true &&
                previous.single['status'] != 'cloud') {
              await txn.update(
                'LocalTransfers',
                {
                  'payload': jsonEncode(payload),
                  'cloud_id': cloudId,
                  'needs_review': 0,
                },
                where: 'direction = ? AND type = ? AND uuid = ?',
                whereArgs: ['outbox', entry.key, item['uuid']],
              );
            }
            return;
          }
          await txn.insert('LocalTransfers', {
            'direction': 'outbox',
            'type': entry.key,
            'uuid': item['uuid'],
            'hash': item['hash'],
            'payload': jsonEncode(payload),
            'local_id': row['id'],
            'source': source,
            'status': 'prepared',
            'cloud_id': cloudId,
            'needs_review': needsReview ? 1 : 0,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        });
      }
    }
    return packets();
  }

  Future<List<Map<String, dynamic>>> packets() async => [
    for (final row in await store.list(direction: 'outbox'))
      if (row['status'] != 'conflict' && row['status'] != 'cloud')
        {
          'type': row['type'],
          'uuid': row['uuid'],
          'hash': row['hash'],
          'payload': jsonDecode(row['payload'] as String),
          'source': row['source'],
          'needs_review': row['needs_review'] == 1,
        },
  ];

  Future<String> applyReceipt(
    Map<String, dynamic> packet,
    Map<String, dynamic> ack,
  ) async {
    if (ack['uuid'] != packet['uuid'] || ack['hash'] != packet['hash']) {
      throw StateError('La confirmación no corresponde al paquete enviado');
    }
    if (!['received', 'cloud', 'conflict', 'review'].contains(ack['status']) ||
        (ack['status'] == 'cloud' &&
            OperationSyncEngine.integer(ack['cloud_id']) <= 0)) {
      throw StateError('La maestra no confirmó un estado válido');
    }
    final rows = await store.list(
      type: packet['type'] as String,
      direction: 'outbox',
    );
    final row = rows.singleWhere((row) => row['uuid'] == packet['uuid']);
    if (row['status'] == 'conflict') {
      throw StateError(
        'La copia local tiene un conflicto; no se marcó como enviada.',
      );
    }
    // Una confirmación válida con ID, UUID y contenido coincidentes resuelve
    // también una copia que antes requería conciliación. No basta su entrega.
    if (ack['status'] == 'cloud') {
      if (!await _confirmSource(
        row,
        OperationSyncEngine.integer(ack['cloud_id']),
      )) {
        throw StateError(
          'La operación local cambió o no coincide con la confirmación. No se marcó como enviada.',
        );
      }
      return 'cloud';
    }
    if (ack['status'] == 'conflict') {
      await store.status(row, 'conflict');
      throw StateError(
        'La maestra conserva otra versión. No se marcó como enviada.',
      );
    }
    if (ack['status'] == 'review' || row['needs_review'] == 1) {
      await store.status(row, 'review');
      return 'review';
    }
    if (ack['status'] == 'received' && row['status'] != 'cloud') {
      await store.status(row, 'delivered');
    }
    return row['status'] == 'cloud' ? 'cloud' : 'delivered';
  }

  Future<bool> _confirmSource(Map<String, dynamic> item, int cloudId) async {
    final table = TransferContent.tables[item['type']]!;
    final rows = await db.query(
      table,
      where: 'id = ? AND sync_uuid = ?',
      whereArgs: [item['local_id'], item['uuid']],
    );
    if (rows.isEmpty) {
      await store.status(item, 'conflict');
      return false;
    }
    final snapshot = rows.single;
    final payload = (await export(item['type'] as String, [
      Map<String, dynamic>.from(snapshot),
    ])).single;
    if (payload['estado'] != 'cerrado' ||
        TransferContent.fingerprint(item['type'] as String, payload) !=
            item['hash']) {
      await store.status(item, 'conflict');
      return false;
    }
    // El formulario puede editar mientras se espera la red. Confirmar únicamente
    // si TODO el snapshot sigue igual, dentro de la misma transacción.
    return db.transaction((txn) async {
      final current = (await txn.query(
        table,
        where: 'id = ?',
        whereArgs: [item['local_id']],
      )).single;
      if (snapshot.keys.any((key) => current[key] != snapshot[key])) {
        return false;
      }
      if (OperationSyncEngine.integer(current['idNube']) > 0 &&
          current['idNube'] != cloudId) {
        await txn.update(
          'LocalTransfers',
          {'status': 'conflict'},
          where: 'direction = ? AND type = ? AND uuid = ?',
          whereArgs: ['outbox', item['type'], item['uuid']],
        );
        return false;
      }
      // Ya confirmado y sin cambios: no reescribir (conserva updated_at para
      // que la revisión periódica termine al vencer la ventana).
      if (item['status'] == 'cloud' &&
          OperationSyncEngine.integer(item['cloud_id']) == cloudId &&
          OperationSyncEngine.integer(current['idNube']) == cloudId &&
          OperationSyncEngine.state(current['envio']) == 1 &&
          current['sync_cloud_hash'] == item['hash']) {
        return true;
      }
      await txn.update(
        table,
        {'idNube': cloudId, 'envio': 1, 'sync_cloud_hash': item['hash']},
        where: 'id = ?',
        whereArgs: [item['local_id']],
      );
      await txn.update(
        'LocalTransfers',
        {
          'status': 'cloud',
          'cloud_id': cloudId,
          'needs_review': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'direction = ? AND type = ? AND uuid = ? AND hash = ?',
        whereArgs: ['outbox', item['type'], item['uuid'], item['hash']],
      );
      return true;
    });
  }

  /// Consulta ligera: el original ya no figura como enviado con el mismo ID.
  Future<bool> _sourceLeftCloud(Map<String, dynamic> item) async {
    final rows = await db.query(
      TransferContent.tables[item['type']]!,
      columns: ['envio', 'idNube'],
      where: 'id = ? AND sync_uuid = ?',
      whereArgs: [item['local_id'], item['uuid']],
    );
    return rows.isEmpty ||
        OperationSyncEngine.state(rows.single['envio']) != 1 ||
        OperationSyncEngine.integer(rows.single['idNube']) !=
            OperationSyncEngine.integer(item['cloud_id']);
  }

  /// Ventana en la que se sigue comprobando que el original de una copia ya
  /// confirmada no haya cambiado. Pasado ese plazo no se revisa en cada ciclo.
  static const cloudRecheckWindow = Duration(days: 7);

  Future<OperationSyncResult> sync({
    String? type,
    bool Function()? shouldStop,
    DateTime? now,
  }) async {
    final result = OperationSyncResult();
    final recheckSince = (now ?? DateTime.now()).toUtc().subtract(
      cloudRecheckWindow,
    );
    for (final item in await store.syncQueue(
      type: type,
      recheckSince: recheckSince,
    )) {
      if (item['status'] == 'cloud') {
        // Detectar modificaciones locales posteriores sin enviar PUT obsoletos.
        final updated = DateTime.tryParse('${item['updated_at']}');
        if (item['direction'] == 'outbox' &&
            (updated == null ||
                updated.isAfter(recheckSince) ||
                await _sourceLeftCloud(item))) {
          await _confirmSource(
            item,
            OperationSyncEngine.integer(item['cloud_id']),
          );
        }
        continue;
      }
      if (shouldStop?.call() == true) {
        result.interrupted = true;
        break;
      }
      if (item['needs_review'] == 1 || item['status'] == 'review') {
        result.uncertain++;
        result.errors.add(
          'Copia antigua ${item['uuid']}: requiere conciliación antes de subir.',
        );
        continue;
      }
      if (item['status'] == 'conflict') {
        result.errors.add(
          'Conflicto ${item['type']} / ${item['uuid']}: requiere revisión.',
        );
        continue;
      }
      try {
        final payload = Map<String, dynamic>.from(
          jsonDecode(item['payload'] as String),
        );
        if (item['direction'] == 'outbox') {
          final source = await db.query(
            TransferContent.tables[item['type']]!,
            where: 'id = ? AND sync_uuid = ?',
            whereArgs: [item['local_id'], item['uuid']],
          );
          if (source.isEmpty ||
              TransferContent.fingerprint(
                    item['type'] as String,
                    (await export(item['type'] as String, [
                      Map<String, dynamic>.from(source.single),
                    ])).single,
                  ) !=
                  item['hash']) {
            await store.status(item, 'conflict');
            result.errors.add(
              'La operación transferida fue modificada: requiere revisión.',
            );
            continue;
          }
        }
        final response = await confirm(
          item['type'] as String,
          payload,
          item['hash'] as String,
        );
        if (response['sync_uuid'] != item['uuid'] ||
            response['hash'] != item['hash']) {
          throw StateError('Confirmación de nube inválida');
        }
        final cloudId = OperationSyncEngine.integer(response['server_id']);
        if (response['status'] == 'confirmed' && cloudId > 0) {
          if (item['direction'] == 'outbox') {
            if (!await _confirmSource(item, cloudId)) {
              result.errors.add(
                'La copia local cambió: no se marcó como enviada.',
              );
              continue;
            }
          } else {
            await store.status(item, 'cloud', cloudId: cloudId);
          }
          result.recovered++;
        } else if (response['status'] == 'conflict') {
          await store.status(item, 'conflict');
          final detail = switch (response['reason']) {
            'missing_base' =>
              'No se conserva la versión activa confirmada y los datos remotos son distintos. Requiere conciliación.',
            'remote_changed' =>
              'La versión activa en nube cambió después de la última confirmación del operador.',
            'identity_mismatch' =>
              'La identidad del registro remoto no coincide con la copia recibida.',
            _ => 'La nube conserva otra versión. No se sobrescribió.',
          };
          result.errors.add('${item['uuid']}: $detail');
        } else {
          throw StateError('Respuesta de nube no confirmada');
        }
      } catch (error) {
        result.retryable++;
        result.errors.add(
          'Transferencia pendiente ${item['uuid']}: no se pudo confirmar con la nube. Detalle: $error',
        );
        // Sin red, cada copia restante solo sumaría otro timeout.
        if (isNetworkError(error)) {
          result.networkFailed = true;
          break;
        }
      }
    }
    return result;
  }
}
