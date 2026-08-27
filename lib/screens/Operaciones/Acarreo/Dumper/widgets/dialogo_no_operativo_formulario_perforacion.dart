import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioNoOpeDumper extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioNoOpeDumper({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);
  
  @override
  State<DialogoFormularioNoOpeDumper> createState() => _DialogoFormularioNoPerforacionState();
}

class _DialogoFormularioNoPerforacionState extends State<DialogoFormularioNoOpeDumper> {
  bool isEditable = false;
  bool isLoading = true;
  bool isSmallScreen = false;

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
        dbHelper.getOrigenDestino('DUMPER', 'ORIGEN'),
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
      });
    } catch (e) {
      print("Error cargando planes combinados: $e");
      setState(() {
        opcionesNivel = ['Nivel 1', 'Nivel 2', 'Nivel 3', 'Nivel 4'];
        opcionesTipoLabor = ['Galería', 'Crucero', 'Rampa', 'Chimenea', 'Subterráneo'];
        opcionesLabor = ['Labor A', 'Labor B', 'Labor C', 'Labor D'];
        opcionesAla = ['Ala Norte', 'Ala Sur', 'Ala Este', 'Ala Oeste'];
        filteredTiposLabor = List.from(opcionesTipoLabor);
        filteredLabores = List.from(opcionesLabor);
        filteredAlas = List.from(opcionesAla);
      });
    }
  }

  void _onNivelChanged(String? nuevoNivel) {
    setState(() {
      nivelSeleccionado = nuevoNivel;
      tipoLaborSeleccionado = null;
      laborSeleccionado = null;
      alaSeleccionado = null;
      _actualizarFiltros();
    });
  }

  void _onTipoLaborChanged(String? nuevoTipoLabor) {
    setState(() {
      tipoLaborSeleccionado = nuevoTipoLabor;
      laborSeleccionado = null;
      alaSeleccionado = null;
      _actualizarFiltros();
    });
  }

  void _onLaborChanged(String? nuevoLabor) {
    setState(() {
      laborSeleccionado = nuevoLabor;
      alaSeleccionado = null;
      _actualizarFiltros();
    });
  }

  void _actualizarFiltros() {
    // Filtrar tipos de labor basados en nivel seleccionado
    if (nivelSeleccionado != null) {
      Set<String> tiposLaborFiltrados = {};
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelSeleccionado && (plan.tipoLabor?.isNotEmpty ?? false)) {
          tiposLaborFiltrados.add(plan.tipoLabor!);
        }
      }
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
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelSeleccionado && 
            plan.tipoLabor == tipoLaborSeleccionado && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelSeleccionado && 
            plan.tipoLabor == tipoLaborSeleccionado && 
            (plan.labor?.isNotEmpty ?? false)) {
          laboresFiltrados.add(plan.labor!);
        }
      }
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
      for (var plan in planesMensualCompletos) {
        if (plan.nivel == nivelSeleccionado && 
            plan.tipoLabor == tipoLaborSeleccionado && 
            plan.labor == laborSeleccionado && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
      for (var plan in planesProduccionCompletos) {
        if (plan.nivel == nivelSeleccionado && 
            plan.tipoLabor == tipoLaborSeleccionado && 
            plan.labor == laborSeleccionado && 
            (plan.ala?.isNotEmpty ?? false)) {
          alasFiltrados.add(plan.ala!);
        }
      }
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
        nivelSeleccionado = widget.datosIniciales!['nivel_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['nivel_inicio'] : null;
        tipoLaborSeleccionado = widget.datosIniciales!['tipo_labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['tipo_labor_inicio'] : null;
        laborSeleccionado = widget.datosIniciales!['labor_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['labor_inicio'] : null;
        alaSeleccionado = widget.datosIniciales!['ala_inicio']?.isNotEmpty == true 
            ? widget.datosIniciales!['ala_inicio'] : null;
        observacionesController.text = widget.datosIniciales!['observaciones'] ?? '';
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actualizarFiltros();
      });
    }
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosFormulario = {
      'nivel_inicio': nivelSeleccionado ?? '',
      'tipo_labor_inicio': tipoLaborSeleccionado ?? '',
      'labor_inicio': laborSeleccionado ?? '',
      'ala_inicio': alaSeleccionado ?? '',
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
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;
    
    final dialogWidth = isSmallScreen 
        ? screenWidth * 0.95
        : 800.0;
    
    final dialogHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.85
        : MediaQuery.of(context).size.height * 0.7;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: dialogHeight,
          maxWidth: 800,
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
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSeccionUbicacion(),
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

  Widget _buildSeccionUbicacion() {
    if (isSmallScreen) {
      // Versión para móvil: dropdowns apilados verticalmente
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
                  Icons.location_on,
                  size: 14,
                  color: widget.primaryColor,
                ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: Colors.grey.shade300,
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCompactDropdownField(
            label: 'Nivel',
            value: nivelSeleccionado,
            items: opcionesNivel,
            onChanged: isEditable ? _onNivelChanged : null,
            icon: Icons.stairs,
          ),
          const SizedBox(height: 12),
          _buildCompactDropdownField(
            label: 'Tipo Labor',
            value: tipoLaborSeleccionado,
            items: filteredTiposLabor,
            onChanged: (nivelSeleccionado != null && isEditable) 
                ? _onTipoLaborChanged : null,
            icon: Icons.construction,
          ),
          const SizedBox(height: 12),
          _buildCompactDropdownField(
            label: 'Labor',
            value: laborSeleccionado,
            items: filteredLabores,
            onChanged: (tipoLaborSeleccionado != null && isEditable) 
                ? _onLaborChanged : null,
            icon: Icons.factory,
          ),
          const SizedBox(height: 12),
          _buildCompactDropdownField(
            label: 'Ala',
            value: alaSeleccionado,
            items: filteredAlas,
            onChanged: (laborSeleccionado != null && isEditable) 
                ? (value) => setState(() => alaSeleccionado = value) : null,
            icon: Icons.compare_arrows,
          ),
        ],
      );
    } else {
      // Versión para PC: dropdowns horizontales en fila
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
                  Icons.location_on,
                  size: 14,
                  color: widget.primaryColor,
                ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: Colors.grey.shade300,
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Nivel',
                  value: nivelSeleccionado,
                  items: opcionesNivel,
                  onChanged: isEditable ? _onNivelChanged : null,
                  icon: Icons.stairs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Tipo Labor',
                  value: tipoLaborSeleccionado,
                  items: filteredTiposLabor,
                  onChanged: (nivelSeleccionado != null && isEditable) 
                      ? _onTipoLaborChanged : null,
                  icon: Icons.construction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Labor',
                  value: laborSeleccionado,
                  items: filteredLabores,
                  onChanged: (tipoLaborSeleccionado != null && isEditable) 
                      ? _onLaborChanged : null,
                  icon: Icons.factory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdownField(
                  label: 'Ala',
                  value: alaSeleccionado,
                  items: filteredAlas,
                  onChanged: (laborSeleccionado != null && isEditable) 
                      ? (value) => setState(() => alaSeleccionado = value) : null,
                  icon: Icons.compare_arrows,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

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
        const SizedBox(height: 12),
        Container(
          height: isSmallScreen ? 120 : 100,
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
                fontSize: isSmallScreen ? 12 : 13,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.comment,
                  size: isSmallScreen ? 16 : 18,
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
            style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
          ),
        ),
      ],
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
            child: Icon(
              Icons.description,
              color: Colors.white,
              size: isSmallScreen ? 16 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSmallScreen ? 'Formulario No Operativo' : 'Formulario de Perforación no operativa',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 16,
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
              Icon(icon, size: isSmallScreen ? 12 : 14, color: widget.primaryColor),
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
          icon: Icon(Icons.arrow_drop_down, size: isSmallScreen ? 16 : 18, color: widget.primaryColor),
          style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.black87),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(6),
          items: items.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: Colors.grey.shade500),
                    ),
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