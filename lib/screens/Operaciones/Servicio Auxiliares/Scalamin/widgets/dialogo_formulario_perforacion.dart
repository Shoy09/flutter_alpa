import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/TipoLabor.dart';

class DialogoFormularioScalamin extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioScalamin({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);

  @override
  State<DialogoFormularioScalamin> createState() => _DialogoFormularioScalaminState();
}

class _DialogoFormularioScalaminState extends State<DialogoFormularioScalamin> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // 🔥 Controlador para ubicación combinada
  final TextEditingController ubicacionController = TextEditingController();
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // 🔥 Variable para la ubicación seleccionada (cadena combinada)
  String? laborSeleccionado;

  // 🔥 CONTROLADORES PARA LOS CAMPOS ADICIONALES
  final TextEditingController metrosLinealesController = TextEditingController();
  final TextEditingController areaM2Controller = TextEditingController();
  // ❌ ELIMINAMOS tipoLaborTextoController porque ahora será dropdown
  // final TextEditingController tipoLaborTextoController = TextEditingController();

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // 🔥 Opciones combinadas para el buscador
  List<String> opcionesUbicacionCombinadas = [];
  List<String> opcionesUbicacionFiltradas = [];
  
  // Almacenar objetos completos
  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];

  // 🔥 PARA TIPO DE LABOR (DROP DOWN)
  List<TipoLabor> tiposLaborCompletos = [];
  List<String> opcionesTipoLabor = [];
  String? tipoLaborSeleccionado;

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
      await Future.wait([
        _cargarPlanesCombinados(),
        _cargarTiposLabor(), // ✅ Cargar tipos de labor
      ]);
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ✅ MÉTODO PARA CARGAR TIPOS DE LABOR DESDE SQLite
  Future<void> _cargarTiposLabor() async {
    try {
      final dbHelper = DatabaseHelper();
      // 🔥 OBTENER POR PROCESO "Scalamin"
      tiposLaborCompletos = await dbHelper.getTiposLaborByProceso("SCALAMIN");
      
      // Extraer solo los nombres para el dropdown
      final lista = tiposLaborCompletos
          .map((t) => t.nombre ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      
      setState(() {
        opcionesTipoLabor = lista;
      });
      
      print("✅ Tipos de Labor cargados: $opcionesTipoLabor");
    } catch (e) {
      print("❌ Error cargando tipos de labor: $e");
      setState(() {
        opcionesTipoLabor = [];
      });
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

      _generarOpcionesUbicacion();
      
    } catch (e) {
      print("Error cargando planes: $e");
      setState(() {
        opcionesUbicacionCombinadas = [
          'Galería_LaborA_AlaNorte',
          'Galería_LaborA_AlaSur',
          'Crucero_LaborB_AlaEste',
          'Rampa_LaborC_AlaOeste',
          'Chimenea_LaborD_AlaNorte',
        ];
        opcionesUbicacionFiltradas = List.from(opcionesUbicacionCombinadas);
      });
    }
  }

  void _generarOpcionesUbicacion() {
    Set<String> opcionesCombinadas = {};
    
    for (var plan in planesMensualCompletos) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }
    
    for (var plan in planesProduccionCompletos) {
      String combinado = '';
      if (plan.tipoLabor?.isNotEmpty ?? false) combinado += plan.tipoLabor!;
      if (plan.labor?.isNotEmpty ?? false) combinado += '_${plan.labor!}';
      if (plan.ala?.isNotEmpty ?? false) combinado += '_${plan.ala!}';
      if (combinado.isNotEmpty) opcionesCombinadas.add(combinado);
    }
    
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

  // ✅ CARGAR DATOS INICIALES - AHORA CON DROPDOWN
  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // Cargar labor
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor'] 
            : null;
        
        if (laborSeleccionado != null) {
          ubicacionController.text = laborSeleccionado!;
        }
        
        // Cargar campos numéricos
        metrosLinealesController.text = widget.datosIniciales!['metros_lineales']?.toString() ?? '';
        areaM2Controller.text = widget.datosIniciales!['area_m2']?.toString() ?? '';
        
        // ✅ CARGAR TIPO DE LABOR DESDE tipo_labor_texto
        final tipoLaborGuardado = widget.datosIniciales!['tipo_labor_texto'] ?? '';
        if (tipoLaborGuardado.isNotEmpty) {
          tipoLaborSeleccionado = tipoLaborGuardado;
        }
        
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
    }
  }

  // ✅ GUARDAR DATOS - AHORA CON DROPDOWN
  Future<void> _guardarDatos() async {
    String laborFinal = laborSeleccionado ?? '';
    
    if (laborFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
      laborFinal = ubicacionController.text.trim();
    }
    
    Map<String, dynamic> datosFormulario = {
      'labor': laborFinal,
      'observaciones': observacionesController.text,
      'metros_lineales': double.tryParse(metrosLinealesController.text.trim()) ?? 0.0,
      'area_m2': double.tryParse(areaM2Controller.text.trim()) ?? 0.0,
      // ✅ GUARDAR EL VALOR SELECCIONADO EN tipo_labor_texto
      'tipo_labor_texto': tipoLaborSeleccionado ?? '',
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
    metrosLinealesController.dispose();
    areaM2Controller.dispose();
    // ❌ No dispose de tipoLaborTextoController porque ya no existe
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.95 : 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
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
                          const SizedBox(height: 16),
                          // ✅ AHORA USAMOS _buildSeccionDatosAdicionales CON DROPDOWN
                          _buildSeccionDatosAdicionales(),
                          const SizedBox(height: 16),
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

  // 🔥 SECCIÓN DE UBICACIÓN (sin cambios)
  Widget _buildSeccionUbicacion() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.location_on, size: 14, color: widget.primaryColor),
              ),
              const SizedBox(width: 6),
              Text(
                'Labor (TipoLabor_Labor_Ala)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ubicacionController,
                focusNode: ubicacionFocusNode,
                enabled: isEditable,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar o escribir nueva ubicación...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 18, color: widget.primaryColor),
                  suffixIcon: ubicacionController.text.isNotEmpty && isEditable
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    
                    opcionesUbicacionFiltradas = opcionesUbicacionCombinadas
                        .where((item) => item.toLowerCase().contains(text.toLowerCase()))
                        .toList();
                    
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
                  margin: const EdgeInsets.only(top: 4),
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
                          style: const TextStyle(fontSize: 12),
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
              
              if (laborSeleccionado != null && ubicacionController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: widget.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          laborSeleccionado!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.primaryColor,
                          ),
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
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
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
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ SECCIÓN DE DATOS ADICIONALES CON DROPDOWN PARA TIPO DE LABOR
  Widget _buildSeccionDatosAdicionales() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.calculate, size: 14, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 6),
              Text(
                'Datos Adicionales (Opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Opcional',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 🔥 FILA: Metros Lineales + Área
          Row(
            children: [
              // 1. Metros Lineales
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: metrosLinealesController,
                  label: 'Metros Lineales',
                  hint: '0.0',
                  icon: Icons.straighten,
                  isEnabled: isEditable,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              // 2. Área (m²)
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: areaM2Controller,
                  label: 'Área (m²)',
                  hint: '0.0',
                  icon: Icons.crop_square,
                  isEnabled: isEditable,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 🔥 3. TIPO DE LABOR - AHORA DROPDOWN (ocupa todo el ancho)
          _buildSeccionDatosScalamin(),
        ],
      ),
    );
  }

  // ✅ SECCIÓN EXCLUSIVA PARA TIPO DE LABOR (DROPDOWN)
  Widget _buildSeccionDatosScalamin() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Tipo de Labor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 🔥 DROPDOWN PARA TIPO DE LABOR
          _buildDropdownField(
            label: 'Seleccionar Tipo de Labor',
            value: tipoLaborSeleccionado,
            items: opcionesTipoLabor,
            onChanged: isEditable
                ? (value) => setState(() => tipoLaborSeleccionado = value)
                : null,
            icon: Icons.work_outline,
          ),
          if (opcionesTipoLabor.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No hay tipos de labor disponibles para Rompebanco',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ WIDGET REUTILIZABLE PARA DROPDOWN
  Widget _buildDropdownField({
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valueExists ? value : null,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: widget.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Cargando...' : label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 20, color: widget.primaryColor),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

  // 🔥 WIDGET REUTILIZABLE PARA CAMPOS DE TEXTO
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isEnabled,
    required bool isSmallScreen,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        enabled: isEnabled,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(icon, size: isSmallScreen ? 14 : 16, color: widget.primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 6 : 8,
          ),
          isDense: true,
        ),
      ),
    );
  }

  // 🔥 SECCIÓN OBSERVACIONES (sin cambios)
  Widget _buildSeccionObservaciones() {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: isSmallScreen ? 70 : 80,
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
                hintStyle: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.comment,
                    size: isSmallScreen ? 14 : 16,
                    color: widget.primaryColor.withOpacity(0.7),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 12),
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
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSmallScreen ? 'Scalamin' : 'Formulario Scalamin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildEstadoBadge(),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEditable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEditable ? Colors.green : Colors.grey, width: 0.5),
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
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 10),
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
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isEditable)
            ElevatedButton(
              onPressed: _guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: isSmallScreen ? 12 : 14),
                  const SizedBox(width: 6),
                  Text(
                    'Guardar',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}