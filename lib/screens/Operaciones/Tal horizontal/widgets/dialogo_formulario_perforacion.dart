import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/TipoPerforacion.dart';

class DialogoFormularioPerforacion extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;
  final String codigo; 

  const DialogoFormularioPerforacion({
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
  State<DialogoFormularioPerforacion> createState() =>
      _DialogoFormularioPerforacionState();
}

class _DialogoFormularioPerforacionState
    extends State<DialogoFormularioPerforacion> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // Controlador para ubicación combinada
  final TextEditingController ubicacionController = TextEditingController();
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // Variable para la ubicación seleccionada (cadena combinada)
  String? laborSeleccionado;

  // Controladores para los campos de texto
  final TextEditingController talProdController = TextEditingController();
  final TextEditingController talRimadosController = TextEditingController();
  final TextEditingController talAlivioController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // Opciones combinadas para el buscador
  List<String> opcionesUbicacionCombinadas = [];
  List<String> opcionesUbicacionFiltradas = [];

  // Opciones para otros dropdowns
  List<String> opcionesTipoPerforacion = [];
  List<String> opcionesLongitudBarras = [];

  // Materiales
  List<Map<String, dynamic>> materialesDisponibles = [{'nombre': 'MINERAL'}, {'nombre': 'DESMONTE'}];
  String? materialSeleccionado;

  // Almacenar objetos completos
   List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];
  List<TipoPerforacion> tiposPerforacionCompletos = [];

  // Variables para otros campos
  String? tipoPerforacionSeleccionado;
  String? longitudBarraSeleccionada;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
    print('Código: ${widget.codigo}');
  }

  bool get _debeMostrarDatosPerforacion  {
  // Códigos que NO deben mostrar cucharas: 111 y 112
  final codigosOmitir = ['103', '104', '105', '106', '107'];
  
  // Convertir a string para comparar
  final codigoStr = widget.codigo.toString();
  
  return !codigosOmitir.contains(codigoStr);
}


  Future<void> _cargarDatosDesdeBD() async {
    setState(() => isLoading = true);

    try {
      await Future.wait([
        _cargarPlanesCombinados(),
        _cargarTiposPerforacion(),
        _cargarLongitudBarras(),
      ]);
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cargarLongitudBarras() async {
    try {
      final dbHelper = DatabaseHelper();
      final data = await dbHelper.getLongitudBarrasPorProceso(
        "PERFORACIÓN HORIZONTAL",
      );

      final lista = data.map((e) => e['longitud_pies'].toString()).toSet().toList()
        ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));

      setState(() {
        opcionesLongitudBarras = lista;
      });
    } catch (e) {
      print("Error cargando longitudes: $e");
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

      // Generar opciones combinadas para ubicación
      _generarOpcionesUbicacion();
      
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

   void _generarOpcionesUbicacion() {
    Set<String> opcionesCombinadas = {};
    
    // Combinar datos de PlanMensual
    for (var plan in planesMensualCompletos) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }
    
    // Combinar datos de PlanProduccion
    for (var plan in planesProduccionCompletos) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }
    
    // Combinar datos de PlanMetraje
    for (var plan in planesMetrajeCompletos) {
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


  Future<void> _cargarTiposPerforacion() async {
    try {
      final dbHelper = DatabaseHelper();
      tiposPerforacionCompletos = await dbHelper.getTiposPerforacionByProceso(
        "PERFORACIÓN HORIZONTAL",
      );

      final lista = tiposPerforacionCompletos
          .map((t) => t.nombre ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        opcionesTipoPerforacion = lista;
      });
    } catch (e) {
      print("Error cargando tipos de perforación: $e");
      setState(() {
        opcionesTipoPerforacion = ['Perforación 1', 'Perforación 2', 'Perforación 3', 'Perforación 4'];
      });
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true
            ? widget.datosIniciales!['labor']
            : null;

        if (laborSeleccionado != null) {
          ubicacionController.text = laborSeleccionado!;
        }

        talProdController.text = widget.datosIniciales!['tal_prod'] ?? '';
        talRimadosController.text = widget.datosIniciales!['tal_rimados'] ?? '';
        talAlivioController.text = widget.datosIniciales!['tal_alivio'] ?? '';
        longitudBarraSeleccionada = widget.datosIniciales!['long_barras']?.toString();
        tipoPerforacionSeleccionado = widget.datosIniciales!['tipo_perforacion']?.isNotEmpty == true
            ? widget.datosIniciales!['tipo_perforacion']
            : null;
        materialSeleccionado = widget.datosIniciales!['material']?.isNotEmpty == true
            ? widget.datosIniciales!['material']
            : null;
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
    }
  }

Future<void> _guardarDatos() async {

  // 🔥 CAMBIO IMPORTANTE: Permitir texto libre si no hay selección
  String laborFinal = laborSeleccionado ?? '';
  
  // Si no hay labor seleccionada pero hay texto en el campo, usar ese texto
  if (laborFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
    laborFinal = ubicacionController.text.trim();
  }
  
  if (laborFinal.isEmpty) {
    _mostrarSnackbar('Debe ingresar o seleccionar una ubicación', Colors.orange);
    return;
  }

  Map<String, dynamic> datosFormulario = {
    'labor': laborFinal,  // Usar el texto final (sea seleccionado o escrito)
    'tal_prod': talProdController.text,
    'tal_rimados': talRimadosController.text,
    'tal_alivio': talAlivioController.text,
    'long_barras': longitudBarraSeleccionada ?? '',
    'tipo_perforacion': tipoPerforacionSeleccionado ?? '',
    'tipo_perforacion_id': _obtenerIdTipoPerforacion(tipoPerforacionSeleccionado),
    'material': materialSeleccionado ?? '',
    'observaciones': observacionesController.text,
  };

  widget.onGuardar(datosFormulario);
  _mostrarSnackbar('Formulario guardado correctamente', Colors.green);
  Navigator.pop(context);
}
  int? _obtenerIdTipoPerforacion(String? nombre) {
    if (nombre == null) return null;
    try {
      return tiposPerforacionCompletos.firstWhere((tipo) => tipo.nombre == nombre).id;
    } catch (e) {
      return null;
    }
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
    talProdController.dispose();
    talRimadosController.dispose();
    talAlivioController.dispose();
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
                          if (_debeMostrarDatosPerforacion) ...[
              const SizedBox(height: 12),
              _buildSeccionTaladros(),
              const SizedBox(height: 12),
              _buildSeccionBarrasYMaterial(),
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

  // SECCIÓN 1: Ubicación
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
                'Labor',
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
        // Coincidencia exacta: mostrar sugerencias
        mostrarSugerencias = true;
      } else if (opcionesUbicacionFiltradas.isNotEmpty) {
        // Hay sugerencias disponibles: mostrar
        mostrarSugerencias = true;
      } else {
        // Sin sugerencias: es texto libre
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
        ],
      ),
    );
  }

  Widget _buildSeccionTaladros() {
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
                child: const Icon(Icons.golf_course, size: 12, color: Colors.orange),
              ),
              const SizedBox(width: 6),
              const Text(
                'Taladros',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 6),
          isSmallScreen
              ? Column(
                  children: [
                    _buildCompactTextField('Producción', talProdController, Icons.calculate),
                    const SizedBox(height: 6),
                    _buildCompactTextField('Rimados', talRimadosController, Icons.calculate),
                    const SizedBox(height: 6),
                    _buildCompactTextField('Alivio', talAlivioController, Icons.calculate),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildCompactTextField('Producción', talProdController, Icons.calculate)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCompactTextField('Rimados', talRimadosController, Icons.calculate)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCompactTextField('Alivio', talAlivioController, Icons.calculate)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSeccionBarrasYMaterial() {
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.height, size: 12, color: Colors.purple),
              ),
              const SizedBox(width: 6),
              const Text(
                'Barras y Material',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 6),
          isSmallScreen
              ? Column(
                  children: [
                    _buildCompactDropdownField(
                      label: 'Longitud (pies)',
                      value: longitudBarraSeleccionada,
                      items: opcionesLongitudBarras,
                      onChanged: isEditable
                          ? (value) => setState(() => longitudBarraSeleccionada = value)
                          : null,
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 6),
                    _buildCompactDropdownField(
                      label: 'Material',
                      value: materialSeleccionado,
                      items: materialesDisponibles.map((m) => m['nombre'] as String).toList(),
                      onChanged: isEditable
                          ? (value) => setState(() => materialSeleccionado = value)
                          : null,
                      icon: Icons.inventory_2,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildCompactDropdownField(
                        label: 'Longitud (pies)',
                        value: longitudBarraSeleccionada,
                        items: opcionesLongitudBarras,
                        onChanged: isEditable
                            ? (value) => setState(() => longitudBarraSeleccionada = value)
                            : null,
                        icon: Icons.straighten,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactDropdownField(
                        label: 'Material',
                        value: materialSeleccionado,
                        items: materialesDisponibles.map((m) => m['nombre'] as String).toList(),
                        onChanged: isEditable
                            ? (value) => setState(() => materialSeleccionado = value)
                            : null,
                        icon: Icons.inventory_2,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSeccionTipoPerforacion() {
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
                child: const Icon(Icons.settings_input_component, size: 12, color: Colors.blue),
              ),
              const SizedBox(width: 6),
              const Text(
                'Tipo Perforación',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildCompactDropdownField(
            label: 'Seleccione tipo',
            value: tipoPerforacionSeleccionado,
            items: opcionesTipoPerforacion,
            onChanged: isEditable
                ? (value) => setState(() => tipoPerforacionSeleccionado = value)
                : null,
            icon: Icons.settings_input_component,
          ),
        ],
      ),
    );
  }

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
                hintText: 'Ingrese observaciones...',
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

  Widget _buildCompactTextField(String label, TextEditingController controller, IconData icon) {
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
            keyboardType: TextInputType.number,
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
              isSmallScreen ? 'Perforación' : 'Formulario de Perforación',
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
          Container(width: 5, height: 5, decoration: BoxDecoration(color: isEditable ? Colors.green : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(isEditable ? 'EDITABLE' : 'LECTURA', style: TextStyle(color: isEditable ? Colors.green : Colors.grey, fontSize: 8, fontWeight: FontWeight.w600)),
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
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: Size.zero),
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
                  Text('Guardar', style: TextStyle(fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}