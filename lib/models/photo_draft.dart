import 'package:i_miner/models/photo_proceso.dart';

/// Borrador en memoria. Leer una foto nunca escribe en la base de datos.
class PhotoDraft {
  static const headerKeys = [
    'fecha',
    'turno',
    'seccion',
    'operador',
    'ayudante',
    'jefe_guardia',
    'equipo',
    'n_equipo',
    'modelo_equipo',
  ];
  final PhotoProceso proceso;
  final Map<String, String> cabecera;
  final List<PhotoActivity> actividades;
  final Map<String, Map<String, String>> horometros;
  final List<String> advertencias;

  /// Empernador: tipo y longitud del catálogo para cada columna de pernos o
  /// mallas (ej. ss7 → {tipo: SPLIT SET, longitud: 7}); los fija la pantalla.
  final Map<String, Map<String, String>> catalogoColumnas = {};

  /// Scoop: id del destino del catálogo SCOOPTRAM por nombre (lo fija la
  /// pantalla, como el formulario al guardar).
  final Map<String, int> idsDestino = {};

  /// Id de cada opción por campo (ej. tipo_perforacion → {FRENTE: 3}) para
  /// los campos que el formulario guarda con su id; los fija la pantalla.
  final Map<String, Map<String, int>> idsCatalogo = {};

  PhotoDraft({
    this.proceso = PhotoProceso.talLargo,
    Map<String, String>? cabecera,
    List<PhotoActivity>? actividades,
    Map<String, Map<String, String>>? horometros,
    List<String>? advertencias,
  }) : cabecera = {for (final k in headerKeys) k: cabecera?[k] ?? ''},
       actividades = actividades ?? [],
       horometros = {
         for (final k in proceso.horometros)
           k: {
             'inicio': horometros?[k]?['inicio'] ?? '',
             'final': horometros?[k]?['final'] ?? '',
           },
       },
       advertencias = advertencias ?? [];

  factory PhotoDraft.fromJson(
    Map<String, dynamic> json, {
    PhotoProceso proceso = PhotoProceso.talLargo,
  }) {
    final header = Map<String, dynamic>.from(json['cabecera'] as Map);
    final rows = json['actividades'] as List;
    if (rows.length > 100) {
      throw const FormatException('Demasiadas actividades.');
    }
    final meters = Map<String, dynamic>.from(json['horometros'] as Map);
    return PhotoDraft(
        proceso: proceso,
        cabecera: {for (final k in headerKeys) k: photoText(header[k])},
        actividades: rows
            .map(
              (v) =>
                  PhotoActivity.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
        horometros: {
          for (final k in proceso.horometros)
            k: {
              for (final f in ['inicio', 'final'])
                f: photoText((meters[k] as Map?)?[f]),
            },
        },
        advertencias: (json['advertencias'] as List? ?? [])
            .map((v) => photoText(v))
            .where((v) => v.isNotEmpty)
            .toList(),
      )
      ..normalizarFecha()
      ..normalizarHoras()
      ..dividirViajes()
      ..normalizarCampos();
  }

  /// Scoop: un estado por viaje. Si la hoja anota dos viajes en un mismo
  /// estado (la fila de abajo sin código ni horas), se divide en dos estados
  /// repartiendo el tiempo en múltiplos de 5 minutos, y se avisa.
  void dividirViajes() {
    if (proceso.formato != PhotoFormato.scoop) return;
    final turno = cabecera['turno']!;
    final resultado = <PhotoActivity>[];
    for (final (i, actividad) in actividades.indexed) {
      _tipoLaborAObservaciones(actividad.datos);
      final viajes = actividad.viajes
          .where((v) => v.values.any((x) => x.isNotEmpty))
          .toList();
      if (viajes.length <= 1) {
        _aplicarViaje(actividad, viajes.firstOrNull, i);
        resultado.add(actividad);
        continue;
      }
      final inicio = shiftMinutes(actividad.datos['hora_inicio']!, turno);
      final fin = shiftMinutes(actividad.datos['hora_final']!, turno);
      final cortes = [
        for (var k = 1; k < viajes.length; k++)
          if (inicio != null && fin != null && fin > inicio)
            ((inicio + (fin - inicio) * k ~/ viajes.length) ~/ 5) * 5,
      ];
      for (final (k, viaje) in viajes.indexed) {
        final parte = PhotoActivity(
          datos: {
            ...actividad.datos,
            // Sin horas válidas se dejan para completarlas al revisar.
            if (k > 0)
              'hora_inicio': cortes.length == viajes.length - 1
                  ? _hhmm(cortes[k - 1] % 1440)
                  : '',
            if (k < viajes.length - 1)
              'hora_final': cortes.length == viajes.length - 1
                  ? _hhmm(cortes[k] % 1440)
                  : '',
            if (k > 0) 'observaciones': '',
          },
        );
        _aplicarViaje(parte, viaje, i);
        resultado.add(parte);
      }
      advertencias.add(
        'Actividad ${i + 1} (${actividad.datos['codigo']}) tenía '
        '${viajes.length} viajes: se dividió en ${viajes.length} estados '
        '(${[for (final p in resultado.skip(resultado.length - viajes.length)) '${p.datos['hora_inicio']}–${p.datos['hora_final']}'].join(', ')}); '
        'confirma las horas.',
      );
    }
    actividades
      ..clear()
      ..addAll(resultado);
  }

  /// Cucharas de un solo material por viaje: N° cucharas es esa cantidad y
  /// Material el de su columna.
  void _aplicarViaje(PhotoActivity a, Map<String, String>? viaje, int fila) {
    if (viaje == null) return;
    a.datos['labor_inicio'] = viaje['origen']!;
    a.datos['ubicacion_destino'] = viaje['destino']!;
    a.datos['numero_volquete'] = viaje['numero_volquete']!;
    final cucharas = {
      for (final m in ['mineral', 'desmonte', 'relleno', 'relave'])
        if (viaje[m]!.isNotEmpty && !RegExp(r'^[-–—]+$').hasMatch(viaje[m]!))
          m: viaje[m]!,
    };
    if (cucharas.isEmpty) return;
    final material = cucharas.entries.reduce(
      (a, b) => (photoNumber(b.value) ?? 0) > (photoNumber(a.value) ?? 0) ? b : a,
    );
    a.datos['n_cucharas'] = material.value;
    a.datos['material'] = material.key.toUpperCase();
    if (cucharas.length > 1) {
      advertencias.add(
        'Actividad ${fila + 1}: hay cucharas en varios materiales '
        '(${cucharas.entries.map((e) => '${e.key} ${e.value}').join(', ')}); '
        'se tomó ${material.key.toUpperCase()}. Revísalo.',
      );
    }
  }

  /// La hoja de Scoop tiene "Tipo de labor" (F, B, TL…) pero el formulario no.
  static void _tipoLaborAObservaciones(Map<String, String> datos) {
    final letra = datos['tipo_labor']!.trim().toUpperCase();
    if (letra.isEmpty) return;
    final tipo = PhotoProceso.tiposLaborScoop[letra] ?? letra;
    final obs = datos['observaciones']!.trim();
    datos['observaciones'] =
        obs.isEmpty ? 'Tipo de labor: $tipo' : 'Tipo de labor: $tipo · $obs';
    datos['tipo_labor'] = '';
  }

  /// Pasa lo escrito en la hoja al valor del formulario: "M" → MINERAL,
  /// "F" → FRENTE, "-" → vacío. Texto en una columna de números (ej. "P.7"
  /// escrito en metros lineales) no es un dato: pasa a las observaciones.
  void normalizarCampos() {
    for (final actividad in actividades) {
      final datos = actividad.datos;
      for (final campo in proceso.campos) {
        var valor = datos[campo.key]!.trim();
        if (RegExp(r'^[-–—]+$').hasMatch(valor)) valor = '';
        if (campo.numero) valor = valor.replaceAll(',', '.');
        if (campo.numero && valor.isNotEmpty && photoNumber(valor) == null) {
          final obs = datos['observaciones']!.trim();
          datos['observaciones'] = obs.isEmpty ? valor : '$obs · $valor';
          valor = '';
        }
        valor = campo.equivalencias[valor.toUpperCase()] ?? valor;
        datos[campo.key] = valor;
      }
    }
  }

  bool llevaDatos(String? estado, String codigo) =>
      proceso.llevaDatos(estado, codigo);

  /// La hoja trae la fecha como DD/MM/AA ("21/10/26"); el registro usa
  /// AAAA-MM-DD. Si no se puede interpretar, queda como vino para corregirla.
  void normalizarFecha() {
    final texto = cabecera['fecha']!.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return;
    final partes = RegExp(r'\d+').allMatches(texto).map((m) => m.group(0)!);
    if (partes.length != 3) return;
    final [a, b, c] = partes.map(int.parse).toList();
    // AAAA/MM/DD o DD/MM/AA(AA).
    final (anio, mes, dia) = partes.first.length == 4
        ? (a, b, c)
        : (c < 100 ? 2000 + c : c, b, a);
    final fecha = DateTime.tryParse(
      '${anio.toString().padLeft(4, '0')}-'
      '${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}',
    );
    if (fecha == null || fecha.month != mes || fecha.day != dia) return;
    cabecera['fecha'] = fecha.toIso8601String().substring(0, 10);
  }

  /// Pasa turno y horas leídas ("7:30", "07:30:00", "7.30", "730", "1:00 pm")
  /// a DÍA/NOCHE y HH:mm en 24 h. Una hora de 12 h sin AM/PM se resuelve con
  /// el turno y la hora anterior; si no encaja, queda tal cual para revisarla.
  void normalizarHoras() {
    final t = cabecera['turno']!
        .trim()
        .toUpperCase()
        .replaceAll('́', '')
        .replaceAll('Í', 'I');
    if (t.contains('NOCH') || t == 'N' || t.contains('NIGHT')) {
      cabecera['turno'] = 'NOCHE';
    } else if (t.contains('DIA') || t.contains('DIURN') || t == 'D' ||
        t.contains('DAY')) {
      cabecera['turno'] = 'DÍA';
    } else {
      final deducido = _deducirTurno();
      if (deducido != null) {
        cabecera['turno'] = deducido;
        advertencias.add(
          'Turno deducido como $deducido por la primera hora de la hoja; confírmalo.',
        );
      }
    }
    final turno = cabecera['turno']!;
    int? previo;
    for (final (fila, actividad) in actividades.indexed) {
      final redondeadas = <String>[];
      for (final campo in ['hora_inicio', 'hora_final']) {
        final hora = _leerHora(actividad.datos[campo]!);
        if (hora == null) continue;
        final elegida =
            _elegirHora(hora, turno, previo) ??
            _elegirHora(hora, turno, null) ??
            hora.first;
        // La app registra de 5 en 5 minutos: 7:12 → 07:10, 7:13 → 07:15.
        final redondeada = ((elegida + 2) ~/ 5 * 5) % 1440;
        if (redondeada != elegida) {
          redondeadas.add('${_hhmm(elegida)} → ${_hhmm(redondeada)}');
        }
        actividad.datos[campo] = _hhmm(redondeada);
        previo = shiftMinutes(actividad.datos[campo]!, turno) ?? previo;
      }
      if (redondeadas.isNotEmpty) {
        advertencias.add(
          'Actividad ${fila + 1}: hora redondeada a 5 minutos '
          '(${redondeadas.join(', ')}); revísala con la hoja.',
        );
      }
    }
  }

  /// Sin turno legible: una hoja que empieza entre 06:00 y 11:59 es de DÍA y
  /// una que empieza entre 17:00 y 20:59 (o 5:00–8:59 de la tarde) es de NOCHE.
  String? _deducirTurno() {
    if (actividades.isEmpty) return null;
    final hora = _leerHora(actividades.first.datos['hora_inicio']!);
    if (hora == null) return null;
    final h = hora.first ~/ 60;
    if (hora.length == 1) {
      if (h >= 6 && h < 12) return 'DÍA';
      if (h >= 17 && h < 21) return 'NOCHE';
      return null;
    }
    // Sin AM/PM: 6–11 se lee como inicio de mañana (DÍA).
    return h >= 6 && h < 12 ? 'DÍA' : null;
  }

  /// Lecturas posibles en minutos del día; la primera es la escrita.
  static List<int>? _leerHora(String raw) {
    var s = raw.trim().toLowerCase().replaceAll(' ', '');
    if (s.isEmpty) return null;
    final periodo = RegExp(r'([ap])\.?m\.?$').firstMatch(s);
    if (periodo != null) s = s.substring(0, periodo.start);
    s = s.replaceAll(RegExp(r'[.,hH\-]'), ':');
    int? h, m;
    final conSeparador = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?:?$',
    ).firstMatch(s);
    final digitos = RegExp(r'^\d{1,4}$').hasMatch(s);
    if (conSeparador != null) {
      h = int.parse(conSeparador.group(1)!);
      m = int.parse(conSeparador.group(2)!);
    } else if (digitos && s.length >= 3) {
      h = int.parse(s.substring(0, s.length - 2));
      m = int.parse(s.substring(s.length - 2));
    } else if (digitos) {
      h = int.parse(s);
      m = 0;
    }
    if (h == null || m == null || h > 23 || m > 59) return null;
    if (periodo != null) {
      if (h < 1 || h > 12) return null;
      return [(h % 12 + (periodo.group(1) == 'p' ? 12 : 0)) * 60 + m];
    }
    if (h == 0 || h > 12) return [h * 60 + m];
    return [h * 60 + m, ((h + 12) % 24) * 60 + m];
  }

  /// La lectura más temprana dentro del turno que no retrocede respecto a la anterior.
  static int? _elegirHora(List<int> opciones, String turno, int? previo) {
    int? elegida, mejor;
    for (final opcion in opciones) {
      final s = shiftMinutes(_hhmm(opcion), turno);
      if (s == null) continue;
      final dentro = switch (turno) {
        'DÍA' => s >= inicioDia && s <= 1110,
        'NOCHE' => s >= 1110 && s <= 1830,
        _ => true,
      };
      if (!dentro || (previo != null && s < previo)) continue;
      if (mejor == null || s < mejor) {
        mejor = s;
        elegida = opcion;
      }
    }
    return elegida;
  }

  /// En la hoja el turno DÍA puede empezar a las 06:00 (el formulario manual
  /// empieza a las 06:30); al leer la foto se acepta desde las 06:00.
  static const inicioDia = 360;

  static String _hhmm(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';

  static int? shiftMinutes(String value, String turno) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return null;
    final parts = value.split(':').map(int.parse).toList();
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 +
        parts[1] +
        (turno == 'NOCHE' && parts[0] < 7 ? 1440 : 0);
  }

  /// Taladro largo: solo OPERATIVO lleva barras, salvo 107–110 y 200–599.
  static bool llevaBarras(String? estado, String codigo) =>
      PhotoProceso.talLargo.llevaDatos(estado, codigo);

  /// Los operadores a veces anotan los datos de perforación junto a un estado
  /// que no los lleva (una demora, un traslado). Pasan al estado con datos
  /// anterior (o al siguiente, si no hay anterior) y se avisa para revisarlo.
  void reubicarDatos(Map<String, String> estadosPorCodigo) {
    if (!proceso.reubicar) return;
    bool lleva(PhotoActivity a) =>
        llevaDatos(estadosPorCodigo[a.datos['codigo']], a.datos['codigo']!);
    // El brazo (IZQ/DCH) acompaña a los datos de perforación.
    final claves = [...proceso.campos.map((c) => c.key), 'brazo'];
    for (var i = 0; i < actividades.length; i++) {
      final origen = actividades[i];
      if (lleva(origen)) continue;
      final filas = origen.barras.where((b) => !_isEmptyBar(b)).toList();
      final valores = {
        for (final k in claves)
          if (origen.datos[k]!.isNotEmpty) k: origen.datos[k]!,
      };
      if (filas.isEmpty && valores.isEmpty) continue;
      var destino = -1;
      for (var j = i - 1; j >= 0 && destino < 0; j--) {
        if (lleva(actividades[j])) destino = j;
      }
      for (var j = i + 1; j < actividades.length && destino < 0; j++) {
        if (lleva(actividades[j])) destino = j;
      }
      origen.barras.clear();
      for (final k in valores.keys) {
        origen.datos[k] = '';
      }
      final codigo = origen.datos['codigo'];
      final que = filas.isNotEmpty
          ? '${filas.length} fila(s) de taladros'
          : 'los datos de perforación';
      // En una hoja sin barras, si el destino ya tiene datos no se mezclan.
      final ocupado =
          destino >= 0 &&
          claves.any((k) => actividades[destino].datos[k]!.isNotEmpty);
      if (destino < 0 || (valores.isNotEmpty && ocupado)) {
        advertencias.add(
          'Actividad ${i + 1} ($codigo) no lleva datos de perforación: se '
          'descartaron $que; revísalos con la hoja.',
        );
        continue;
      }
      actividades[destino].barras.addAll(filas);
      actividades[destino].datos.addAll(valores);
      advertencias.add(
        'Actividad ${i + 1} ($codigo) no lleva datos de perforación: $que '
        'pasaron a la actividad ${destino + 1} '
        '(${actividades[destino].datos['codigo']}); confírmalo con la hoja.',
      );
    }
    // El formulario no tiene campo de brazo: queda en las observaciones.
    for (final actividad in actividades) {
      final datos = actividad.datos;
      final brazo = datos['brazo']!.trim();
      if (brazo.isEmpty) continue;
      final obs = datos['observaciones']!.trim();
      datos['observaciones'] = obs.isEmpty ? 'Brazo $brazo' : 'Brazo $brazo · $obs';
      datos['brazo'] = '';
    }
  }

  /// Labores siempre en mayúsculas y unidas con "_": "tj 493" y "TJ493" →
  /// "TJ_493".
  /// La cámara se escribe "C 730", "CR 730", "CH 730" o "Cámara 70": siempre
  /// es CM.
  static String formatearLabor(String texto) => texto
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-.,/]+'), '_')
      .replaceAllMapped(
        RegExp(r'([A-ZÑ])(?=\d)'),
        (m) => '${m[1]}_',
      )
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .replaceFirst(RegExp(r'^(C|CR|CH|CAM|CAMARA|CÁMARA)_(?=\d)'), 'CM_');

  /// Gemini a veces copia en la labor el H. INICIAL/FINAL de la fila (columnas
  /// vecinas). Una labor nunca es un número con decimales ("4523.4") ni un
  /// número dentro del rango de los horómetros del pie de la hoja.
  bool esLecturaHorometro(String texto) {
    final t = texto.trim();
    if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(t)) return false;
    if (RegExp(r'[.,]').hasMatch(t)) return true;
    final valor = double.parse(t);
    for (final h in horometros.values) {
      final lecturas = [h['inicio'], h['final']]
          .map((v) => v == null ? null : photoNumber(v))
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (lecturas.isEmpty) continue;
      lecturas.sort();
      if (valor >= lecturas.first - 1 && valor <= lecturas.last + 1) {
        return true;
      }
    }
    return false;
  }

  /// Da formato a las labores y completa las actividades de perforación sin
  /// labor: en la hoja la UBICACIÓN suele escribirse una sola vez (a veces en
  /// vertical) para varias filas. Toma la labor escrita más cercana, primero
  /// la de arriba, y avisa para confirmarlo.
  void completarLabores(Map<String, String> estadosPorCodigo) {
    for (final (fila, actividad) in actividades.indexed) {
      final leida = actividad.datos['labor']!.trim();
      if (esLecturaHorometro(leida)) {
        actividad.datos['labor'] = '';
        advertencias.add(
          'Actividad ${fila + 1}: se leyó "$leida" como labor, pero parece una '
          'lectura de horómetro; se dejó la labor vacía. Revísala con la hoja.',
        );
      }
      var labor = formatearLabor(actividad.datos['labor']!);
      // Las letras ("TJ") pueden llegar en tipo_labor, o mal ubicadas en ala o
      // nivel; solo se toman si son letras sueltas y la labor es solo número.
      var tipo = formatearLabor(actividad.datos['tipo_labor']!);
      if (tipo.isEmpty && RegExp(r'^\d+$').hasMatch(labor)) {
        for (final k in ['ala', 'nivel']) {
          final letras = formatearLabor(actividad.datos[k]!);
          if (RegExp(r'^[A-ZÑ]{1,4}$').hasMatch(letras)) {
            tipo = letras;
            break;
          }
        }
      }
      // "TJ" + "493" leídos por separado → "TJ_493".
      if (labor.isNotEmpty &&
          tipo.isNotEmpty &&
          !labor.split('_').contains(tipo)) {
        labor = formatearLabor('${tipo}_$labor');
      }
      actividad.datos['labor'] = labor;
    }
    if (!proceso.propagarLabor) return;
    final conLabor = [
      for (var i = 0; i < actividades.length; i++)
        if (actividades[i].datos['labor']!.isNotEmpty) i,
    ];
    if (conLabor.isEmpty) return;
    final aplicadas = <String, List<int>>{};
    for (var i = 0; i < actividades.length; i++) {
      final datos = actividades[i].datos;
      if (datos['labor']!.isNotEmpty ||
          !llevaDatos(estadosPorCodigo[datos['codigo']], datos['codigo']!)) {
        continue;
      }
      final anteriores = conLabor.where((j) => j < i);
      final origen = anteriores.isNotEmpty ? anteriores.last : conLabor.first;
      datos['labor'] = actividades[origen].datos['labor']!;
      aplicadas.putIfAbsent(datos['labor']!, () => []).add(i + 1);
    }
    aplicadas.forEach((labor, filas) {
      advertencias.add(
        'Labor $labor aplicada también a la(s) actividad(es) ${filas.join(', ')} '
        '(en la hoja está escrita una sola vez); confírmalo.',
      );
    });
  }

  /// Datos sin los que no se puede crear el registro: cabecera, códigos y horas.
  /// El último estado queda abierto (sin hora final), como en el registro manual.
  List<String> validate(Map<String, String> estadosPorCodigo) {
    final errors = <String>[];
    for (final k in [
      'fecha',
      'turno',
      'seccion',
      'operador',
      'jefe_guardia',
      'equipo',
      'n_equipo',
    ]) {
      if (cabecera[k]!.trim().isEmpty) errors.add('Falta completar $k.');
    }
    final date = cabecera['fecha']!;
    final parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != date) {
      errors.add('La fecha debe ser válida, en formato AAAA-MM-DD.');
    }
    final turno = cabecera['turno'];
    if (turno != 'DÍA' && turno != 'NOCHE') errors.add('Confirma el turno.');
    if (actividades.isEmpty) errors.add('Agrega al menos una actividad.');
    int? previousEnd;
    final starts = <int>{};
    for (var i = 0; i < actividades.length; i++) {
      final row = actividades[i];
      final label = 'Actividad ${i + 1}';
      if (!estadosPorCodigo.containsKey(row.datos['codigo'])) {
        errors.add('$label: selecciona un código del catálogo.');
      }
      final ultima = i == actividades.length - 1;
      final start = shiftMinutes(row.datos['hora_inicio']!, turno ?? '');
      final end = ultima
          ? null
          : shiftMinutes(row.datos['hora_final']!, turno ?? '');
      if (start == null || (!ultima && end == null)) {
        errors.add(
          ultima
              ? '$label: completa la hora de inicio en formato 24 h (HH:mm).'
              : '$label: completa inicio y fin en formato 24 h (HH:mm).',
        );
      } else {
        final min = turno == 'NOCHE' ? 1110 : inicioDia;
        final maxStart = turno == 'NOCHE' ? 1765 : 1045;
        final maxEnd = turno == 'NOCHE' ? 1830 : 1110;
        final inicio = row.datos['hora_inicio']!;
        final fin = row.datos['hora_final']!;
        if (start % 5 != 0) {
          errors.add(
            '$label: el inicio $inicio no es múltiplo de 5 minutos '
            '(el formulario solo admite :00, :05, :10…); corrígelo.',
          );
        } else if (start < min || start > maxStart) {
          errors.add(
            '$label: el inicio $inicio está fuera del turno $turno; '
            'revisa la hora o el turno.',
          );
        } else if (end != null && end <= start) {
          errors.add('$label: el fin $fin no es posterior al inicio $inicio.');
        } else if (end != null && end > maxEnd) {
          errors.add(
            '$label: el fin $fin está fuera del turno $turno; '
            'revisa la hora o el turno.',
          );
        }
        if (!starts.add(start) ||
            (previousEnd != null && start < previousEnd)) {
          errors.add(
            '$label: las horas se repiten o se superponen con la anterior.',
          );
        }
        previousEnd = end ?? start;
      }
    }
    return errors;
  }

  /// Datos de perforación y horómetros incompletos. No impiden crear el
  /// registro: se corrigen después con los diálogos habituales del módulo.
  List<String> pendientes(Map<String, String> estadosPorCodigo) {
    final notes = <String>[];
    for (var i = 0; i < actividades.length; i++) {
      final codigo = actividades[i].datos['codigo']!;
      if (!llevaDatos(estadosPorCodigo[codigo], codigo)) continue;
      final faltan = [
        for (final campo in proceso.campos)
          if (campo.pendienteSiFalta &&
              actividades[i].datos[campo.key]!.isEmpty)
            campo.label.toLowerCase(),
      ];
      if (faltan.isNotEmpty) {
        notes.add('Actividad ${i + 1}: completa ${faltan.join(', ')}.');
      }
      final barras = actividades[i].barras;
      for (var j = 0; j < barras.length; j++) {
        final bar = barras[j];
        if (_isEmptyBar(bar)) continue;
        final length = photoNumber(bar['longitud_perforacion']);
        if ((int.tryParse(bar['n_taladro'] ?? '') ?? 0) < 1 ||
            (int.tryParse(bar['n_barras'] ?? '') ?? -1) < 0 ||
            length == null ||
            length <= 0 ||
            (int.tryParse(bar['n_fila'] ?? '') ?? -1) < 0 ||
            (bar['tipo_perforacion'] ?? '').trim().isEmpty) {
          notes.add(
            'Actividad ${i + 1}, taladro ${j + 1}: completa fila, número, barras, tipo y metros.',
          );
        }
      }
    }
    for (final entry in horometros.entries) {
      final a = entry.value['inicio']!;
      final b = entry.value['final']!;
      if (a.isEmpty && b.isEmpty) continue;
      final start = photoNumber(a), end = photoNumber(b);
      if (start == null || end == null || start < 0 || end < start) {
        notes.add('Horómetro ${entry.key}: revisa inicio y final.');
      }
    }
    return notes;
  }

  static bool _isEmptyBar(Map<String, String> bar) =>
      PhotoActivity.barKeys.every((k) => (bar[k] ?? '').trim().isEmpty);

  List<Map<String, dynamic>> registros(
    Map<String, String> estadosPorCodigo, {
    required int firstId,
  }) => [
    for (var i = 0; i < actividades.length; i++)
      _registro(i, estadosPorCodigo, firstId),
  ];

  /// Campos sueltos (Tal horizontal, Scalamin, Scissor) con la clave, el tipo
  /// y el id con que los guarda cada formulario.
  Map<String, dynamic> _campos(Map<String, String> datos, bool lleva) {
    final resultado = <String, dynamic>{};
    for (final campo in proceso.campos) {
      final valor = lleva ? datos[campo.key]! : '';
      resultado[campo.guardarComo ?? campo.key] =
          campo.decimal ? photoNumber(valor) ?? 0.0 : valor;
      if (campo.idComo != null) {
        resultado[campo.idComo!] = idsCatalogo[campo.key]?[valor];
      }
    }
    return resultado;
  }

  /// Igual que el formulario de Scoop al guardar. Las cucharas por material
  /// (mineral, desmonte…) quedan vacías: se usan N° cucharas y Material.
  Map<String, dynamic> _scoop(Map<String, String> datos, bool lleva) {
    String v(String k) => lleva ? datos[k]! : '';
    return {
      'labor_inicio': v('labor_inicio'),
      'ubicacion_destino': v('ubicacion_destino'),
      'ubicacion_destino_id': lleva ? idsDestino[datos['ubicacion_destino']] ?? 0 : 0,
      'n_cucharas': lleva ? int.tryParse(datos['n_cucharas']!) ?? 0 : 0,
      'material': v('material'),
      'mineral': '',
      'desmonte': '',
      'relleno': '',
      'relave': '',
      'numero_volquete': v('numero_volquete'),
    };
  }

  /// Igual que DialogoFormularioEmpernador al guardar: tipo de perforación y las
  /// listas perforacion, perno (una fila por columna SS/SW/PH con cantidad) y
  /// malla (una fila por columna con m²).
  Map<String, dynamic> _empernador(Map<String, String> datos, bool lleva) {
    final codigo = datos['codigo']!;
    bool usa(PhotoCampo c) =>
        lleva && proceso.usaCampo(c, codigo) && datos[c.key]!.isNotEmpty;
    Iterable<PhotoCampo> grupo(PhotoGrupo g) =>
        proceso.campos.where((c) => c.grupo == g && usa(c));
    String catalogo(PhotoCampo c, String k, String porDefecto) =>
        catalogoColumnas[c.key]?[k] ?? porDefecto;
    final perforacion = grupo(PhotoGrupo.perforacion).isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            {
              'n_taladros': int.tryParse(datos['tald_perf']!) ?? 0,
              'longitud_perforacion': photoNumber(datos['long_perf']) ?? 0.0,
            },
          ];
    return {
      'tipo_perforacion': lleva ? datos['tipo_perforacion'] : '',
      'perforacion': perforacion,
      'perno': [
        for (final c in grupo(PhotoGrupo.perno))
          {
            'tipo_pernos': catalogo(c, 'tipo', c.tipo),
            'log_pernos': catalogo(c, 'longitud', '${c.pies?.toInt() ?? ''}'),
            'n_pernos_instalados': int.tryParse(datos[c.key]!) ?? 0,
            'sistematico_puntual': '',
          },
      ],
      'malla': [
        for (final c in grupo(PhotoGrupo.malla))
          {
            'tipo_malla': catalogo(c, 'tipo', c.tipo),
            'mt52_malla': datos[c.key],
          },
      ],
    };
  }

  /// Misma forma que el createEstado del módulo: los datos de perforación solo
  /// en los estados que los llevan.
  Map<String, dynamic> _registro(
    int i,
    Map<String, String> estadosPorCodigo,
    int firstId,
  ) {
    final lleva = llevaDatos(
      estadosPorCodigo[actividades[i].datos['codigo']],
      actividades[i].datos['codigo']!,
    );
    return {
        'id': firstId + i,
        'numero': i + 1,
        'estado': estadosPorCodigo[actividades[i].datos['codigo']],
        'codigo': actividades[i].datos['codigo'],
        'hora_inicio': actividades[i].datos['hora_inicio'],
        // El último estado queda abierto, igual que al registrar a mano.
        'hora_final': i == actividades.length - 1
            ? null
            : actividades[i].datos['hora_final'],
        'operacion': {
          for (final k in [
            'nivel',
            'tipo_labor',
            'labor',
            'ala',
            'observaciones',
          ])
            k: actividades[i].datos[k],
          if (proceso.formato == PhotoFormato.empernador)
            ..._empernador(actividades[i].datos, lleva)
          else if (proceso.formato == PhotoFormato.scoop)
            ..._scoop(actividades[i].datos, lleva)
          else
            ..._campos(actividades[i].datos, lleva),
          // Lo ilegible queda en 0 para corregirlo en el formulario de perforación.
          if (proceso.usaBarras)
            'barras': [
              if (lleva)
                for (final b in actividades[i].barras)
                  if (!_isEmptyBar(b))
                    {
                      'n_fila': int.tryParse(b['n_fila'] ?? '') ?? 0,
                      'n_taladro': int.tryParse(b['n_taladro'] ?? '') ?? 0,
                      'n_barras': int.tryParse(b['n_barras'] ?? '') ?? 0,
                      'longitud_perforacion':
                          photoNumber(b['longitud_perforacion']) ?? 0.0,
                      'tipo_perforacion': b['tipo_perforacion'] ?? '',
                    },
            ],
        },
      };
  }
}

class PhotoActivity {
  /// Campos de todas las hojas; cada proceso usa los suyos (ver PhotoProceso).
  static const keys = [
    'codigo',
    'hora_inicio',
    'hora_final',
    'nivel',
    'tipo_labor',
    'labor',
    'ala',
    'observaciones',
    'tal_prod',
    'tal_rimados',
    'tal_alivio',
    'long_barras',
    'brazo',
    'material',
    'tipo_perforacion',
    'tald_perf',
    'long_perf',
    'ss3',
    'ss7',
    'sw7',
    'ph7',
    'malla_c10',
    'malla_c8',
    'malla_eslabonada',
    'metros_lineales',
    'area_m2',
    'tipo_labor_texto',
    'labor_inicio',
    'ubicacion_destino',
    'n_cucharas',
    'numero_volquete',
    'destino',
    'ducto',
    'cable',
    'tuberia',
  ];

  /// Scoop: cada desplazamiento (origen → destino) con sus cucharas por material.
  static const viajeKeys = [
    'origen',
    'destino',
    'mineral',
    'desmonte',
    'relleno',
    'relave',
    'numero_volquete',
  ];
  static const barKeys = [
    'n_fila',
    'n_taladro',
    'n_barras',
    'longitud_perforacion',
    'tipo_perforacion',
  ];
  final Map<String, String> datos;
  final List<Map<String, String>> barras;
  final List<Map<String, String>> viajes;
  PhotoActivity({
    Map<String, String>? datos,
    List<Map<String, String>>? barras,
    List<Map<String, String>>? viajes,
  }) : datos = {for (final k in keys) k: datos?[k] ?? ''},
       barras = barras ?? [],
       viajes = viajes ?? [];

  factory PhotoActivity.fromJson(Map<String, dynamic> json) {
    final bars = json['barras'] as List? ?? [];
    final trips = json['viajes'] as List? ?? [];
    if (bars.length > 200 || trips.length > 20) {
      throw const FormatException('Demasiadas filas en una actividad.');
    }
    return PhotoActivity(
      datos: {for (final k in keys) k: photoText(json[k])},
      barras: bars
          .map((b) => {for (final k in barKeys) k: photoText((b as Map)[k])})
          .toList(),
      viajes: trips
          .map((v) => {for (final k in viajeKeys) k: photoText((v as Map)[k])})
          .toList(),
    );
  }
}

String photoText(Object? value) => value == null ? '' : value.toString().trim();
double? photoNumber(String? value) {
  final number = double.tryParse((value ?? '').replaceAll(',', '.'));
  return number != null && number.isFinite ? number : null;
}
