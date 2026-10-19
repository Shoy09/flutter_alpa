import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/TipoPerforacion.dart'; // 👈 usa el mismo modelo (o crea TipoLabor si prefieres)

class DialogoFormularioRompebanco extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioRompebanco({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);

  @override
  State<DialogoFormularioRompebanco> createState() =>
      _DialogoFormularioRompebancoState();
}

class _DialogoFormularioRompebancoState extends State<DialogoFormularioRompebanco> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // 🔹 Controladores
  final TextEditingController laborController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController ductoController = TextEditingController();
  final TextEditingController cableController = TextEditingController();
  final TextEditingController tuberiaController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // 🔹 Focus para sugerencias de Labor
  final FocusNode laborFocusNode = FocusNode();
  bool mostrarSugerenciasLabor = false;
  String? laborSeleccionada;
  List<String> opcionesLaborCombinadas = [];
  List<String> opcionesLaborFiltradas = [];

  // 🔥 Focus para sugerencias de Destino
  final FocusNode destinoFocusNode = FocusNode();
  bool mostrarSugerenciasDestino = false;
  String? destinoSeleccionado;
  List<String> opcionesDestinoFiltradas = [];

  // 🔥 Tipo de Labor (mismo patrón que "Tipo de Perforación")
  List<String> opcionesTipoLabor = [];
  List<TipoPerforacion> tiposLaborCompletos = [];   // 👈 objetos completos con ID
  String? tipoLaborSeleccionado;

  // 🔹 Datos completos
  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
  }

  @override
  void dispose() {
    laborController.dispose();
    destinoController.dispose();
    ductoController.dispose();
    cableController.dispose();
    tuberiaController.dispose();
    observacionesController.dispose();
    laborFocusNode.dispose();
    destinoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosDesdeBD() async {
    setState(() => isLoading = true);
    try {
      await _cargarPlanesCombinados();
      await _cargarTiposLabor();
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

      planesMensualCompletos = results[0] as List<PlanMensual>;
      planesProduccionCompletos = results[1] as List<PlanProduccion>;
      planesMetrajeCompletos = results[2] as List<PlanMetraje>;

      _generarOpcionesLabor();
    } catch (e) {
      print("Error cargando planes combinados: $e");
      setState(() {
        opcionesLaborCombinadas = [
          'Galería_LaborA_AlaNorte',
          'Galería_LaborA_AlaSur',
          'Crucero_LaborB_AlaEste',
        ];
        opcionesLaborFiltradas = List.from(opcionesLaborCombinadas);
        opcionesDestinoFiltradas = List.from(opcionesLaborCombinadas);
      });
    }
  }

  /// 🔥 Combina tipoLabor + labor + ala para los buscadores
  void _generarOpcionesLabor() {
    Set<String> opciones = {};

    void agregarDesde(dynamic plan) {
      String combinado = '';
      if ((plan.tipoLabor ?? '').isNotEmpty) combinado += plan.tipoLabor!;
      if ((plan.labor ?? '').isNotEmpty) combinado += '_${plan.labor!}';
      if ((plan.ala ?? '').isNotEmpty) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opciones.add(combinado);
    }

    for (var p in planesMensualCompletos) agregarDesde(p);
    for (var p in planesProduccionCompletos) agregarDesde(p);
    for (var p in planesMetrajeCompletos) agregarDesde(p);

    setState(() {
      opcionesLaborCombinadas = opciones.toList()..sort();
      opcionesLaborFiltradas = List.from(opcionesLaborCombinadas);
      opcionesDestinoFiltradas = List.from(opcionesLaborCombinadas);
    });
  }

  /// 🔥 Tipo de Labor: MISMO patrón que "Tipo de Perforación"
  Future<void> _cargarTiposLabor() async {
    try {
      final dbHelper = DatabaseHelper();

      // 🔥 Cambia "PERFORACIÓN HORIZONTAL" por el proceso que uses para SCISSOR
      // Por ejemplo: "ROMPEBANCO" o "SCISSOR"
      tiposLaborCompletos = await dbHelper.getTiposPerforacionByProceso(
        "PERFORACIÓN HORIZONTAL",   // 👈 ajusta el proceso aquí
      );

      final lista = tiposLaborCompletos
          .map((t) => t.nombre ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        opcionesTipoLabor = lista;
      });
    } catch (e) {
      print("Error cargando tipos de labor: $e");
      setState(() {
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
        tiposLaborCompletos = [];
      });
    }
  }

  /// 🔥 Obtener ID del tipo de labor seleccionado (igual que en Perforación)
  int? _obtenerIdTipoLabor(String? nombre) {
    if (nombre == null) return null;
    try {
      return tiposLaborCompletos
          .firstWhere((tipo) => tipo.nombre == nombre)
          .id;
    } catch (e) {
      return null;
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales == null) return;

    setState(() {
      // LABOR
      final laborInicial = widget.datosIniciales!['labor'] ?? '';
      laborSeleccionada = laborInicial.isNotEmpty ? laborInicial : null;
      laborController.text = laborInicial;

      // DESTINO
      final destinoInicial = widget.datosIniciales!['destino'] ?? '';
      destinoSeleccionado = destinoInicial.isNotEmpty ? destinoInicial : null;
      destinoController.text = destinoInicial;

      // N° METROS
      ductoController.text = widget.datosIniciales!['ducto']?.toString() ?? '';
      cableController.text = widget.datosIniciales!['cable']?.toString() ?? '';
      tuberiaController.text = widget.datosIniciales!['tuberia']?.toString() ?? '';

      // TIPO DE LABOR
      final tipoLab = widget.datosIniciales!['tipo_labor'] ?? '';
      tipoLaborSeleccionado = tipoLab.isNotEmpty ? tipoLab : null;

      // OBSERVACIONES
      observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
    });
  }

  void _guardarDatos() async {
    String laborFinal = laborSeleccionada ?? laborController.text.trim();
    String destinoFinal = destinoSeleccionado ?? destinoController.text.trim();

    Map<String, dynamic> datosFormulario = {
      'labor': laborFinal,
      'destino': destinoFinal,
      'ducto': ductoController.text.trim(),
      'cable': cableController.text.trim(),
      'tuberia': tuberiaController.text.trim(),
      'tipo_labor': tipoLaborSeleccionado ?? '',
      'tipo_labor_id': _obtenerIdTipoLabor(tipoLaborSeleccionado),  // 🔥 NUEVO
      'observaciones': observacionesController.text.trim(),
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.95 : 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                          const SizedBox(height: 12),
                          _buildSeccionMetros(),
                          const SizedBox(height: 12),
                          _buildSeccionTipoLabor(),
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

  // ==================== SECCIÓN: UBICACIÓN (LABOR + DESTINO) ====================
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
                child: const Icon(Icons.location_on, size: 12, color: Colors.green),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ubicación',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 6),

          _buildLaborBuscador(),
          const SizedBox(height: 8),
          _buildDestinoBuscador(),
        ],
      ),
    );
  }

  /// Campo Labor con sugerencias
  Widget _buildLaborBuscador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.work_outline, size: 10, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              'Labor',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        TextField(
          controller: laborController,
          focusNode: laborFocusNode,
          enabled: isEditable,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Buscar o escribir labor...',
            hintStyle: const TextStyle(fontSize: 11),
            prefixIcon: Icon(Icons.search, size: 16, color: widget.primaryColor),
            suffixIcon: laborController.text.isNotEmpty && isEditable
                ? IconButton(
                    icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                    onPressed: () {
                      laborController.clear();
                      setState(() {
                        opcionesLaborFiltradas = List.from(opcionesLaborCombinadas);
                        mostrarSugerenciasLabor = false;
                        laborSeleccionada = null;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (text) {
            setState(() {
              if (text.isEmpty) {
                opcionesLaborFiltradas = List.from(opcionesLaborCombinadas);
                mostrarSugerenciasLabor = false;
                laborSeleccionada = null;
                return;
              }
              opcionesLaborFiltradas = opcionesLaborCombinadas
                  .where((e) => e.toLowerCase().contains(text.toLowerCase()))
                  .toList();

              final esMatchExacto = opcionesLaborCombinadas
                  .any((e) => e.toLowerCase() == text.toLowerCase());

              if (esMatchExacto || opcionesLaborFiltradas.isNotEmpty) {
                mostrarSugerenciasLabor = true;
              } else {
                laborSeleccionada = text;
                mostrarSugerenciasLabor = false;
              }
            });
          },
          onTap: () {
            setState(() {
              mostrarSugerenciasLabor = true;
              if (laborController.text.isEmpty) {
                opcionesLaborFiltradas = List.from(opcionesLaborCombinadas);
              }
            });
          },
        ),
        if (mostrarSugerenciasLabor &&
            opcionesLaborFiltradas.isNotEmpty &&
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
              itemCount: opcionesLaborFiltradas.length,
              itemBuilder: (context, index) {
                final s = opcionesLaborFiltradas[index];
                return ListTile(
                  dense: true,
                  title: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  onTap: () {
                    setState(() {
                      laborSeleccionada = s;
                      laborController.text = s;
                      mostrarSugerenciasLabor = false;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// Campo Destino con sugerencias (misma data que Labor)
  Widget _buildDestinoBuscador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag, size: 10, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              'Destino',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        TextField(
          controller: destinoController,
          focusNode: destinoFocusNode,
          enabled: isEditable,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Buscar o escribir destino...',
            hintStyle: const TextStyle(fontSize: 11),
            prefixIcon: Icon(Icons.search, size: 16, color: widget.primaryColor),
            suffixIcon: destinoController.text.isNotEmpty && isEditable
                ? IconButton(
                    icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                    onPressed: () {
                      destinoController.clear();
                      setState(() {
                        opcionesDestinoFiltradas = List.from(opcionesLaborCombinadas);
                        mostrarSugerenciasDestino = false;
                        destinoSeleccionado = null;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (text) {
            setState(() {
              if (text.isEmpty) {
                opcionesDestinoFiltradas = List.from(opcionesLaborCombinadas);
                mostrarSugerenciasDestino = false;
                destinoSeleccionado = null;
                return;
              }
              opcionesDestinoFiltradas = opcionesLaborCombinadas
                  .where((e) => e.toLowerCase().contains(text.toLowerCase()))
                  .toList();

              final esMatchExacto = opcionesLaborCombinadas
                  .any((e) => e.toLowerCase() == text.toLowerCase());

              if (esMatchExacto || opcionesDestinoFiltradas.isNotEmpty) {
                mostrarSugerenciasDestino = true;
              } else {
                destinoSeleccionado = text;
                mostrarSugerenciasDestino = false;
              }
            });
          },
          onTap: () {
            setState(() {
              mostrarSugerenciasDestino = true;
              if (destinoController.text.isEmpty) {
                opcionesDestinoFiltradas = List.from(opcionesLaborCombinadas);
              }
            });
          },
        ),
        if (mostrarSugerenciasDestino &&
            opcionesDestinoFiltradas.isNotEmpty &&
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
              itemCount: opcionesDestinoFiltradas.length,
              itemBuilder: (context, index) {
                final s = opcionesDestinoFiltradas[index];
                return ListTile(
                  dense: true,
                  title: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  onTap: () {
                    setState(() {
                      destinoSeleccionado = s;
                      destinoController.text = s;
                      mostrarSugerenciasDestino = false;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ==================== SECCIÓN: N° METROS ====================
  Widget _buildSeccionMetros() {
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.straighten, size: 12, color: Colors.orange),
              ),
              const SizedBox(width: 6),
              const Text(
                'N° Metros',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 6),
          isSmallScreen
              ? Column(
                  children: [
                    _buildTextFieldSimple('Ducto', ductoController, Icons.cable, keyboardType: TextInputType.number),
                    const SizedBox(height: 6),
                    _buildTextFieldSimple('Cable', cableController, Icons.cable, keyboardType: TextInputType.number),
                    const SizedBox(height: 6),
                    _buildTextFieldSimple('Tubería', tuberiaController, Icons.plumbing, keyboardType: TextInputType.number),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildTextFieldSimple('Ducto', ductoController, Icons.cable, keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextFieldSimple('Cable', cableController, Icons.electrical_services, keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextFieldSimple('Tubería', tuberiaController, Icons.plumbing, keyboardType: TextInputType.number),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ==================== SECCIÓN: TIPO DE LABOR ====================
  Widget _buildSeccionTipoLabor() {
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.category, size: 12, color: Colors.blue),
              ),
              const SizedBox(width: 6),
              const Text(
                'Tipo de Labor',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildCompactDropdownField(
            label: 'Seleccione tipo de labor',
            value: tipoLaborSeleccionado,
            items: opcionesTipoLabor,
            onChanged: isEditable
                ? (value) => setState(() => tipoLaborSeleccionado = value)
                : null,
            icon: Icons.category,
          ),
        ],
      ),
    );
  }

  // ==================== SECCIÓN: OBSERVACIONES ====================
  Widget _buildSeccionObservaciones() {
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
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.note_alt, size: 12, color: widget.primaryColor),
              ),
              const SizedBox(width: 6),
              Text(
                'Observaciones',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: isSmallScreen ? 70 : 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: observacionesController,
              enabled: isEditable,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Indicar falla mecánica y firma mecánica...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.comment, size: 14, color: widget.primaryColor.withOpacity(0.7)),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget _buildTextFieldSimple(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: widget.primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            enabled: isEditable,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required IconData icon,
  }) {
    bool valueExists = value != null && items.contains(value);
    bool isEnabled = onChanged != null && isEditable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: widget.primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: valueExists ? value : null,
              hint: Text(
                items.isEmpty ? 'Cargando...' : 'Seleccionar',
                style: TextStyle(fontSize: 11, color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400),
              ),
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, size: 16, color: widget.primaryColor),
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(6),
              items: items.isEmpty
                  ? [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('No hay opciones', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ),
                    ]
                  : items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
              onChanged: isEnabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.description, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSmallScreen ? 'Rompebanco' : 'Formulario Rompebanco',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _buildEstadoBadge(),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isEditable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEditable ? Colors.green : Colors.grey, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isEditable ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            isEditable ? 'EDITABLE' : 'LECTURA',
            style: TextStyle(
              color: isEditable ? Colors.green : Colors.grey,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700, fontSize: isSmallScreen ? 11 : 12)),
          ),
          const SizedBox(width: 8),
          if (isEditable)
            ElevatedButton(
              onPressed: _guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: isSmallScreen ? 11 : 12),
                  const SizedBox(width: 4),
                  Text(
                    'Guardar',
                    style: TextStyle(fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}