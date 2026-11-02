import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Equipo.dart';
import 'package:i_miner/models/checklist_respuesta.dart';
import 'package:i_miner/models/photo_draft.dart';
import 'package:i_miner/models/photo_proceso.dart';
import 'package:i_miner/screens/widgets/custom_dropdown.dart';
import 'package:i_miner/services/api_service.dart';
import 'package:i_miner/services/photo_service.dart';
import 'package:i_miner/services/photo_store.dart';

/// Al volver a la pantalla del módulo con el registro creado: confirma o lista
/// lo que quedó pendiente de revisar con la hoja.
void mostrarResultadoFoto(
  BuildContext context,
  Map<String, dynamic> result,
  Color primaryColor,
) {
  final pendientes = List<String>.from(result['pendientes'] as List? ?? []);
  if (pendientes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registro creado desde la foto. Revísalo con la hoja.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  // Lo dudoso de la lectura se corrige allí, con los diálogos habituales.
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: primaryColor, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Registro creado: revisa con la hoja',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          'Corrige estos datos con «Ver detalle» (ojo) de cada estado o con Horómetro:\n\n'
          '${pendientes.map((p) => '• $p').join('\n')}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Importa la hoja de papel de un módulo de operación (ver [PhotoProceso]).
class ImportarFotoScreen extends StatefulWidget {
  final String dni;
  final PhotoProceso proceso;
  const ImportarFotoScreen({
    super.key,
    required this.dni,
    this.proceso = PhotoProceso.talLargo,
  });
  @override
  State<ImportarFotoScreen> createState() =>
      _ImportarFotoState();
}

class _ImportarFotoState extends State<ImportarFotoScreen> {
  static const _primaryColor = Color(0xFF1B5E6B);
  final _db = DatabaseHelper();
  late final _reader = PhotoService(proceso: widget.proceso);
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  late PhotoDraft _draft = PhotoDraft(proceso: widget.proceso);
  List<Equipo> _equipos = [];
  List<Map<String, String>> _catalogo = [];
  List<String> _tiposPerforacion = [];
  Map<String, int> _idsTiposPerforacion = {};
  List<String> _longitudesBarras = [];
  List<String> _tiposLabor = [];

  /// Scoop: mismas opciones que su formulario (labores de los planes + orígenes
  /// y destinos SCOOPTRAM) y el id de cada destino.
  List<String> _materiales = [];
  List<String> _origenes = [];
  List<String> _destinos = [];
  Map<String, int> _idsDestino = {};

  /// Empernador: catálogos de pernos (tipo_perno, longitud) y mallas.
  List<Map<String, dynamic>> _pernos = [];
  List<String> _mallas = [];
  List<String> _operadores = [];
  List<String> _guardias = [];
  List<String> _jefes = [];
  List<String> _labores = [];
  Uint8List? _photo;
  String _mime = 'image/jpeg';
  bool _loading = true, _allowed = false, _busy = false;
  String? _message;
  String? _catalogWarning;
  List<String> _errors = [];
  int _revision = 0;

  Map<String, String> get _states => {
    for (final e in _catalogo) e['codigo']!: e['estado']!,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _db.getUserByDni(widget.dni);
      if (user?['rol'].toString().trim().toLowerCase() != 'master') {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }
      final equipos = await _db.getEquipos();
      final catalogo = await _db.getEstadosBD(widget.proceso.nombre);
      final operadores =
          (await _db.getAllUsuarios())
              .map(_formatearOperador)
              .where((nombre) => nombre.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final guardias =
          (await _db.getGuardias()).map((g) => g.guardia).toSet().toList()
            ..sort();
      final jefes = (await _db.getJefesGuardiaNombres()).toSet().toList()
        ..sort();
      // Mismas opciones que el buscador de labor del formulario de perforación.
      var labores = <String>[];
      try {
        final planes = [
          for (final p in await _db.getPlanesMensual())
            [p.tipoLabor, p.labor, p.ala],
          for (final p in await _db.getPlanesProduccion())
            [p.tipoLabor, p.labor, p.ala],
          for (final p in await _db.getPlanesMetraje())
            [p.tipoLabor, p.labor, p.ala],
        ];
        labores =
            planes.map(_combinarLabor).where((l) => l.isNotEmpty).toSet().toList()
              ..sort();
      } catch (_) {
        labores = [];
      }
      var tiposPerforacion = <String>[];
      var idsTipos = <String, int>{};
      try {
        final types = await _db.getTiposPerforacionByProceso(
          widget.proceso.procesoTipos ?? widget.proceso.nombre,
        );
        tiposPerforacion =
            types
                .map((type) => type.nombre)
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        idsTipos = {
          for (final type in types)
            if (type.nombre.isNotEmpty && type.id != null) type.nombre: type.id!,
        };
      } catch (error) {
        tiposPerforacion = [];
        _catalogWarning =
            'No se pudo cargar el catálogo de tipos de perforación ($error). '
            'Puedes escribir el tipo manualmente.';
      }
      // Mismas opciones que "Longitud (pies)" del formulario del módulo.
      var longitudesBarras = <String>[];
      if (widget.proceso.campos.any(
        (c) => c.catalogo == PhotoCatalogo.longitudBarras,
      )) {
        try {
          longitudesBarras =
              (await _db.getLongitudBarrasPorProceso(widget.proceso.nombre))
                  .map((e) => e['longitud_pies'].toString())
                  .toSet()
                  .toList()
                ..sort(
                  (a, b) =>
                      (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0),
                );
        } catch (_) {
          longitudesBarras = [];
        }
      }
      // Mismas opciones que "Tipo de labor" del formulario del módulo.
      var tiposLabor = <String>[];
      if (widget.proceso.campos.any(
        (c) => c.catalogo == PhotoCatalogo.tiposLabor,
      )) {
        try {
          tiposLabor =
              (await _db.getTiposLaborByProceso(widget.proceso.nombre))
                  .map((t) => t.nombre)
                  .where((n) => n.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
        } catch (_) {
          tiposLabor = [];
        }
      }
      var materiales = <String>[];
      var origenes = <String>[];
      var destinos = <String>[];
      var idsDestino = <String, int>{};
      if (widget.proceso.formato == PhotoFormato.scoop) {
        try {
          String nombre(Map<String, dynamic> e) => e['nombre']?.toString() ?? '';
          materiales = (await _db.getMateriales(widget.proceso.nombre))
              .map(nombre)
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList();
          final origen = await _db.getOrigenDestino(widget.proceso.nombre, 'ORIGEN');
          final destino = await _db.getOrigenDestino(widget.proceso.nombre, 'DESTINO');
          origenes = {...labores, ...origen.map(nombre)}
              .where((n) => n.isNotEmpty)
              .toList();
          destinos = {...labores, ...destino.map(nombre)}
              .where((n) => n.isNotEmpty)
              .toList();
          idsDestino = {
            for (final d in destino)
              if (d['id'] is int && nombre(d).isNotEmpty) nombre(d): d['id'] as int,
          };
        } catch (_) {
          materiales = [];
          origenes = [];
          destinos = [];
          idsDestino = {};
        }
      }
      var pernos = <Map<String, dynamic>>[];
      var mallas = <String>[];
      if (widget.proceso.formato == PhotoFormato.empernador) {
        try {
          pernos = await _db.getPernos();
          mallas = (await _db.getMallas())
              .map((e) => e['tipo_malla'].toString())
              .toSet()
              .toList();
        } catch (_) {
          pernos = [];
          mallas = [];
        }
      }
      if (!mounted) return;
      setState(() {
        _materiales = materiales;
        _origenes = origenes;
        _destinos = destinos;
        _idsDestino = idsDestino;
        _tiposLabor = tiposLabor;
        _pernos = pernos;
        _mallas = mallas;
        _allowed = true;
        _loading = false;
        _equipos = equipos
            .where((e) => e.proceso == widget.proceso.nombre)
            .toList();
        _tiposPerforacion = tiposPerforacion;
        _idsTiposPerforacion = idsTipos;
        _longitudesBarras = longitudesBarras;
        _operadores = operadores;
        _guardias = guardias;
        _jefes = jefes;
        _labores = labores;
        final seen = <String>{};
        _catalogo = [
          for (final e in catalogo)
            if (seen.add(e['codigo'].toString()))
              {
                'codigo': e['codigo'].toString(),
                'estado': e['estado_principal'].toString(),
                'nombre': e['tipo_estado'].toString(),
              },
        ];
      });
      // Android puede destruir la actividad mientras la cámara está abierta.
      if (Theme.of(context).platform == TargetPlatform.android) {
        final lost = await _picker.retrieveLostData();
        if (lost.files?.isNotEmpty == true && mounted) {
          await _usePhoto(lost.files!.first);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'No se pudieron cargar los permisos o los catálogos. Vuelve a abrir la pantalla.';
        });
      }
    }
  }

  void _changed() {
    setState(() {
      _errors = [];
    });
  }

  /// Lo mínimo para crear el registro. El resto se corrige en la pantalla del módulo.
  List<String> _requiredErrors() {
    final errors = _draft.validate(_states);
    final matches = _equipos.where(
      (e) =>
          e.codigo == _draft.cabecera['n_equipo'] &&
          e.nombre == _draft.cabecera['equipo'] &&
          e.modelo == _draft.cabecera['modelo_equipo'],
    );
    if (matches.isEmpty) errors.add('Selecciona el equipo del catálogo local.');
    for (final (campo, lista, nombre) in [
      ('seccion', _guardias, 'la guardia'),
      ('operador', _operadores, 'el operador'),
      ('jefe_guardia', _jefes, 'el jefe de guardia'),
    ]) {
      if (lista.isNotEmpty && !lista.contains(_draft.cabecera[campo])) {
        errors.add('Selecciona $nombre de la lista.');
      }
    }
    return errors;
  }

  /// Opciones del formulario del módulo para un campo (vacío = texto libre).
  List<String> _opcionesDe(PhotoCampo campo) => campo.opciones.isNotEmpty
      ? campo.opciones
      : switch (campo.catalogo) {
          PhotoCatalogo.tiposPerforacion => _tiposPerforacion,
          PhotoCatalogo.tiposLabor => _tiposLabor,
          PhotoCatalogo.materiales => _materiales,
          PhotoCatalogo.labores => _labores,
          PhotoCatalogo.origenes => _origenes,
          PhotoCatalogo.destinos => _destinos,
          PhotoCatalogo.longitudBarras => _longitudesBarras,
          null => const [],
        };

  /// Empernador: cada columna de la hoja (SS 7', Malla C-10…) se busca en el
  /// catálogo de pernos o mallas. "SS" coincide con un tipo cuyo nombre empieza
  /// por SS o es SPLIT SET; 7' con 7 (pies) o 2.1 (metros).
  void _ajustarColumnasEmpernador(PhotoDraft draft) {
    const nombres = {
      'SS': ['SS', 'SPLIT'],
      'SW': ['SW', 'SWELLEX'],
      'PH': ['PH', 'HELICOIDAL'],
    };
    bool esTipo(String catalogo, String tipo) {
      final c = _clave(catalogo).replaceAll(' ', '');
      return (nombres[tipo] ?? [tipo]).any(
        (n) => c.startsWith(_clave(n).replaceAll(' ', '')),
      );
    }

    for (final campo in widget.proceso.campos) {
      if (campo.grupo != PhotoGrupo.perno && campo.grupo != PhotoGrupo.malla) {
        continue;
      }
      if (draft.actividades.every((a) => a.datos[campo.key]!.isEmpty)) continue;
      if (campo.grupo == PhotoGrupo.malla) {
        final tipo = _mallas.where((m) => esTipo(m, campo.tipo));
        if (tipo.length == 1) {
          draft.catalogoColumnas[campo.key] = {'tipo': tipo.single};
          continue;
        }
      } else {
        final candidatos = _pernos.where(
          (p) => esTipo(p['tipo_perno'].toString(), campo.tipo),
        );
        final pies = campo.pies!;
        final conLongitud = candidatos.where((p) {
          final l = photoNumber(p['longitud'].toString());
          return l != null && ((l - pies).abs() < 0.01 || (l - pies * 0.3048).abs() < 0.1);
        }).toList();
        if (conLongitud.length == 1) {
          draft.catalogoColumnas[campo.key] = {
            'tipo': conLongitud.single['tipo_perno'].toString(),
            'longitud': conLongitud.single['longitud'].toString(),
          };
          continue;
        }
      }
      draft.advertencias.add(
        'La columna ${campo.label} no coincide con un único registro del '
        'catálogo; elige tipo y longitud en el formulario de Empernador.',
      );
    }
  }

  /// Usa la forma exacta de la opción del catálogo ("13" → "13.0", "frente" →
  /// "FRENTE"). Si no figura, queda lo leído y se avisa para elegirlo.
  void _ajustarACatalogos(PhotoDraft draft) {
    if (widget.proceso.formato == PhotoFormato.empernador) {
      _ajustarColumnasEmpernador(draft);
    }
    // "CM5181" coincide con "CM_5181" y "cm 5181".
    String sinEspacios(String s) => _clave(s).replaceAll(' ', '');
    for (final campo in widget.proceso.campos) {
      final opciones = _opcionesDe(campo);
      for (final (i, actividad) in draft.actividades.indexed) {
        final valor = actividad.datos[campo.key]!;
        if (valor.isEmpty) continue;
        final numero = photoNumber(valor);
        final opcion = opciones.where(
          (o) => campo.numero && numero != null
              ? photoNumber(o) == numero
              : sinEspacios(o) == sinEspacios(valor),
        );
        if (opcion.isNotEmpty) {
          actividad.datos[campo.key] = opcion.first;
        } else if (campo.autocompletar) {
          // Texto libre, como en el formulario: con el formato de las labores.
          actividad.datos[campo.key] = PhotoDraft.formatearLabor(valor);
        } else if (opciones.isEmpty) {
          continue;
        } else {
          if (campo.soloCatalogo) actividad.datos[campo.key] = '';
          draft.advertencias.add(
            'Actividad ${i + 1}: ${campo.label} "$valor" no figura en las '
            'opciones del formulario; elígelo al revisar.',
          );
        }
      }
    }
    draft.idsDestino.addAll(_idsDestino);
    for (final campo in widget.proceso.campos) {
      if (campo.idComo != null &&
          campo.catalogo == PhotoCatalogo.tiposPerforacion) {
        draft.idsCatalogo[campo.key] = _idsTiposPerforacion;
      }
    }
  }

  /// Igual que _generarOpcionesUbicacion: "TIPO_LABOR_ALA".
  static String _combinarLabor(List<String?> partes) {
    final tipo = partes[0], labor = partes[1], ala = partes[2];
    var combinado = '';
    if (tipo?.isNotEmpty ?? false) combinado += tipo!;
    if (labor?.isNotEmpty ?? false) combinado += '_$labor';
    if (ala?.isNotEmpty ?? false) combinado += '_$ala';
    return combinado;
  }

  /// Sin tildes, mayúsculas, sin la palabra GUARDIA ni signos: "Guardia B" → "B".
  static String _clave(String texto) => _palabras(
    texto,
    minimo: 1,
  ).where((p) => p != 'GUARDIA').join(' ');

  /// Igual que en la tarjeta de operación. Ej: "SALVATIERRA ANGOMA, HEVER"
  static String _formatearOperador(Map<String, dynamic> usuario) {
    final apellidos = (usuario['apellidos'] ?? '').toString().trim();
    final nombres = (usuario['nombres'] ?? '').toString().trim();
    if (apellidos.isEmpty && nombres.isEmpty) return '';
    if (apellidos.isEmpty) return nombres.toUpperCase();
    if (nombres.isEmpty) return apellidos.toUpperCase();
    return '${apellidos.toUpperCase()}, ${nombres.toUpperCase()}';
  }

  static List<String> _palabras(String texto, {int minimo = 2}) => texto
      .toUpperCase()
      .replaceAll(RegExp('[ÁÀÄ]'), 'A')
      .replaceAll(RegExp('[ÉÈË]'), 'E')
      .replaceAll(RegExp('[ÍÌÏ]'), 'I')
      .replaceAll(RegExp('[ÓÒÖ]'), 'O')
      .replaceAll(RegExp('[ÚÙÜ]'), 'U')
      .split(RegExp(r'[^A-ZÑ0-9]+'))
      .where((p) => p.length >= minimo)
      .toList();

  /// Busca en la lista lo escrito en la hoja. Primero una coincidencia exacta
  /// (sin tildes ni mayúsculas); si no, un único nombre con al menos dos
  /// palabras coincidentes (o todas, si leyó una).
  static String? _buscarEnLista(String leido, List<String> lista) {
    final clave = _clave(leido);
    if (clave.isEmpty) return null;
    final exactos = lista.where((o) => _clave(o) == clave).toList();
    if (exactos.length == 1) return exactos.single;
    final palabras = _palabras(leido);
    if (palabras.isEmpty) return null;
    final minimo = palabras.length == 1 ? 1 : 2;
    var mejor = 0;
    final candidatos = <String>[];
    for (final nombre in lista) {
      final delOperador = _palabras(nombre).toSet();
      final coinciden = palabras.where(delOperador.contains).length;
      if (coinciden < minimo || coinciden < mejor) continue;
      if (coinciden > mejor) {
        mejor = coinciden;
        candidatos.clear();
      }
      candidatos.add(nombre);
    }
    return candidatos.length == 1 ? candidatos.single : null;
  }

  Widget _operadorField() {
    final valor = _draft.cabecera['operador']!;
    final enLista = _operadores.contains(valor);
    return SizedBox(
      width: 320,
      child: InkWell(
        onTap: _operadores.isEmpty ? null : _mostrarSelectorOperador,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Operador (*)',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            suffixIcon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
            helperText: enLista
                ? null
                : valor.isEmpty
                ? 'Toca para elegir de la lista'
                : 'Leído: $valor · elige de la lista',
            helperStyle: TextStyle(color: Colors.orange.shade800),
          ),
          child: Text(
            enLista ? valor : 'Seleccionar operador',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: enLista ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  /// Mismo desplegable que la tarjeta de operación. Debajo, lo leído en la hoja
  /// cuando no coincide con la lista, o la referencia de lo elegido.
  Widget _listaField({
    required String label,
    required String valor,
    required List<String> opciones,
    required IconData icon,
    required ValueChanged<String> onChanged,
    String? leido,
    String? referencia,
    double width = 210,
  }) {
    final enLista = opciones.contains(valor);
    final nota = enLista
        ? referencia
        : (leido ?? valor).trim().isEmpty
        ? 'Pendiente de elegir'
        : 'Leído: ${(leido ?? valor).trim()} · elige de la lista';
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomMaterialDropdown(
            label: label,
            value: enLista ? valor : null,
            items: opciones,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            icon: icon,
            hint: opciones.isEmpty ? 'Sin opciones' : label,
            primaryColor: _primaryColor,
          ),
          if (nota != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                nota,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: enLista ? Colors.grey.shade600 : Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _equipoField() {
    final h = _draft.cabecera;
    final elegido = _equipos.where(
      (e) =>
          e.codigo == h['n_equipo'] &&
          e.nombre == h['equipo'] &&
          e.modelo == h['modelo_equipo'],
    );
    final leido = '${h['equipo']} ${h['n_equipo']}'.trim();
    return _listaField(
      label: 'Código de equipo (*)',
      // Solo cuenta como elegido si nombre y modelo coinciden con el catálogo.
      valor: elegido.isEmpty ? '' : h['n_equipo']!,
      opciones: _equipos.map((e) => e.codigo).toList(),
      icon: Icons.qr_code,
      leido: leido,
      referencia: elegido.isEmpty
          ? null
          : '${elegido.first.nombre} · ${elegido.first.modelo}',
      onChanged: (codigo) {
        final e = _equipos.firstWhere((e) => e.codigo == codigo);
        h.addAll({
          'equipo': e.nombre,
          'n_equipo': e.codigo,
          'modelo_equipo': e.modelo,
        });
        _changed();
      },
    );
  }

  void _mostrarSelectorOperador() {
    var busqueda = '';
    final searchCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtrados = busqueda.isEmpty
              ? _operadores
              : _operadores
                    .where(
                      (o) => o.toLowerCase().contains(busqueda.toLowerCase()),
                    )
                    .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seleccionar operador',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          if (_draft.cabecera['operador']!.isNotEmpty &&
                              !_operadores.contains(_draft.cabecera['operador']))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'En la hoja: ${_draft.cabecera['operador']}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            onChanged: (v) => setModalState(() => busqueda = v),
                            decoration: InputDecoration(
                              hintText: 'Buscar operador...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: _primaryColor,
                              ),
                              suffixIcon: busqueda.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        searchCtrl.clear();
                                        setModalState(() => busqueda = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron operadores',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtrados.length,
                              itemBuilder: (ctx, i) {
                                final nombre = filtrados[i];
                                final seleccionado =
                                    nombre == _draft.cabecera['operador'];
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: seleccionado
                                        ? _primaryColor
                                        : Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    nombre,
                                    style: TextStyle(
                                      fontWeight: seleccionado
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: seleccionado
                                          ? _primaryColor
                                          : Colors.black87,
                                    ),
                                  ),
                                  trailing: seleccionado
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: _primaryColor,
                                        )
                                      : null,
                                  onTap: () {
                                    _draft.cabecera['operador'] = nombre;
                                    _changed();
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(searchCtrl.dispose);
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || !_allowed) return;
    if (_photo != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cambiar foto'),
          content: const Text('Se descartarán los datos de esta vista previa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Conservar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cambiar foto'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2600,
        maxHeight: 3400,
      );
      if (file != null && mounted) await _usePhoto(file);
    } on PlatformException {
      if (mounted) {
        setState(() {
          _message =
              'No se pudo abrir la cámara o galería. Revisa los permisos de la aplicación.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'No se pudo abrir la foto seleccionada.';
        });
      }
    }
  }

  Future<void> _usePhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    // Verifica el contenido, sin confiar en la extensión de la galería.
    final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final png =
        bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e;
    if ((!jpeg && !png) || bytes.length > 8 * 1024 * 1024) {
      setState(() {
        _message = 'Selecciona una foto JPG o PNG de hasta 8 MB.';
      });
      return;
    }
    setState(() {
      _photo = bytes;
      _mime = png ? 'image/png' : 'image/jpeg';
      _draft = PhotoDraft(proceso: widget.proceso);
      _revision++;
      _errors = [];
      _message =
          'Foto lista. Pulsa «Leer con Gemini» para generar la vista previa. '
          'La foto se enviará al servicio de Google para su lectura.';
    });
  }

  Future<void> _read() async {
    if (_photo == null || _busy || !_allowed) return;
    if (_draft.actividades.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Volver a leer la foto'),
          content: const Text(
            'Una lectura correcta reemplazará las actividades editadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Volver a leer'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _message = 'Leyendo la foto…';
    });
    try {
      final token = await ApiService().getToken() ?? '';
      final draft = await _reader.read(
        bytes: _photo!,
        mimeType: _mime,
        token: token,
        catalogo: _catalogo,
      );
      if (!mounted) return;
      // El código resuelve nombre y modelo con el catálogo local. "SIMBA 02",
      // "2" y "02" se reconocen como 02 si solo un equipo coincide.
      String codigoClave(String c) {
        final digitos = RegExp(r'\d+').allMatches(c).map((m) => m.group(0)!);
        return digitos.isEmpty
            ? _clave(c)
            : int.parse(digitos.last).toString();
      }

      final leido = draft.cabecera['n_equipo']!;
      var equipment = _equipos.where((e) => e.codigo == leido).toList();
      if (equipment.isEmpty && leido.isNotEmpty) {
        equipment = _equipos
            .where((e) => codigoClave(e.codigo) == codigoClave(leido))
            .toList();
      }
      if (equipment.length == 1) {
        draft.cabecera['n_equipo'] = equipment.single.codigo;
        draft.cabecera['equipo'] = equipment.single.nombre;
        draft.cabecera['modelo_equipo'] = equipment.single.modelo;
      }
      // Si no hay coincidencia única, se conserva lo leído para elegirlo a mano.
      for (final (campo, lista) in [
        ('seccion', _guardias),
        ('operador', _operadores),
        ('jefe_guardia', _jefes),
      ]) {
        final encontrado = _buscarEnLista(draft.cabecera[campo]!, lista);
        if (encontrado != null) draft.cabecera[campo] = encontrado;
      }
      // Como el formulario de perforación, solo interesa la labor. Queda tal
      // como está en la hoja (TJ_493); los planes solo se usan al editarla.
      draft.completarLabores(_states);
      for (final actividad in draft.actividades) {
        for (final k in ['tipo_labor', 'ala', 'nivel']) {
          actividad.datos[k] = '';
        }
      }
      draft.reubicarDatos(_states);
      _ajustarACatalogos(draft);
      if (kDebugMode) {
        // TEMPORAL: labor después de que la app la procesa.
        for (final (i, a) in draft.actividades.indexed) {
          debugPrint(
            '[FOTO] App actividad ${i + 1}: codigo=${a.datos['codigo']} '
            'labor=${a.datos['labor']}',
          );
        }
      }
      _draft = draft;
      // Nunca se guarda solo: el master revisa y confirma con «Crear registro».
      final errors = _requiredErrors();
      setState(() {
        _revision++;
        _errors = errors;
        _message = errors.isEmpty
            ? 'Lectura lista. Compara los datos con la foto, corrige lo necesario '
                  'y pulsa «Crear registro».'
            : 'Lectura lista. Completa lo marcado, revisa el resto con la foto '
                  'y pulsa «Crear registro».';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e is PhotoImportException
              ? e.message
              : 'No se pudo leer la foto. Intenta nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_allowed || _photo == null) return;
    final errors = _requiredErrors();
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
      });
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = 'Guardando el registro revisado…';
    });
    try {
      final items = await _db.getCheckListByProceso(
        widget.proceso.nombre,
        codigoEquipo: _draft.cabecera['n_equipo'],
      );
      final id = await PhotoStore.save(
        await _db.database,
        dni: widget.dni,
        draft: _draft,
        estadosPorCodigo: _states,
        checklist: items
            .map((i) => ChecklistRespuesta.desdeCatalogo(i).toMap())
            .toList(),
        imageHash: sha256.convert(_photo!).toString(),
      );
      if (mounted) {
        Navigator.pop(context, {
          'id': id,
          'fecha': _draft.cabecera['fecha'],
          'turno': _draft.cabecera['turno'],
          'pendientes': [..._draft.advertencias, ..._draft.pendientes(_states)],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e is StateError
              ? e.message.toString()
              : 'No se guardó el registro. Revisa los datos e intenta nuevamente.';
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reader.close();
    _scroll.dispose();
    super.dispose();
  }

  Widget _field(
    Map<String, String> values,
    String key,
    String label, {
    double width = 210,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      key: ValueKey('$_revision-${identityHashCode(values)}-$key'),
      initialValue: values[key],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        helperText: (values[key] ?? '').isEmpty
            ? 'Pendiente de completar'
            : null,
      ),
      onChanged: (v) {
        values[key] = v.trim();
        _changed();
      },
    ),
  );

  void _zoom() => showDialog<void>(
    context: context,
    builder: (c) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('Foto del reporte')),
        body: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: Center(child: Image.memory(_photo!)),
        ),
      ),
    ),
  );

  Future<void> _editActivity(int index) async {
    final source = _draft.actividades[index];
    final edited = await showDialog<PhotoActivity>(
      context: context,
      builder: (_) => _PhotoActivityEditor(
        activity: PhotoActivity(
          datos: Map.of(source.datos),
          barras: source.barras.map(Map<String, String>.of).toList(),
        ),
        catalogo: _catalogo,
        estados: _states,
        tiposPerforacion: _tiposPerforacion,
        labores: _labores,
        proceso: widget.proceso,
        opcionesCampos: {
          for (final c in widget.proceso.campos) c.key: _opcionesDe(c),
        },
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _draft.actividades[index] = edited;
      _errors = [];
    });
  }

  Future<void> _addActivity() async {
    final activity = await showDialog<PhotoActivity>(
      context: context,
      builder: (_) => _PhotoActivityEditor(
        activity: PhotoActivity(),
        catalogo: _catalogo,
        estados: _states,
        tiposPerforacion: _tiposPerforacion,
        labores: _labores,
        proceso: widget.proceso,
        opcionesCampos: {
          for (final c in widget.proceso.campos) c.key: _opcionesDe(c),
        },
      ),
    );
    if (activity == null || !mounted) return;
    setState(() {
      _draft.actividades.add(activity);
      _errors = [];
    });
  }

  String _formatTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return value.isEmpty ? '--:--' : value;
    final hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  Color _stateColor(String state) => switch (state) {
    'OPERATIVO' => const Color(0xFF4CAF50),
    'DEMORA' => const Color(0xFFFF9800),
    'MANTENIMIENTO' => const Color(0xFF2196F3),
    'RESERVA' => const Color(0xFF9C27B0),
    'FUERA DE PLAN' => const Color(0xFFF44336),
    _ => Colors.grey,
  };

  Widget _activityTable() {
    if (_draft.actividades.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'No hay actividades. Usa “Agregar actividad” para completar el registro.',
          style: TextStyle(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(Colors.grey.shade50),
          columns: const [
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Hora Inicio')),
            DataColumn(label: Text('Hora Fin')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: [
            for (var index = 0; index < _draft.actividades.length; index++)
              _activityDataRow(index),
          ],
        ),
      ),
    );
  }

  DataRow _activityDataRow(int index) {
    final activity = _draft.actividades[index];
    final state = _states[activity.datos['codigo']] ?? 'REVISAR';
    final color = _stateColor(state);
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          Container(
            constraints: const BoxConstraints(minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              state,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            activity.datos['codigo']!.isEmpty ? '—' : activity.datos['codigo']!,
          ),
        ),
        DataCell(Text(_formatTime(activity.datos['hora_inicio']!))),
        DataCell(
          index == _draft.actividades.length - 1
              ? Text(
                  'En curso',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              : Text(_formatTime(activity.datos['hora_final']!)),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar actividad',
                onPressed: () => _editActivity(index),
                icon: const Icon(Icons.edit_outlined),
                color: Colors.orange.shade800,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Eliminar actividad',
                onPressed: () => setState(() {
                  _draft.actividades.removeAt(index);
                }),
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade700,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 2,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.horizontal_rule, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.proceso.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_allowed
            ? Center(
                child: Text(
                  _message ?? 'Esta función está disponible solo para master.',
                ),
              )
            : AbsorbPointer(
                absorbing: _busy,
                child: Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'Importar registro desde foto',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toma la foto y pulsa «Leer con Gemini». Revisa y corrige los datos '
                                'leídos; el registro solo se crea cuando pulsas «Crear registro».',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _pick(ImageSource.camera),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                      side: const BorderSide(
                                        color: _primaryColor,
                                      ),
                                    ),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('Tomar foto'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _pick(ImageSource.gallery),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primaryColor,
                                      side: const BorderSide(
                                        color: _primaryColor,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    label: const Text('Elegir foto'),
                                  ),
                                  if (_photo != null)
                                    FilledButton.icon(
                                      onPressed: _read,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(
                                        Icons.document_scanner_outlined,
                                      ),
                                      label: const Text('Leer con Gemini'),
                                    ),
                                ],
                              ),
                              if (_message != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              if (_errors.isNotEmpty)
                                Card(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(_errors.join('\n')),
                                  ),
                                ),
                              if (_photo != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.photo_outlined,
                                            color: _primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'FOTO DEL REPORTE',
                                            style: TextStyle(
                                              color: _primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _zoom,
                                        child: SizedBox(
                                          height: 240,
                                          width: double.infinity,
                                          child: Image.memory(
                                            _photo!,
                                            fit: BoxFit.contain,
                                            cacheWidth: 900,
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _zoom,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _primaryColor,
                                          ),
                                          icon: const Icon(Icons.zoom_in),
                                          label: const Text(
                                            'Ampliar foto para comparar',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Form(
                                  key: ValueKey(_revision),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_catalogWarning != null)
                                        Card(
                                          color: Colors.amber.shade100,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(_catalogWarning!),
                                          ),
                                        ),
                                      if (_draft.advertencias.isNotEmpty)
                                        Card(
                                          color: Colors.amber.shade100,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              'Revisa estas observaciones de la lectura:\n${_draft.advertencias.join('\n')}',
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.description_outlined,
                                                  color: _primaryColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'DATOS GENERALES',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: _primaryColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 20),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 16,
                                              children: [
                                                _field(
                                                  _draft.cabecera,
                                                  'fecha',
                                                  'Fecha AAAA-MM-DD (*)',
                                                ),
                                                SizedBox(
                                                  width: 210,
                                                  child: DropdownButtonFormField<String>(
                                                    initialValue:
                                                        [
                                                          'DÍA',
                                                          'NOCHE',
                                                        ].contains(
                                                          _draft
                                                              .cabecera['turno'],
                                                        )
                                                        ? _draft
                                                              .cabecera['turno']
                                                        : null,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Turno (*)',
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    items: [
                                                      for (final t in [
                                                        'DÍA',
                                                        'NOCHE',
                                                      ])
                                                        DropdownMenuItem(
                                                          value: t,
                                                          child: Text(t),
                                                        ),
                                                    ],
                                                    onChanged: (v) {
                                                      _draft.cabecera['turno'] =
                                                          v ?? '';
                                                      // 01:20 pasa a 13:20 en DÍA.
                                                      _draft.normalizarHoras();
                                                      _changed();
                                                    },
                                                  ),
                                                ),
                                                _listaField(
                                                  label: 'Guardia (*)',
                                                  valor: _draft
                                                      .cabecera['seccion']!,
                                                  opciones: _guardias,
                                                  icon: Icons.map,
                                                  onChanged: (v) {
                                                    _draft.cabecera['seccion'] =
                                                        v;
                                                    _changed();
                                                  },
                                                ),
                                                _operadorField(),
                                                _field(
                                                  _draft.cabecera,
                                                  'ayudante',
                                                  'Ayudante (referencia de la hoja)',
                                                ),
                                                _listaField(
                                                  label: 'Jefe Guardia (*)',
                                                  valor: _draft
                                                      .cabecera['jefe_guardia']!,
                                                  opciones: _jefes,
                                                  icon: Icons.person,
                                                  width: 260,
                                                  onChanged: (v) {
                                                    _draft.cabecera['jefe_guardia'] =
                                                        v;
                                                    _changed();
                                                  },
                                                ),
                                                _equipoField(),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.view_list,
                                            color: _primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ACTIVIDADES DEL REGISTRO',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: _primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Usa horas de 24 h. Ejemplo: 23:55 → 00:10 en turno NOCHE. '
                                        'Agrupa las filas que continúan la misma actividad.',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _activityTable(),
                                      OutlinedButton.icon(
                                        onPressed: _addActivity,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _primaryColor,
                                          side: const BorderSide(
                                            color: _primaryColor,
                                          ),
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Agregar actividad'),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.speed,
                                            color: _primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'HORÓMETROS',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: _primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Si no figuran en la hoja, deja ambos valores vacíos.',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      for (final entry
                                          in _draft.horometros.entries)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              _field(
                                                entry.value,
                                                'inicio',
                                                '${entry.key} · inicial',
                                              ),
                                              _field(
                                                entry.value,
                                                'final',
                                                '${entry.key} · final',
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Al pulsar «Crear registro» se creará la operación y volverás a '
                                        'la pantalla del módulo para continuarla con el flujo habitual. Cancelar no guarda datos.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed:
                                  _photo != null &&
                                      _draft.actividades.isNotEmpty
                                  ? _save
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Crear registro'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PhotoActivityEditor extends StatefulWidget {
  final PhotoActivity activity;
  final List<Map<String, String>> catalogo;
  final Map<String, String> estados;
  final List<String> tiposPerforacion;
  final List<String> labores;
  final PhotoProceso proceso;

  /// Opciones de cada campo del proceso; vacío = texto libre.
  final Map<String, List<String>> opcionesCampos;

  const _PhotoActivityEditor({
    required this.activity,
    required this.catalogo,
    required this.estados,
    required this.tiposPerforacion,
    required this.labores,
    required this.proceso,
    required this.opcionesCampos,
  });

  @override
  State<_PhotoActivityEditor> createState() => _PhotoActivityEditorState();
}

class _PhotoActivityEditorState extends State<_PhotoActivityEditor> {
  static const _primaryColor = Color(0xFF1B5E6B);
  late final PhotoActivity _activity;

  bool get _llevaDatos => widget.proceso.llevaDatos(
    widget.estados[_activity.datos['codigo']],
    _activity.datos['codigo']!,
  );

  bool get _llevaBarras => widget.proceso.usaBarras && _llevaDatos;

  /// Origen y destino del Scoop: buscador con texto libre, como su formulario.
  Widget _buscador(PhotoCampo campo, List<String> opciones) => SizedBox(
    width: 300,
    child: Autocomplete<String>(
      initialValue: TextEditingValue(text: _activity.datos[campo.key]!),
      optionsBuilder: (value) {
        final texto = value.text.trim().toLowerCase();
        return texto.isEmpty
            ? opciones
            : opciones.where((o) => o.toLowerCase().contains(texto));
      },
      onSelected: (v) => setState(() => _activity.datos[campo.key] = v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (texto) => _activity.datos[campo.key] = texto.trim(),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: campo.label,
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: _primaryColor,
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
    ),
  );

  /// Campos de perforación del módulo (Tal horizontal: taladros, longitud,
  /// tipo y material), con las mismas opciones que su formulario.
  Widget _camposProceso() => Wrap(
    spacing: 10,
    runSpacing: 12,
    children: [
      for (final campo in widget.proceso.campos.where(
        (c) => widget.proceso.usaCampo(c, _activity.datos['codigo']!),
      ))
        if (campo.autocompletar)
          _buscador(campo, widget.opcionesCampos[campo.key] ?? const [])
        else if ((widget.opcionesCampos[campo.key] ?? const []).isEmpty)
          _field(
            values: _activity.datos,
            keyName: campo.key,
            label: campo.label,
            icon: campo.numero ? Icons.calculate : Icons.edit_note,
            width: 170,
            keyboardType: campo.numero
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
          )
        else
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              initialValue: _activity.datos[campo.key]!.isEmpty
                  ? null
                  : _activity.datos[campo.key],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: campo.label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final opcion in {
                  if (_activity.datos[campo.key]!.isNotEmpty)
                    _activity.datos[campo.key]!,
                  ...widget.opcionesCampos[campo.key]!,
                })
                  DropdownMenuItem(
                    value: opcion,
                    child: Text(opcion, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) =>
                  setState(() => _activity.datos[campo.key] = v ?? ''),
            ),
          ),
    ],
  );

  /// Como el formulario de perforación: busca en las labores de los planes y
  /// acepta texto libre si la labor no figura.
  Widget _laborField() => Autocomplete<String>(
    initialValue: TextEditingValue(text: _activity.datos['labor']!),
    optionsBuilder: (value) {
      final texto = value.text.trim().toLowerCase();
      return texto.isEmpty
          ? widget.labores
          : widget.labores.where((o) => o.toLowerCase().contains(texto));
    },
    onSelected: (labor) => setState(() => _activity.datos['labor'] = labor),
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (texto) =>
              setState(() => _activity.datos['labor'] = texto.trim()),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Buscar o escribir nueva ubicación...',
            hintStyle: const TextStyle(fontSize: 11),
            prefixIcon: const Icon(Icons.search, size: 16, color: _primaryColor),
            helperText:
                _activity.datos['labor']!.isEmpty ||
                    widget.labores.contains(_activity.datos['labor'])
                ? null
                : 'No figura en los planes; se guardará como texto libre.',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final opcion in options)
                ListTile(
                  dense: true,
                  title: Text(
                    opcion,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelected(opcion),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  Widget _sectionTitle(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 15, color: _primaryColor),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: _primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    ),
  );

  Widget _field({
    required Map<String, String> values,
    required String keyName,
    required String label,
    required IconData icon,
    double width = 180,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      initialValue: values[keyName],
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (value) => values[keyName] = value.trim(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: _primaryColor),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
    ),
  );

  Widget _barField(
    Map<String, String> bar,
    String keyName,
    String label,
    IconData icon, {
    required double width,
  }) => _field(
    values: bar,
    keyName: keyName,
    label: label,
    icon: icon,
    width: width,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );

  Widget _barTypeField(int index) {
    final bar = _activity.barras[index];
    final value = bar['tipo_perforacion']!;
    if (widget.tiposPerforacion.isEmpty) {
      return _field(
        values: bar,
        keyName: 'tipo_perforacion',
        label: 'Tipo Perforación',
        icon: Icons.settings_input_component,
        width: 205,
      );
    }

    final options = {if (value.isNotEmpty) value, ...widget.tiposPerforacion};
    return SizedBox(
      width: 205,
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tipo Perforación',
          prefixIcon: Icon(Icons.settings_input_component, size: 16),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final type in options)
            DropdownMenuItem(
              value: type,
              child: Text(type, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (next) => setState(() {
          bar['tipo_perforacion'] = next ?? '';
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: screenWidth < 600 ? screenWidth * 0.96 : 950,
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                color: _primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Formulario de Perforación · Actividad',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        'EDITABLE',
                        style: TextStyle(
                          color: Colors.green.shade100,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle(Icons.schedule, 'Actividad'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                widget.estados.containsKey(
                                  _activity.datos['codigo'],
                                )
                                ? _activity.datos['codigo']
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Estado / código (*)',
                              helperText:
                                  widget.estados.containsKey(
                                    _activity.datos['codigo'],
                                  )
                                  ? null
                                  : 'Confirma el código leído: ${_activity.datos['codigo']}',
                              prefixIcon: const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final item in widget.catalogo)
                                DropdownMenuItem(
                                  value: item['codigo'],
                                  child: Text(
                                    '${item['codigo']} · ${item['nombre']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _activity.datos['codigo'] = value ?? '',
                            ),
                          ),
                        ),
                        _field(
                          values: _activity.datos,
                          keyName: 'hora_inicio',
                          label: 'Hora Inicio (24 h)',
                          icon: Icons.access_time,
                          width: 165,
                          keyboardType: TextInputType.datetime,
                        ),
                        _field(
                          values: _activity.datos,
                          keyName: 'hora_final',
                          label: 'Hora Fin (24 h)',
                          icon: Icons.access_time,
                          width: 165,
                          keyboardType: TextInputType.datetime,
                        ),
                      ],
                    ),
                    // Scoop no usa labor: su viaje tiene labor inicio y destino.
                    if (widget.proceso.formato != PhotoFormato.scoop) ...[
                      const SizedBox(height: 20),
                      _sectionTitle(Icons.location_on_outlined, 'Labor'),
                      _laborField(),
                    ],
                    // Igual que el formulario de perforación: sin barras para
                    // estados no operativos ni códigos 107–110.
                    if (_llevaBarras) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.view_list, 'Barras Fila'),
                    if (_activity.barras.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'No hay filas agregadas',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    for (
                      var index = 0;
                      index < _activity.barras.length;
                      index++
                    )
                      Container(
                        key: ObjectKey(_activity.barras[index]),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _barField(
                              _activity.barras[index],
                              'n_fila',
                              'N° Fila',
                              Icons.format_list_numbered,
                              width: 95,
                            ),
                            _barField(
                              _activity.barras[index],
                              'n_taladro',
                              'N° Taladro',
                              Icons.gps_fixed,
                              width: 135,
                            ),
                            _barField(
                              _activity.barras[index],
                              'n_barras',
                              'N° Barras',
                              Icons.square_foot,
                              width: 130,
                            ),
                            _barField(
                              _activity.barras[index],
                              'longitud_perforacion',
                              'Longitud (m)',
                              Icons.straighten,
                              width: 155,
                            ),
                            _barTypeField(index),
                            IconButton(
                              tooltip: 'Eliminar fila',
                              onPressed: () => setState(
                                () => _activity.barras.removeAt(index),
                              ),
                              color: Colors.red.shade600,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Agregar fila',
                        onPressed: () => setState(
                          () => _activity.barras.add({
                            for (final key in PhotoActivity.barKeys) key: '',
                          }),
                        ),
                        color: _primaryColor,
                        icon: const Icon(Icons.add_circle),
                      ),
                    ),
                    ],
                    if (_llevaDatos && widget.proceso.campos.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      widget.proceso.formato == PhotoFormato.scoop
                          ? _sectionTitle(Icons.local_shipping_outlined, 'Viaje')
                          : _sectionTitle(Icons.golf_course, 'Perforación'),
                      _camposProceso(),
                    ],
                    const SizedBox(height: 14),
                    _sectionTitle(Icons.note_alt_outlined, 'Observaciones'),
                    TextFormField(
                      initialValue: _activity.datos['observaciones'],
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (value) =>
                          _activity.datos['observaciones'] = value.trim(),
                      decoration: const InputDecoration(
                        hintText: 'Ingrese observaciones...',
                        prefixIcon: Icon(Icons.comment_outlined),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _activity),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
