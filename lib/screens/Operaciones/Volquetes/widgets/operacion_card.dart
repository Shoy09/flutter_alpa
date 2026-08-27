
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/screens/widgets/custom_dropdown.dart';

class OperacionCardVolquetes extends StatefulWidget {
  final Function(Map<String, dynamic>) onOperacionCreada;
  final Function(String?) onTurnoChanged;
  final Function(String) onFechaChanged;
  final String? dniUsuario;
  final Map<String, dynamic>? operacionExistente;

  final String fechaActual;
  final String? selectedTurno;

  final Color primaryColor;

  const OperacionCardVolquetes({
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
  State<OperacionCardVolquetes> createState() => _OperacionCardState();
}

class _OperacionCardState extends State<OperacionCardVolquetes> {

  String? selectedNVolquete;
  String? selectedJefeGuardia;
  String? selectedGuardia;
  String? selectedEmpresa;  // ← nuevo campo
  String? operador;
  
  List<String> volquetes = [];
  List<String> guardias = [];
  
  // Lista directa de empresas
List<String> empresas = [];

  bool get operacionBloqueada => widget.operacionExistente != null;

  final String operadorEjemplo = "Juan Pérez";

  List<String> turnos = ['DÍA', 'NOCHE'];
  List<String> jefesGuardia = [];

  @override
  void initState() {
    super.initState();
    
    _cargarOperadorPorDni();
    _cargarVolquetes();
    _cargarEmpresas();
    _cargarJefesGuardia();
    _cargarGuardias();
    
    if (widget.operacionExistente != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cargarDatosOperacionExistente();
      });
    }
  }

  Future<void> _cargarGuardias() async {
    try {
      final dbHelper = DatabaseHelper();
      final guardiasDB = await dbHelper.getGuardias();

      setState(() {
        guardias = guardiasDB.map((g) => g.guardia).toList()..sort();
      });

      print("Guardias cargadas: $guardias");

    } catch (e) {
      print("Error cargando guardias: $e");
      setState(() {
        guardias = [];
      });
    }
  }

  void _cargarDatosOperacionExistente() {
    if (widget.operacionExistente == null) return;
    
    setState(() {
      selectedNVolquete = widget.operacionExistente!['n_volquete'];
      selectedJefeGuardia = widget.operacionExistente!['jefe_guardia'];
      selectedGuardia = widget.operacionExistente!['guardia'];
      selectedEmpresa = widget.operacionExistente!['empresa'];
    });
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

  Future<void> _cargarVolquetes() async {
  try {
    final dbHelper = DatabaseHelper();
    final equiposCompletos = await dbHelper.getEquipos();

    String tipoOperacion = 'ACARREO'; // ajusta según tu proceso

    List<String> codigos = equiposCompletos
        .where((e) => e.proceso == tipoOperacion)
        .map((e) => e.codigo)
        .toSet() // evita duplicados
        .toList()
      ..sort();

    setState(() {
      volquetes = codigos;

      if (widget.operacionExistente != null) {
        selectedNVolquete = widget.operacionExistente!['nVolquete'];
      }
    });

    print('Volquetes cargados: ${volquetes.length}');
  } catch (e) {
    print("Error cargando volquetes: $e");

    setState(() {
      volquetes = [];
    });
  }
}

Future<void> _cargarEmpresas() async {
  try {
    final dbHelper = DatabaseHelper();
    final empresasDb = await dbHelper.getEmpresas();

    List<String> nombres = empresasDb
        .map((e) => e.nombre)
        .where((nombre) => nombre.isNotEmpty)
        .toSet() // evita duplicados
        .toList()
      ..sort();

    setState(() {
      empresas = nombres;

      if (widget.operacionExistente != null) {
        selectedEmpresa = widget.operacionExistente!['empresa'];
      }
    });

    print('Empresas cargadas: ${empresas.length}');
  } catch (e) {
    print("Error cargando empresas: $e");

    setState(() {
      empresas = [];
    });
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
  void didUpdateWidget(covariant OperacionCardVolquetes oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.operacionExistente != oldWidget.operacionExistente) {
      if (widget.operacionExistente != null) {
        setState(() {
          selectedNVolquete = widget.operacionExistente!['n_volquete'];
          selectedJefeGuardia = widget.operacionExistente!['jefe_guardia'];
          selectedGuardia = widget.operacionExistente!['guardia'];
          selectedEmpresa = widget.operacionExistente!['empresa'];
        });
      } else {
        setState(() {
          selectedNVolquete = null;
          selectedJefeGuardia = null;
          selectedGuardia = null;
          selectedEmpresa = null;
        });
      }
    }
  }

  Future<void> refrescarDatos() async {
    await Future.wait([
      _cargarVolquetes(),
      _cargarJefesGuardia(),
      _cargarOperadorPorDni(),
      _cargarGuardias(),
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
            if (volquetes.isEmpty || jefesGuardia.isEmpty || guardias.isEmpty)
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
        
        // Fila 2: N° Volquete
        CustomMaterialDropdown(
          label: 'N° Volquete',
          value: selectedNVolquete,
          items: volquetes,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedNVolquete = value),
          icon: Icons.local_shipping,
          hint: volquetes.isEmpty ? 'Cargando...' : 'N° Volquete',
          primaryColor: widget.primaryColor,
        ),
        const SizedBox(height: 12),
        
        // Fila 3: Operador y Jefe Guardia (2 columnas)
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
        
        // Fila 4: Guardia
        CustomMaterialDropdown(
          label: 'Guardia',
          value: selectedGuardia,
          items: guardias,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedGuardia = value),
          icon: Icons.map,
          hint: 'Guardia',
          primaryColor: widget.primaryColor,
        ),
        const SizedBox(height: 12),
        
        // Fila 5: Empresa
        CustomMaterialDropdown(
          label: 'Empresa',
          value: selectedEmpresa,
          items: empresas,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedEmpresa = value),
          icon: Icons.business,
          hint: 'Empresa',
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
        
        // Fila 2: N° Volquete y Operador (2 columnas)
        Row(
          children: [
            Expanded(
              child: CustomMaterialDropdown(
                label: 'N° Volquete',
                value: selectedNVolquete,
                items: volquetes,
                onChanged: operacionBloqueada
                    ? null
                    : (value) => setState(() => selectedNVolquete = value),
                icon: Icons.local_shipping,
                hint: volquetes.isEmpty ? 'Cargando...' : 'N° Volquete',
                primaryColor: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildOperadorField()),
          ],
        ),
        const SizedBox(height: 16),
        
        // Fila 3: Jefe Guardia y Guardia (2 columnas)
        Row(
          children: [
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
            const SizedBox(width: 12),
            Expanded(
              child: CustomMaterialDropdown(
                label: 'Guardia',
                value: selectedGuardia,
                items: guardias,
                onChanged: operacionBloqueada
                    ? null
                    : (value) => setState(() => selectedGuardia = value),
                icon: Icons.map,
                hint: 'Guardia',
                primaryColor: widget.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Fila 4: Empresa (ocupa todo el ancho en tablet)
        CustomMaterialDropdown(
          label: 'Empresa',
          value: selectedEmpresa,
          items: empresas,
          onChanged: operacionBloqueada
              ? null
              : (value) => setState(() => selectedEmpresa = value),
          icon: Icons.business,
          hint: 'Empresa',
          primaryColor: widget.primaryColor,
        ),
      ],
    );
  }

  // Layout para desktop
  Widget _buildDesktopLayout(double cardWidth) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        _buildFlexibleField(
          width: _calculateFieldWidth(cardWidth, 1.5),
          child: _buildFechaField(),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidth(cardWidth, 1.5),
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
          width: _calculateFieldWidth(cardWidth, 1.5),
          child: CustomMaterialDropdown(
            label: 'N° Volquete',
            value: selectedNVolquete,
            items: volquetes,
            onChanged: operacionBloqueada
                ? null
                : (value) => setState(() => selectedNVolquete = value),
            icon: Icons.local_shipping,
            hint: volquetes.isEmpty ? 'Cargando...' : 'N° Volquete',
            primaryColor: widget.primaryColor,
          ),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidth(cardWidth, 1.5),
          child: _buildOperadorField(),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidth(cardWidth, 1.5),
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
          width: _calculateFieldWidth(cardWidth, 1.5),
          child: CustomMaterialDropdown(
            label: 'Guardia',
            value: selectedGuardia,
            items: guardias,
            onChanged: operacionBloqueada
                ? null
                : (value) => setState(() => selectedGuardia = value),
            icon: Icons.map,
            hint: 'Guardia',
            primaryColor: widget.primaryColor,
          ),
        ),
        _buildFlexibleField(
          width: _calculateFieldWidth(cardWidth, 1.5),
          child: CustomMaterialDropdown(
            label: 'Empresa',
            value: selectedEmpresa,
            items: empresas,
            onChanged: operacionBloqueada
                ? null
                : (value) => setState(() => selectedEmpresa = value),
            icon: Icons.business,
            hint: 'Empresa',
            primaryColor: widget.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFlexibleField({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
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

  double _calculateFieldWidth(double totalWidth, double weight) {
    double totalWeights = 7.0; // 7 campos
    double spacing = 12 * 6; // 6 espacios entre 7 campos
    double padding = 16 * 2;
    double availableWidth = totalWidth - spacing - padding;
    return (availableWidth * weight) / totalWeights;
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
    if (widget.selectedTurno == null ||
        selectedNVolquete == null ||
        selectedJefeGuardia == null ||
        selectedGuardia == null ||
        selectedEmpresa == null) {
      _showSnackbar('Complete todos los campos', Colors.orange);
      return;
    }

    widget.onOperacionCreada({
      'fecha': widget.fechaActual,
      'turno': widget.selectedTurno,
      'guardia': selectedGuardia,
      'operador': operador ?? operadorEjemplo,
      'jefeGuardia': selectedJefeGuardia,
      'nVolquete': selectedNVolquete,
      'empresa': selectedEmpresa,
    });

    setState(() {
      selectedNVolquete = null;
      selectedJefeGuardia = null;
      selectedGuardia = null;
      selectedEmpresa = null;
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