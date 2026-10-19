import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/PlanMetraje.dart';

// ============================================================
// MODELOS DE FILA
// ============================================================
class PernoFila {
  String tipoPerno;
  String longitud;
  int nPernos;
  String sistematico;

  PernoFila({
    required this.tipoPerno,
    required this.longitud,
    required this.nPernos,
    required this.sistematico,
  });

  Map<String, dynamic> toMap() => {
    'tipo_pernos': tipoPerno,
    'log_pernos': longitud,
    'n_pernos_instalados': nPernos,
    'sistematico_puntual': sistematico,
  };
}

class MallaFila {
  String tipoMalla;
  String mt52;

  MallaFila({
    required this.tipoMalla,
    required this.mt52,
  });

  Map<String, dynamic> toMap() => {
    'tipo_malla': tipoMalla,
    'mt52_malla': mt52,
  };
}

// 🔥 MODELO Perforación (sin tipoPerforacion — ahora va a nivel raíz)
class PerforacionFila {
  int nTaladros;
  double longitudPerforacion;

  PerforacionFila({
    required this.nTaladros,
    required this.longitudPerforacion,
  });

  Map<String, dynamic> toMap() => {
    'n_taladros': nTaladros,
    'longitud_perforacion': longitudPerforacion,
  };
}

class DialogoFormularioEmpernador extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;
  final String codigo;

  const DialogoFormularioEmpernador({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
    required this.codigo,
  }) : super(key: key);

  @override
  State<DialogoFormularioEmpernador> createState() =>
      _DialogoFormularioEmpernadorState();
}

class _DialogoFormularioEmpernadorState
    extends State<DialogoFormularioEmpernador> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;
  List<String> opcionesTipoPerforacion = [];

  // 🔥 Tipo de perforación a nivel raíz
  String? tipoPerforacionSeleccionado;

  // Ubicación combinada
  final TextEditingController ubicacionController = TextEditingController();
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;
  String? laborSeleccionado;

  List<String> opcionesUbicacionCombinadas = [];
  List<String> opcionesUbicacionFiltradas = [];

  final TextEditingController observacionesController = TextEditingController();

  // Catálogos de pernos
  List<Map<String, dynamic>> pernosCompletos = [];
  List<String> tiposPerno = [];

  // Catálogos de mallas
  List<String> opcionesMalla = [];

  List<String> opcionesSistematicoPuntual = ['Sistemático', 'Puntual'];

  // Listas dinámicas
  List<PernoFila> pernosFilas = [];
  List<MallaFila> mallasFilas = [];
  List<PerforacionFila> perforacionesFilas = [];

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
    _cargarTiposPerforacion();
  }

  bool get _debeMostrarDatosPerforacion {
    final codigosOmitir = ['103', '104', '105', '106'];
    final codigoStr = widget.codigo.toString();
    return !codigosOmitir.contains(codigoStr);
  }

  // 🔥 Códigos donde la labor es OBLIGATORIA
  bool get _laborEsObligatoria {
    final codigosObligatorio = ['101', '102'];
    return codigosObligatorio.contains(widget.codigo.toString());
  }

  // 🔥 Validación del botón Guardar
  bool get _puedeGuardar {
    if (!_laborEsObligatoria) return true;

    final laborTexto = ubicacionController.text.trim();
    return (laborSeleccionado != null &&
            laborSeleccionado!.trim().isNotEmpty) ||
        laborTexto.isNotEmpty;
  }

  // 🔥 Para código 101, ocultar sección de Perforación
  bool get _debeMostrarSeccionPerforacion {
    final codigoStr = widget.codigo.toString();
    return _debeMostrarDatosPerforacion && codigoStr != '101';
  }

  // 🔥 Para código 102, ocultar secciones de Pernos y Mallas
  bool get _debeMostrarSeccionPernosMallas {
    final codigoStr = widget.codigo.toString();
    return _debeMostrarDatosPerforacion && codigoStr != '102';
  }

  Future<void> _cargarTiposPerforacion() async {
    try {
      final dbHelper = DatabaseHelper();
      final tipos =
          await dbHelper.getTiposPerforacionByProceso("EMPERNADOR");
      final lista = tipos
          .map((t) => t.nombre ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        opcionesTipoPerforacion = lista;
      });
    } catch (e) {
      print("Error cargando tipos perforación: $e");
      setState(() {
        opcionesTipoPerforacion = ['Perforación 1', 'Perforación 2'];
      });
    }
  }

  Future<void> _cargarDatosDesdeBD() async {
    setState(() => isLoading = true);

    try {
      await _cargarPlanesCombinados();
      await _cargarPernos();
      await _cargarMallas();
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cargarPlanesCombinados() async {
    try {
      final dbHelper = DatabaseHelper();

      final results = await Future.wait([
        dbHelper.getPlanesMensual(),
        dbHelper.getPlanesProduccion(),
        dbHelper.getPlanesMetraje(),
      ]);

      final planesMensual = results[0] as List<PlanMensual>;
      final planesProduccion = results[1] as List<PlanProduccion>;
      final planesMetraje = results[2] as List<PlanMetraje>;

      _generarOpcionesUbicacion(planesMensual, planesProduccion, planesMetraje);
    } catch (e) {
      print("Error cargando planes: $e");
      setState(() {
        opcionesUbicacionCombinadas = [
          'Galería_LaborA_AlaNorte',
          'Galería_LaborA_AlaSur',
          'Crucero_LaborB_AlaEste',
        ];
        opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
      });
    }
  }

  void _generarOpcionesUbicacion(
    List<PlanMensual> planesMensual,
    List<PlanProduccion> planesProduccion,
    List<PlanMetraje> planesMetraje,
  ) {
    Set<String> opcionesCombinadas = {};

    for (var plan in planesMensual) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }

    for (var plan in planesProduccion) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }

    for (var plan in planesMetraje) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }

    setState(() {
      opcionesUbicacionCombinadas = opcionesCombinadas.toList()..sort();
      opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
    });
  }

  Future<void> _cargarPernos() async {
    try {
      final dbHelper = DatabaseHelper();
      final data = await dbHelper.getPernos();

      pernosCompletos = data;

      final tipos = data.map((e) => e['tipo_perno'].toString()).toSet().toList()
        ..sort();

      setState(() {
        tiposPerno = tipos;
      });
    } catch (e) {
      print("Error cargando pernos: $e");
    }
  }

  Future<void> _cargarMallas() async {
    try {
      final dbHelper = DatabaseHelper();
      final data = await dbHelper.getMallas();

      final lista = data.map((e) => e['tipo_malla'].toString()).toSet().toList()
        ..sort();

      setState(() {
        opcionesMalla = lista;
      });
    } catch (e) {
      print("Error cargando mallas: $e");
    }
  }

  List<String> _longitudesParaTipo(String tipo) {
    if (tipo.isEmpty) return [];
    return pernosCompletos
        .where((e) => e['tipo_perno'] == tipo)
        .map((e) => e['longitud'].toString())
        .toSet()
        .toList()
      ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));
  }

  // ============================================================
  // CARGA DE DATOS INICIALES
  // ============================================================
  void _cargarDatosIniciales() {
    if (widget.datosIniciales == null) return;

    setState(() {
      laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true
          ? widget.datosIniciales!['labor']
          : null;

      if (laborSeleccionado != null) {
        ubicacionController.text = laborSeleccionado!;
      }

      observacionesController.text =
          widget.datosIniciales!['observaciones'] ?? '';

      // 🔥 Tipo de perforación a nivel raíz
      final tipoPerf = widget.datosIniciales!['tipo_perforacion'];
      tipoPerforacionSeleccionado =
          (tipoPerf != null && tipoPerf.toString().isNotEmpty)
              ? tipoPerf.toString()
              : null;

      pernosFilas.clear();
      mallasFilas.clear();
      perforacionesFilas.clear();

      // ---- Pernos ----
      final pernosData = widget.datosIniciales!['perno'];
      if (pernosData is List && pernosData.isNotEmpty) {
        pernosFilas = pernosData.map<PernoFila>((d) {
          return PernoFila(
            tipoPerno: (d['tipo_pernos'] ?? '').toString(),
            longitud: (d['log_pernos'] ?? '').toString(),
            nPernos:
                int.tryParse(d['n_pernos_instalados']?.toString() ?? '') ?? 0,
            sistematico: (d['sistematico_puntual'] ?? '').toString(),
          );
        }).toList();
      } else if (isEditable && _debeMostrarDatosPerforacion) {
        pernosFilas.add(PernoFila(
          tipoPerno: '',
          longitud: '',
          nPernos: 0,
          sistematico: '',
        ));
      }

      // ---- Mallas ----
      final mallasData = widget.datosIniciales!['malla'];
      if (mallasData is List && mallasData.isNotEmpty) {
        mallasFilas = mallasData.map<MallaFila>((d) {
          return MallaFila(
            tipoMalla: (d['tipo_malla'] ?? '').toString(),
            mt52: (d['mt52_malla'] ?? '').toString(),
          );
        }).toList();
      } else if (isEditable && _debeMostrarDatosPerforacion) {
        mallasFilas.add(MallaFila(
          tipoMalla: '',
          mt52: '',
        ));
      }

      // ---- Perforación 🔥 (sin tipo_perforacion) ----
      final perforacionesData = widget.datosIniciales!['perforacion'];
      if (perforacionesData is List && perforacionesData.isNotEmpty) {
        perforacionesFilas = perforacionesData.map<PerforacionFila>((d) {
          return PerforacionFila(
            nTaladros: int.tryParse(d['n_taladros']?.toString() ?? '') ?? 0,
            longitudPerforacion: double.tryParse(
                    d['longitud_perforacion']?.toString() ?? '') ??
                0.0,
          );
        }).toList();
      } else if (isEditable && _debeMostrarDatosPerforacion) {
        perforacionesFilas.add(PerforacionFila(
          nTaladros: 0,
          longitudPerforacion: 0.0,
        ));
      }
    });
  }

  // ============================================================
  // PERNOS
  // ============================================================
  void _agregarPernoFila() {
    setState(() {
      pernosFilas.add(PernoFila(
        tipoPerno: '',
        longitud: '',
        nPernos: 0,
        sistematico: '',
      ));
    });
  }

  void _eliminarPernoFila(int index) {
    setState(() => pernosFilas.removeAt(index));
  }

  void _actualizarPernoFila(int index, String campo, dynamic valor) {
    setState(() {
      switch (campo) {
        case 'tipo_pernos':
          pernosFilas[index].tipoPerno = valor.toString();
          pernosFilas[index].longitud = '';
          break;
        case 'log_pernos':
          pernosFilas[index].longitud = valor.toString();
          break;
        case 'n_pernos_instalados':
          pernosFilas[index].nPernos = int.tryParse(valor.toString()) ?? 0;
          break;
        case 'sistematico_puntual':
          pernosFilas[index].sistematico = valor.toString();
          break;
      }
    });
  }

  // ============================================================
  // MALLAS
  // ============================================================
  void _agregarMallaFila() {
    setState(() {
      mallasFilas.add(MallaFila(
        tipoMalla: '',
        mt52: '',
      ));
    });
  }

  void _eliminarMallaFila(int index) {
    setState(() => mallasFilas.removeAt(index));
  }

  void _actualizarMallaFila(int index, String campo, dynamic valor) {
    setState(() {
      switch (campo) {
        case 'tipo_malla':
          mallasFilas[index].tipoMalla = valor.toString();
          break;
        case 'mt52_malla':
          mallasFilas[index].mt52 = valor.toString();
          break;
      }
    });
  }

  // ============================================================
  // PERFORACIÓN 🔥
  // ============================================================
  void _agregarPerforacionFila() {
    setState(() {
      perforacionesFilas.add(PerforacionFila(
        nTaladros: 0,
        longitudPerforacion: 0.0,
      ));
    });
  }

  void _eliminarPerforacionFila(int index) {
    setState(() => perforacionesFilas.removeAt(index));
  }

  void _actualizarPerforacionFila(int index, String campo, dynamic valor) {
    setState(() {
      switch (campo) {
        case 'n_taladros':
          perforacionesFilas[index].nTaladros =
              int.tryParse(valor.toString()) ?? 0;
          break;
        case 'longitud_perforacion':
          perforacionesFilas[index].longitudPerforacion =
              double.tryParse(valor.toString()) ?? 0.0;
          break;
      }
    });
  }

  // ============================================================
  // GUARDAR
  // ============================================================
  Future<void> _guardarDatos() async {
    String laborFinal = laborSeleccionado ?? '';
    if (laborFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
      laborFinal = ubicacionController.text.trim();
    }

    if (_laborEsObligatoria && laborFinal.isEmpty) {
      _mostrarSnackbar('Debe ingresar una labor', Colors.orange);
      return;
    }

    Map<String, dynamic> datosFormulario = {
      'labor': laborFinal,
      // 🔥 Tipo de perforación a nivel raíz
      'tipo_perforacion': tipoPerforacionSeleccionado ?? '',
      'perno': pernosFilas.map((p) => p.toMap()).toList(),
      'malla': mallasFilas.map((m) => m.toMap()).toList(),
      'perforacion': perforacionesFilas.map((p) => p.toMap()).toList(),
      'observaciones': observacionesController.text,
    };

    widget.onGuardar(datosFormulario);
    _mostrarSnackbar('Formulario guardado correctamente', Colors.green);
    Navigator.pop(context);
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    observacionesController.dispose();
    ubicacionController.dispose();
    ubicacionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.95 : 1100,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSeccionUbicacion(),
                          if (_debeMostrarDatosPerforacion) ...[
                            if (_debeMostrarSeccionPerforacion) ...[
                              const SizedBox(height: 12),
                              _buildSeccionPerforacionFila(),
                            ],
                            if (_debeMostrarSeccionPernosMallas) ...[
                              const SizedBox(height: 12),
                              _buildSeccionPernosFila(),
                              const SizedBox(height: 12),
                              _buildSeccionMallasFila(),
                            ],
                            // 🔥 Tipo de perforación al final, arriba de Observaciones
                            const SizedBox(height: 12),
                            _buildSeccionTipoPerforacion(),
                          ],
                          const SizedBox(height: 12),
                          _buildSeccionObservaciones(),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // SECCIÓN UBICACIÓN
  // ============================================================
  Widget _buildSeccionUbicacion() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.location_on,
                    size: 12, color: Colors.green),
              ),
              const SizedBox(width: 6),
              const Text(
                'Labor (TipoLabor_Labor_Ala)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: ubicacionController,
                      focusNode: ubicacionFocusNode,
                      enabled: isEditable,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Buscar o escribir nueva ubicación...',
                        hintStyle: const TextStyle(fontSize: 11),
                        prefixIcon: Icon(Icons.search,
                            size: 16, color: widget.primaryColor),
                        suffixIcon: ubicacionController.text.isNotEmpty &&
                                isEditable
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    size: 14, color: Colors.grey.shade500),
                                onPressed: () {
                                  ubicacionController.clear();
                                  setState(() {
                                    opcionesUbicacionFiltradas = List.from(
                                        opcionesUbicacionCombinadas);
                                    mostrarSugerencias = false;
                                    laborSeleccionado = null;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (text) {
                        setState(() {
                          if (text.isEmpty) {
                            opcionesUbicacionFiltradas =
                                List.from(opcionesUbicacionCombinadas);
                            mostrarSugerencias = false;
                            laborSeleccionado = null;
                            return;
                          }
                          opcionesUbicacionFiltradas =
                              opcionesUbicacionCombinadas
                                  .where((item) => item
                                      .toLowerCase()
                                      .contains(text.toLowerCase()))
                                  .toList();
                          final esMatchExacto =
                              opcionesUbicacionCombinadas.any((item) =>
                                  item.toLowerCase() == text.toLowerCase());
                          if (esMatchExacto) {
                            mostrarSugerencias = true;
                          } else if (opcionesUbicacionFiltradas.isNotEmpty) {
                            mostrarSugerencias = true;
                          } else {
                            laborSeleccionado = text;
                            mostrarSugerencias = false;
                          }
                        });
                      },
                      onTap: () {
                        setState(() {
                          mostrarSugerencias = true;
                          if (ubicacionController.text.isEmpty) {
                            opcionesUbicacionFiltradas =
                                List.from(opcionesUbicacionCombinadas);
                          }
                        });
                      },
                    ),
                    if (mostrarSugerencias &&
                        opcionesUbicacionFiltradas.isNotEmpty &&
                        isEditable)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: opcionesUbicacionFiltradas.length,
                          itemBuilder: (context, index) {
                            final suggestion =
                                opcionesUbicacionFiltradas[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                suggestion,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  laborSeleccionado = suggestion;
                                  ubicacionController.text = suggestion;
                                  mostrarSugerencias = false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    if (laborSeleccionado != null &&
                        ubicacionController.text.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  widget.primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 12, color: widget.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                laborSeleccionado!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: widget.primaryColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEditable)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    laborSeleccionado = null;
                                    ubicacionController.clear();
                                    opcionesUbicacionFiltradas = List.from(
                                        opcionesUbicacionCombinadas);
                                  });
                                },
                                child: Icon(Icons.close,
                                    size: 14,
                                    color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (opcionesUbicacionCombinadas.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay ubicaciones disponibles',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SECCIÓN PERFORACIÓN 🔥 (solo N° Taladros y Longitud)
  // ============================================================
  Widget _buildSeccionPerforacionFila() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.gps_fixed,
                  size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              'Perforación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            if (isEditable)
              IconButton(
                icon: Icon(Icons.add_circle,
                    color: widget.primaryColor, size: 20),
                onPressed: _agregarPerforacionFila,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
                tooltip: 'Agregar perforación',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (perforacionesFilas.isEmpty)
          _buildEmptyRow('No hay perforaciones agregadas')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: perforacionesFilas.length,
            itemBuilder: (context, index) {
              final p = perforacionesFilas[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInlineTextField(
                        label: 'N° Taladros',
                        value: p.nTaladros == 0 ? '' : p.nTaladros.toString(),
                        onChanged: isEditable
                            ? (v) => _actualizarPerforacionFila(
                                index, 'n_taladros', v)
                            : null,
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildInlineTextField(
                        label: 'Longitud (m)',
                        value: p.longitudPerforacion == 0
                            ? ''
                            : p.longitudPerforacion.toString(),
                        onChanged: isEditable
                            ? (v) => _actualizarPerforacionFila(
                                index, 'longitud_perforacion', v)
                            : null,
                        icon: Icons.straighten,
                      ),
                    ),
                    if (isEditable && perforacionesFilas.length > 1)
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade400, size: 20),
                          onPressed: () => _eliminarPerforacionFila(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                          tooltip: 'Eliminar perforación',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // SECCIÓN TIPO DE PERFORACIÓN 🔥 (a nivel raíz, arriba de Observaciones)
  // ============================================================
  Widget _buildSeccionTipoPerforacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.settings_input_component,
                  size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              'Tipo de Perforación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (tipoPerforacionSeleccionado != null &&
                      opcionesTipoPerforacion
                          .contains(tipoPerforacionSeleccionado))
                  ? tipoPerforacionSeleccionado
                  : null,
              hint: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_input_component,
                      size: 13, color: widget.primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      opcionesTipoPerforacion.isEmpty
                          ? 'Cargando...'
                          : 'Seleccione tipo de perforación',
                      style: TextStyle(
                        fontSize: 12,
                        color: isEditable
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down,
                  size: 18, color: widget.primaryColor),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(6),
              items: opcionesTipoPerforacion.isEmpty
                  ? [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'No hay opciones',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                    ]
                  : opcionesTipoPerforacion.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child:
                            Text(item, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
              onChanged: isEditable
                  ? (v) =>
                      setState(() => tipoPerforacionSeleccionado = v)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECCIÓN PERNOS
  // ============================================================
  Widget _buildSeccionPernosFila() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.build, size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              'Pernos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            if (isEditable)
              IconButton(
                icon: Icon(Icons.add_circle,
                    color: widget.primaryColor, size: 20),
                onPressed: _agregarPernoFila,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
                tooltip: 'Agregar perno',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (pernosFilas.isEmpty)
          _buildEmptyRow('No hay pernos agregados')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pernosFilas.length,
            itemBuilder: (context, index) {
              final p = pernosFilas[index];
              final longitudes = _longitudesParaTipo(p.tipoPerno);
              final longitudValue =
                  (p.longitud.isNotEmpty && longitudes.contains(p.longitud))
                      ? p.longitud
                      : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInlineDropdownField(
                        label: 'Tipo Perno',
                        value: p.tipoPerno.isEmpty ? null : p.tipoPerno,
                        items: tiposPerno,
                        onChanged: isEditable
                            ? (v) => _actualizarPernoFila(
                                index, 'tipo_pernos', v ?? '')
                            : null,
                        icon: Icons.category,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildInlineDropdownField(
                        label: 'Longitud',
                        value: longitudValue,
                        items: longitudes,
                        onChanged: (p.tipoPerno.isNotEmpty && isEditable)
                            ? (v) => _actualizarPernoFila(
                                index, 'log_pernos', v ?? '')
                            : null,
                        icon: Icons.straighten,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildInlineTextField(
                        label: 'N° Pernos',
                        value: p.nPernos == 0 ? '' : p.nPernos.toString(),
                        onChanged: isEditable
                            ? (v) => _actualizarPernoFila(
                                index, 'n_pernos_instalados', v)
                            : null,
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildInlineDropdownField(
                        label: 'Sistemático/Puntual',
                        value:
                            p.sistematico.isEmpty ? null : p.sistematico,
                        items: opcionesSistematicoPuntual,
                        onChanged: isEditable
                            ? (v) => _actualizarPernoFila(
                                index, 'sistematico_puntual', v ?? '')
                            : null,
                        icon: Icons.timeline,
                      ),
                    ),
                    if (isEditable && pernosFilas.length > 1)
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade400, size: 20),
                          onPressed: () => _eliminarPernoFila(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                          tooltip: 'Eliminar perno',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // SECCIÓN MALLAS
  // ============================================================
  Widget _buildSeccionMallasFila() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child:
                  Icon(Icons.grid_on, size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              'Mallas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            if (isEditable)
              IconButton(
                icon: Icon(Icons.add_circle,
                    color: widget.primaryColor, size: 20),
                onPressed: _agregarMallaFila,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
                tooltip: 'Agregar malla',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (mallasFilas.isEmpty)
          _buildEmptyRow('No hay mallas agregadas')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mallasFilas.length,
            itemBuilder: (context, index) {
              final m = mallasFilas[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInlineDropdownField(
                        label: 'Tipo Malla',
                        value: m.tipoMalla.isEmpty ? null : m.tipoMalla,
                        items: opcionesMalla,
                        onChanged: isEditable
                            ? (v) => _actualizarMallaFila(
                                index, 'tipo_malla', v ?? '')
                            : null,
                        icon: Icons.grid_3x3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildInlineTextField(
                        label: 'M2 Malla',
                        value: m.mt52,
                        onChanged: isEditable
                            ? (v) =>
                                _actualizarMallaFila(index, 'mt52_malla', v)
                            : null,
                        icon: Icons.straighten,
                      ),
                    ),
                    if (isEditable && mallasFilas.length > 1)
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade400, size: 20),
                          onPressed: () => _eliminarMallaFila(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                          tooltip: 'Eliminar malla',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _buildEmptyRow(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          mensaje,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTextField({
    required String label,
    required String value,
    required Function(String)? onChanged,
    required IconData icon,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        initialValue: value,
        enabled: onChanged != null,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, size: 13, color: widget.primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
        ),
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildInlineDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required IconData icon,
  }) {
    bool valueExists = value != null && items.contains(value);
    bool isEnabled = onChanged != null && isEditable;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valueExists ? value : null,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: widget.primaryColor),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Cargando...' : label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isEnabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down,
              size: 16, color: widget.primaryColor),
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ),
                ]
              : items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
          onChanged: isEnabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildSeccionObservaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child:
                  Icon(Icons.note_alt, size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              'Observaciones',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: observacionesController,
            enabled: isEditable,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Ingrese observaciones adicionales...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.comment,
                  size: 16,
                  color: widget.primaryColor.withOpacity(0.7),
                ),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.build, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            isSmallScreen ? 'Empernador' : 'Formulario de Empernador',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildEstadoBadge(),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEditable
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditable ? Colors.green : Colors.grey,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isEditable ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isEditable ? 'EDITABLE' : 'LECTURA',
            style: TextStyle(
              color: isEditable ? Colors.green : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          if (isEditable)
            Tooltip(
              message: _puedeGuardar
                  ? 'Guardar datos'
                  : 'Ingrese una labor para poder guardar',
              child: ElevatedButton(
                onPressed: _puedeGuardar ? _guardarDatos : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Guardar',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}