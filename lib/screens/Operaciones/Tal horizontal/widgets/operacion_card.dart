import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Equipo.dart';
import 'package:i_miner/screens/widgets/custom_dropdown.dart';
import 'package:i_miner/screens/widgets/custom_field.dart';

class OperacionCard extends StatefulWidget {
  final Function(Map<String, dynamic>) onOperacionCreada;
  final Function(String?) onTurnoChanged;
  final Function(String) onFechaChanged;
  final String? dniUsuario;
  final Map<String, dynamic>? operacionExistente; 

  final String fechaActual;
  final String? selectedTurno;

  final Color primaryColor;

  const OperacionCard({
    Key? key,
    required this.onOperacionCreada,
    required this.onTurnoChanged,
    required this.onFechaChanged,
    required this.fechaActual,
    required this.selectedTurno,
    required this.operacionExistente,
    this.dniUsuario,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<OperacionCard> createState() => _OperacionCardState();
}

class _OperacionCardState extends State<OperacionCard> {

  String? selectedEquipo;
  String? selectedCodigo;
  String? selectedModelo;
  String? selectedJefeGuardia;
  String? selectedSeccion;
  String? operador;
  
  bool get operacionBloqueada => widget.operacionExistente != null;

  final String operadorEjemplo = "Juan Pérez";

  List<String> turnos = ['DÍA', 'NOCHE'];

  List<String> equipos = [];
  List<String> jefesGuardia = [];
  List<String> secciones = [];

  // Mapas para relaciones
  final Map<String, List<String>> codigosPorEquipo = {};
  final Map<String, String> modeloPorCodigo = {}; // ✅ Ahora es 1:1 (código -> modelo)
  final Map<String, String> equipoPorCodigo = {};  // ✅ Para saber qué equipo pertenece cada código
  
  List<Equipo> equiposCompletos = [];
  List<String> codigosFiltrados = [];

  @override
  void initState() {
    super.initState();
    
    _cargarOperadorPorDni();
    _cargarEquipos();
    _cargarJefesGuardia();
    _cargarSecciones();

    if (widget.operacionExistente != null) {
      selectedEquipo = widget.operacionExistente!['equipo'];
          selectedCodigo = widget.operacionExistente!['n_equipo'];      // ← Cambiado
    selectedModelo = widget.operacionExistente!['modelo_equipo']; // ← Cambiado
    selectedJefeGuardia = widget.operacionExistente!['jefe_guardia']; // ← Cambiad
      selectedSeccion = widget.operacionExistente!['seccion'];
    }
  }

  Future<void> _cargarSecciones() async {
    try {
      final dbHelper = DatabaseHelper();
      final guardiasDB = await dbHelper.getGuardias();

      setState(() {
        secciones = guardiasDB.map((g) => g.guardia).toList()..sort();
      });

      print("Guardias cargadas: $secciones");
    } catch (e) {
      print("Error cargando guardias: $e");
      setState(() {
        secciones = [];
      });
    }
  }

  Future<void> _cargarOperadorPorDni() async {
    if (widget.dniUsuario == null) return;

    try {
      final dbHelper = DatabaseHelper();
      final usuario = await dbHelper.getUserByDni(widget.dniUsuario!);

      if (usuario != null) {
        setState(() {
          operador = '${usuario['nombres']} ${usuario['apellidos']}';
        });
        print('Operador cargado: $operador');
      } else {
        print('No se encontró usuario con DNI: ${widget.dniUsuario}');
        setState(() {
          operador = operadorEjemplo;
        });
      }
    } catch (e) {
      print('Error al cargar operador: $e');
      setState(() {
        operador = operadorEjemplo;
      });
    }
  }

  Future<void> _cargarEquipos() async {
    try {
      codigosPorEquipo.clear();
      modeloPorCodigo.clear();
      equipoPorCodigo.clear();

      final dbHelper = DatabaseHelper();
      equiposCompletos = await dbHelper.getEquipos();

      String tipoOperacion = 'PERFORACIÓN HORIZONTAL';

      List<Equipo> equiposFiltrados = equiposCompletos
          .where((e) => e.proceso == tipoOperacion)
          .toList();

      Set<String> nombresEquipos = {};

      for (var equipo in equiposFiltrados) {
        nombresEquipos.add(equipo.nombre);

        // equipo -> códigos
        codigosPorEquipo.putIfAbsent(equipo.nombre, () => []);
        if (!codigosPorEquipo[equipo.nombre]!.contains(equipo.codigo)) {
          codigosPorEquipo[equipo.nombre]!.add(equipo.codigo);
        }

        // código -> modelo (1:1)
        modeloPorCodigo[equipo.codigo] = equipo.modelo;
        
        // código -> equipo
        equipoPorCodigo[equipo.codigo] = equipo.nombre;
      }

      setState(() {
        equipos = nombresEquipos.toList()..sort();
        codigosFiltrados = _obtenerTodosLosCodigos();
        
        // Auto-seleccionar si solo hay un equipo
        _autoSelectSingleEquipo();
      });

      print('Equipos cargados: ${equipos.length}');
      print('Total códigos: ${codigosFiltrados.length}');

    } catch (e) {
      print("Error cargando equipos: $e");
    }
  }

  // Obtener todos los códigos de todos los equipos
  List<String> _obtenerTodosLosCodigos() {
    List<String> todosCodigos = [];
    for (var codigos in codigosPorEquipo.values) {
      todosCodigos.addAll(codigos);
    }
    return todosCodigos;
  }

  void _autoSelectSingleEquipo() {
    // Si hay exactamente un equipo y ninguno está seleccionado
    if (equipos.length == 1 && selectedEquipo == null && !operacionBloqueada) {
      setState(() {
        selectedEquipo = equipos.first;
        // Filtrar códigos para ese equipo
        codigosFiltrados = codigosPorEquipo[selectedEquipo] ?? [];
        
        // Si además hay exactamente un código, seleccionarlo automáticamente
        if (codigosFiltrados.length == 1) {
          _autoSelectSingleCodigo();
        }
      });
    }
  }

  void _autoSelectSingleCodigo() {
    if (codigosFiltrados.length == 1 && selectedCodigo == null && !operacionBloqueada) {
      setState(() {
        selectedCodigo = codigosFiltrados.first;
        _actualizarModeloPorCodigo(selectedCodigo!);
      });
    }
  }

  void _actualizarModeloPorCodigo(String codigo) {
  print('🔍 Buscando modelo para código: $codigo');
  print('📋 modeloPorCodigo actual: $modeloPorCodigo');
  
  String? modelo = modeloPorCodigo[codigo];
  String? equipo = equipoPorCodigo[codigo];
  
  if (modelo != null) {
    print('✅ Modelo encontrado: $modelo');
    setState(() {
      selectedModelo = modelo;
      if (equipo != null) {
        selectedEquipo = equipo;
      }
    });
  } else {
    print('❌ No se encontró modelo para el código: $codigo');
    setState(() {
      selectedModelo = null;
      selectedEquipo = null;
    });
    
    // Mostrar error al usuario
    _showSnackbar('El código $codigo no tiene un modelo asociado', Colors.orange);
  }
}

  Future<void> _cargarJefesGuardia() async {
    try {
      final dbHelper = DatabaseHelper();
      List<String> jefesList = await dbHelper.getJefesGuardiaNombres();

      print("Jefes de guardia obtenidos de la BD local: $jefesList");

      setState(() {
        jefesGuardia = jefesList..sort();
      });

      print('Jefes de guardia cargados: $jefesGuardia');
    } catch (e) {
      print("Error al obtener los jefes de guardia: $e");
      setState(() {
        jefesGuardia = [];
      });
    }
  }

  @override
  void didUpdateWidget(covariant OperacionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.operacionExistente != oldWidget.operacionExistente) {
      if (widget.operacionExistente != null) {
        setState(() {
          selectedEquipo = widget.operacionExistente!['equipo'];
 selectedCodigo = widget.operacionExistente!['n_equipo'];      // ← Cambiado
        selectedModelo = widget.operacionExistente!['modelo_equipo']; // ← Cambiado
        selectedJefeGuardia = widget.operacionExistente!['jefe_guardia']; // ← Cambiado
          selectedSeccion = widget.operacionExistente!['seccion'];
        });
      } else {
        setState(() {
          selectedEquipo = null;
          selectedCodigo = null;
          selectedModelo = null;
          selectedJefeGuardia = null;
          selectedSeccion = null;
        });
      }
    }
  }

  Future<void> refrescarDatos() async {
    await Future.wait([
      _cargarEquipos(),
      _cargarJefesGuardia(),
      _cargarOperadorPorDni(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (equipos.isEmpty || jefesGuardia.isEmpty)
              const LinearProgressIndicator(),
            _buildFormFields(),
            const SizedBox(height: 20),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth = constraints.maxWidth;
        
        // Detectar tamaño de pantalla
        if (cardWidth < 600) {
          return _buildMobileLayout();
        } else if (cardWidth >= 600 && cardWidth < 900) {
          return _buildTabletLayout();
        } else {
          return _buildDesktopLayout(cardWidth);
        }
      },
    );
  }

  // Layout para móviles
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Fecha y Turno
        Row(
          children: [
            Expanded(child: _buildFechaField()),
            const SizedBox(width: 10),
            Expanded(
              child: CustomMaterialDropdown(
                label: 'Turno',
                value: widget.selectedTurno,
                items: turnos,
                onChanged: operacionBloqueada ? null : widget.onTurnoChanged,
                icon: Icons.access_time,
                hint: 'Turno',
                primaryColor: widget.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Fila 2: Solo Código (Equipo y Modelo van ocultos)
        CustomMaterialDropdown(
          label: 'Código',
          value: selectedCodigo,
          items: codigosFiltrados,
          onChanged: operacionBloqueada
              ? null
              : (value) {
                  setState(() {
                    selectedCodigo = value;
                    _actualizarModeloPorCodigo(value!);
                  });
                },
          icon: Icons.qr_code,
          hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código',
          primaryColor: widget.primaryColor,
        ),
        const SizedBox(height: 12),
        
        // Fila 3: Operador y Jefe Guardia
        Row(
          children: [
            Expanded(child: _buildOperadorField()),
            const SizedBox(width: 10),
            Expanded(
              child: CustomMaterialDropdown(
                label: 'Jefe Guardia',
                value: selectedJefeGuardia,
                items: jefesGuardia,
                onChanged: operacionBloqueada
                    ? null
                    : (value) => setState(() => selectedJefeGuardia = value),
                icon: Icons.person,
                hint: jefesGuardia.isEmpty ? 'Cargando...' : 'Jefe',
                primaryColor: widget.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Fila 4: Guardia/Sección
        CustomMaterialDropdown(
          label: 'Guardia',
          value: selectedSeccion,
          items: secciones,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedSeccion = value),
          icon: Icons.map,
          hint: 'Guardia',
          primaryColor: widget.primaryColor,
        ),
      ],
    );
  }

  // Layout para tablets
  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Fecha y Turno
        Row(
          children: [
            Expanded(flex: 1, child: _buildFechaField()),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: CustomMaterialDropdown(
              label: 'Turno',
              value: widget.selectedTurno,
              items: turnos,
              onChanged: operacionBloqueada ? null : widget.onTurnoChanged,
              icon: Icons.access_time,
              hint: 'Turno',
              primaryColor: widget.primaryColor,
            )),
          ],
        ),
        const SizedBox(height: 16),
        
        // Fila 2: Código
        CustomMaterialDropdown(
          label: 'Código',
          value: selectedCodigo,
          items: codigosFiltrados,
          onChanged: operacionBloqueada
              ? null
              : (value) {
                  setState(() {
                    selectedCodigo = value;
                    _actualizarModeloPorCodigo(value!);
                  });
                },
          icon: Icons.qr_code,
          hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código',
          primaryColor: widget.primaryColor,
        ),
        const SizedBox(height: 16),
        
        // Fila 3: Operador y Jefe Guardia
        Row(
          children: [
            Expanded(child: _buildOperadorField()),
            const SizedBox(width: 12),
            Expanded(
              child: CustomMaterialDropdown(
                label: 'Jefe Guardia',
                value: selectedJefeGuardia,
                items: jefesGuardia,
                onChanged: operacionBloqueada
                    ? null
                    : (value) => setState(() => selectedJefeGuardia = value),
                icon: Icons.person,
                hint: jefesGuardia.isEmpty ? 'Cargando...' : 'Jefe',
                primaryColor: widget.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Fila 4: Guardia
        CustomMaterialDropdown(
          label: 'Guardia',
          value: selectedSeccion,
          items: secciones,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedSeccion = value),
          icon: Icons.map,
          hint: 'Guardia',
          primaryColor: widget.primaryColor,
        ),
      ],
    );
  }

  // Layout para desktop
  Widget _buildDesktopLayout(double cardWidth) {
    Map<String, double> fieldWeights = {
      'fecha': 1.5,
      'turno': 1.5,
      'codigo': 2.0,      // El código ocupa más espacio ahora
      'operador': 1.5,
      'jefe': 1.5,
      'seccion': 1.5,
    };

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['fecha']!),
          child: _buildFechaField(),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['turno']!),
          child: CustomMaterialDropdown(
            label: 'Turno',
            value: widget.selectedTurno,
            items: turnos,
            onChanged: operacionBloqueada ? null : widget.onTurnoChanged,
            icon: Icons.access_time,
            hint: 'Turno',
            primaryColor: widget.primaryColor,
          ),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['codigo']!),
          child: CustomMaterialDropdown(
            label: 'Código',
            value: selectedCodigo,
            items: codigosFiltrados,
            onChanged: operacionBloqueada
                ? null
                : (value) {
                    setState(() {
                      selectedCodigo = value;
                      _actualizarModeloPorCodigo(value!);
                    });
                  },
            icon: Icons.qr_code,
            hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código',
            primaryColor: widget.primaryColor,
          ),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['operador']!),
          child: _buildOperadorField(),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['jefe']!),
          child: CustomMaterialDropdown(
            label: 'Jefe Guardia',
            value: selectedJefeGuardia,
            items: jefesGuardia,
            onChanged: operacionBloqueada
                ? null
                : (value) => setState(() => selectedJefeGuardia = value),
            icon: Icons.person,
            hint: jefesGuardia.isEmpty ? 'Cargando...' : 'Jefe',
            primaryColor: widget.primaryColor,
          ),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidthDesktop(cardWidth, fieldWeights['seccion']!),
          child: CustomMaterialDropdown(
            label: 'Guardia',
            value: selectedSeccion,
            items: secciones,
            onChanged: operacionBloqueada
                ? null
                : (value) => setState(() => selectedSeccion = value),
            icon: Icons.map,
            hint: 'Guardia',
            primaryColor: widget.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFlexibleField({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  double _calculateFieldWidthDesktop(double totalWidth, double weight) {
    double totalWeights = 1.5 + 1.5 + 2.0 + 1.5 + 1.5 + 1.5;
    double spacing = 12 * 5;
    double padding = 16 * 2;
    double availableWidth = totalWidth - spacing - padding;
    return (availableWidth * weight) / totalWeights;
  }

  Widget _buildFechaField() {
    bool isEnabled = !operacionBloqueada;

    return InkWell(
      onTap: isEnabled ? _selectDate : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
              color: isEnabled
                  ? widget.primaryColor.withOpacity(0.5)
                  : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: isEnabled ? Colors.white : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fecha',
                    style: TextStyle(
                      fontSize: 11,
                      color: isEnabled ? widget.primaryColor : Colors.grey,
                    ),
                  ),
                  Text(
                    widget.fechaActual,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isEnabled ? Colors.black87 : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: isEnabled ? widget.primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperadorField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Operador',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600),
                ),
                Text(
                  operador ?? operadorEjemplo,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.person_outline,
              size: 16,
              color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: operacionBloqueada ? null : _crearOperacion,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 16),
            SizedBox(width: 6),
            Text(
              'CREAR OPERACIÓN',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(widget.fechaActual),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      String nuevaFecha = DateFormat('yyyy-MM-dd').format(picked);

      if (nuevaFecha != widget.fechaActual) {
        widget.onFechaChanged(nuevaFecha);
        _showSnackbar('Fecha actualizada: $nuevaFecha', Colors.green);
      }
    }
  }

  void _crearOperacion() {
    // Validar solo los campos visibles (Código incluye equipo y modelo automáticamente)
    if (widget.selectedTurno == null ||
        selectedCodigo == null ||
        selectedJefeGuardia == null ||
        selectedSeccion == null) {
      _showSnackbar('Complete todos los campos', Colors.orange);
      return;
    }

    // Validación adicional: si por algún motivo no se asignó el modelo
    if (selectedModelo == null) {
      _showSnackbar('Error: No se pudo determinar el modelo del equipo', Colors.red);
      return;
    }

    widget.onOperacionCreada({
      'turno': widget.selectedTurno,
      'equipo': selectedEquipo,      // Se asigna automáticamente
      'codigo': selectedCodigo,
      'modelo': selectedModelo,      // Se asigna automáticamente
      'operador': operador ?? operadorEjemplo,
      'jefeGuardia': selectedJefeGuardia,
      'seccion': selectedSeccion,
      'fecha': widget.fechaActual,
    });

    // Limpiar campos después de crear
    setState(() {
      selectedEquipo = null;
      selectedCodigo = null;
      selectedModelo = null;
      selectedJefeGuardia = null;
      selectedSeccion = null;
      
      // Restaurar la lista completa de códigos
      codigosFiltrados = _obtenerTodosLosCodigos();
      
      // Auto-seleccionar si hay un solo equipo
      _autoSelectSingleEquipo();
    });

    _showSnackbar('Operación creada exitosamente', Colors.green);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}