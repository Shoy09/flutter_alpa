import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioPerforacionVolquetes extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;
  final String codigo; 

  const DialogoFormularioPerforacionVolquetes({
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
  State<DialogoFormularioPerforacionVolquetes> createState() => _DialogoFormularioPerforacionState();
}

class _DialogoFormularioPerforacionState extends State<DialogoFormularioPerforacionVolquetes> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Variables para INICIO
  String? ubicacionInicioSeleccionado;
  List<String> opcionesUbicacionInicio = [];
  final TextEditingController ubicacionInicioController = TextEditingController();
  List<String> opcionesUbicacionInicioFiltradas = [];
  FocusNode ubicacionInicioFocusNode = FocusNode();
  bool mostrarSugerencias = false;

  // Variable para DESTINO
  String? ubicacionDestinoSeleccionado;
  int? ubicacionDestinoId;
  final TextEditingController ubicacionDestinoController = TextEditingController();
  List<String> opcionesUbicacionDestinoFiltradas = [];
  FocusNode ubicacionDestinoFocusNode = FocusNode();
  bool mostrarSugerenciasDestino = false;

  // Número de cucharas
  final TextEditingController nCucharasController = TextEditingController();
  final TextEditingController mineralController = TextEditingController();
  final TextEditingController desmonteController = TextEditingController();
  final TextEditingController rellenoController = TextEditingController();
  final TextEditingController numeroVolqueteController = TextEditingController();
  final TextEditingController relaveController = TextEditingController();

  // NUEVOS CAMPOS
  final TextEditingController totalViajesController = TextEditingController();
  String? scoopSeleccionado;
  List<String> opcionesScoop = [];

  // Opciones para ubicación destino
  List<Map<String, dynamic>> destinosDisponibles = [];
  List<String> opcionesUbicacionDestino = [];

  // Almacenar objetos completos
  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];
  
  // Almacenar orígenes de SCOOPTRAM
  List<Map<String, dynamic>> origenesScooptram = [];
  
  // Materiales
  List<Map<String, dynamic>> materialesDisponibles = [];
  String? materialSeleccionado;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
    _cargarOpcionesScoop();
    print('Código: ${widget.codigo}');
  }

  Future<void> _cargarOpcionesScoop() async {
    try {
      final dbHelper = DatabaseHelper();
      // Obtener equipos de tipo SCOOPTRAM
      final equipos = await dbHelper.getEquipos();
      
      // Filtrar equipos que sean SCOOPTRAM (ajusta según tu lógica)
      final scoops = equipos
          .where((e) => e.nombre.toLowerCase().contains('scoop') || 
                       e.proceso?.toLowerCase() == 'scooptram')
          .map((e) => e.codigo)
          .toList();
      
      setState(() {
        opcionesScoop = scoops.cast<String>()..sort();
      });
    } catch (e) {
      print("Error cargando opciones de scoop: $e");
      setState(() {
        opcionesScoop = [];
      });
    }
  }

  // Getter para saber si debe mostrar la sección de cucharas
  bool get _debeMostrarCucharas {
    final codigosOmitir = ['111', '112'];
    final codigoStr = widget.codigo.toString();
    return !codigosOmitir.contains(codigoStr);
  }

  Future<void> _cargarMateriales() async {
    try {
      final dbHelper = DatabaseHelper();
      final materiales = await dbHelper.getMateriales('ACARREO');
      setState(() {
        materialesDisponibles = materiales;
      });
    } catch (e) {
      print("Error cargando materiales: $e");
      setState(() => materialesDisponibles = []);
    }
  }

  Future<void> _cargarDatosDesdeBD() async {
    setState(() => isLoading = true);
    
    try {
      await Future.wait([
        _cargarPlanesCombinados(),
        _cargarDestinosSCOOPTRAM(),
        _cargarMateriales(),
      ]);
    } catch (e) {
      print("Error cargando datos: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cargarDestinosSCOOPTRAM() async {
    try {
      final dbHelper = DatabaseHelper();
      destinosDisponibles = await dbHelper.getOrigenDestino('SCOOPTRAM', 'DESTINO');
      _generarOpcionesUbicacionDestino();
    } catch (e) {
      print("Error cargando destinos: $e");
      setState(() {
        destinosDisponibles = [];
        opcionesUbicacionDestino = [];
        opcionesUbicacionDestinoFiltradas = [];
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
        dbHelper.getOrigenDestino('SCOOPTRAM', 'ORIGEN'),
      ]);
      
      planesMensualCompletos = results[0] as List<PlanMensual>;
      planesProduccionCompletos = results[1] as List<PlanProduccion>;
      planesMetrajeCompletos = results[2] as List<PlanMetraje>;
      origenesScooptram = results[3] as List<Map<String, dynamic>>;

      _generarOpcionesUbicacionInicio();
      
    } catch (e) {
      print("Error cargando planes: $e");
      setState(() {
        opcionesUbicacionInicio = [
          'Galería_Labor01_AlaNorte',
          'Galería_Labor02_AlaSur',
          'Crucero_Labor03_AlaEste',
          'Origen_SCOOPTRAM'
        ];
        opcionesUbicacionDestino = [
          'Galería_Labor01_AlaNorte',
          'Galería_Labor02_AlaSur',
          'Destino_SCOOPTRAM_1',
          'Destino_SCOOPTRAM_2'
        ];
        opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
        opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
      });
    }
  }

  void _generarOpcionesUbicacionInicio() {
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
    
    for (var origen in origenesScooptram) {
      if (origen['nombre'] != null && origen['nombre'].toString().isNotEmpty) {
        opcionesCombinadas.add(origen['nombre']);
      }
    }
    
    setState(() {
      opcionesUbicacionInicio = opcionesCombinadas.toList()..sort();
      opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
    });
  }

  void _generarOpcionesUbicacionDestino() {
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
    
    for (var destino in destinosDisponibles) {
      if (destino['nombre'] != null && destino['nombre'].toString().isNotEmpty) {
        opcionesCombinadas.add(destino['nombre']);
      }
    }
    
    setState(() {
      opcionesUbicacionDestino = opcionesCombinadas.toList()..sort();
      opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
    });
  }

  void _cargarDatosIniciales() {
    if (widget.datosIniciales != null) {
      setState(() {
        ubicacionInicioSeleccionado = widget.datosIniciales!['labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_inicio'] : null;

        if (ubicacionInicioSeleccionado != null) {
          ubicacionInicioController.text = ubicacionInicioSeleccionado!;
        }
            
        ubicacionDestinoId = widget.datosIniciales!['ubicacion_destino_id'];
        ubicacionDestinoSeleccionado = widget.datosIniciales!['ubicacion_destino'];
      
        if (ubicacionDestinoSeleccionado != null) {
          ubicacionDestinoController.text = ubicacionDestinoSeleccionado!;
        }

        nCucharasController.text = widget.datosIniciales!['toneladas']?.toString() ?? '0';
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
        materialSeleccionado = widget.datosIniciales!['material']?.isNotEmpty == true 
            ? widget.datosIniciales!['material'] : null;

        mineralController.text = widget.datosIniciales!['mineral']?.toString() ?? '';
        desmonteController.text = widget.datosIniciales!['desmonte']?.toString() ?? '';
        rellenoController.text = widget.datosIniciales!['relleno']?.toString() ?? '';
        numeroVolqueteController.text = widget.datosIniciales!['numero_volquete']?.toString() ?? '';
        relaveController.text = widget.datosIniciales!['relave']?.toString() ?? '';

        // NUEVOS CAMPOS
        scoopSeleccionado = widget.datosIniciales!['scoop']?.isNotEmpty == true 
            ? widget.datosIniciales!['scoop'] : null;
        totalViajesController.text = widget.datosIniciales!['total_viajes']?.toString() ?? '0';
      });
    }
  }

  Future<void> _guardarDatos() async {
    String ubicacionInicioFinal = ubicacionInicioSeleccionado ?? '';
    if (ubicacionInicioFinal.isEmpty && ubicacionInicioController.text.trim().isNotEmpty) {
      ubicacionInicioFinal = ubicacionInicioController.text.trim();
    }
    
    int? destinoId;
    if (ubicacionDestinoSeleccionado != null) {
      final destinoEncontrado = destinosDisponibles.firstWhere(
        (destino) => destino['nombre'] == ubicacionDestinoSeleccionado,
        orElse: () => {},
      );
      destinoId = destinoEncontrado['id'];
    }
    
    String ubicacionDestinoFinal = ubicacionDestinoSeleccionado ?? '';
    if (ubicacionDestinoFinal.isEmpty && ubicacionDestinoController.text.trim().isNotEmpty) {
      ubicacionDestinoFinal = ubicacionDestinoController.text.trim();
    }
    
    Map<String, dynamic> datosFormulario = {
      'labor_inicio': ubicacionInicioFinal,
      'ubicacion_destino_id': destinoId ?? 0,
      'ubicacion_destino': ubicacionDestinoFinal,
      'toneladas': double.tryParse(nCucharasController.text) ?? 0.0,
      'material': materialSeleccionado ?? '', 
      'observaciones': observacionesController.text,
      'mineral': mineralController.text.trim().isEmpty ? '' : mineralController.text.trim(),
      'desmonte': desmonteController.text.trim().isEmpty ? '' : desmonteController.text.trim(),
      'relleno': rellenoController.text.trim().isEmpty ? '' : rellenoController.text.trim(),
      'numero_volquete': numeroVolqueteController.text.trim().isEmpty ? '' : numeroVolqueteController.text.trim(),
      'relave': relaveController.text.trim().isEmpty ? '' : relaveController.text.trim(),
      'scoop': scoopSeleccionado ?? '',
      'total_viajes': int.tryParse(totalViajesController.text) ?? 0,
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

  // NUEVA SECCIÓN: Scoops y Viaje
  Widget _buildSeccionScoopsViaje() {
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
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.directions_car, size: 14, color: Colors.teal),
              ),
              const SizedBox(width: 6),
              const Text(
                'Scoops y Viaje',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          isSmallScreen
              ? Column(
                  children: [
                    _buildDropdownScoop(),
                    const SizedBox(height: 8),
                    _buildTextFieldTotalViajes(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildDropdownScoop()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextFieldTotalViajes()),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDropdownScoop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.precision_manufacturing, size: 12, color: Colors.teal),
            const SizedBox(width: 4),
            Text(
              'Scoop',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.teal),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: scoopSeleccionado,
              hint: Row(
                children: [
                  Icon(Icons.precision_manufacturing, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Seleccionar scoop',
                      style: TextStyle(
                        fontSize: 11,
                        color: isEditable ? Colors.grey.shade600 : Colors.grey.shade400,
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
              items: opcionesScoop.map((String scoop) {
                return DropdownMenuItem<String>(
                  value: scoop,
                  child: Text(
                    scoop,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: isEditable ? (newValue) {
                setState(() {
                  scoopSeleccionado = newValue;
                });
              } : null,
            ),
          ),
        ),
        if (opcionesScoop.isEmpty && !isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No hay scoops disponibles',
              style: TextStyle(fontSize: 10, color: Colors.red.shade400),
            ),
          ),
      ],
    );
  }

  Widget _buildTextFieldTotalViajes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, size: 12, color: Colors.teal),
            const SizedBox(width: 4),
            Text(
              'Total Viajes',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.teal),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: totalViajesController,
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
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeccionDatos() {
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.bar_chart, size: 14, color: Colors.purple),
              ),
              const SizedBox(width: 6),
              const Text(
                'Datos de Operación',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          isSmallScreen
              ? Column(
                  children: [
                    _buildDatoTextField('Mineral', mineralController, Icons.tonality),
                    const SizedBox(height: 8),
                    _buildDatoTextField('Desmonte', desmonteController, Icons.landscape),
                    const SizedBox(height: 8),
                    _buildDatoTextField('Relleno', rellenoController, Icons.grain),
                    const SizedBox(height: 8),
                    _buildDatoTextField('N° Volquete', numeroVolqueteController, Icons.local_shipping),
                    const SizedBox(height: 8),
                    _buildDatoTextField('Relave', relaveController, Icons.water),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildDatoTextField('Mineral', mineralController, Icons.tonality)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDatoTextField('Desmonte', desmonteController, Icons.landscape)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDatoTextField('Relleno', rellenoController, Icons.grain)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDatoTextField('N° Volquete', numeroVolqueteController, Icons.local_shipping)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDatoTextField('Relave', relaveController, Icons.water)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDatoTextField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.purple.shade300),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.purple.shade700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: isEditable,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: 'Ingrese $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nCucharasController.dispose();
    observacionesController.dispose();
    mineralController.dispose();
    desmonteController.dispose();
    rellenoController.dispose();
    numeroVolqueteController.dispose();
    relaveController.dispose();
    totalViajesController.dispose();
    ubicacionInicioController.dispose();
    ubicacionInicioFocusNode.dispose();
    ubicacionDestinoController.dispose();
    ubicacionDestinoFocusNode.dispose();
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
        : 700.0;
    
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
                          _buildSeccionUbicacionDestino(),
                          if (_debeMostrarCucharas) ...[
                            const SizedBox(height: 16),
                            _buildSeccionCucharas(),
                          ],
                          const SizedBox(height: 16),
                          _buildSeccionScoopsViaje(), // NUEVA SECCIÓN
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

  // Los siguientes métodos se mantienen igual que en tu código original:
  // _buildSeccionUbicacionInicio(), _buildSeccionUbicacionDestino(), 
  // _buildSeccionCucharas(), _buildTextFieldCucharas(), _buildDropdownMaterial(),
  // _buildSeccionObservaciones(), _buildHeader(), _buildEstadoBadge(), _buildFooter()
  
  // Incluye aquí todos los métodos que ya tenías sin cambios (son demasiado largos para repetirlos)
  // Pero asegúrate de mantenerlos exactamente igual que en tu código original
  
  Widget _buildSeccionUbicacionInicio() {
    // ... (tu código original sin cambios)
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ubicacionInicioController,
                focusNode: ubicacionInicioFocusNode,
                enabled: isEditable,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Buscar ubicación...',
                  prefixIcon: Icon(Icons.search, size: 18, color: widget.primaryColor),
                  suffixIcon: ubicacionInicioController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                          onPressed: () {
                            ubicacionInicioController.clear();
                            setState(() {
                              opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
                              mostrarSugerencias = false;
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
                      opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
                      mostrarSugerencias = false;
                      ubicacionInicioSeleccionado = null;
                    } else {
                      opcionesUbicacionInicioFiltradas = opcionesUbicacionInicio
                          .where((item) => item.toLowerCase().contains(text.toLowerCase()))
                          .toList();
                      
                      final esMatchExacto = opcionesUbicacionInicio
                          .any((item) => item.toLowerCase() == text.toLowerCase());
                      
                      if (esMatchExacto) {
                        mostrarSugerencias = true;
                      } else if (opcionesUbicacionInicioFiltradas.isNotEmpty) {
                        mostrarSugerencias = true;
                      } else {
                        ubicacionInicioSeleccionado = text;
                        mostrarSugerencias = false;
                      }
                    }
                  });
                },
                onTap: () {
                  setState(() {
                    mostrarSugerencias = true;
                    if (ubicacionInicioController.text.isEmpty) {
                      opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
                    }
                  });
                },
              ),
              
              if (mostrarSugerencias && opcionesUbicacionInicioFiltradas.isNotEmpty && isEditable)
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
                    itemCount: opcionesUbicacionInicioFiltradas.length,
                    itemBuilder: (context, index) {
                      final suggestion = opcionesUbicacionInicioFiltradas[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            ubicacionInicioSeleccionado = suggestion;
                            ubicacionInicioController.text = suggestion;
                            mostrarSugerencias = false;
                          });
                        },
                      );
                    },
                  ),
                ),
                
              if (ubicacionInicioSeleccionado != null && ubicacionInicioController.text.isEmpty)
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
                          ubicacionInicioSeleccionado!,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEditable)
                        InkWell(
                          onTap: () {
                            setState(() {
                              ubicacionInicioSeleccionado = null;
                              ubicacionInicioController.clear();
                            });
                          },
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (opcionesUbicacionInicio.isEmpty && !isLoading)
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

  Widget _buildSeccionUbicacionDestino() {
    // ... (tu código original sin cambios)
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange),
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
                  'ACARREO',
                  style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ubicacionDestinoController,
                focusNode: ubicacionDestinoFocusNode,
                enabled: isEditable,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Buscar destino...',
                  prefixIcon: Icon(Icons.search, size: 18, color: widget.primaryColor),
                  suffixIcon: ubicacionDestinoController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                          onPressed: () {
                            ubicacionDestinoController.clear();
                            setState(() {
                              opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
                              mostrarSugerenciasDestino = false;
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
                      opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
                      mostrarSugerenciasDestino = false;
                      ubicacionDestinoSeleccionado = null;
                    } else {
                      opcionesUbicacionDestinoFiltradas = opcionesUbicacionDestino
                          .where((item) => item.toLowerCase().contains(text.toLowerCase()))
                          .toList();
                      
                      final esMatchExacto = opcionesUbicacionDestino
                          .any((item) => item.toLowerCase() == text.toLowerCase());
                      
                      if (esMatchExacto) {
                        mostrarSugerenciasDestino = true;
                      } else if (opcionesUbicacionDestinoFiltradas.isNotEmpty) {
                        mostrarSugerenciasDestino = true;
                      } else {
                        ubicacionDestinoSeleccionado = text;
                        mostrarSugerenciasDestino = false;
                      }
                    }
                  });
                },
                onTap: () {
                  setState(() {
                    mostrarSugerenciasDestino = true;
                    if (ubicacionDestinoController.text.isEmpty) {
                      opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
                    }
                  });
                },
              ),
              
              if (mostrarSugerenciasDestino && opcionesUbicacionDestinoFiltradas.isNotEmpty && isEditable)
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
                    itemCount: opcionesUbicacionDestinoFiltradas.length,
                    itemBuilder: (context, index) {
                      final suggestion = opcionesUbicacionDestinoFiltradas[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            ubicacionDestinoSeleccionado = suggestion;
                            ubicacionDestinoController.text = suggestion;
                            mostrarSugerenciasDestino = false;
                          });
                        },
                      );
                    },
                  ),
                ),
                
              if (ubicacionDestinoSeleccionado != null && 
                  ubicacionDestinoSeleccionado!.isNotEmpty && 
                  ubicacionDestinoController.text.isEmpty)
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
                          ubicacionDestinoSeleccionado!,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEditable)
                        InkWell(
                          onTap: () {
                            setState(() {
                              ubicacionDestinoSeleccionado = null;
                              ubicacionDestinoController.clear();
                              opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
                            });
                          },
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (opcionesUbicacionDestino.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay destinos disponibles',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionCucharas() {
    // ... (tu código original sin cambios)
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
                child: Icon(Icons.calculate, size: 14, color: widget.primaryColor),
              ),
              const SizedBox(width: 6),
              Text(
                'Toneladas y Material',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          isSmallScreen
              ? Column(
                  children: [
                    _buildTextFieldCucharas(),
                    const SizedBox(height: 8),
                    _buildDropdownMaterial(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildTextFieldCucharas()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDropdownMaterial()),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildTextFieldCucharas() {
    // ... (tu código original sin cambios)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toneladas',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget.primaryColor),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: nCucharasController,
          enabled: isEditable,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ingrese número',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDropdownMaterial() {
    // ... (tu código original sin cambios)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory, size: 12, color: widget.primaryColor),
            const SizedBox(width: 4),
            Text(
              'Material',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: materialSeleccionado,
              hint: Row(
                children: [
                  Icon(Icons.inventory_2, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Seleccionar material',
                      style: TextStyle(
                        fontSize: 11,
                        color: isEditable ? Colors.grey.shade600 : Colors.grey.shade400,
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
              items: materialesDisponibles.map((Map<String, dynamic> material) {
                return DropdownMenuItem<String>(
                  value: material['nombre'] as String,
                  child: Text(
                    material['nombre'] as String,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: isEditable ? (newValue) {
                setState(() {
                  materialSeleccionado = newValue;
                });
              } : null,
            ),
          ),
        ),
        if (materialesDisponibles.isEmpty && !isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No hay materiales disponibles',
              style: TextStyle(fontSize: 10, color: Colors.red.shade400),
            ),
          ),
      ],
    );
  }

  Widget _buildSeccionObservaciones() {
    // ... (tu código original sin cambios)
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
    // ... (tu código original sin cambios)
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
              isSmallScreen ? 'ACARREO' : 'Formulario ACARREO',
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
    // ... (tu código original sin cambios)
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
    // ... (tu código original sin cambios)
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