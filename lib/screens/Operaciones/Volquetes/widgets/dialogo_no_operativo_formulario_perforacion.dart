import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioNoOpeVolquetes extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioNoOpeVolquetes({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);
  
  @override
  State<DialogoFormularioNoOpeVolquetes> createState() => _DialogoFormularioNoPerforacionState();
}

class _DialogoFormularioNoPerforacionState extends State<DialogoFormularioNoOpeVolquetes> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Para el buscador de ubicación
  final TextEditingController ubicacionController = TextEditingController();
  List<String> opcionesUbicacion = [];
  List<String> opcionesUbicacionFiltradas = [];
  FocusNode ubicacionFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // Variable para la ubicación seleccionada (cadena combinada) - AHORA ES LO QUE SE GUARDA
  String? ubicacionSeleccionado;

  // Almacenar objetos completos
  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];
  
  // Almacenar orígenes de SCOOPTRAM
  List<Map<String, dynamic>> origenesScooptram = [];

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
        dbHelper.getOrigenDestino('SCOOPTRAM', 'ORIGEN'),
      ]);
      
      planesMensualCompletos = results[0] as List<PlanMensual>;
      planesProduccionCompletos = results[1] as List<PlanProduccion>;
      planesMetrajeCompletos = results[2] as List<PlanMetraje>;
      origenesScooptram = results[3] as List<Map<String, dynamic>>;

      // Generar opciones combinadas
      _generarOpcionesUbicacion();
      
    } catch (e) {
      print("Error cargando planes: $e");
      setState(() {
        opcionesUbicacion = [
          'Galería_Labor01_AlaNorte',
          'Galería_Labor02_AlaSur',
          'Crucero_Labor03_AlaEste',
          'Origen_SCOOPTRAM'
        ];
        opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
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
    
    // Agregar orígenes de SCOOPTRAM como opciones individuales
    for (var origen in origenesScooptram) {
      if (origen['nombre'] != null && origen['nombre'].toString().isNotEmpty) {
        opcionesCombinadas.add(origen['nombre']);
      }
    }
    
    setState(() {
      opcionesUbicacion = opcionesCombinadas.toList()..sort();
      opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
    });
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // 🔥 SIMPLIFICADO: Ahora solo cargamos el campo 'labor_inicio' que contiene la cadena completa
        ubicacionSeleccionado = widget.datosIniciales!['labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_inicio'] 
            : null;
        
        if (ubicacionSeleccionado != null) {
          ubicacionController.text = ubicacionSeleccionado!;
        }
        
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
    }
  }

  Future<void> _guardarDatos() async {
    // Obtener la ubicación final (texto libre o seleccionado)
    String ubicacionFinal = ubicacionSeleccionado ?? '';
    
    // Si no hay ubicación seleccionada pero hay texto en el campo, usar ese texto
    if (ubicacionFinal.isEmpty && ubicacionController.text.trim().isNotEmpty) {
      ubicacionFinal = ubicacionController.text.trim();
    }
    
    if (ubicacionFinal.isEmpty) {
      _mostrarSnackbar('Debe ingresar o seleccionar una ubicación', Colors.orange);
      return;
    }

    // 🔥 SIMPLIFICADO: Solo guardamos el campo 'labor_inicio' con la cadena completa
    Map<String, dynamic> datosFormulario = {
      'labor_inicio': ubicacionFinal,  // Guardamos la cadena completa (ej: "Galería_LaborA_AlaNorte")
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
    
    final dialogWidth = isSmallScreen 
        ? screenWidth * 0.95
        : 800.0;
    
    final dialogHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.85
        : 700.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: dialogHeight,
          maxWidth: 800,
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
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSeccionUbicacion(),
                          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(12),
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
                'Ubicación (TipoLabor_Labor_Ala)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Campo de búsqueda con autocompletado
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
                  prefixIcon: Icon(Icons.search, size: 18, color: widget.primaryColor),
                  suffixIcon: ubicacionController.text.isNotEmpty && isEditable
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                          onPressed: () {
                            ubicacionController.clear();
                            setState(() {
                              opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
                              mostrarSugerencias = false;
                              ubicacionSeleccionado = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (text) {
                  setState(() {
                    if (text.isEmpty) {
                      opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
                      mostrarSugerencias = false;
                      ubicacionSeleccionado = null;
                      return;
                    }
                    
                    // Filtrar sugerencias
                    opcionesUbicacionFiltradas = opcionesUbicacion
                        .where((item) => item.toLowerCase().contains(text.toLowerCase()))
                        .toList();
                    
                    // Verificar si es match exacto
                    final esMatchExacto = opcionesUbicacion
                        .any((item) => item.toLowerCase() == text.toLowerCase());
                    
                    if (esMatchExacto) {
                      mostrarSugerencias = true;
                    } else if (opcionesUbicacionFiltradas.isNotEmpty) {
                      mostrarSugerencias = true;
                    } else {
                      ubicacionSeleccionado = text;
                      mostrarSugerencias = false;
                    }
                  });
                },
                onTap: () {
                  setState(() {
                    mostrarSugerencias = true;
                    if (ubicacionController.text.isEmpty) {
                      opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
                    }
                  });
                },
              ),
              
              // Lista de sugerencias
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
                  constraints: const BoxConstraints(maxHeight: 200),
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
                            ubicacionSeleccionado = suggestion;
                            ubicacionController.text = suggestion;
                            mostrarSugerencias = false;
                          });
                        },
                      );
                    },
                  ),
                ),
                
              // Badge de selección (solo cuando hay selección y campo vacío)
              if (ubicacionSeleccionado != null && 
                  ubicacionSeleccionado!.isNotEmpty && 
                  ubicacionController.text.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: widget.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ubicacionSeleccionado!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEditable)
                        InkWell(
                          onTap: () {
                            setState(() {
                              ubicacionSeleccionado = null;
                              ubicacionController.clear();
                              opcionesUbicacionFiltradas = List.from(opcionesUbicacion);
                            });
                          },
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          
          if (opcionesUbicacion.isEmpty && !isLoading)
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
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.comment, size: 16, color: widget.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Observaciones',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: observacionesController,
            enabled: isEditable,
            maxLines: isSmallScreen ? 4 : 3,
            decoration: InputDecoration(
              hintText: 'Escriba observaciones adicionales...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
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
            child: Icon(Icons.description, color: Colors.white, size: isSmallScreen ? 16 : 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSmallScreen ? 'Formulario No Operativo' : 'Formulario de ACARREO No Operativo',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 16,
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
              fontSize: isSmallScreen ? 8 : 10,
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
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}