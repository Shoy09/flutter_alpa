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
  late TextEditingController programadoController;
  late TextEditingController realizadoController;

  bool isEditable = false;

  @override
  void initState() {
    super.initState();

    isEditable = widget.estado.toLowerCase() != "cerrado";

    programadoController = TextEditingController(
      text: (widget.programaTrabajoData['n_cucharas_programado'] ?? 0).toString(),
    );

    realizadoController = TextEditingController(
      text: (widget.programaTrabajoData['n_cucharas_realizado'] ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    programadoController.dispose();
    realizadoController.dispose();
    super.dispose();
  }

  int _parseInt(String value) {
    return int.tryParse(value) ?? 0;
  }

  Future<void> _guardarProgramaTrabajo() async {

    Map<String, dynamic> data = {
      'n_cucharas_programado': _parseInt(programadoController.text),
      'n_cucharas_realizado': _parseInt(realizadoController.text),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 420,
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  /// PROGRAMADO
                  TextField(
                    controller: programadoController,
                    enabled: isEditable,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "N° cucharas programado",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// REALIZADO
                  TextField(
                    controller: realizadoController,
                    enabled: isEditable,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "N° cucharas realizado",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
    foregroundColor: Colors.white, // 👈 texto blanco
  ),
  child: const Text("Guardar"),
)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}