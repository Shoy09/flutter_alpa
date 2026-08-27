import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioPerforacion extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioPerforacion({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);
  
  @override
  State<DialogoFormularioPerforacion> createState() => _DialogoFormularioPerforacionState();
}

class _DialogoFormularioPerforacionState extends State<DialogoFormularioPerforacion> {
  bool isEditable = false;
  bool isLoading = true;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Variables para INICIO (vienen de PlanMensual)
  String? nivelInicioSeleccionado;
  String? tipoLaborInicioSeleccionado;
  String? laborInicioSeleccionado;
  String? alaInicioSeleccionado;

  // Variable para DESTINO (viene de tabla origen_destino)
  String? ubicacionDestinoSeleccionado;
  int? ubicacionDestinoId;  // Guardar el ID del destino seleccionado

  // Número de cucharas
  final TextEditingController nCucharasController = TextEditingController();

  // Opciones para los dropdowns (de PlanMensual)
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];
  
  // Opciones para ubicación destino (desde tabla origen_destino)
  List<Map<String, dynamic>> destinosDisponibles = [];
  List<String> opcionesUbicacionDestino = [];

  // Listas filtradas para INICIO
  List<String> filteredTiposLaborInicio = [];
  List<String> filteredLaboresInicio = [];
  List<String> filteredAlasInicio = [];

  // Almacenar objetos completos para referencia
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

  Future<void> _cargarDatosDesdeBD() async {
    setState(() => isLoading = true);
    
    try {
      await Future.wait([
        _cargarPlanesCombinados(),  // Para ubicación INICIO
        _cargarDestinosDUMPER(),     // Para ubicación DESTINO
      ]);
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> _cargarDestinosDUMPER() async {
  try {
    final dbHelper = DatabaseHelper();

    destinosDisponibles = await dbHelper.getOrigenDestino(
      'DUMPER',
      'DESTINO',
    );

    setState(() {
      opcionesUbicacionDestino = destinosDisponibles
          .map((destino) => destino['nombre'] as String)
          .toList();
    });

    print("Destinos DUMPER cargados: ${destinosDisponibles.length}");
  } catch (e) {
    print("Error cargando destinos DUMPER: $e");
    setState(() {
      opcionesUbicacionDestino = [];
    });
  }
}

  // Cargar planes mensuales y construir opciones únicas
  Future<void> _cargarPlanesCombinados() async {
    try {
      final dbHelper = DatabaseHelper();
      
      // Cargar las tres tablas en paralelo
      final results = await Future.wait([
        dbHelper.getPlanesMensual(),
        dbHelper.getPlanesProduccion(),
        dbHelper.getPlanesMetraje(),
        dbHelper.getOrigenDestino('DUMPER', 'ORIGEN'),
      ]);
      
      planesMensualCompletos = results[0] as List<PlanMensual>;
      planesProduccionCompletos = results[1] as List<PlanProduccion>;
      planesMetrajeCompletos = results[2] as List<PlanMetraje>;
      final origenes = results[3] as List<Map<String, dynamic>>;

      print("Planes Mensual obtenidos: ${planesMensualCompletos.length}");
      print("Planes Producción obtenidos: ${planesProduccionCompletos.length}");
      print("Planes Metraje obtenidos: ${planesMetrajeCompletos.length}");

      Set<String> nivelesSet = {};
      Set<String> tiposLaborSet = {};
      Set<String> laboresSet = {};
      Set<String> alasSet = {};

      // Procesar PlanMensual
      for (var plan in planesMensualCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      // Procesar PlanProduccion
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      // Procesar PlanMetraje
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      for (var origen in origenes) {
  if (origen['nombre'] != null && origen['nombre'].toString().isNotEmpty) {
    nivelesSet.add(origen['nombre']);
  }
}

      setState(() {
        opcionesNivel = nivelesSet.toList()..sort();
        opcionesTipoLabor = tiposLaborSet.toList()..sort();
        opcionesLabor = laboresSet.toList()..sort();
        opcionesAla = alasSet.toList()..sort();

        // Inicializar listas filtradas
        filteredTiposLaborInicio = List.from(opcionesTipoLabor);
        filteredLaboresInicio = List.from(opcionesLabor);
        filteredAlasInicio = List.from(opcionesAla);
      });

    } catch (e) {
      print("Error cargando planes combinados: $e");
      // Fallback con datos de ejemplo
      setState(() {
        opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
        opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
        
        filteredTiposLaborInicio = List.from(opcionesTipoLabor);
        filteredLaboresInicio = List.from(opcionesLabor);
        filteredAlasInicio = List.from(opcionesAla);
      });
    }
  }

  // Actualizar filtros de INICIO
  void _actualizarFiltrosInicio() {
    // Filtrar tipos de labor basados en nivel seleccionado
    if (nivelInicioSeleccionado != null) {
      Set<String> tiposLaborFiltrados = {};
      
      // Buscar en PlanMensual
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      
      // Buscar en PlanProduccion
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      
      // Buscar en PlanMetraje
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      
      filteredTiposLaborInicio = tiposLaborFiltrados.toList()..sort();
    } else {
      filteredTiposLaborInicio = List.from(opcionesTipoLabor);
    }

    // Filtrar labores basados en nivel y tipo labor
    if (nivelInicioSeleccionado != null && tipoLaborInicioSeleccionado != null) {
      Set<String> laboresFiltrados = {};
      
      // Buscar en PlanMensual
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      // Buscar en PlanProduccion
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      // Buscar en PlanMetraje
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      filteredLaboresInicio = laboresFiltrados.toList()..sort();
    } else {
      filteredLaboresInicio = List.from(opcionesLabor);
    }

    // Filtrar alas basados en nivel, tipo labor y labor
    if (nivelInicioSeleccionado != null && 
        tipoLaborInicioSeleccionado != null && 
        laborInicioSeleccionado != null) {
      Set<String> alasFiltrados = {};
      
      // Buscar en PlanMensual
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            plan.labor == laborInicioSeleccionado && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      // Buscar en PlanProduccion
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            plan.labor == laborInicioSeleccionado && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      // Buscar en PlanMetraje
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivelInicioSeleccionado && 
            plan.tipoLabor == tipoLaborInicioSeleccionado && 
            plan.labor == laborInicioSeleccionado && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      filteredAlasInicio = alasFiltrados.toList()..sort();
    } else {
      filteredAlasInicio = List.from(opcionesAla);
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // Campos de INICIO
        nivelInicioSeleccionado = widget.datosIniciales!['nivel_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['nivel_inicio'] 
            : null;
        tipoLaborInicioSeleccionado = widget.datosIniciales!['tipo_labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['tipo_labor_inicio'] 
            : null;
        laborInicioSeleccionado = widget.datosIniciales!['labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_inicio'] 
            : null;
        alaInicioSeleccionado = widget.datosIniciales!['ala_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['ala_inicio'] 
            : null;

        // Ubicación destino (desde tabla origen_destino)
        ubicacionDestinoId = widget.datosIniciales!['ubicacion_destino_id'];
        ubicacionDestinoSeleccionado = widget.datosIniciales!['ubicacion_destino'];
        
        // Número de cucharas
        nCucharasController.text = widget.datosIniciales!['n_cucharas']?.toString() ?? '0';
        
        // Observaciones
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
      
      // Después de cargar, actualizar filtros
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltrosInicio();
      });
    }
  }

  Future<void> _guardarDatos() async {
    // Encontrar el ID del destino seleccionado
    int? destinoId;
    if (ubicacionDestinoSeleccionado != null) {
      final destinoEncontrado = destinosDisponibles.firstWhere(
        (destino) => destino['nombre'] == ubicacionDestinoSeleccionado,
        orElse: () => {},
      );
      destinoId = destinoEncontrado['id'];
    }
    
    Map<String, dynamic> datosFormulario = {
      // Campos de INICIO
      'nivel_inicio': nivelInicioSeleccionado ?? '',
      'tipo_labor_inicio': tipoLaborInicioSeleccionado ?? '',
      'labor_inicio': laborInicioSeleccionado ?? '',
      'ala_inicio': alaInicioSeleccionado ?? '',
      
      // Ubicación destino (guardamos ID y nombre)
      'ubicacion_destino_id': destinoId ?? 0,
      'ubicacion_destino': ubicacionDestinoSeleccionado ?? '',
      
      // Número de cucharas
      'n_cucharas': int.tryParse(nCucharasController.text) ?? 0,
      
      // Observaciones
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
    nCucharasController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 1000,
        constraints: const BoxConstraints(
          maxHeight: 700,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECCIÓN 1: Ubicación INICIO
                          _buildSeccionUbicacionInicio(),
                          
                          const SizedBox(height: 16),
                          
                          // SECCIÓN 2: Ubicación DESTINO (desde tabla origen_destino)
                          _buildSeccionUbicacionDestino(),
                          
                          const SizedBox(height: 16),
                          
                          // SECCIÓN 3: Número de Cucharas
                          _buildSeccionCucharas(),
                          
                          const SizedBox(height: 16),
                          
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

  Widget _buildSeccionUbicacionInicio() {
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.play_circle_outline, size: 14, color: Colors.green),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ubicación INICIO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Nivel',
                  value: nivelInicioSeleccionado,
                  items: opcionesNivel,
                  onChanged: isEditable ? (value) {
                    setState(() {
                      nivelInicioSeleccionado = value;
                      tipoLaborInicioSeleccionado = null;
                      laborInicioSeleccionado = null;
                      alaInicioSeleccionado = null;
                      _actualizarFiltrosInicio();
                    });
                  } : null,
                  icon: Icons.stairs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Tipo Labor',
                  value: tipoLaborInicioSeleccionado,
                  items: filteredTiposLaborInicio,
                  onChanged: (nivelInicioSeleccionado != null && isEditable) 
                      ? (value) {
                          setState(() {
                            tipoLaborInicioSeleccionado = value;
                            laborInicioSeleccionado = null;
                            alaInicioSeleccionado = null;
                            _actualizarFiltrosInicio();
                          });
                        } 
                      : null,
                  icon: Icons.construction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Labor',
                  value: laborInicioSeleccionado,
                  items: filteredLaboresInicio,
                  onChanged: (tipoLaborInicioSeleccionado != null && isEditable) 
                      ? (value) {
                          setState(() {
                            laborInicioSeleccionado = value;
                            alaInicioSeleccionado = null;
                            _actualizarFiltrosInicio();
                          });
                        } 
                      : null,
                  icon: Icons.factory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Ala',
                  value: alaInicioSeleccionado,
                  items: filteredAlasInicio,
                  onChanged: (laborInicioSeleccionado != null && isEditable) 
                      ? (value) => setState(() => alaInicioSeleccionado = value) 
                      : null,
                  icon: Icons.compare_arrows,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionUbicacionDestino() {
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.location_on, size: 14, color: Colors.orange),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ubicación DESTINO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'DUMPER',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactDropdownField(
            label: 'Seleccionar destino',
            value: ubicacionDestinoSeleccionado,
            items: opcionesUbicacionDestino,
            onChanged: isEditable ? (value) => setState(() => ubicacionDestinoSeleccionado = value) : null,
            icon: Icons.flag,
          ),
          if (opcionesUbicacionDestino.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay destinos disponibles para proceso "DUMPER"',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionCucharas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.calculate, size: 14, color: widget.primaryColor),
          ),
          const SizedBox(width: 6),
          Text(
            'N° Cucharas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 42,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: nCucharasController,
                enabled: isEditable,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ingrese número',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: observacionesController,
            enabled: isEditable,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escriba observaciones adicionales...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: widget.primaryColor),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
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
            child: const Icon(Icons.description, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Formulario de Perforación',
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
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: widget.primaryColor),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ]
              : items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
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
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
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