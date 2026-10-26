import 'dart:async';

typedef OperationPayload = Map<String, dynamic>;

class OperationSyncResult {
  int created = 0;
  int updated = 0;
  int uncertain = 0;
  int retryable = 0;
  int recovered = 0;
  bool apiUnverified = false;
  final errors = <String>[];
  final blocked = <OperationPayload>[];
  String get message =>
      'Creados: $created · Actualizados: $updated'
      '${recovered > 0 ? " · Recuperados: $recovered" : ""}'
      '${retryable > 0 ? " · Pendientes de reintento: $retryable" : ""}'
      '${uncertain > 0 ? " · Sin confirmación: $uncertain (requieren revisión en nube)" : ""}'
      '${errors.isNotEmpty ? "\n${errors.join('\n')}" : ""}'
      '${errors.isNotEmpty || uncertain > 0 || retryable > 0 ? "\nDiagnóstico: SYNC-20261024-R2" : ""}';
}

/// Es el mismo bloqueo para las rutas automáticas y las pantallas manuales.
class OperationSyncGate {
  Future<void> _tail = Future.value();
  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        finished.complete();
      }
    }();
  }
}

abstract class OperationSyncStore {
  Future<List<OperationPayload>> load(Set<int>? ids);
  Future<void> claim(
    List<OperationPayload> rows, {
    bool idempotentCreates = false,
  });
  Future<void> mark(int id, double state);
  Future<void> confirm(int id, int cloudId, double state, {String? cloudHash});
  Future<List<String>> attemptedHashes(String uuid) async => [];
}

abstract class OperationSyncApi {
  Future<bool> supportsIdempotentCreates();
  Future<List<dynamic>?> crearParciales(String type, dynamic data);
  Future<List<dynamic>> actualizarMasivoResultados(
    String type,
    List<dynamic> data,
  );
}

class OperationSyncEngine {
  OperationSyncEngine({
    required this.store,
    required this.api,
    required this.prepare,
    this.idempotentCreates = false,
    this.requireIdempotentCreates = true,
  });
  final OperationSyncStore store;
  final OperationSyncApi api;
  final bool idempotentCreates;
  final bool requireIdempotentCreates;
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static bool hasIdentity(OperationPayload row) =>
      _uuid.hasMatch('${row['sync_uuid']}');
  final Future<List<OperationPayload>> Function(
    Set<int>,
    List<OperationPayload>,
  )
  prepare;

  static int integer(dynamic value) => int.tryParse('$value') ?? 0;
  static double state(dynamic value) => double.tryParse('$value') ?? 0;
  static double finalState(OperationPayload row) =>
      '${row['estado']}'.trim().toLowerCase() == 'cerrado' ? 1 : 0.5;

  Future<OperationSyncResult> sync(String type, {Set<int>? ids}) async {
    final result = OperationSyncResult();
    // Nunca utilizar la copia del listado: puede estar obsoleta tras un autoenvío.
    final rows = await store.load(ids);
    if (rows.any(
      (row) => state(row['envio']) == 1 && integer(row['idNube']) == 0,
    )) {
      result.errors.add(
        'Hay registros antiguos marcados como enviados sin ID de nube; requieren conciliación antes de reenviar.',
      );
    }
    bool canRetry(OperationPayload row) =>
        integer(row['idNube']) > 0 ||
        (idempotentCreates &&
            hasIdentity(row) &&
            integer(row['sync_retry_safe']) == 1);
    final eligible = rows
        .where(
          (row) =>
              [0.0, 0.5].contains(state(row['envio'])) ||
              ([2.0, 3.0].contains(state(row['envio'])) && canRetry(row)),
        )
        .toList();
    final pending = <OperationPayload>[];
    for (final row in eligible) {
      if (requireIdempotentCreates &&
          !idempotentCreates &&
          integer(row['idNube']) == 0) {
        result.retryable++;
        result.apiUnverified = true;
      } else {
        pending.add(row);
      }
    }
    if (result.retryable > 0) {
      result.errors.add(
        'No se verificó la compatibilidad de la API. No se inició ninguna creación sin protección; vuelve a intentar con conexión.',
      );
    }
    result.uncertain = rows
        .where(
          (row) => [2.0, 3.0].contains(state(row['envio'])) && !canRetry(row),
        )
        .length;
    for (final row in rows.where(
      (row) => [2.0, 3.0].contains(state(row['envio'])) && !canRetry(row),
    )) {
      final protected =
          hasIdentity(row) && integer(row['sync_retry_safe']) == 1;
      if (protected && !idempotentCreates) result.apiUnverified = true;
      result.blocked.add({
        ...row,
        'can_recover':
            !protected &&
            [2.0, 3.0].contains(state(row['envio'])) &&
            hasIdentity(row) &&
            integer(row['idNube']) == 0,
      });
      result.errors.add(
        protected
            ? 'Registro local ${row['id']}: tiene clave protegida, pero no se pudo verificar la API en este intento. Reintenta con conexión.'
            : 'Registro local ${row['id']}: el envío anterior quedó sin confirmar. Puede ser nuevo; comprueba si llegó a la nube antes de recuperarlo.',
      );
    }
    if (pending.isEmpty) return result;
    final payloads = await prepare(
      pending.map((row) => integer(row['id'])).toSet(),
      pending,
    );
    final source = {for (final row in pending) integer(row['id']): row};
    final seen = <int>{};
    final creates = <OperationPayload>[];
    final updates = <OperationPayload>[];
    for (final payload in payloads) {
      final id = integer(payload['local_id']);
      final row = source[id];
      if (id <= 0 || row == null || !seen.add(id)) {
        throw StateError('Identificación local inválida o duplicada.');
      }
      if (idempotentCreates &&
          integer(row['idNube']) == 0 &&
          !hasIdentity(row)) {
        throw StateError(
          'El registro $id no tiene una clave de sincronización válida.',
        );
      }
      final item = Map<String, dynamic>.from(payload)
        ..['local_id'] = id
        ..['sync_uuid'] = row['sync_uuid']
        ..['idNube'] = integer(row['idNube'])
        ..['envio'] = finalState(row);
      if (row['sync_cloud_hash'] is String) {
        item['base_cloud_hash'] = row['sync_cloud_hash'];
      }
      final attempts = await store.attemptedHashes('${row['sync_uuid']}');
      if (attempts.isNotEmpty) item['attempted_hashes'] = attempts;
      item.remove('sync_retry_safe');
      // El ID remoto decide POST o PUT, independientemente del estado de envío.
      (integer(row['idNube']) > 0 ? updates : creates).add(item);
    }
    if (seen.length != source.length) {
      throw StateError('No se prepararon todos los registros seleccionados.');
    }

    if (creates.isNotEmpty) {
      await store.claim(creates, idempotentCreates: idempotentCreates);
      List<dynamic>? response;
      try {
        response = await api.crearParciales(type, creates);
      } catch (error) {
        result.errors.add(
          idempotentCreates
              ? 'No se confirmó el envío; queda pendiente para reintentar con la misma clave. Detalle: $error'
              : 'No se confirmó la creación. Revisar en nube antes de reenviar. Detalle: $error',
        );
      }
      final acknowledged = <int>{};
      final remoteIds = <int>{};
      final requested = {
        for (final row in creates) integer(row['local_id']): row,
      };
      for (final raw in response ?? []) {
        if (raw is! Map) continue;
        final localId = integer(raw['local_id']);
        final cloudId = integer(raw['server_id']);
        final row = requested[localId];
        if (row != null && raw['error'] != null) {
          final detail = '${raw['error']}';
          result.errors.add(
            'Registro local $localId: ${detail.length > 300 ? detail.substring(0, 300) : detail}',
          );
        } else if (row != null && cloudId <= 0) {
          result.errors.add(
            'Registro local $localId: la API no devolvió un ID remoto válido.',
          );
        }
        if (row != null &&
            idempotentCreates &&
            raw['creado'] != false &&
            raw['sync_uuid'] != row['sync_uuid']) {
          result.errors.add(
            'Registro local $localId: la API no confirmó la misma clave UUID.',
          );
        }
        if (row == null ||
            cloudId <= 0 ||
            raw['creado'] == false ||
            (idempotentCreates && raw['sync_uuid'] != row['sync_uuid']) ||
            acknowledged.contains(localId) ||
            remoteIds.contains(cloudId)) {
          continue;
        }
        // ID y envío se confirman en una única escritura local.
        // Si el POST original llegó, el payload remoto puede ser anterior a
        // las ediciones locales. Conservar un PUT pendiente para actualizarlo.
        final reused = raw['reutilizado'] == true;
        await store.confirm(
          localId,
          cloudId,
          reused ? 0.5 : state(row['envio']),
          cloudHash: raw['cloud_hash'] is String
              ? raw['cloud_hash'] as String
              : null,
        );
        acknowledged.add(localId);
        remoteIds.add(cloudId);
        if (reused) {
          result.recovered++;
          result
              .retryable++; // PUT pendiente para enviar la versión local actual.
        } else {
          result.created++;
        }
      }
      for (final row in creates) {
        final id = integer(row['local_id']);
        if (!acknowledged.contains(id)) {
          await store.mark(id, 3);
          if (idempotentCreates) {
            result.retryable++;
          } else {
            result.uncertain++;
          }
        }
      }
    }

    if (updates.isNotEmpty) {
      await store.claim(updates);
      final data = updates
          .map(
            (row) => Map<String, dynamic>.from(row)
              ..remove('local_id')
              ..remove('id'),
          )
          .toList();
      List<dynamic> response = [];
      try {
        response = await api.actualizarMasivoResultados(type, data);
      } catch (_) {
        result.errors.add(
          'No se confirmó la actualización; queda pendiente para reintentar.',
        );
      }
      final confirmed = response
          .whereType<Map>()
          .where((row) => row['actualizado'] == true)
          .map((row) => integer(row['idNube']))
          .toSet();
      for (final row in updates) {
        final id = integer(row['local_id']);
        final cloudId = integer(row['idNube']);
        if (confirmed.contains(cloudId)) {
          final acknowledgement = response.whereType<Map>().firstWhere(
            (r) => integer(r['idNube']) == cloudId && r['actualizado'] == true,
          );
          await store.confirm(
            id,
            cloudId,
            state(row['envio']),
            cloudHash: acknowledgement['cloud_hash'] is String
                ? acknowledgement['cloud_hash'] as String
                : null,
          );
          result.updated++;
        } else {
          await store.mark(id, 0.5);
          final rejected = response.whereType<Map>().where(
            (r) => integer(r['idNube']) == cloudId,
          );
          result.errors.add(
            'La nube no confirmó la actualización del registro $id.'
            '${rejected.isNotEmpty && rejected.first['error'] != null ? " Detalle: ${rejected.first['error']}" : ""}',
          );
        }
      }
    }
    return result;
  }
}
