import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Equipo.dart';
import 'package:i_miner/models/TipoEquipo.dart';
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
  String? selectedJefeGuardia;
  String? selectedSeccion;
  String? operador;
  List<Map<String, dynamic>> _operadoresDisponibles = [];

  // Lista dinámica de tipos de equipo
  List<TipoEquipo> tiposEquipo = [];
  // Mapa para almacenar el estado de cada checkbox (true/false)
  Map<int, bool> tiposSeleccionados = {};

  bool get operacionBloqueada => widget.operacionExistente != null;

  final String operadorEjemplo = "Juan Pérez";

  List<String> turnos = ['DÍA', 'NOCHE'];

  List<String> equipos = [];
  List<String> jefesGuardia = [];

  List<String> secciones = [];

  final Map<String, List<String>> codigosPorEquipo = {};
  
  List<Equipo> equiposCompletos = [];
  List<String> codigosFiltrados = [];

  @override
  void initState() {
    super.initState();
    
    _cargarOperadorPorDni();
    _cargarEquipos();
    _cargarJefesGuardia();
    _cargarTiposEquipo();
    _cargarSecciones();

    if (widget.operacionExistente != null) {
      selectedEquipo = widget.operacionExistente!['equipo'];
      selectedCodigo = widget.operacionExistente!['n_equipo'];
      selectedJefeGuardia = widget.operacionExistente!['jefe_guardia'];
      selectedSeccion = widget.operacionExistente!['seccion'];

      codigosFiltrados = codigosPorEquipo[selectedEquipo] ?? [];
    }
  }

  @override
void dispose() {
  super.dispose();
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
      final String empresa = usuario['empresa'] ?? '';
      final String nombres = usuario['nombres'] ?? '';
      final String apellidos = usuario['apellidos'] ?? '';
      
      if (empresa.toUpperCase() == 'SEMINCO') {
        await _cargarOperadoresSeminco();
      } else {
        setState(() {
          operador = '$nombres $apellidos';
          _operadoresDisponibles = [];
        });
        print('Operador automático cargado: $operador (Empresa: $empresa)');
      }
    } else {
      print('No se encontró usuario con DNI: ${widget.dniUsuario}');
      setState(() {
        operador = operadorEjemplo;
        _operadoresDisponibles = [];
      });
    }
  } catch (e) {
    print('Error al cargar operador: $e');
    setState(() {
      operador = operadorEjemplo;
      _operadoresDisponibles = [];
    });
  }
}

Future<void> _cargarOperadoresSeminco() async {
  try {
    final dbHelper = DatabaseHelper();
    final List<Map<String, dynamic>> usuarios = await dbHelper.getAllUsuarios();
    
    final usuarioActual = await dbHelper.getUserByDni(widget.dniUsuario!);
    final String nombreCompletoActual = usuarioActual != null 
        ? '${usuarioActual['nombres']} ${usuarioActual['apellidos']}'
        : '';
    
    List<Map<String, dynamic>> operadoresOrdenados = List.from(usuarios);
    operadoresOrdenados.sort((a, b) {
      final String nombreA = '${a['nombres']} ${a['apellidos']}';
      final String nombreB = '${b['nombres']} ${b['apellidos']}';
      
      if (nombreA == nombreCompletoActual) return -1;
      if (nombreB == nombreCompletoActual) return 1;
      return nombreA.compareTo(nombreB);
    });
    
    setState(() {
      _operadoresDisponibles = operadoresOrdenados;
      
      if (_operadoresDisponibles.isNotEmpty) {
        final usuarioActualEncontrado = _operadoresDisponibles.firstWhere(
          (op) => '${op['nombres']} ${op['apellidos']}' == nombreCompletoActual,
          orElse: () => _operadoresDisponibles.first,
        );
        operador = '${usuarioActualEncontrado['nombres']} ${usuarioActualEncontrado['apellidos']}';
      } else {
        operador = 'Sin operadores disponibles';
        _operadoresDisponibles = [];
      }
    });
    
    print('Operadores de Seminco cargados: ${_operadoresDisponibles.length}');
    print('Usuario actual seleccionado: $operador');
  } catch (e) {
    print('Error al cargar operadores de Seminco: $e');
    setState(() {
      _operadoresDisponibles = [];
      operador = 'Error al cargar operadores';
    });
  }
}

Future<void> _cargarEquipos() async {
  try {
    codigosPorEquipo.clear();

    final dbHelper = DatabaseHelper();
    equiposCompletos = await dbHelper.getEquipos();

    String tipoOperacion = 'EMPERNADOR';

    List<Equipo> equiposFiltrados = equiposCompletos
        .where((e) => e.proceso == tipoOperacion)
        .toList();

    Set<String> nombresEquipos = {};

    for (var equipo in equiposFiltrados) {
      nombresEquipos.add(equipo.nombre);

      codigosPorEquipo.putIfAbsent(equipo.nombre, () => []);
      if (!codigosPorEquipo[equipo.nombre]!.contains(equipo.codigo)) {
        codigosPorEquipo[equipo.nombre]!.add(equipo.codigo);
      }
    }

    setState(() {
      equipos = nombresEquipos.toList()..sort();
      codigosFiltrados = _obtenerTodosLosCodigos();
      
      _autoSelectSingleEquipo();
    });

    print('Equipos cargados: ${equipos.length}');
    print('Total códigos: ${codigosFiltrados.length}');

  } catch (e) {
    print("Error cargando equipos: $e");
  }
}

List<String> _obtenerTodosLosCodigos() {
  List<String> todosCodigos = [];
  for (var codigos in codigosPorEquipo.values) {
    todosCodigos.addAll(codigos);
  }
  return todosCodigos;
}

void _autoSelectSingleEquipo() {
  if (equipos.length == 1 && selectedEquipo == null && !operacionBloqueada) {
    setState(() {
      selectedEquipo = equipos.first;
      codigosFiltrados = codigosPorEquipo[selectedEquipo] ?? [];
      
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

Future<void> _cargarTiposEquipo() async {
  try {
    final dbHelper = DatabaseHelper();
    final List<TipoEquipo> tipos = await dbHelper.getTiposEquipo();
    
    setState(() {
      tiposEquipo = tipos;
      
      tiposSeleccionados.clear();
      for (var tipo in tiposEquipo) {
        if (tipo.id != null) {
          tiposSeleccionados[tipo.id!] = true;
        }
      }
      
      if (widget.operacionExistente != null) {
        final String? tiposJsonString = widget.operacionExistente!['tipo_equipo'];
        
        if (tiposJsonString != null && tiposJsonString.isNotEmpty) {
          try {
            Map<String, dynamic> tiposGuardados = jsonDecode(tiposJsonString);
            
            for (var tipo in tiposEquipo) {
              if (tipo.id != null && tiposGuardados.containsKey(tipo.nombre)) {
                tiposSeleccionados[tipo.id!] = tiposGuardados[tipo.nombre] as bool;
              }
            }
          } catch (e) {
            print('Error al decodificar tipos de equipo: $e');
          }
        }
      }
    });
    
    print('Tipos de equipo cargados: ${tiposEquipo.length}');
  } catch (e) {
    print('Error al cargar tipos de equipo: $e');
  }
}

  @override
void didUpdateWidget(covariant OperacionCard oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (widget.operacionExistente != oldWidget.operacionExistente) {
    if (widget.operacionExistente != null) {
      setState(() {
        selectedEquipo = widget.operacionExistente!['equipo'];
        selectedCodigo = widget.operacionExistente!['n_equipo'];
        selectedJefeGuardia = widget.operacionExistente!['jefe_guardia'];
        selectedSeccion = widget.operacionExistente!['seccion'];
        
        final String? tiposJsonString = widget.operacionExistente!['tipo_equipo'];
        
        if (tiposJsonString != null && tiposJsonString.isNotEmpty) {
          try {
            Map<String, dynamic> tiposGuardados = jsonDecode(tiposJsonString);
            
            for (var tipo in tiposEquipo) {
              if (tipo.id != null && tiposGuardados.containsKey(tipo.nombre)) {
                tiposSeleccionados[tipo.id!] = tiposGuardados[tipo.nombre] as bool;
              }
            }
          } catch (e) {
            print('Error al decodificar tipos de equipo: $e');
          }
        }

        codigosFiltrados = codigosPorEquipo[selectedEquipo] ?? [];
      });
    } else {
      setState(() {
        selectedEquipo = null;
        selectedCodigo = null;
        selectedJefeGuardia = null;
        selectedSeccion = null;
        
        for (var tipo in tiposEquipo) {
          if (tipo.id != null) {
            tiposSeleccionados[tipo.id!] = true;
          }
        }
        
        codigosFiltrados = _obtenerTodosLosCodigos();
        _autoSelectSingleEquipo();
      });
    }
  }
}

  Future<void> refrescarDatos() async {
    await Future.wait([
      _cargarEquipos(),
      _cargarJefesGuardia(),
      _cargarOperadorPorDni(),
      _cargarTiposEquipo(),
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
            if (equipos.isEmpty || jefesGuardia.isEmpty || tiposEquipo.isEmpty)
              const LinearProgressIndicator(),
            _buildFormFields(),
            const SizedBox(height: 20),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  // 🔥 NUEVO: Layout responsive con 3 tamaños
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

  // 📱 LAYOUT MÓVIL
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
        
        // Fila 2: Código de equipo
        CustomMaterialDropdown(
          label: 'Código de equipo',
          value: selectedCodigo,
          items: codigosFiltrados,
          onChanged: operacionBloqueada || selectedEquipo == null
              ? null
              : (value) {
                  setState(() {
                    selectedCodigo = value;
                  });
                },
          icon: Icons.qr_code,
          hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código de equipo',
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

  // 📟 LAYOUT TABLET
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
        
        // Fila 2: Código de equipo
        CustomMaterialDropdown(
          label: 'Código de equipo',
          value: selectedCodigo,
          items: codigosFiltrados,
          onChanged: operacionBloqueada || selectedEquipo == null
              ? null
              : (value) {
                  setState(() {
                    selectedCodigo = value;
                  });
                },
          icon: Icons.qr_code,
          hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código de equipo',
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

  // 💻 LAYOUT DESKTOP
  Widget _buildDesktopLayout(double cardWidth) {
    Map<String, double> fieldWeights = {
      'fecha': 1.5,
      'turno': 1.5,
      'codigo': 2.5,      // Código ocupa más espacio
      'operador': 2.0,
      'jefe': 2.0,
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
            label: 'Código de equipo',
            value: selectedCodigo,
            items: codigosFiltrados,
            onChanged: operacionBloqueada || selectedEquipo == null
                ? null
                : (value) {
                    setState(() {
                      selectedCodigo = value;
                    });
                  },
            icon: Icons.qr_code,
            hint: codigosFiltrados.isEmpty ? 'Cargando...' : 'Código de equipo',
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
    double totalWeights = 1.5 + 1.5 + 2.5 + 2.0 + 2.0 + 1.5;
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
  bool isSeminco = _operadoresDisponibles.isNotEmpty;
  bool isEnabled = !operacionBloqueada;

  if (isSeminco) {
    return InkWell(
      onTap: isEnabled ? () => _mostrarSelectorOperador(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled
                ? widget.primaryColor.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
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
                    'Operador',
                    style: TextStyle(
                      fontSize: 11,
                      color: isEnabled ? widget.primaryColor : Colors.grey,
                    ),
                  ),
                  Text(
                    operador ?? 'Seleccionar operador',
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
              Icons.arrow_drop_down,
              size: 20,
              color: isEnabled ? widget.primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

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
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                operador ?? operadorEjemplo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Icon(Icons.person_outline, size: 16, color: Colors.grey.shade400),
      ],
    ),
  );
}

void _mostrarSelectorOperador(BuildContext context) {
  String searchText = '';
  final TextEditingController searchCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final List<Map<String, dynamic>> filtrados = searchText.isEmpty
              ? _operadoresDisponibles
              : _operadoresDisponibles.where((op) {
                  final nombreCompleto =
                      '${op['nombres']} ${op['apellidos']}'.toLowerCase();
                  return nombreCompleto.contains(searchText.toLowerCase());
                }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seleccionar operador',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: searchCtrl,
                              autofocus: true,
                              onChanged: (v) =>
                                  setModalState(() => searchText = v),
                              decoration: InputDecoration(
                                hintText: 'Buscar operador...',
                                prefixIcon:
                                    Icon(Icons.search, color: widget.primaryColor),
                                suffixIcon: searchText.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          setModalState(() => searchText = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filtrados.isEmpty
                            ? const Center(
                                child: Text(
                                  'No se encontraron operadores',
                                  style: TextStyle(
                                      color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtrados.length,
                                itemBuilder: (ctx, i) {
                                  final op = filtrados[i];
                                  final nombreCompleto =
                                      '${op['nombres']} ${op['apellidos']}';
                                  final isSelected = nombreCompleto == operador;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isSelected
                                          ? widget.primaryColor
                                          : Colors.grey.shade300,
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 16),
                                    ),
                                    title: Text(
                                      nombreCompleto,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? widget.primaryColor
                                            : Colors.black87,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(Icons.check_circle,
                                            color: widget.primaryColor)
                                        : null,
                                    onTap: () {
                                      setState(() => operador = nombreCompleto);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
        operacionBloqueada ? null : _crearOperacion,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding:
          const EdgeInsets.symmetric(vertical: 12),
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
      String nuevaFecha =
      DateFormat('yyyy-MM-dd').format(picked);

      if (nuevaFecha != widget.fechaActual) {
        widget.onFechaChanged(nuevaFecha);
        _showSnackbar(
            'Fecha actualizada: $nuevaFecha',
            Colors.green);
      }
    }
  }

  void _crearOperacion() {
    if (widget.selectedTurno == null ||
        selectedEquipo == null ||
        selectedCodigo == null ||
        selectedJefeGuardia == null ||
        selectedSeccion == null) {
      _showSnackbar(
          'Complete todos los campos',
          Colors.orange);
      return;
    }
  
  if (_operadoresDisponibles.isNotEmpty && operador == null) {
    _showSnackbar('Seleccione un operador', Colors.orange);
    return;
  }

    bool algunTipoSeleccionado = tiposSeleccionados.values.contains(true);
    if (!algunTipoSeleccionado) {
      _showSnackbar(
          'Seleccione al menos un tipo de equipo',
          Colors.orange);
      return;
    }

    Map<String, bool> tiposMap = {};
    for (var tipo in tiposEquipo) {
      if (tipo.id != null) {
        tiposMap[tipo.nombre] = tiposSeleccionados[tipo.id!] ?? false;
      }
    }

    String tiposJsonString = jsonEncode(tiposMap);

    widget.onOperacionCreada({
      'turno': widget.selectedTurno,
      'equipo': selectedEquipo,
      'n_equipo': selectedCodigo,
      'tipo_equipo': tiposJsonString,
      'operador': operador ?? operadorEjemplo,
      'jefe_guardia': selectedJefeGuardia,
      'seccion': selectedSeccion,
      'fecha': widget.fechaActual,
    });

    setState(() {
      selectedEquipo = null;
      selectedCodigo = null;
      selectedJefeGuardia = null;
      selectedSeccion = null;
      _operadoresDisponibles = []; 
      for (var tipo in tiposEquipo) {
      if (tipo.id != null) {
        tiposSeleccionados[tipo.id!] = true;
      }
    }
      
      codigosFiltrados = _obtenerTodosLosCodigos();
      _autoSelectSingleEquipo();
    });

    _showSnackbar(
        'Operación creada exitosamente',
        Colors.green);
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