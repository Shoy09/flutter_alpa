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
  bool isSmallScreen = false;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();
  
  // Controlador para número de viajes
  final TextEditingController nViajesController = TextEditingController();

  // Variables para INICIO
  String? nivelInicioSeleccionado;
  String? tipoLaborInicioSeleccionado;
  String? laborInicioSeleccionado;
  String? alaInicioSeleccionado;

  // Variables para FIN
  String? nivelFinSeleccionado;
  String? tipoLaborFinSeleccionado;
  String? laborFinSeleccionado;
  String? alaFinSeleccionado;

  // Opciones para los dropdowns
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];
  
  // Listas filtradas para INICIO
  List<String> filteredTiposLaborInicio = [];
  List<String> filteredLaboresInicio = [];
  List<String> filteredAlasInicio = [];
  
  // Listas filtradas para FIN
  List<String> filteredTiposLaborFin = [];
  List<String> filteredLaboresFin = [];
  List<String> filteredAlasFin = [];

  // Almacenar objetos completos
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

      Set<String> nivelesSet = {};
      Set<String> tiposLaborSet = {};
      Set<String> laboresSet = {};
      Set<String> alasSet = {};

      for (var plan in planesMensualCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      for (var plan in planesProduccionCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
      }

      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel?.isNotEmpty ?? false) nivelesSet.add(plan.nivel!);
        if (plan.tipoLabor?.isNotEmpty ?? false) tiposLaborSet.add(plan.tipoLabor!);
        if (plan.labor?.isNotEmpty ?? false) laboresSet.add(plan.labor!);
        if (plan.ala?.isNotEmpty ?? false) alasSet.add(plan.ala!);
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
        filteredTiposLaborFin = List.from(opcionesTipoLabor);
        filteredLaboresFin = List.from(opcionesLabor);
        filteredAlasFin = List.from(opcionesAla);
      });
    } catch (e) {
      print("Error cargando planes: $e");
      setState(() {
        opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
        opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
        filteredTiposLaborInicio = List.from(opcionesTipoLabor);
        filteredLaboresInicio = List.from(opcionesLabor);
        filteredAlasInicio = List.from(opcionesAla);
        filteredTiposLaborFin = List.from(opcionesTipoLabor);
        filteredLaboresFin = List.from(opcionesLabor);
        filteredAlasFin = List.from(opcionesAla);
      });
    }
  }

  void _actualizarFiltrosInicio() {
    _actualizarFiltros(
      nivel: nivelInicioSeleccionado,
      tipoLabor: tipoLaborInicioSeleccionado,
      labor: laborInicioSeleccionado,
      setTiposLabor: (valores) => filteredTiposLaborInicio = valores,
      setLabores: (valores) => filteredLaboresInicio = valores,
      setAlas: (valores) => filteredAlasInicio = valores,
    );
  }

  void _actualizarFiltrosFin() {
    _actualizarFiltros(
      nivel: nivelFinSeleccionado,
      tipoLabor: tipoLaborFinSeleccionado,
      labor: laborFinSeleccionado,
      setTiposLabor: (valores) => filteredTiposLaborFin = valores,
      setLabores: (valores) => filteredLaboresFin = valores,
      setAlas: (valores) => filteredAlasFin = valores,
    );
  }

  void _actualizarFiltros({
    required String? nivel,
    required String? tipoLabor,
    required String? labor,
    required Function(List<String>) setTiposLabor,
    required Function(List<String>) setLabores,
    required Function(List<String>) setAlas,
  }) {
    if (nivel != null) {
      Set<String> tiposLaborFiltrados = {};
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivel && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivel && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivel && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      setTiposLabor(tiposLaborFiltrados.toList()..sort());
    } else {
      setTiposLabor(List.from(opcionesTipoLabor));
    }

    if (nivel != null && tipoLabor != null) {
      Set<String> laboresFiltrados = {};
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      setLabores(laboresFiltrados.toList()..sort());
    } else {
      setLabores(List.from(opcionesLabor));
    }

    if (nivel != null && tipoLabor != null && labor != null) {
      Set<String> alasFiltrados = {};
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            plan.labor == labor && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            plan.labor == labor && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      for (var plan in planesMetrajeCompletos) {
        if (plan.nivel == nivel && 
            plan.tipoLabor == tipoLabor && 
            plan.labor == labor && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      setAlas(alasFiltrados.toList()..sort());
    } else {
      setAlas(List.from(opcionesAla));
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // INICIO
        nivelInicioSeleccionado = widget.datosIniciales!['nivel_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['nivel_inicio'] : null;
        tipoLaborInicioSeleccionado = widget.datosIniciales!['tipo_labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['tipo_labor_inicio'] : null;
        laborInicioSeleccionado = widget.datosIniciales!['labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_inicio'] : null;
        alaInicioSeleccionado = widget.datosIniciales!['ala_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['ala_inicio'] : null;
        
        // FIN
        nivelFinSeleccionado = widget.datosIniciales!['nivel_fin']?.isNotEmpty == true 
            ? widget.datosIniciales!['nivel_fin'] : null;
        tipoLaborFinSeleccionado = widget.datosIniciales!['tipo_labor_fin']?.isNotEmpty == true 
            ? widget.datosIniciales!['tipo_labor_fin'] : null;
        laborFinSeleccionado = widget.datosIniciales!['labor_fin']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_fin'] : null;
        alaFinSeleccionado = widget.datosIniciales!['ala_fin']?.isNotEmpty == true 
            ? widget.datosIniciales!['ala_fin'] : null;
        
        // NÚMERO DE VIAJES
        nViajesController.text = widget.datosIniciales!['n_viajes']?.toString() ?? '0';
        
        // OBSERVACIONES
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltrosInicio();
        _actualizarFiltrosFin();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      // INICIO
      'nivel_inicio': nivelInicioSeleccionado ?? '',
      'tipo_labor_inicio': tipoLaborInicioSeleccionado ?? '',
      'labor_inicio': laborInicioSeleccionado ?? '',
      'ala_inicio': alaInicioSeleccionado ?? '',
      
      // FIN
      'nivel_fin': nivelFinSeleccionado ?? '',
      'tipo_labor_fin': tipoLaborFinSeleccionado ?? '',
      'labor_fin': laborFinSeleccionado ?? '',
      'ala_fin': alaFinSeleccionado ?? '',
      
      // NÚMERO DE VIAJES
      'n_viajes': int.tryParse(nViajesController.text) ?? 0,
      
      // OBSERVACIONES
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
    nViajesController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;
    
    final dialogWidth = isSmallScreen 
        ? screenWidth * 0.95
        : 1000.0;
    
    final dialogHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.9
        : 750.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: dialogHeight,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSeccionUbicacionInicio(),
                          const SizedBox(height: 16),
                          _buildSeccionUbicacionFin(),
                          const SizedBox(height: 16),
                          _buildSeccionViajes(),
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

  Widget _buildSeccionUbicacionInicio() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSmallScreen)
            _buildVerticalDropdownsInicio()
          else
            _buildHorizontalDropdownsInicio(),
        ],
      ),
    );
  }

  Widget _buildVerticalDropdownsInicio() {
    return Column(
      children: [
        _buildCompactDropdownField(
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
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
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
                } : null,
          icon: Icons.construction,
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
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
                } : null,
          icon: Icons.factory,
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
          label: 'Ala',
          value: alaInicioSeleccionado,
          items: filteredAlasInicio,
          onChanged: (laborInicioSeleccionado != null && isEditable) 
              ? (value) => setState(() => alaInicioSeleccionado = value) : null,
          icon: Icons.compare_arrows,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildHorizontalDropdownsInicio() {
    return Row(
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
            color: Colors.green,
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
                  } : null,
            icon: Icons.construction,
            color: Colors.green,
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
                  } : null,
            icon: Icons.factory,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactDropdownField(
            label: 'Ala',
            value: alaInicioSeleccionado,
            items: filteredAlasInicio,
            onChanged: (laborInicioSeleccionado != null && isEditable) 
                ? (value) => setState(() => alaInicioSeleccionado = value) : null,
            icon: Icons.compare_arrows,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionUbicacionFin() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.stop_circle_outlined, size: 14, color: Colors.red),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ubicación FIN',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSmallScreen)
            _buildVerticalDropdownsFin()
          else
            _buildHorizontalDropdownsFin(),
        ],
      ),
    );
  }

  Widget _buildVerticalDropdownsFin() {
    return Column(
      children: [
        _buildCompactDropdownField(
          label: 'Nivel',
          value: nivelFinSeleccionado,
          items: opcionesNivel,
          onChanged: isEditable ? (value) {
            setState(() {
              nivelFinSeleccionado = value;
              tipoLaborFinSeleccionado = null;
              laborFinSeleccionado = null;
              alaFinSeleccionado = null;
              _actualizarFiltrosFin();
            });
          } : null,
          icon: Icons.stairs,
          color: Colors.red,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
          label: 'Tipo Labor',
          value: tipoLaborFinSeleccionado,
          items: filteredTiposLaborFin,
          onChanged: (nivelFinSeleccionado != null && isEditable) 
              ? (value) {
                  setState(() {
                    tipoLaborFinSeleccionado = value;
                    laborFinSeleccionado = null;
                    alaFinSeleccionado = null;
                    _actualizarFiltrosFin();
                  });
                } : null,
          icon: Icons.construction,
          color: Colors.red,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
          label: 'Labor',
          value: laborFinSeleccionado,
          items: filteredLaboresFin,
          onChanged: (tipoLaborFinSeleccionado != null && isEditable) 
              ? (value) {
                  setState(() {
                    laborFinSeleccionado = value;
                    alaFinSeleccionado = null;
                    _actualizarFiltrosFin();
                  });
                } : null,
          icon: Icons.factory,
          color: Colors.red,
        ),
        const SizedBox(height: 8),
        _buildCompactDropdownField(
          label: 'Ala',
          value: alaFinSeleccionado,
          items: filteredAlasFin,
          onChanged: (laborFinSeleccionado != null && isEditable) 
              ? (value) => setState(() => alaFinSeleccionado = value) : null,
          icon: Icons.compare_arrows,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildHorizontalDropdownsFin() {
    return Row(
      children: [
        Expanded(
          child: _buildCompactDropdownField(
            label: 'Nivel',
            value: nivelFinSeleccionado,
            items: opcionesNivel,
            onChanged: isEditable ? (value) {
              setState(() {
                nivelFinSeleccionado = value;
                tipoLaborFinSeleccionado = null;
                laborFinSeleccionado = null;
                alaFinSeleccionado = null;
                _actualizarFiltrosFin();
              });
            } : null,
            icon: Icons.stairs,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactDropdownField(
            label: 'Tipo Labor',
            value: tipoLaborFinSeleccionado,
            items: filteredTiposLaborFin,
            onChanged: (nivelFinSeleccionado != null && isEditable) 
                ? (value) {
                    setState(() {
                      tipoLaborFinSeleccionado = value;
                      laborFinSeleccionado = null;
                      alaFinSeleccionado = null;
                      _actualizarFiltrosFin();
                    });
                  } : null,
            icon: Icons.construction,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactDropdownField(
            label: 'Labor',
            value: laborFinSeleccionado,
            items: filteredLaboresFin,
            onChanged: (tipoLaborFinSeleccionado != null && isEditable) 
                ? (value) {
                    setState(() {
                      laborFinSeleccionado = value;
                      alaFinSeleccionado = null;
                      _actualizarFiltrosFin();
                    });
                  } : null,
            icon: Icons.factory,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactDropdownField(
            label: 'Ala',
            value: alaFinSeleccionado,
            items: filteredAlasFin,
            onChanged: (laborFinSeleccionado != null && isEditable) 
                ? (value) => setState(() => alaFinSeleccionado = value) : null,
            icon: Icons.compare_arrows,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionViajes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.timeline, size: 14, color: widget.primaryColor),
              ),
              const SizedBox(width: 6),
              Text(
                'Número de Viajes (Cucharas)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nViajesController,
            enabled: isEditable,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ingrese número de viajes',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
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
              isSmallScreen ? 'Perforación' : 'Formulario de Perforación',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
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

  Widget _buildCompactDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required IconData icon,
    Color color = Colors.blue,
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
              Icon(icon, size: isSmallScreen ? 12 : 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Cargando...' : label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: isSmallScreen ? 16 : 18, color: color),
          style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No hay opciones', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ]
              : items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
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