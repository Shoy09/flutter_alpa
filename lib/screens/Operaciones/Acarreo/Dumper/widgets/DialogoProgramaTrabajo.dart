import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class DialogoProgramaTrabajo extends StatefulWidget {
  final int operacionId;
  final String estado;
  final Map<String, dynamic> programaTrabajoData;
  final Color primaryColor;

  const DialogoProgramaTrabajo({
    Key? key,
    required this.operacionId,
    required this.estado,
    required this.programaTrabajoData,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<DialogoProgramaTrabajo> createState() => _DialogoProgramaTrabajoState();
}

class _DialogoProgramaTrabajoState extends State<DialogoProgramaTrabajo> {
  late TextEditingController nViajeMineralController;
  late TextEditingController nViajeDesmonteController;
  late TextEditingController programadoController;
  late TextEditingController realizadoController;
  late TextEditingController totalController;

  bool isEditable = false;
  bool isSmallScreen = false;

  @override
  void initState() {
    super.initState();

    isEditable = widget.estado.toLowerCase() != "cerrado";

    nViajeMineralController = TextEditingController(
      text: _formatNumber(widget.programaTrabajoData['n_viaje_mineral'] ?? 0).toString(),
    );

    nViajeDesmonteController = TextEditingController(
      text: _formatNumber(widget.programaTrabajoData['n_viaje_desmonte'] ?? 0).toString(),
    );

    programadoController = TextEditingController(
      text: _formatNumber(widget.programaTrabajoData['programado'] ?? 0).toString(),
    );

    realizadoController = TextEditingController(
      text: _formatNumber(widget.programaTrabajoData['realizado'] ?? 0).toString(),
    );

    totalController = TextEditingController(
      text: _formatNumber(widget.programaTrabajoData['total'] ?? 0).toString(),
    );
  }

  String _formatNumber(dynamic value) {
  double number = (value ?? 0).toDouble();

  if (number % 1 == 0) {
    return number.toInt().toString(); // sin .0
  } else {
    return number.toString(); // con decimales
  }
}

  @override
  void dispose() {
    nViajeMineralController.dispose();
    nViajeDesmonteController.dispose();
    programadoController.dispose();
    realizadoController.dispose();
    totalController.dispose();
    super.dispose();
  }

  double _parseDouble(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  Future<void> _guardarProgramaTrabajo() async {
    Map<String, dynamic> data = {
      'n_viaje_mineral': _parseDouble(nViajeMineralController.text),
      'n_viaje_desmonte': _parseDouble(nViajeDesmonteController.text),
      'programado': _parseDouble(programadoController.text),
      'realizado': _parseDouble(realizadoController.text),
      'total': _parseDouble(totalController.text),
    };

    bool guardado = await DatabaseHelper()
        .updateProgramaTrabajoDumper(widget.operacionId, data);

    if (guardado) {
      _mostrarSnackbar('Programa de trabajo guardado', Colors.green);
      Navigator.pop(context, true);
    } else {
      _mostrarSnackbar('Error al guardar', Colors.red);
    }
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;
    
    final dialogWidth = isSmallScreen ? screenWidth * 0.95 : 500.0;
    final dialogHeight = isSmallScreen ? null : 600.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: dialogHeight ?? 600,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.work,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Programa de trabajo",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isEditable ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isEditable ? "EDITABLE" : "SOLO LECTURA",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    /// SECCIÓN: VIAJES
                    Container(
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
                              Icon(Icons.directions_bus, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Viajes',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: nViajeMineralController,
                            label: 'N° Viajes Mineral',
                            icon: Icons.agriculture,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: nViajeDesmonteController,
                            label: 'N° Viajes Desmonte',
                            icon: Icons.landscape,
                            enabled: isEditable,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// SECCIÓN: PRODUCCIÓN
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.production_quantity_limits, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Producción',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: programadoController,
                            label: 'Programado',
                            icon: Icons.calendar_today,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: realizadoController,
                            label: 'Realizado',
                            icon: Icons.check_circle,
                            enabled: isEditable,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// SECCIÓN: TOTAL
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.summarize, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: totalController,
                            label: 'Total General',
                            icon: Icons.calculate,
                            enabled: isEditable,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// FOOTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  if (isEditable)
                    ElevatedButton(
                      onPressed: _guardarProgramaTrabajo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Guardar"),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    bool isTotal = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      style: TextStyle(
        fontSize: 14,
        fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isTotal ? Colors.orange.shade700 : Colors.grey.shade700,
          fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
        ),
        prefixIcon: Icon(icon, size: 20, color: isTotal ? Colors.orange.shade700 : widget.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isTotal ? Colors.orange.shade200 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isTotal ? Colors.orange : widget.primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}