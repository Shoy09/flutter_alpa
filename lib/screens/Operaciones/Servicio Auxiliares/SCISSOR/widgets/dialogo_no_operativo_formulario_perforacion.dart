import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class DialogoFormularioNoOpeScissor extends StatefulWidget {
  final int operacionId;
  final int estadoId;
  final Map<String, dynamic>? datosIniciales;
  final String estado;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onGuardar;

  const DialogoFormularioNoOpeScissor({
    Key? key,
    required this.operacionId,
    required this.estadoId,
    this.datosIniciales,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
    required this.onGuardar,
  }) : super(key: key);

  @override
  State<DialogoFormularioNoOpeScissor> createState() =>
      _DialogoFormularioNoOpeScissorState();
}

class _DialogoFormularioNoOpeScissorState
    extends State<DialogoFormularioNoOpeScissor> {
  final TextEditingController laborController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();
  final FocusNode laborFocusNode = FocusNode();

  bool isEditable = false;
  bool isLoading = true;
  bool mostrarSugerenciasLabor = false;
  List<String> opcionesLabor = [];
  List<String> opcionesLaborFiltradas = [];

  List<PlanMensual> planesMensualCompletos = [];
  List<PlanProduccion> planesProduccionCompletos = [];
  List<PlanMetraje> planesMetrajeCompletos = [];

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != 'cerrado';
    _cargarDatosIniciales();
    _cargarOpcionesLabor();
  }

  void _cargarDatosIniciales() {
    final datos = widget.datosIniciales;
    if (datos == null) return;

    laborController.text = (datos['labor'] ?? datos['origen_labor'] ?? '')
        .toString();
    observacionesController.text = (datos['observaciones'] ?? '').toString();
  }

  Future<void> _cargarOpcionesLabor() async {
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

      final opciones = <String>{};
      void agregarLabor(dynamic plan) {
        final partes = [
          plan.tipoLabor,
          plan.labor,
          plan.ala,
        ].whereType<String>().where((parte) => parte.trim().isNotEmpty);
        final labor = partes.join('_');
        if (labor.isNotEmpty) opciones.add(labor);
      }

      for (final plan in planesMensualCompletos) {
        agregarLabor(plan);
      }
      for (final plan in planesProduccionCompletos) {
        agregarLabor(plan);
      }
      for (final plan in planesMetrajeCompletos) {
        agregarLabor(plan);
      }

      opcionesLabor = opciones.toList()..sort();
      opcionesLaborFiltradas = List.of(opcionesLabor);
    } catch (error) {
      debugPrint('Error cargando labores Scissor: $error');
      opcionesLabor = const [
        'Galería_LaborA_AlaNorte',
        'Galería_LaborA_AlaSur',
        'Crucero_LaborB_AlaEste',
      ];
      opcionesLaborFiltradas = List.of(opcionesLabor);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onLaborChanged(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        opcionesLaborFiltradas = List.of(opcionesLabor);
        mostrarSugerenciasLabor = false;
        return;
      }

      opcionesLaborFiltradas = opcionesLabor
          .where((labor) => labor.toLowerCase().contains(value.toLowerCase()))
          .toList();
      mostrarSugerenciasLabor = opcionesLaborFiltradas.isNotEmpty;
    });
  }

  void _guardarDatos() {
    widget.onGuardar({
      'labor': laborController.text.trim(),
      'observaciones': observacionesController.text.trim(),
    });
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
    laborController.dispose();
    observacionesController.dispose();
    laborFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.95 : 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                      child: Column(
                        children: [
                          _buildSeccionLabor(),
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

  Widget _buildSeccionLabor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.location_on, 'Ubicación'),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.work_outline, size: 16, color: widget.primaryColor),
            const SizedBox(width: 6),
            Text(
              'Labor',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: laborController,
          focusNode: laborFocusNode,
          enabled: isEditable,
          decoration: InputDecoration(
            hintText: 'Buscar o escribir labor...',
            prefixIcon: Icon(Icons.search, color: widget.primaryColor),
            suffixIcon: laborController.text.isNotEmpty && isEditable
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      laborController.clear();
                      setState(() {
                        opcionesLaborFiltradas = List.of(opcionesLabor);
                        mostrarSugerenciasLabor = false;
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _onLaborChanged,
          onTap: () {
            setState(() {
              opcionesLaborFiltradas = List.of(opcionesLabor);
              mostrarSugerenciasLabor = true;
            });
          },
        ),
        if (mostrarSugerenciasLabor &&
            opcionesLaborFiltradas.isNotEmpty &&
            isEditable)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opcionesLaborFiltradas.length,
              itemBuilder: (context, index) {
                final labor = opcionesLaborFiltradas[index];
                return ListTile(
                  dense: true,
                  title: Text(labor),
                  onTap: () {
                    laborController.text = labor;
                    setState(() => mostrarSugerenciasLabor = false);
                    laborFocusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSeccionObservaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.note_alt, 'Observaciones'),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: TextField(
            controller: observacionesController,
            enabled: isEditable,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Ingrese observaciones...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: widget.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.content_cut, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Formulario Scissor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            isEditable ? 'EDITABLE' : 'LECTURA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          if (isEditable)
            ElevatedButton.icon(
              onPressed: _guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Guardar'),
            ),
        ],
      ),
    );
  }
}
