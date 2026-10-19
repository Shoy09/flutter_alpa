import 'dart:async';

typedef OperationPayload = Map<String, dynamic>;

class OperationSyncResult {
  int created = 0;
  int updated = 0;
  int uncertain = 0;
  final errors = <String>[];
  String get message =>
      'Creados: $created · Actualizados: $updated'
      '${uncertain > 0 ? " · Sin confirmación: $uncertain (revisar en nube antes de reenviar)" : ""}'
      '${errors.isNotEmpty ? "\n${errors.join('\n')}" : ""}';
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
  Future<void> claim(List<OperationPayload> rows);
  Future<void> mark(int id, double state);
  Future<void> confirm(int id, int cloudId, double state);
}

abstract class OperationSyncApi {
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
  });
  final OperationSyncStore store;
  final OperationSyncApi api;
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
    final pending = rows
        .where((row) => [0.0, 0.5].contains(state(row['envio'])))
        .toList();
    result.uncertain = rows.where((row) => state(row['envio']) == 3).length;
    if (rows.any((row) => state(row['envio']) == 2)) {
      result.errors.add(
        'Hay registros con un envío pendiente de confirmación.',
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
      final item = Map<String, dynamic>.from(payload)
        ..['local_id'] = id
        ..['idNube'] = integer(row['idNube'])
        ..['envio'] = finalState(row);
      // El ID remoto decide POST o PUT, independientemente del estado de envío.
      (integer(row['idNube']) > 0 ? updates : creates).add(item);
    }
    if (seen.length != source.length) {
      throw StateError('No se prepararon todos los registros seleccionados.');
    }

    if (creates.isNotEmpty) {
      await store.claim(creates);
      List<dynamic>? response;
      try {
        response = await api.crearParciales(type, creates);
      } catch (_) {
        result.errors.add(
          'No se confirmó la creación. Se evita repetir el POST para no duplicar.',
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
        if (row == null ||
            cloudId <= 0 ||
            raw['creado'] == false ||
            acknowledged.contains(localId) ||
            remoteIds.contains(cloudId)) {
          continue;
        }
        // ID y envío se confirman en una única escritura local.
        await store.confirm(localId, cloudId, state(row['envio']));
        acknowledged.add(localId);
        remoteIds.add(cloudId);
        result.created++;
      }
      for (final row in creates) {
        final id = integer(row['local_id']);
        if (!acknowledged.contains(id)) {
          await store.mark(id, 3);
          result.uncertain++;
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
          await store.confirm(id, cloudId, state(row['envio']));
          result.updated++;
        } else {
          await store.mark(id, 0.5);
          result.errors.add(
            'La nube no confirmó la actualización del registro $id.',
          );
        }
      }
    }
    return result;
  }
}
