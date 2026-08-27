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

  // Variables para los campos seleccionables (NUEVO ORDEN)
  String? tipoLaborSeleccionado;    // 1º
  String? laborSeleccionado;         // 2º  
  String? alaSeleccionado;           // 3º
  String? nivelSeleccionado;         // 4º (manejado internamente, no visible)

  // Opciones para los dropdowns
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];

  // Listas filtradas para la selección en cascada
  List<String> filteredTiposLabor = [];
  List<String> filteredLabores = [];
  List<String> filteredAlas = [];
  List<String> filteredNiveles = [];  // Para filtrar niveles internamente

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

      setState(() {
        opcionesNivel = nivelesSet.toList()..sort();
        opcionesTipoLabor = tiposLaborSet.toList()..sort();
        opcionesLabor = laboresSet.toList()..sort();
        opcionesAla = alasSet.toList()..sort();

        filteredTiposLabor = List.from(opcionesTipoLabor);
        filteredLabores = List.from(opcionesLabor);
        filteredAlas = List.from(opcionesAla);
        filteredNiveles = List.from(opcionesNivel);
      });

    } catch (e) {
      print("Error cargando planes combinados: $e");
      setState(() {
        opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
        opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
        
        filteredTiposLabor = List.from(opcionesTipoLabor);
        filteredLabores = List.from(opcionesLabor);
        filteredAlas = List.from(opcionesAla);
        filteredNiveles = List.from(opcionesNivel);
      });
    }
  }

  // NUEVAS FUNCIONES DE FILTRADO (orden: Tipo Labor → Labor → Ala)
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

  void _actualizarFiltros() {
    // Filtrar Labores basado en Tipo Labor
    if (tipoLaborSeleccionado != null) {
      Set<String> laboresFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
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
      
      for (var plan in planesMensualCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        if (plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado &&
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
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
    // Filtra por tipo labor + labor + ala
    if (tipoLaborSeleccionado != null && laborSeleccionado != null) {
      Set<String> nivelesFiltrados = {};
      
      for (var plan in planesMensualCompletos) {
        bool coincideBase = plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado;
        
        bool coincideAla = alaSeleccionado == null ||
            alaSeleccionado!.isEmpty ||
            plan.ala == alaSeleccionado;

        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesProduccionCompletos) {
        bool coincideBase = plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado;
        
        bool coincideAla = alaSeleccionado == null ||
            alaSeleccionado!.isEmpty ||
            plan.ala == alaSeleccionado;

        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      for (var plan in planesMetrajeCompletos) {
        bool coincideBase = plan.tipoLabor == tipoLaborSeleccionado &&
            plan.labor == laborSeleccionado;
        
        bool coincideAla = alaSeleccionado == null ||
            alaSeleccionado!.isEmpty ||
            plan.ala == alaSeleccionado;

        if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
          nivelesFiltrados.add(plan.nivel!);
        }
      }
      
      filteredNiveles = nivelesFiltrados.toList()..sort();

      // Auto seleccionar nivel internamente
      if (filteredNiveles.isNotEmpty) {
        if (nivelSeleccionado == null || !filteredNiveles.contains(nivelSeleccionado)) {
          nivelSeleccionado = filteredNiveles.first;
        }
      } else {
        nivelSeleccionado = null;
      }
    } else {
      filteredNiveles = List.from(opcionesNivel);
      // No auto-seleccionar nivel si no hay filtros completos
      if (tipoLaborSeleccionado == null || laborSeleccionado == null) {
        nivelSeleccionado = null;
      }
    }
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // Cargar en el nuevo orden (Tipo Labor → Labor → Ala → Nivel interno)
        tipoLaborSeleccionado = widget.datosIniciales!['tipo_labor']?.isNotEmpty == true
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

        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltros();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      // NUEVO ORDEN: tipo_labor, labor, ala, nivel (interno)
      'tipo_labor': tipoLaborSeleccionado ?? '',
      'labor': laborSeleccionado ?? '',
      'ala': alaSeleccionado ?? '',
      'nivel': nivelSeleccionado ?? '',
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 900, // Reducido de 1000 a 900 porque ahora son 3 campos visibles
        constraints: const BoxConstraints(
          maxHeight: 500,
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
                          // SECCIÓN: Ubicación con NUEVO ORDEN (sin Nivel visible)
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
                'Ubicación',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Tipo Labor',        // 1º
                  value: tipoLaborSeleccionado,
                  items: filteredTiposLabor,
                  onChanged: isEditable ? _onTipoLaborChanged : null,
                  icon: Icons.construction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Labor',              // 2º
                  value: laborSeleccionado,
                  items: filteredLabores,
                  onChanged: (tipoLaborSeleccionado != null && isEditable) 
                      ? _onLaborChanged 
                      : null,
                  icon: Icons.factory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Ala',                // 3º
                  value: alaSeleccionado,
                  items: filteredAlas,
                  onChanged: (laborSeleccionado != null && isEditable) 
                      ? _onAlaChanged 
                      : null,
                  icon: Icons.compare_arrows,
                ),
              ),
              // ❌ NOTA: El campo Nivel ya no se muestra, se maneja internamente
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
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Formulario Rompebanco',
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
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ]
              : items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12),
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