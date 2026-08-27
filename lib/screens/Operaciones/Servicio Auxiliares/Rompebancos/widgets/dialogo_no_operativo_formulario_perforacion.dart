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

  // ✅ SOLO Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Variables para los campos seleccionables
  String? nivelSeleccionado;
  String? tipoLaborSeleccionado;
  String? laborSeleccionado;
  String? alaSeleccionado;

  // Opciones para los dropdowns (vienen de PlanMensual)
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];

  // Listas filtradas para la selección en cascada
  List<String> filteredTiposLabor = [];
  List<String> filteredLabores = [];
  List<String> filteredAlas = [];

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

  // Cargar planes mensuales y construir opciones únicas
  Future<void> _cargarPlanesCombinados() async {
  try {
    final dbHelper = DatabaseHelper();
    
    // Cargar las tres tablas en paralelo
    final results = await Future.wait([
      dbHelper.getPlanesMensual(),
      dbHelper.getPlanesProduccion(),
      dbHelper.getPlanesMetraje(),
    ]);
    
   planesMensualCompletos = results[0] as List<PlanMensual>;
planesProduccionCompletos = results[1] as List<PlanProduccion>;
planesMetrajeCompletos = results[2] as List<PlanMetraje>;

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

    setState(() {
      opcionesNivel = nivelesSet.toList()..sort();
      opcionesTipoLabor = tiposLaborSet.toList()..sort();
      opcionesLabor = laboresSet.toList()..sort();
      opcionesAla = alasSet.toList()..sort();

      // Inicializar listas filtradas
      filteredTiposLabor = List.from(opcionesTipoLabor);
      filteredLabores = List.from(opcionesLabor);
      filteredAlas = List.from(opcionesAla);
    });

  } catch (e) {
    print("Error cargando planes combinados: $e");
    // Fallback con datos de ejemplo
    setState(() {
      opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
      opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
      opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
      opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
      
      filteredTiposLabor = List.from(opcionesTipoLabor);
      filteredLabores = List.from(opcionesLabor);
      filteredAlas = List.from(opcionesAla);
    });
  }
}


  // Actualizar filtros cuando cambia el nivel
  void _onNivelChanged(String? nuevoNivel) {
    setState(() {
      nivelSeleccionado = nuevoNivel;
      // Resetear selecciones dependientes
      tipoLaborSeleccionado = null;
      laborSeleccionado = null;
      alaSeleccionado = null;
      
      _actualizarFiltros();
    });
  }

  // Actualizar filtros cuando cambia el tipo de labor
  void _onTipoLaborChanged(String? nuevoTipoLabor) {
    setState(() {
      tipoLaborSeleccionado = nuevoTipoLabor;
      // Resetear selecciones dependientes
      laborSeleccionado = null;
      alaSeleccionado = null;
      
      _actualizarFiltros();
    });
  }

  // Actualizar filtros cuando cambia la labor
  void _onLaborChanged(String? nuevoLabor) {
    setState(() {
      laborSeleccionado = nuevoLabor;
      // Resetear selecciones dependientes
      alaSeleccionado = null;
      
      _actualizarFiltros();
    });
  }

  // Actualizar filtros en cascada basados en selecciones
  void _actualizarFiltros() {
  // Filtrar tipos de labor basados en nivel seleccionado
  if (nivelSeleccionado != null) {
    Set<String> tiposLaborFiltrados = {};
    
    // Buscar en PlanMensual
    for (var plan in planesMensualCompletos) {
      if (plan.nivel == nivelSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
        tiposLaborFiltrados.add(plan.tipoLabor!);
      }
    }
    
    // Buscar en PlanProduccion
    for (var plan in planesProduccionCompletos) {
      if (plan.nivel == nivelSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
        tiposLaborFiltrados.add(plan.tipoLabor!);
      }
    }
    
    // Buscar en PlanMetraje
    for (var plan in planesMetrajeCompletos) {
      if (plan.nivel == nivelSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
        tiposLaborFiltrados.add(plan.tipoLabor!);
      }
    }
    
    filteredTiposLabor = tiposLaborFiltrados.toList()..sort();
  } else {
    filteredTiposLabor = List.from(opcionesTipoLabor);
  }

  // Filtrar labores basados en nivel y tipo labor
  if (nivelSeleccionado != null && tipoLaborSeleccionado != null) {
    Set<String> laboresFiltrados = {};
    
    // Buscar en PlanMensual
    for (var plan in planesMensualCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
        laboresFiltrados.add(plan.labor!);
      }
    }
    
    // Buscar en PlanProduccion
    for (var plan in planesProduccionCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
        laboresFiltrados.add(plan.labor!);
      }
    }
    
    // Buscar en PlanMetraje
    for (var plan in planesMetrajeCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
        laboresFiltrados.add(plan.labor!);
      }
    }
    
    filteredLabores = laboresFiltrados.toList()..sort();
  } else {
    filteredLabores = List.from(opcionesLabor);
  }

  // Filtrar alas basados en nivel, tipo labor y labor
  if (nivelSeleccionado != null &&
      tipoLaborSeleccionado != null &&
      laborSeleccionado != null) {
    Set<String> alasFiltrados = {};
    
    // Buscar en PlanMensual
    for (var plan in planesMensualCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          plan.labor == laborSeleccionado &&
          (plan.ala?.isNotEmpty ?? false)) {
        alasFiltrados.add(plan.ala!);
      }
    }
    
    // Buscar en PlanProduccion
    for (var plan in planesProduccionCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          plan.labor == laborSeleccionado &&
          (plan.ala?.isNotEmpty ?? false)) {
        alasFiltrados.add(plan.ala!);
      }
    }
    
    // Buscar en PlanMetraje
    for (var plan in planesMetrajeCompletos) {
      if (plan.nivel == nivelSeleccionado &&
          plan.tipoLabor == tipoLaborSeleccionado &&
          plan.labor == laborSeleccionado &&
          (plan.ala?.isNotEmpty ?? false)) {
        alasFiltrados.add(plan.ala!);
      }
    }
    
    filteredAlas = alasFiltrados.toList()..sort();
  } else {
    filteredAlas = List.from(opcionesAla);
  }
}

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        nivelSeleccionado = widget.datosIniciales!['nivel']?.isNotEmpty == true 
            ? widget.datosIniciales!['nivel'] 
            : null;
        tipoLaborSeleccionado = widget.datosIniciales!['tipo_labor']?.isNotEmpty == true 
            ? widget.datosIniciales!['tipo_labor'] 
            : null;
        laborSeleccionado = widget.datosIniciales!['labor']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor'] 
            : null;
        alaSeleccionado = widget.datosIniciales!['ala']?.isNotEmpty == true 
            ? widget.datosIniciales!['ala'] 
            : null;
        
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
      
      // Después de cargar, actualizar filtros
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltros();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      'nivel': nivelSeleccionado ?? '',
      'tipo_labor': tipoLaborSeleccionado ?? '',
      'labor': laborSeleccionado ?? '',
      'ala': alaSeleccionado ?? '',
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
        width: 800, // Ancho reducido para un formulario más compacto
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7, // 70% de la altura
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
                  
                  // Contenido con scroll
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // SECCIÓN ÚNICA: Ubicación (con datos de PlanMensual)
                          _buildSeccionCompacta(
                            icon: Icons.location_on,
                            titulo: 'Ubicación',
                            children: [
                              _buildCompactDropdownField(
                                label: 'Nivel',
                                value: nivelSeleccionado,
                                items: opcionesNivel,
                                onChanged: isEditable ? _onNivelChanged : null,
                                icon: Icons.stairs,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Tipo Labor',
                                value: tipoLaborSeleccionado,
                                items: filteredTiposLabor,
                                onChanged: (nivelSeleccionado != null && isEditable) 
                                    ? _onTipoLaborChanged 
                                    : null,
                                icon: Icons.construction,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Labor',
                                value: laborSeleccionado,
                                items: filteredLabores,
                                onChanged: (tipoLaborSeleccionado != null && isEditable) 
                                    ? _onLaborChanged 
                                    : null,
                                icon: Icons.factory,
                              ),
                              const SizedBox(width: 8),
                              _buildCompactDropdownField(
                                label: 'Ala',
                                value: alaSeleccionado,
                                items: filteredAlas,
                                onChanged: (laborSeleccionado != null && isEditable) 
                                    ? (value) => setState(() => alaSeleccionado = value)
                                    : null,
                                icon: Icons.compare_arrows,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // SECCIÓN: Observaciones
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

  // Widget para la sección de observaciones
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
              child: Icon(
                Icons.note_alt,
                size: 14,
                color: widget.primaryColor,
              ),
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
            Expanded(
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 100, // Altura aumentada para mejor visibilidad
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
              hintText: 'Ingrese observaciones...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.comment,
                  size: 18,
                  color: widget.primaryColor.withOpacity(0.7),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontSize: 14),
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
              child: Icon(
                icon,
                size: 14,
                color: widget.primaryColor,
              ),
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
            Expanded(
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 1,
              ),
            ),
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
            child: const Icon(
              Icons.description,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Formulario de Perforación no operativa',
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