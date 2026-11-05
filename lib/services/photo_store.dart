import 'dart:convert';
import 'package:i_miner/models/photo_draft.dart';
import 'package:sqflite/sqflite.dart';

/// Guarda toda la hoja en una transacción, en la tabla del proceso. Los datos
/// u horómetros incompletos se guardan vacíos o en 0 y se revisan después en
/// la pantalla del módulo.
class PhotoStore {
  static Future<int> save(
    Database db, {
    required String dni,
    required PhotoDraft draft,
    required Map<String, String> estadosPorCodigo,
    required List<Map<String, dynamic>> checklist,
    required String imageHash,
  }) async {
    final errors = draft.validate(estadosPorCodigo);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return db.transaction((txn) async {
      final users = await txn.query(
        'Usuario',
        columns: ['rol'],
        where: 'codigo_dni = ?',
        whereArgs: [dni],
      );
      if (users.isEmpty ||
          users.first['rol'].toString().trim().toLowerCase() != 'master') {
        throw StateError('Solo un usuario master puede importar reportes.');
      }
      final h = draft.cabecera;
      final duplicate = await txn.query(
        draft.proceso.tabla,
        columns: ['id'],
        where: 'fecha = ? AND turno = ? AND n_equipo = ?',
        whereArgs: [h['fecha'], h['turno'], h['n_equipo']],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw StateError(
          'Ya existe una operación de ese equipo, fecha y turno. '
          'Revisa el registro existente para evitar duplicarlo.',
        );
      }
      // Las tablas no tienen la misma cabecera: Scalamin y Scissor guardan la
      // guardia en `guardia` (no `seccion`) y solo las de perforación tienen
      // `modelo_equipo`.
      final columnas = {
        for (final c in await txn.rawQuery(
          'PRAGMA table_info(${draft.proceso.tabla})',
        ))
          c['name'] as String,
      };
      final cabecera = <String, Object?>{
        for (final k in [
          'fecha',
          'turno',
          'operador',
          'jefe_guardia',
          'equipo',
          'n_equipo',
          'modelo_equipo',
        ])
          if (columnas.contains(k)) k: h[k]!.trim(),
        columnas.contains('seccion') ? 'seccion' : 'guardia':
            h['seccion']!.trim(),
      };
      return txn.insert(draft.proceso.tabla, {
        ...cabecera,
        'registros': jsonEncode(
          draft.registros(
            estadosPorCodigo,
            firstId: DateTime.now().microsecondsSinceEpoch,
          ),
        ),
        'horometros': jsonEncode({
          for (final entry in draft.horometros.entries)
            entry.key: {
              'inicio': photoNumber(entry.value['inicio']) ?? 0,
              'final': photoNumber(entry.value['final']) ?? 0,
              'op': entry.value['inicio']!.isNotEmpty,
              'inop': false,
            },
        }),
        'check_list': jsonEncode(checklist),
        'condiciones_equipo': jsonEncode({
          'op': false,
          'noOp': false,
          'lugar': '',
          'descripcion': '',
          'aceiteMotor': false,
          'aceiteHidraulico': false,
          'aceiteTransmision': false,
          'combustible': '',
          'horaLlenado': '',
          'reporte_foto': {
            'ayudante': h['ayudante'],
            'revisado_por': dni,
            'image_sha256': imageHash,
            'advertencias': [...draft.advertencias, ...draft.pendientes(estadosPorCodigo)],
            'revisado_en': DateTime.now().toUtc().toIso8601String(),
          },
        }),
        'control_llantas': jsonEncode({
          for (var i = 1; i <= 4; i++) 'numero$i': false,
        }),
        'estado': 'activo',
        'envio': 0,
      });
    });
  }
}
