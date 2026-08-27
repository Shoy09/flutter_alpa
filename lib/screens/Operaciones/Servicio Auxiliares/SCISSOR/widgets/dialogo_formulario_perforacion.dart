import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

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
  State<DialogoFormularioRompebanco> createState() => _DialogoFormularioRompebancoState();
}

class _DialogoFormularioRompebancoState extends State<DialogoFormularioRompebanco> {
  bool isEditable = false;
  bool isLoading = true;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Variables para ORIGEN (NUEVO ORDEN: Tipo Labor → Labor → Ala, Nivel interno)
  String? origenTipoLaborSeleccionado;    // 1º
  String? origenLaborSeleccionado;         // 2º
  String? origenAlaSeleccionado;           // 3º
  String? origenNivelSeleccionado;         // 4º (interno, no visible)

  // Variables para DESTINO (NUEVO ORDEN: Tipo Labor → Labor → Ala, Nivel interno)
  String? destTipoLaborSeleccionado;       // 1º
  String? destinoLaborSeleccionado;        // 2º
  String? destinoAlaSeleccionado;          // 3º
  String? destinoNivelSeleccionado;        // 4º (interno, no visible)

  // Opciones para los dropdowns
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];

  // Listas filtradas para ORIGEN
  List<String> filteredOrigenTiposLabor = [];
  List<String> filteredOrigenLabores = [];
  List<String> filteredOrigenAlas = [];
  List<String> filteredOrigenNiveles = [];

  // Listas filtradas para DESTINO
  List<String> filteredDestinoTiposLabor = [];
  List<String> filteredDestinoLabores = [];
  List<String> filteredDestinoAlas = [];
  List<String> filteredDestinoNiveles = [];

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

        filteredOrigenTiposLabor = List.from(opcionesTipoLabor);
        filteredOrigenLabores = List.from(opcionesLabor);
        filteredOrigenAlas = List.from(opcionesAla);
        filteredOrigenNiveles = List.from(opcionesNivel);
        
        filteredDestinoTiposLabor = List.from(opcionesTipoLabor);
        filteredDestinoLabores = List.from(opcionesLabor);
        filteredDestinoAlas = List.from(opcionesAla);
        filteredDestinoNiveles = List.from(opcionesNivel);
      });

    } catch (e) {
      print("Error cargando planes combinados: $e");
      setState(() {
        opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
        opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];

        filteredOrigenTiposLabor = List.from(opcionesTipoLabor);
        filteredOrigenLabores = List.from(opcionesLabor);
        filteredOrigenAlas = List.from(opcionesAla);
        filteredOrigenNiveles = List.from(opcionesNivel);
        
        filteredDestinoTiposLabor = List.from(opcionesTipoLabor);
        filteredDestinoLabores = List.from(opcionesLabor);
        filteredDestinoAlas = List.from(opcionesAla);
        filteredDestinoNiveles = List.from(opcionesNivel);
      });
    }
  }

  // ==================== FUNCIONES PARA ORIGEN ====================
  void _onOrigenTipoLaborChanged(String? nuevoTipoLabor) {
    setState(() {
      origenTipoLaborSeleccionado = nuevoTipoLabor;
      origenLaborSeleccionado = null;
      origenAlaSeleccionado = null;
      origenNivelSeleccionado = null;
      _actualizarFiltrosOrigen();
    });
  }

  void _onOrigenLaborChanged(String? nuevoLabor) {
    setState(() {
      origenLaborSeleccionado = nuevoLabor;
      origenAlaSeleccionado = null;
      origenNivelSeleccionado = null;
      _actualizarFiltrosOrigen();
    });
  }

  void _onOrigenAlaChanged(String? nuevoAla) {
    setState(() {
      origenAlaSeleccionado = nuevoAla;
      origenNivelSeleccionado = null;
      _actualizarFiltrosOrigen();
    });
  }

  void _actualizarFiltrosOrigen() {
    // Filtrar Labores basado en Tipo Labor
    if (origenTipoLaborSeleccionado != null) {
      Set<String> laboresFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      filteredOrigenLabores = laboresFiltrados.toList()..sort();
    } else {
      filteredOrigenLabores = List.from(opcionesLabor);
    }

    // Filtrar Alas basado en Tipo Labor y Labor
    if (origenTipoLaborSeleccionado != null && origenLaborSeleccionado != null) {
      Set<String> alasFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado &&
            plan.labor == origenLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado &&
            plan.labor == origenLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        if (plan.tipoLabor == origenTipoLaborSeleccionado &&
            plan.labor == origenLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      filteredOrigenAlas = alasFiltrados.toList()..sort();
    } else {
      filteredOrigenAlas = List.from(opcionesAla);
    }

    // Filtrar Niveles (INTERNO)
    if (origenTipoLaborSeleccionado != null && origenLaborSeleccionado != null) {
      Set<String> nivelesFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado && plan.labor == origenLaborSeleccionado;
        bool coincideAla = origenAlaSeleccionado == null || origenAlaSeleccionado!.isEmpty || plan.ala == origenAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado && plan.labor == origenLaborSeleccionado;
        bool coincideAla = origenAlaSeleccionado == null || origenAlaSeleccionado!.isEmpty || plan.ala == origenAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado && plan.labor == origenLaborSeleccionado;
        bool coincideAla = origenAlaSeleccionado == null || origenAlaSeleccionado!.isEmpty || plan.ala == origenAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      filteredOrigenNiveles = nivelesFiltrados.toList()..sort();

      if (filteredOrigenNiveles.isNotEmpty) {
        if (origenNivelSeleccionado == null || !filteredOrigenNiveles.contains(origenNivelSeleccionado)) {
          origenNivelSeleccionado = filteredOrigenNiveles.first;
        }
      } else {
        origenNivelSeleccionado = null;
      }
    } else {
      filteredOrigenNiveles = List.from(opcionesNivel);
      if (origenTipoLaborSeleccionado == null || origenLaborSeleccionado == null) {
        origenNivelSeleccionado = null;
      }
    }
  }

  // ==================== FUNCIONES PARA DESTINO ====================
  void _onDestinoTipoLaborChanged(String? nuevoTipoLabor) {
    setState(() {
      destTipoLaborSeleccionado = nuevoTipoLabor;
      destinoLaborSeleccionado = null;
      destinoAlaSeleccionado = null;
      destinoNivelSeleccionado = null;
      _actualizarFiltrosDestino();
    });
  }

  void _onDestinoLaborChanged(String? nuevoLabor) {
    setState(() {
      destinoLaborSeleccionado = nuevoLabor;
      destinoAlaSeleccionado = null;
      destinoNivelSeleccionado = null;
      _actualizarFiltrosDestino();
    });
  }

  void _onDestinoAlaChanged(String? nuevoAla) {
    setState(() {
      destinoAlaSeleccionado = nuevoAla;
      destinoNivelSeleccionado = null;
      _actualizarFiltrosDestino();
    });
  }

  void _actualizarFiltrosDestino() {
    // Filtrar Labores basado en Tipo Labor
    if (destTipoLaborSeleccionado != null) {
      Set<String> laboresFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado && (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      filteredDestinoLabores = laboresFiltrados.toList()..sort();
    } else {
      filteredDestinoLabores = List.from(opcionesLabor);
    }

    // Filtrar Alas basado en Tipo Labor y Labor
    if (destTipoLaborSeleccionado != null && destinoLaborSeleccionado != null) {
      Set<String> alasFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado &&
            plan.labor == destinoLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado &&
            plan.labor == destinoLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        if (plan.tipoLabor == destTipoLaborSeleccionado &&
            plan.labor == destinoLaborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      filteredDestinoAlas = alasFiltrados.toList()..sort();
    } else {
      filteredDestinoAlas = List.from(opcionesAla);
    }

    // Filtrar Niveles (INTERNO)
    if (destTipoLaborSeleccionado != null && destinoLaborSeleccionado != null) {
      Set<String> nivelesFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        bool coincideBase = plan.tipoLabor == destTipoLaborSeleccionado && plan.labor == destinoLaborSeleccionado;
        bool coincideAla = destinoAlaSeleccionado == null || destinoAlaSeleccionado!.isEmpty || plan.ala == destinoAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        bool coincideBase = plan.tipoLabor == destTipoLaborSeleccionado && plan.labor == destinoLaborSeleccionado;
        bool coincideAla = destinoAlaSeleccionado == null || destinoAlaSeleccionado!.isEmpty || plan.ala == destinoAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        bool coincideBase = plan.tipoLabor == destTipoLaborSeleccionado && plan.labor == destinoLaborSeleccionado;
        bool coincideAla = destinoAlaSeleccionado == null || destinoAlaSeleccionado!.isEmpty || plan.ala == destinoAlaSeleccionado;
        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      filteredDestinoNiveles = nivelesFiltrados.toList()..sort();

      if (filteredDestinoNiveles.isNotEmpty) {
        if (destinoNivelSeleccionado == null || !filteredDestinoNiveles.contains(destinoNivelSeleccionado)) {
          destinoNivelSeleccionado = filteredDestinoNiveles.first;
        }
      } else {
        destinoNivelSeleccionado = null;
      }
    } else {
      filteredDestinoNiveles = List.from(opcionesNivel);
      if (destTipoLaborSeleccionado == null || destinoLaborSeleccionado == null) {
        destinoNivelSeleccionado = null;
      }
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // ORIGEN
        origenTipoLaborSeleccionado = widget.datosIniciales!['origen_tipo_labor']?.isNotEmpty == true
            ? widget.datosIniciales!['origen_tipo_labor']
            : null;
        origenLaborSeleccionado = widget.datosIniciales!['origen_labor']?.isNotEmpty == true
            ? widget.datosIniciales!['origen_labor']
            : null;
        origenAlaSeleccionado = widget.datosIniciales!['origen_ala']?.isNotEmpty == true
            ? widget.datosIniciales!['origen_ala']
            : null;
        origenNivelSeleccionado = widget.datosIniciales!['origen_nivel']?.isNotEmpty == true
            ? widget.datosIniciales!['origen_nivel']
            : null;

        // DESTINO
        destTipoLaborSeleccionado = widget.datosIniciales!['destino_tipo_labor']?.isNotEmpty == true
            ? widget.datosIniciales!['destino_tipo_labor']
            : null;
        destinoLaborSeleccionado = widget.datosIniciales!['destino_labor']?.isNotEmpty == true
            ? widget.datosIniciales!['destino_labor']
            : null;
        destinoAlaSeleccionado = widget.datosIniciales!['destino_ala']?.isNotEmpty == true
            ? widget.datosIniciales!['destino_ala']
            : null;
        destinoNivelSeleccionado = widget.datosIniciales!['destino_nivel']?.isNotEmpty == true
            ? widget.datosIniciales!['destino_nivel']
            : null;

        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltrosOrigen();
        _actualizarFiltrosDestino();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      // ORIGEN (nuevo orden)
      'origen_tipo_labor': origenTipoLaborSeleccionado ?? '',
      'origen_labor': origenLaborSeleccionado ?? '',
      'origen_ala': origenAlaSeleccionado ?? '',
      'origen_nivel': origenNivelSeleccionado ?? '',

      // DESTINO (nuevo orden)
      'destino_tipo_labor': destTipoLaborSeleccionado ?? '',
      'destino_labor': destinoLaborSeleccionado ?? '',
      'destino_ala': destinoAlaSeleccionado ?? '',
      'destino_nivel': destinoNivelSeleccionado ?? '',

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1100,
        constraints: const BoxConstraints(maxHeight: 700),
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
                        children: [
                          _buildSeccionOrigen(),
                          const SizedBox(height: 20),
                          _buildSeccionDestino(),
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

  Widget _buildSeccionOrigen() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.exit_to_app, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text('ORIGEN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Tipo Labor',
                  value: origenTipoLaborSeleccionado,
                  items: filteredOrigenTiposLabor,
                  onChanged: isEditable ? _onOrigenTipoLaborChanged : null,
                  icon: Icons.construction,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Labor',
                  value: origenLaborSeleccionado,
                  items: filteredOrigenLabores,
                  onChanged: (origenTipoLaborSeleccionado != null && isEditable) ? _onOrigenLaborChanged : null,
                  icon: Icons.factory,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Ala',
                  value: origenAlaSeleccionado,
                  items: filteredOrigenAlas,
                  onChanged: (origenLaborSeleccionado != null && isEditable) ? _onOrigenAlaChanged : null,
                  icon: Icons.compare_arrows,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionDestino() {
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
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.login, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text('DESTINO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Tipo Labor',
                  value: destTipoLaborSeleccionado,
                  items: filteredDestinoTiposLabor,
                  onChanged: isEditable ? _onDestinoTipoLaborChanged : null,
                  icon: Icons.construction,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Labor',
                  value: destinoLaborSeleccionado,
                  items: filteredDestinoLabores,
                  onChanged: (destTipoLaborSeleccionado != null && isEditable) ? _onDestinoLaborChanged : null,
                  icon: Icons.factory,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Ala',
                  value: destinoAlaSeleccionado,
                  items: filteredDestinoAlas,
                  onChanged: (destinoLaborSeleccionado != null && isEditable) ? _onDestinoAlaChanged : null,
                  icon: Icons.compare_arrows,
                  color: Colors.green,
                ),
              ),
            ],
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
              Text('Observaciones', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: observacionesController,
            enabled: isEditable,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escriba observaciones adicionales...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.primaryColor)),
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
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Formulario Rompebanco', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
          Container(width: 6, height: 6, decoration: BoxDecoration(color: isEditable ? Colors.green : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(isEditable ? 'EDITABLE' : 'LECTURA', style: TextStyle(color: isEditable ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
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
    Color color = const Color(0xFF1B5E6B),
  }) {
    bool valueExists = value != null && items.contains(value);
    bool isEnabled = onChanged != null && isEditable;

    return Container(
      height: 42,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valueExists ? value : null,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(items.isEmpty ? 'Cargando...' : label, style: TextStyle(fontSize: 11, color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400), overflow: TextOverflow.ellipsis)),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: color),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [DropdownMenuItem<String>(value: null, child: Text('No hay opciones', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)))]
              : items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, style: const TextStyle(fontSize: 12)))).toList(),
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
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), minimumSize: Size.zero),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.save, size: 14), SizedBox(width: 6), Text('Guardar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]),
            ),
        ],
      ),
    );
  }
}