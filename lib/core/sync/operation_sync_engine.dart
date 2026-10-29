import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../transfer/transfer_content.dart';

typedef OperationPayload = Map<String, dynamic>;

/// Errores de red o de tiempo de espera: no dependen del registro, sino de la
/// conexión. Al detectarlos se detiene el ciclo en lugar de esperar más timeouts.
bool isNetworkError(Object error) =>
    error is TimeoutException || error is IOException;

class OperationSyncResult {
  int created = 0;
  int updated = 0;
  int uncertain = 0;
  int retryable = 0;
  int recovered = 0;
  int unchanged = 0;
  int deferred = 0;
  bool apiUnverified = false;
  bool networkFailed = false;
  bool interrupted = false;
  final errors = <String>[];
  final blocked = <OperationPayload>[];

  /// Suma otro resultado (por ejemplo, de otro tipo de operación).
  void absorb(OperationSyncResult other) {
    created += other.created;
    updated += other.updated;
    uncertain += other.uncertain;
    retryable += other.retryable;
    recovered += other.recovered;
    unchanged += other.unchanged;
    deferred += other.deferred;
    apiUnverified |= other.apiUnverified;
    networkFailed |= other.networkFailed;
    interrupted |= other.interrupted;
    errors.addAll(other.errors);
    blocked.addAll(other.blocked);
  }

  String get message =>
      'Creados: $created · Actualizados: $updated'
      '${recovered > 0 ? " · Recuperados: $recovered" : ""}'
      '${unchanged > 0 ? " · Sin cambios (no se reenviaron): $unchanged" : ""}'
      '${retryable > 0 ? " · Pendientes de reintento: $retryable" : ""}'
      '${uncertain > 0 ? " · Sin confirmación: $uncertain (requieren revisión en nube)" : ""}'
      '${deferred > 0 ? " · En espera tras fallos repetidos: $deferred (se reintentan solos o con envío manual)" : ""}'
      '${networkFailed ? "\nLa conexión con la nube falló; el resto se enviará en el próximo intento." : ""}'
      '${interrupted ? "\nEl envío automático se pausó para atender otra solicitud; continúa en el próximo ciclo." : ""}'
      '${errors.isNotEmpty ? "\n${errors.join('\n')}" : ""}'
      '${errors.isNotEmpty || uncertain > 0 || retryable > 0 ? "\nDiagnóstico: SYNC-20261026-R3" : ""}';
}

/// Es el mismo bloqueo para las rutas automáticas y las pantallas manuales.
class OperationSyncGate {
  Future<void> _tail = Future.value();
  int _pending = 0;

  /// Hay al menos una solicitud esperando detrás de la que se está ejecutando.
  /// El envío automático lo consulta para ceder el turno cuanto antes.
  bool get hasWaiters => _pending > 1;

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    _pending++;
    return () async {
      try {
        await previous;
        return await action();
      } finally {
        _pending--;
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

  /// Registra un intento fallido. [penalize] aplica espera progresiva cuando
  /// el rechazo es del propio registro (no de la red).
  Future<void> mark(
    int id,
    double state, {
    String? reason,
    bool penalize = false,
  });
  Future<void> confirm(int id, int cloudId, double state, {String? cloudHash});
  Future<List<String>> attemptedHashes(String uuid) async => [];

  /// Registros omitidos en la última carga automática por estar en espera.
  int get deferred => 0;
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
    this.batchSize = 25,
    this.maxRequestBytes = 8 * 1024 * 1024,
    this.shouldStop,
  });
  final OperationSyncStore store;
  final OperationSyncApi api;
  final bool idempotentCreates;
  final bool requireIdempotentCreates;

  /// Registros por petición. Evita lotes enormes que superen el límite del
  /// servidor o el tiempo de espera y fallen siempre.
  final int batchSize;
  final int maxRequestBytes;

  /// Permite al envío automático ceder el turno entre lotes.
  final bool Function()? shouldStop;
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

  static String? _fingerprint(String type, OperationPayload payload) {
    try {
      return TransferContent.fingerprint(type, payload);
    } catch (_) {
      return null;
    }
  }

  static String _short(String text) =>
      text.length > 300 ? text.substring(0, 300) : text;

  List<int> _requestBody(
    String type,
    List<OperationPayload> rows, {
    required bool update,
  }) {
    final data = update
        ? rows
              .map(
                (row) => Map<String, dynamic>.from(row)
                  ..remove('local_id')
                  ..remove('id'),
              )
              .toList()
        : rows;
    return utf8.encode(jsonEncode({'tipo': type, 'data': data}));
  }

  Future<List<List<OperationPayload>>> _boundedChunks(
    String type,
    List<OperationPayload> rows,
    Map<int, OperationPayload> originalRows,
    OperationSyncResult result, {
    required bool update,
  }) async {
    final size = max(1, batchSize);
    final chunks = <List<OperationPayload>>[];
    var current = <OperationPayload>[];
    for (final row in rows) {
      final candidate = [...current, row];
      final bytes = _requestBody(type, candidate, update: update).length;
      if (bytes > maxRequestBytes && current.isNotEmpty) {
        chunks.add(current);
        current = [];
      }
      final singleBytes = _requestBody(type, [row], update: update).length;
      if (singleBytes > maxRequestBytes) {
        final id = integer(row['local_id']);
        final reason =
            'La operación ocupa $singleBytes bytes y supera el límite seguro '
            'de $maxRequestBytes bytes por petición. Reduce el contenido antes de reenviar.';
        result.errors.add('Registro local $id: $reason');
        await store.mark(
          id,
          OperationSyncEngine.state(originalRows[id]?['envio']),
          reason: reason,
          penalize: true,
        );
        continue;
      }
      current.add(row);
      if (current.length >= size) {
        chunks.add(current);
        current = [];
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  bool _stopRequested(OperationSyncResult result) {
    if (result.networkFailed) return true;
    if (shouldStop?.call() == true) {
      result.interrupted = true;
      return true;
    }
    return false;
  }

  Future<OperationSyncResult> sync(String type, {Set<int>? ids}) async {
    final result = OperationSyncResult();
    // Nunca utilizar la copia del listado: puede estar obsoleta tras un autoenvío.
    final rows = await store.load(ids);
    result.deferred = store.deferred;
    if (ids != null) {
      final found = rows.map((row) => integer(row['id'])).toSet();
      for (final id in ids.difference(found)) {
        result.errors.add(
          'Registro local $id: no se envió desde aquí porque está en una transferencia a la maestra '
          '(se sube desde Transferencias) o ya no existe.',
        );
      }
    }
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
        // Solo este registro queda fuera; el resto del tipo sigue enviándose.
        result.errors.add(
          'Registro local $id: no tiene una clave de sincronización válida. No se envió.',
        );
        continue;
      }
      final item = Map<String, dynamic>.from(payload)
        ..['local_id'] = id
        ..['sync_uuid'] = row['sync_uuid']
        ..['idNube'] = integer(row['idNube'])
        ..['envio'] = finalState(row);
      // Una operación activa ya confirmada no se reenvía si no cambió desde
      // la última versión aceptada por la nube.
      if (integer(row['idNube']) > 0 &&
          state(row['envio']) == 0.5 &&
          finalState(row) == 0.5 &&
          row['sync_cloud_hash'] is String &&
          _fingerprint(type, item) == row['sync_cloud_hash']) {
        result.unchanged++;
        continue;
      }
      if (row['sync_cloud_hash'] is String) {
        item['base_cloud_hash'] = row['sync_cloud_hash'];
      }
      final attempts = await store.attemptedHashes('${row['sync_uuid']}');
      if (attempts.isNotEmpty) item['attempted_hashes'] = attempts;
      item.remove('sync_retry_safe');
      // El ID remoto decide POST o PUT, independientemente del estado de envío.
      (integer(row['idNube']) > 0 ? updates : creates).add(item);
    }
    for (final id in source.keys.where((id) => !seen.contains(id))) {
      result.errors.add(
        'Registro local $id: no se pudo preparar para el envío. Se reintentará.',
      );
    }

    for (final chunk in await _boundedChunks(
      type,
      creates,
      source,
      result,
      update: false,
    )) {
      if (_stopRequested(result)) break;
      await _sendCreates(type, chunk, result);
    }
    for (final chunk in await _boundedChunks(
      type,
      updates,
      source,
      result,
      update: true,
    )) {
      if (_stopRequested(result)) break;
      await _sendUpdates(type, chunk, result);
    }
    return result;
  }

  /// Aparta los registros; si alguno cambió, se aparta el resto uno a uno
  /// para que un registro editado no frene a todo el lote.
  Future<List<OperationPayload>> _claim(
    List<OperationPayload> rows,
    OperationSyncResult result, {
    bool idempotent = false,
  }) async {
    try {
      await store.claim(rows, idempotentCreates: idempotent);
      return rows;
    } on StateError {
      if (rows.length == 1) {
        result.errors.add(
          'Registro local ${rows.single['local_id']}: cambió mientras se preparaba; se enviará en el próximo intento.',
        );
        return [];
      }
      final claimed = <OperationPayload>[];
      for (final row in rows) {
        claimed.addAll(await _claim([row], result, idempotent: idempotent));
      }
      return claimed;
    }
  }

  Future<void> _sendCreates(
    String type,
    List<OperationPayload> batch,
    OperationSyncResult result,
  ) async {
    final creates = await _claim(batch, result, idempotent: idempotentCreates);
    if (creates.isEmpty) return;
    List<dynamic>? response;
    String? batchError;
    try {
      response = await api.crearParciales(type, creates);
    } catch (error) {
      batchError = _short('$error');
      if (isNetworkError(error)) result.networkFailed = true;
      result.errors.add(
        idempotentCreates
            ? 'No se confirmó el envío; queda pendiente para reintentar con la misma clave. Detalle: $error'
            : 'No se confirmó la creación. Revisar en nube antes de reenviar. Detalle: $error',
      );
    }
    final acknowledged = <int>{};
    final remoteIds = <int>{};
    final reasons = <int, String>{};
    final requested = {
      for (final row in creates) integer(row['local_id']): row,
    };
    for (final raw in response ?? []) {
      if (raw is! Map) continue;
      final localId = integer(raw['local_id']);
      final cloudId = integer(raw['server_id']);
      final row = requested[localId];
      if (row != null && raw['error'] != null) {
        final detail = _short('${raw['error']}');
        reasons[localId] = detail;
        result.errors.add('Registro local $localId: $detail');
      } else if (row != null && cloudId <= 0) {
        reasons[localId] = 'La API no devolvió un ID remoto válido.';
        result.errors.add(
          'Registro local $localId: la API no devolvió un ID remoto válido.',
        );
      }
      if (row != null &&
          idempotentCreates &&
          raw['creado'] != false &&
          raw['sync_uuid'] != row['sync_uuid']) {
        reasons[localId] = 'La API no confirmó la misma clave UUID.';
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
        if (row != null && raw['creado'] == false) {
          reasons.putIfAbsent(
            localId,
            () => 'La API respondió que no creó el registro.',
          );
        }
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
            // Si la nube guardó lo enviado, su versión es la de este payload.
            : reused
            ? null
            : _fingerprint(type, row),
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
        final reason = reasons[id];
        await store.mark(
          id,
          3,
          reason: reason ?? batchError ?? 'La API no confirmó este registro.',
          // Solo un rechazo propio del registro activa la espera progresiva.
          penalize: reason != null,
        );
        if (idempotentCreates) {
          result.retryable++;
        } else {
          result.uncertain++;
        }
      }
    }
  }

  Future<void> _sendUpdates(
    String type,
    List<OperationPayload> batch,
    OperationSyncResult result,
  ) async {
    final updates = await _claim(batch, result);
    if (updates.isEmpty) return;
    final data = updates
        .map(
          (row) => Map<String, dynamic>.from(row)
            ..remove('local_id')
            ..remove('id'),
        )
        .toList();
    List<dynamic> response = [];
    String? batchError;
    try {
      response = await api.actualizarMasivoResultados(type, data);
    } catch (error) {
      batchError = _short('$error');
      if (isNetworkError(error)) result.networkFailed = true;
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
              : _fingerprint(type, row),
        );
        result.updated++;
      } else {
        final rejected = response.whereType<Map>().where(
          (r) => integer(r['idNube']) == cloudId,
        );
        final detail = rejected.isNotEmpty && rejected.first['error'] != null
            ? _short('${rejected.first['error']}')
            : null;
        await store.mark(
          id,
          0.5,
          reason:
              detail ??
              batchError ??
              'La nube no confirmó la actualización de este registro.',
          penalize: detail != null,
        );
        result.errors.add(
          'La nube no confirmó la actualización del registro $id.'
          '${detail != null ? " Detalle: $detail" : ""}',
        );
      }
    }
  }
}
