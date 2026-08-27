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
  final String codigo; 

  const DialogoFormularioPerforacion({
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
  State<DialogoFormularioPerforacion> createState() => _DialogoFormularioPerforacionState();
}

class _DialogoFormularioPerforacionState extends State<DialogoFormularioPerforacion> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

  // Controlador para observaciones
  final TextEditingController observacionesController = TextEditingController();

  // Variables para INICIO
  String? ubicacionInicioSeleccionado;  // Guardará "tipoLabor_labor_ala"
List<String> opcionesUbicacionInicio = [];

// Para el buscador de ubicación inicio
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

  
  // Opciones para ubicación destino
  List<Map<String, dynamic>> destinosDisponibles = [];
  List<String> opcionesUbicacionDestino = [];


  // Almacenar objetos completos
  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];
  
  // Almacenar orígenes de SCOOPTRAM
  List<Map<String, dynamic>> origenesScooptram = [];
  

  // En _DialogoFormularioPerforacionState, agregar:
List<Map<String, dynamic>> materialesDisponibles = [];
String? materialSeleccionado;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosIniciales();
    _cargarDatosDesdeBD();
    print('Código: ${widget.codigo}');
  }

  // Getter para saber si debe mostrar la sección de cucharas
bool get _debeMostrarCucharas {
  // Códigos que NO deben mostrar cucharas: 111 y 112
  final codigosOmitir = ['111', '112'];
  
  // Convertir a string para comparar
  final codigoStr = widget.codigo.toString();
  
  return !codigosOmitir.contains(codigoStr);
}

Future<void> _cargarMateriales() async {
  try {
    final dbHelper = DatabaseHelper();
    final materiales = await dbHelper.getMateriales('SCOOPTRAM'); // Ya devuelve List<Map<String, dynamic>>
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
    
    // Generar opciones combinadas (labores del plan + destinos SCOOPTRAM)
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

    // Generar opciones combinadas para INICIO
    _generarOpcionesUbicacionInicio();
    
    // Generar opciones combinadas para DESTINO (después de tener destinos disponibles)
    // Nota: destinosDisponibles se carga en _cargarDestinosSCOOPTRAM()
    // Por eso llamamos _generarOpcionesUbicacionDestino() allí
    
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
    opcionesUbicacionInicio = opcionesCombinadas.toList()..sort();
     opcionesUbicacionInicioFiltradas = List.from(opcionesUbicacionInicio);
  });
}

void _generarOpcionesUbicacionDestino() {
  Set<String> opcionesCombinadas = {};
  
  // 1. Agregar las mismas opciones combinadas de los planes (tipoLabor_labor_ala)
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
  
  // 2. Agregar destinos de SCOOPTRAM
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

// Sincronizar el controlador con el valor seleccionado
if (ubicacionInicioSeleccionado != null) {
  ubicacionInicioController.text = ubicacionInicioSeleccionado!;
}
            
        ubicacionDestinoId = widget.datosIniciales!['ubicacion_destino_id'];
        ubicacionDestinoSeleccionado = widget.datosIniciales!['ubicacion_destino'];
      
      if (ubicacionDestinoSeleccionado != null) {
        ubicacionDestinoController.text = ubicacionDestinoSeleccionado!;
      }


        nCucharasController.text = widget.datosIniciales!['n_cucharas']?.toString() ?? '0';
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';

         // Cargar material
      materialSeleccionado = widget.datosIniciales!['material']?.isNotEmpty == true 
    ? widget.datosIniciales!['material'] : null;

        // Cargar nuevos campos
      mineralController.text = widget.datosIniciales!['mineral']?.toString() ?? '';
      desmonteController.text = widget.datosIniciales!['desmonte']?.toString() ?? '';
      rellenoController.text = widget.datosIniciales!['relleno']?.toString() ?? '';
      numeroVolqueteController.text = widget.datosIniciales!['numero_volquete']?.toString() ?? '';
      relaveController.text = widget.datosIniciales!['relave']?.toString() ?? '';
    });
      
    }
  }

Future<void> _guardarDatos() async {
  // 🔥 Obtener la ubicación inicio (seleccionada o texto libre)
  String ubicacionInicioFinal = ubicacionInicioSeleccionado ?? '';
  
  // Si no hay selección pero hay texto en el campo, usar ese texto
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
  
  // 🔥 También para destino, si es necesario (si quieres permitir texto libre en destino)
  String ubicacionDestinoFinal = ubicacionDestinoSeleccionado ?? '';
  if (ubicacionDestinoFinal.isEmpty && ubicacionDestinoController.text.trim().isNotEmpty) {
    ubicacionDestinoFinal = ubicacionDestinoController.text.trim();
  }
  
  Map<String, dynamic> datosFormulario = {
    'labor_inicio': ubicacionInicioFinal,  // 🔥 Usar la variable final
    'ubicacion_destino_id': destinoId ?? 0,
    'ubicacion_destino': ubicacionDestinoFinal,  // 🔥 Usar la variable final
    'n_cucharas': int.tryParse(nCucharasController.text) ?? 0,
    'material': materialSeleccionado ?? '', 
    'observaciones': observacionesController.text,
    'mineral': mineralController.text.trim().isEmpty ? '' : mineralController.text.trim(),
    'desmonte': desmonteController.text.trim().isEmpty ? '' : desmonteController.text.trim(),
    'relleno': rellenoController.text.trim().isEmpty ? '' : rellenoController.text.trim(),
    'numero_volquete': numeroVolqueteController.text.trim().isEmpty ? '' : numeroVolqueteController.text.trim(),
    'relave': relaveController.text.trim().isEmpty ? '' : relaveController.text.trim(),
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
        
        // Layout responsivo
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

// Método auxiliar para construir cada campo de dato
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
        keyboardType: TextInputType.text, // Texto para permitir números o texto
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

    ubicacionInicioController.dispose();  // ← Agregar
  ubicacionInicioFocusNode.dispose();   // ← Agregar

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
                        // const SizedBox(height: 16),
                        // _buildSeccionDatos(),  
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
        
        // Campo de búsqueda con autocompletado
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
      ubicacionInicioSeleccionado = null;  // 🔥 Limpiar
    } else {
      // Filtrar sugerencias
      opcionesUbicacionInicioFiltradas = opcionesUbicacionInicio
          .where((item) => item.toLowerCase().contains(text.toLowerCase()))
          .toList();
      
      // Verificar si el texto EXACTO está en la lista
      final esMatchExacto = opcionesUbicacionInicio
          .any((item) => item.toLowerCase() == text.toLowerCase());
      
      if (esMatchExacto) {
        // Coincidencia exacta: mostrar sugerencias
        mostrarSugerencias = true;
      } else if (opcionesUbicacionInicioFiltradas.isNotEmpty) {
        // Hay sugerencias: mostrar
        mostrarSugerencias = true;
      } else {
        // No hay sugerencias: es texto libre
        ubicacionInicioSeleccionado = text;  // 🔥 ASIGNAR TEXTO LIBRE
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
            
            // Lista de sugerencias
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
                constraints: BoxConstraints(
                  maxHeight: 200,
                ),
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
              
            // Mostrar valor seleccionado
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
                'SCOOPTRAM',
                style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Campo de búsqueda con autocompletado para destino
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
                            // Resetear las opciones filtradas a todas las opciones
                            opcionesUbicacionDestinoFiltradas = List.from(opcionesUbicacionDestino);
                            mostrarSugerenciasDestino = false;
                            // NO limpiar ubicacionDestinoSeleccionado aquí, 
                            // solo cuando el usuario explícitamente quiere borrar la selección
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
      // Filtrar sugerencias
      opcionesUbicacionDestinoFiltradas = opcionesUbicacionDestino
          .where((item) => item.toLowerCase().contains(text.toLowerCase()))
          .toList();
      
      // Verificar si el texto EXACTO está en la lista
      final esMatchExacto = opcionesUbicacionDestino
          .any((item) => item.toLowerCase() == text.toLowerCase());
      
      if (esMatchExacto) {
        // Coincidencia exacta: mostrar sugerencias
        mostrarSugerenciasDestino = true;
      } else if (opcionesUbicacionDestinoFiltradas.isNotEmpty) {
        // Hay sugerencias: mostrar
        mostrarSugerenciasDestino = true;
      } else {
        // No hay sugerencias: es texto libre
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
            
            // Lista de sugerencias
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
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
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
              
            // Mostrar valor seleccionado (badge de recordatorio)
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
                            // Resetear opciones filtradas
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
              'Cucharas y Material',
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

// Widget para el campo de cucharas
Widget _buildTextFieldCucharas() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'N° Cucharas',
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

// Widget para el dropdown de material
// Widget para el dropdown de material (versión simplificada)
Widget _buildDropdownMaterial() {
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
              isSmallScreen ? 'SCOOPTRAM' : 'Formulario SCOOPTRAM',
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