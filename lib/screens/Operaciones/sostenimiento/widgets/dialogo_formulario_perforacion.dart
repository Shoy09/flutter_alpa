import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';

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

  // Controladores para los campos específicos de empernador
  final TextEditingController nPernosInstaladosController =
      TextEditingController();
  final TextEditingController mt52MallaController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // 🔥 NUEVO
  List<Map<String, dynamic>> pernosCompletos = [];
  List<String> tiposPerno = [];
  List<String> longitudesPerno = [];

  String? tipoPernoSeleccionado;
  String? longitudPernoSeleccionada;

  // 🔥 MALLAS
  List<String> opcionesMalla = [];
  String? mallaSeleccionada;

  // Variables para los campos seleccionables (provenientes de PlanMensual)
  String? tipoLaborSeleccionado; // 1º
  String? laborSeleccionado; // 2º
  String? alaSeleccionado; // 3º
  String? nivelSeleccionado;

  // Opciones para los dropdowns (ahora vienen de PlanMensual)
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];

  // Listas filtradas para la selección en cascada
  List<String> filteredTiposLabor = [];
  List<String> filteredLabores = [];
  List<String> filteredAlas = [];
  List<String> filteredNiveles = []; // ← NUEVA

  // Almacenar objetos completos para referencia
  List<PlanMensual> planesCompletos = [];

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
      await _cargarPlanesMensuales();
      _cargarPernos();
      _cargarMallas();
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
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

      // 🔥 IMPORTANTE: reconstruir longitudes si ya hay tipo seleccionado
      _setLongitudesDesdeTipoInicial();
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

  void _onTipoPernoChanged(String? tipo) {
    setState(() {
      tipoPernoSeleccionado = tipo;
      longitudPernoSeleccionada = null;

      // 🔥 Filtrar longitudes según tipo
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

    // 🔥 asegurar que el valor actual exista
    if (longitudPernoSeleccionada != null &&
        !filtrados.contains(longitudPernoSeleccionada)) {
      filtrados.add(longitudPernoSeleccionada!);
    }

    setState(() {
      longitudesPerno = filtrados;
    });
  }

  // Cargar planes mensuales y construir opciones únicas
  Future<void> _cargarPlanesMensuales() async {
    try {
      final dbHelper = DatabaseHelper();
      planesCompletos = await dbHelper.getPlanesMensual();

      print("Planes Mensuales obtenidos: ${planesCompletos.length}");

      Set<String> nivelesSet = {};
      Set<String> tiposLaborSet = {};
      Set<String> laboresSet = {};
      Set<String> alasSet = {};

      for (var plan in planesCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false)
          tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      setState(() {
        opcionesNivel = nivelesSet.toList()..sort();
        opcionesTipoLabor = tiposLaborSet.toList()..sort();
        opcionesLabor = laboresSet.toList()..sort();
        opcionesAla = alasSet.toList()..sort();

        // Inicializar listas filtradas
        filteredTiposLabor = List.from(opcionesTipoLabor);
        filteredLabores = List.from(opcionesLabor);
        filteredAlas = List.from(opcionesAla);
        filteredNiveles = List.from(opcionesNivel); 
      });

      print('Niveles cargados: $opcionesNivel');
      print('Tipos Labor cargados: $opcionesTipoLabor');
      print('Labores cargados: $opcionesLabor');
      print('Alas cargados: $opcionesAla');
    } catch (e) {
      print("Error cargando planes mensuales: $e");
      // Fallback con datos de ejemplo
      setState(() {
        opcionesNivel = ['Nivel 1', 'Nivel 2', 'Nivel 3', 'Nivel 4'];
        opcionesTipoLabor = [
          'Galería',
          'Crucero',
          'Rampa',
          'Chimenea',
          'Subterráneo',
        ];
        opcionesLabor = ['Labor A', 'Labor B', 'Labor C', 'Labor D'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];

        filteredTiposLabor = List.from(opcionesTipoLabor);
        filteredLabores = List.from(opcionesLabor);
        filteredAlas = List.from(opcionesAla);
      });
    }
  }

  void _onTipoLaborChanged(String? nuevoTipoLabor) {
    setState(() {
      tipoLaborSeleccionado = nuevoTipoLabor;
      laborSeleccionado = null;
      alaSeleccionado = null;
      nivelSeleccionado = null;
      _actualizarFiltros();
    });
  }

  void _onLaborChanged(String? nuevoLabor) {
    setState(() {
      laborSeleccionado = nuevoLabor;
      alaSeleccionado = null;
      nivelSeleccionado = null;
      _actualizarFiltros();
    });
  }

  void _onAlaChanged(String? nuevoAla) {
    setState(() {
      alaSeleccionado = nuevoAla;
      nivelSeleccionado = null;
      _actualizarFiltros();
    });
  }

  // Actualizar filtros en cascada basados en selecciones
  void _actualizarFiltros() {
    // Filtrar Labores basado en Tipo Labor
    if (tipoLaborSeleccionado != null) {
      Set<String> laboresFiltrados = {};
      for (var plan in planesCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      filteredLabores = laboresFiltrados.toList()..sort();
    } else {
      filteredLabores = List.from(opcionesLabor);
    }

    // Filtrar Alas basado en Tipo Labor y Labor
    if (tipoLaborSeleccionado != null && laborSeleccionado != null) {
      Set<String> alasFiltrados = {};
      for (var plan in planesCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      filteredAlas = alasFiltrados.toList()..sort();
    } else {
      filteredAlas = List.from(opcionesAla);
    }

    // Filtrar Niveles (INTERNO, NO VISIBLE)
    if (tipoLaborSeleccionado != null && laborSeleccionado != null) {
      Set<String> nivelesFiltrados = {};

      for (var plan in planesCompletos) {
        bool coincideBase =
            plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado;

        bool coincideAla =
            alaSeleccionado == null ||
            alaSeleccionado!.isEmpty ||
            plan.ala == alaSeleccionado;

        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }

      filteredNiveles = nivelesFiltrados.toList()..sort();

      // Auto seleccionar nivel internamente
      if (filteredNiveles.isNotEmpty) {
        if (nivelSeleccionado == null ||
            !filteredNiveles.contains(nivelSeleccionado)) {
          nivelSeleccionado = filteredNiveles.first;
        }
      } else {
        nivelSeleccionado = null;
      }
    } else {
      filteredNiveles = List.from(opcionesNivel);
      if (tipoLaborSeleccionado == null || laborSeleccionado == null) {
        nivelSeleccionado = null;
      }
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // Campos de ubicación (de PlanMensual)
        tipoLaborSeleccionado =
            widget.datosIniciales!['tipo_labor']?.isNotEmpty == true
            ? widget.datosIniciales!['tipo_labor']
            : null;
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true
            ? widget.datosIniciales!['labor']
            : null;
        alaSeleccionado = widget.datosIniciales!['ala']?.isNotEmpty == true
            ? widget.datosIniciales!['ala']
            : null;
        nivelSeleccionado = widget.datosIniciales!['nivel']?.isNotEmpty == true
            ? widget.datosIniciales!['nivel']
            : null;

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

      // Después de cargar, actualizar filtros
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltros();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      // Campos de ubicación (de PlanMensual)
      'tipo_labor': tipoLaborSeleccionado ?? '',
      'labor': laborSeleccionado ?? '',
      'ala': alaSeleccionado ?? '',
      'nivel': nivelSeleccionado ?? '',

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000, // Un poco más angosto ya que tenemos menos campos
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // SECCIÓN 1: Ubicación (con datos de PlanMensual)
                          _buildSeccionCompacta(
                            icon: Icons.location_on,
                            titulo: 'Ubicación',
                            children: [
                              _buildCompactDropdownField(
                                label: 'Tipo Labor', // 1º
                                value: tipoLaborSeleccionado,
                                items: filteredTiposLabor,
                                onChanged: isEditable
                                    ? _onTipoLaborChanged
                                    : null,
                                icon: Icons.construction,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Labor', // 2º
                                value: laborSeleccionado,
                                items: filteredLabores,
                                onChanged:
                                    (tipoLaborSeleccionado != null &&
                                        isEditable)
                                    ? _onLaborChanged
                                    : null,
                                icon: Icons.factory,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Ala', // 3º
                                value: alaSeleccionado,
                                items: filteredAlas,
                                onChanged:
                                    (laborSeleccionado != null && isEditable)
                                    ? _onAlaChanged
                                    : null,
                                icon: Icons.compare_arrows,
                              ),
                            ],
                          ),

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
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                child: const SizedBox.shrink(),
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
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                child: const SizedBox.shrink(),
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
          const Text(
            'Formulario de Empernador',
            style: TextStyle(
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
