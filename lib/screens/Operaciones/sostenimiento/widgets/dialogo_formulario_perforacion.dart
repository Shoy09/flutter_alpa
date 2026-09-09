import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/PlanMetraje.dart';

class DialogoFormularioEmpernador extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioEmpernador({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
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

  // 🔥 NUEVO: Controlador para ubicación combinada
  final TextEditingController ubicacionController = TextEditingController();
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // 🔥 NUEVO: Variable para la ubicación seleccionada (cadena combinada)
  String? laborSeleccionado;

  // 🔥 NUEVO: Opciones combinadas para el buscador
  List<String> opcionesUbicacionCombinadas = [];
  List<String> opcionesUbicacionFiltradas = [];

  // Controladores para los campos específicos de empernador
  final TextEditingController nPernosInstaladosController =
      TextEditingController();
  final TextEditingController mt52MallaController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // Listas para pernos y mallas
  List<Map<String, dynamic>> pernosCompletos = [];
  List<String> tiposPerno = [];
  List<String> longitudesPerno = [];

  String? tipoPernoSeleccionado;
  String? longitudPernoSeleccionada;

  List<String> opcionesMalla = [];
  String? mallaSeleccionada;

  String? sistematicoPuntualSeleccionado;
  List<String> opcionesSistematicoPuntual = ['Sistemático', 'Puntual'];

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
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

  // 🔥 NUEVO: Cargar planes combinados (Mensual + Produccion + Metraje)
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

      // Generar opciones combinadas para ubicación
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

  // 🔥 NUEVO: Generar opciones combinadas
  void _generarOpcionesUbicacion(
    List<PlanMensual> planesMensual,
    List<PlanProduccion> planesProduccion,
    List<PlanMetraje> planesMetraje,
  ) {
    Set<String> opcionesCombinadas = {};

    // Combinar datos de PlanMensual
    for (var plan in planesMensual) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';

      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }

    // Combinar datos de PlanProduccion
    for (var plan in planesProduccion) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';

      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }

    // Combinar datos de PlanMetraje
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

  // Cargar pernos desde la BD
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

      _setLongitudesDesdeTipoInicial();
    } catch (e) {
      print("Error cargando pernos: $e");
    }
  }

  // Cargar mallas desde la BD
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

  void _onTipoPernoChanged(String? tipo) {
    setState(() {
      tipoPernoSeleccionado = tipo;
      longitudPernoSeleccionada = null;

      final filtrados =
          pernosCompletos
              .where((e) => e['tipo_perno'] == tipo)
              .map((e) => e['longitud'].toString())
              .toSet()
              .toList()
            ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));

      longitudesPerno = filtrados;
    });
  }

  void _setLongitudesDesdeTipoInicial() {
    if (tipoPernoSeleccionado == null) return;

    final filtrados =
        pernosCompletos
            .where((e) => e['tipo_perno'] == tipoPernoSeleccionado)
            .map((e) => e['longitud'].toString())
            .toSet()
            .toList()
          ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));

    if (longitudPernoSeleccionada != null &&
        !filtrados.contains(longitudPernoSeleccionada)) {
      filtrados.add(longitudPernoSeleccionada!);
    }

    setState(() {
      longitudesPerno = filtrados;
    });
  }

  // 🔥 MODIFICADO: Cargar datos iniciales
  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      // 🔥 NUEVO: Cargar 'labor' como cadena combinada
      setState(() {
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true
            ? widget.datosIniciales!['labor']
            : null;

        if (laborSeleccionado != null) {
          ubicacionController.text = laborSeleccionado!;
        }

        // Campos específicos de empernador
        tipoPernoSeleccionado = widget.datosIniciales!['tipo_pernos'];
        longitudPernoSeleccionada = widget.datosIniciales!['log_pernos'];
        nPernosInstaladosController.text =
            widget.datosIniciales!['n_pernos_instalados'] ?? '';
        mallaSeleccionada = widget.datosIniciales!['tipo_malla'];
        mt52MallaController.text = widget.datosIniciales!['mt52_malla'] ?? '';
        sistematicoPuntualSeleccionado =
            widget.datosIniciales!['sistematico_puntual'];
        observacionesController.text =
            widget.datosIniciales!['observaciones'] ?? '';
      });
    }
  }

  // 🔥 MODIFICADO: Guardar datos con 'labor' como cadena única
  Future<void> _guardarDatos() async {
    // Obtener el labor final (texto libre o seleccionado)
    String laborFinal = laborSeleccionado ?? '';

    // Si no hay labor seleccionada pero hay texto en el campo, usar ese texto
    if (laborFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
      laborFinal = ubicacionController.text.trim();
    }

    Map<String, dynamic> datosFormulario = {
      // 🔥 CAMBIO: Solo 'labor' como cadena combinada
      'labor': laborFinal,

      // Campos específicos de empernador
      'tipo_pernos': tipoPernoSeleccionado ?? '',
      'log_pernos': longitudPernoSeleccionada ?? '',
      'n_pernos_instalados': nPernosInstaladosController.text,
      'tipo_malla': mallaSeleccionada ?? '',
      'mt52_malla': mt52MallaController.text,
      'sistematico_puntual': sistematicoPuntualSeleccionado ?? '',
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
    nPernosInstaladosController.dispose();
    mt52MallaController.dispose();
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
        width: isSmallScreen ? screenWidth * 0.95 : 1000,
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
                          // 🔥 NUEVA SECCIÓN: Ubicación con buscador
                          _buildSeccionUbicacion(),
                          const SizedBox(height: 12),
                          // SECCIÓN 2: Pernos
                          _buildSeccionCompacta(
                            icon: Icons.build,
                            titulo: 'Pernos',
                            children: [
                              _buildCompactDropdownField(
                                label: 'Tipo Perno',
                                value: tipoPernoSeleccionado,
                                items: tiposPerno,
                                onChanged: isEditable
                                    ? _onTipoPernoChanged
                                    : null,
                                icon: Icons.category,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Longitud',
                                value: longitudPernoSeleccionada,
                                items: longitudesPerno,
                                onChanged:
                                    (tipoPernoSeleccionado != null &&
                                        isEditable)
                                    ? (value) => setState(
                                        () => longitudPernoSeleccionada = value,
                                      )
                                    : null,
                                icon: Icons.straighten,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactTextField(
                                label: 'N° Pernos Instalados',
                                controller: nPernosInstaladosController,
                                icon: Icons.format_list_numbered,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // SECCIÓN 3: Malla y Sistemático
                          _buildSeccionCompacta(
                            icon: Icons.grid_on,
                            titulo: 'Malla y Sistemático',
                            children: [
                              _buildCompactDropdownField(
                                label: 'Tipo Malla',
                                value: mallaSeleccionada,
                                items: opcionesMalla,
                                onChanged: isEditable
                                    ? (value) => setState(
                                        () => mallaSeleccionada = value,
                                      )
                                    : null,
                                icon: Icons.grid_3x3,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactTextField(
                                label: 'M2 Malla',
                                controller: mt52MallaController,
                                icon: Icons.straighten,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Sistemático/Puntual',
                                value: sistematicoPuntualSeleccionado,
                                items: opcionesSistematicoPuntual,
                                onChanged: isEditable
                                    ? (value) => setState(
                                        () => sistematicoPuntualSeleccionado =
                                            value,
                                      )
                                    : null,
                                icon: Icons.timeline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // SECCIÓN 4: Observaciones
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

  // 🔥 NUEVA SECCIÓN: Ubicación con buscador
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
                'Labor (TipoLabor_Labor_Ala)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
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
                  prefixIcon: Icon(Icons.search, size: 16, color: widget.primaryColor),
                  suffixIcon: ubicacionController.text.isNotEmpty && isEditable
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                          onPressed: () {
                            ubicacionController.clear();
                            setState(() {
                              opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
                              mostrarSugerencias = false;
                              laborSeleccionado = null;
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
                      opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
                      mostrarSugerencias = false;
                      laborSeleccionado = null;
                      return;
                    }

                    // Filtrar sugerencias
                    opcionesUbicacionFiltradas = opcionesUbicacionCombinadas
                        .where((item) => item.toLowerCase().contains(text.toLowerCase()))
                        .toList();

                    // Verificar si es match exacto
                    final esMatchExacto = opcionesUbicacionCombinadas
                        .any((item) => item.toLowerCase() == text.toLowerCase());

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
                      opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
                    }
                  });
                },
              ),

              if (mostrarSugerencias && opcionesUbicacionFiltradas.isNotEmpty && isEditable)
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
                      final suggestion = opcionesUbicacionFiltradas[index];
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

              // Badge de selección
              if (laborSeleccionado != null && ubicacionController.text.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: widget.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          laborSeleccionado!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget.primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEditable)
                        InkWell(
                          onTap: () {
                            setState(() {
                              laborSeleccionado = null;
                              ubicacionController.clear();
                              opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
                            });
                          },
                          child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
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
              child: Icon(Icons.note_alt, size: 14, color: widget.primaryColor),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCompacta({
    required IconData icon,
    required String titulo,
    required List<Widget> children,
  }) {
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
              child: Icon(icon, size: 14, color: widget.primaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              titulo,
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
        Row(
          children: children.map((child) {
            if (child is SizedBox && child.width == 8) {
              return child;
            }
            return Expanded(child: child);
          }).toList(),
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

  Widget _buildCompactTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 42,
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
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, size: 14, color: widget.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
      ),
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

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valueExists ? value : null,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: widget.primaryColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Cargando...' : label,
                  style: TextStyle(
                    fontSize: 11,
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
          icon: Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: widget.primaryColor,
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ]
              : items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
          onChanged: isEnabled ? onChanged : null,
        ),
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
            ElevatedButton(
              onPressed: _guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}