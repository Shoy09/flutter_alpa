import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioAnfochanger extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioAnfochanger({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);

  @override
  State<DialogoFormularioAnfochanger> createState() => _DialogoFormularioAnfochangerState();
}

class _DialogoFormularioAnfochangerState extends State<DialogoFormularioAnfochanger> {
  bool isEditable = false;
  bool isLoading = true;

  // Controladores
  final TextEditingController observacionesController = TextEditingController();
  final TextEditingController taladrosController = TextEditingController();
  final TextEditingController anfoController = TextEditingController();
final TextEditingController cajasController = TextEditingController();

  // Variables para ORIGEN
String? origenTipoLaborSeleccionado;    // 1º
String? origenLaborSeleccionado;         // 2º  
String? origenAlaSeleccionado;           // 3º
String? origenNivelSeleccionado;   

  // Opciones para los dropdowns (de PlanMensual)
  List<String> opcionesNivel = [];
  List<String> opcionesTipoLabor = [];
  List<String> opcionesLabor = [];
  List<String> opcionesAla = [];

  // Listas filtradas para ORIGEN
List<String> filteredOrigenTiposLabor = [];
List<String> filteredOrigenLabores = [];
List<String> filteredOrigenAlas = [];
List<String> filteredOrigenNiveles = [];  // ← NUEVA

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
      filteredOrigenTiposLabor = List.from(opcionesTipoLabor);
      filteredOrigenLabores = List.from(opcionesLabor);
      filteredOrigenAlas = List.from(opcionesAla);
      filteredOrigenNiveles = List.from(opcionesNivel); 
    });

  } catch (e) {
    print("Error cargando planes combinados: $e");
    // Fallback con datos de ejemplo
    setState(() {
      opcionesNivel = ['Nv 300', 'Nv 320', 'Nv 340', 'Nv 360'];
      opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea'];
      opcionesLabor = ['Labor 01', 'Labor 02', 'Labor 03', 'Labor 04'];
      opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
      
      filteredOrigenTiposLabor = List.from(opcionesTipoLabor);
      filteredOrigenLabores = List.from(opcionesLabor);
      filteredOrigenAlas = List.from(opcionesAla);
    });
  }
}

  // Actualizar filtros para ORIGEN
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
      if (plan.tipoLabor == origenTipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
        laboresFiltrados.add(plan.labor!);
      }
    }
    for (var plan in planesProduccionCompletos) {
      if (plan.tipoLabor == origenTipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
        laboresFiltrados.add(plan.labor!);
      }
    }
    for (var plan in planesMetrajeCompletos) {
      if (plan.tipoLabor == origenTipoLaborSeleccionado &&
          (plan.labor?.isNotEmpty ?? false)) {
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

  // Filtrar Niveles (INTERNO, NO VISIBLE)
  if (origenTipoLaborSeleccionado != null && origenLaborSeleccionado != null) {
    Set<String> nivelesFiltrados = {};
    
    for (var plan in planesMensualCompletos) {
      bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado &&
          plan.labor == origenLaborSeleccionado;
      
      bool coincideAla = origenAlaSeleccionado == null ||
          origenAlaSeleccionado!.isEmpty ||
          plan.ala == origenAlaSeleccionado;

      if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
        nivelesFiltrados.add(plan.nivel!);
      }
    }
    for (var plan in planesProduccionCompletos) {
      bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado &&
          plan.labor == origenLaborSeleccionado;
      
      bool coincideAla = origenAlaSeleccionado == null ||
          origenAlaSeleccionado!.isEmpty ||
          plan.ala == origenAlaSeleccionado;

      if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
        nivelesFiltrados.add(plan.nivel!);
      }
    }
    for (var plan in planesMetrajeCompletos) {
      bool coincideBase = plan.tipoLabor == origenTipoLaborSeleccionado &&
          plan.labor == origenLaborSeleccionado;
      
      bool coincideAla = origenAlaSeleccionado == null ||
          origenAlaSeleccionado!.isEmpty ||
          plan.ala == origenAlaSeleccionado;

      if (coincideBase && coincideAla && (plan.nivel?.isNotEmpty ?? false)) {
        nivelesFiltrados.add(plan.nivel!);
      }
    }
    
    filteredOrigenNiveles = nivelesFiltrados.toList()..sort();

    // Auto seleccionar nivel internamente
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

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        // Cargar ORIGEN
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

        // Cargar campos de producción
        taladrosController.text = widget.datosIniciales!['n_taladros_cargados']?.toString() ?? '';
        anfoController.text = widget.datosIniciales!['cantidad_anfo']?.toString() ?? '';
cajasController.text = widget.datosIniciales!['n_cartuchos']?.toString() ?? '';
        // Observaciones
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });

      // Después de cargar, actualizar filtros
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltrosOrigen();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      // ORIGEN
      'origen_tipo_labor': origenTipoLaborSeleccionado ?? '',
      'origen_labor': origenLaborSeleccionado ?? '',
      'origen_ala': origenAlaSeleccionado ?? '',
      'origen_nivel': origenNivelSeleccionado ?? '',

      // Campos de producción
      'n_taladros_cargados': int.tryParse(taladrosController.text) ?? 0,
      'cantidad_anfo': double.tryParse(anfoController.text) ?? 0,
      'n_cartuchos': int.tryParse(cajasController.text) ?? 0,

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
    observacionesController.dispose();
    taladrosController.dispose();
    anfoController.dispose();
    cajasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 900, // Reducido porque eliminamos DESTINO
        constraints: const BoxConstraints(
          maxHeight: 650,
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
                          // SECCIÓN ORIGEN
                          _buildSeccionOrigen(),

                          const SizedBox(height: 20),

                          // SECCIÓN PRODUCCIÓN (NUEVA)
                          _buildSeccionProduccion(),

                          const SizedBox(height: 20),

                          // SECCIÓN Observaciones
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
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.location_on, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                'UBICACIÓN DE LABOR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
          children: [
            Expanded(
              child: _buildCompactDropdownField(
                label: 'Tipo Labor',        // 1º
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
                label: 'Labor',              // 2º
                value: origenLaborSeleccionado,
                items: filteredOrigenLabores,
                onChanged: (origenTipoLaborSeleccionado != null && isEditable)
                    ? _onOrigenLaborChanged
                    : null,
                icon: Icons.factory,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactDropdownField(
                label: 'Ala',                // 3º
                value: origenAlaSeleccionado,
                items: filteredOrigenAlas,
                onChanged: (origenLaborSeleccionado != null && isEditable)
                    ? _onOrigenAlaChanged
                    : null,
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

  Widget _buildSeccionProduccion() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.production_quantity_limits, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              'DATOS DE PRODUCCIÓN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: _buildCompactTextField(
        label: 'Taladros Cargados',
        controller: taladrosController,
        icon: Icons.grid_3x3,
        color: Colors.amber.shade700,
        keyboardType: TextInputType.number,
        isEditable: isEditable,
        unit: 'und',
      ),
    ),
    const SizedBox(width: 12),

    Expanded(
      child: _buildCompactTextField(
        label: 'Cantidad ANFO',
        controller: anfoController,
        icon: Icons.scale,
        color: Colors.amber.shade700,
        keyboardType: TextInputType.number,
        isEditable: isEditable,
        unit: 'sacos',
      ),
    ),
    const SizedBox(width: 12),

    Expanded(
      child: _buildCompactTextField(
        label: 'N° Cartuchos',
        controller: cajasController,
        icon: Icons.inventory_2,
        color: Colors.amber.shade700,
        keyboardType: TextInputType.number,
        isEditable: isEditable,
        unit: 'und',
      ),
    ),
  ],
)
        
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

  Widget _buildCompactTextField({
  required String label,
  required TextEditingController controller,
  required IconData icon,
  required Color color,
  required bool isEditable,
  TextInputType keyboardType = TextInputType.text,
  String? unit, // Nuevo parámetro para unidad de medida
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Título del campo
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
      Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: isEditable,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: isEditable ? 'Ingrese $label' : 'Sin datos',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isEditable ? Colors.grey.shade400 : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            child: const Icon(Icons.local_gas_station, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Formulario Anfocharger',
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
    Color color = const Color(0xFF1B5E6B),
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
              Icon(icon, size: 14, color: color),
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
          icon: Icon(Icons.arrow_drop_down, size: 18, color: color),
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