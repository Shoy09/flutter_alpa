import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioNoOpePerforacion extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioNoOpePerforacion({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);
  
  @override
  State<DialogoFormularioNoOpePerforacion> createState() => _DialogoFormularioNoPerforacionState();
}

class _DialogoFormularioNoPerforacionState extends State<DialogoFormularioNoOpePerforacion> {
    bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // Controlador para ubicación combinada
  final TextEditingController ubicacionController = TextEditingController();
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // Variable para la ubicación seleccionada (cadena combinada) - AHORA ES LO QUE SE GUARDA
  String? laborSeleccionado;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Opciones combinadas para el buscador
  List<String> opcionesUbicacionCombinadas = [];
  List<String> opcionesUbicacionFiltradas = [];
   List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];
  // Almacenar objetos completos
  List<PlanMensual> planesCompletos = [];

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

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      // 🔥 SIMPLIFICADO: Ahora solo cargamos el campo 'labor' que contiene la cadena completa
      setState(() {
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor'] 
            : null;
        
        if (laborSeleccionado != null) {
          ubicacionController.text = laborSeleccionado!;
        }
        
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
    }
  }

  Future<void> _guardarDatos() async {
    // Obtener el labor final (texto libre o seleccionado)
    String laborFinal = laborSeleccionado ?? '';
    
    // Si no hay labor seleccionada pero hay texto en el campo, usar ese texto
    if (laborFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
      laborFinal = ubicacionController.text.trim();
    }
    
    if (laborFinal.isEmpty) {
      _mostrarSnackbar('Debe ingresar o seleccionar una ubicación', Colors.orange);
      return;
    }

    // 🔥 SIMPLIFICADO: Solo guardamos el campo 'labor' con la cadena completa
    Map<String, dynamic> datosFormulario = {
      'labor': laborFinal,  // Guardamos la cadena completa (ej: "Galería_LaborA_AlaNorte")
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
            ? const Center(
                child: CircularProgressIndicator(),
              )
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
              
              // Badge de selección (solo cuando hay selección y campo vacío)
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 10),
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
              isSmallScreen ? 'No Operativa' : 'Formulario de Perforación No Operativa',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isSmallScreen ? 11 : 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
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