import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class DialogoHorometro extends StatefulWidget {
  final int operacionId;
  final String estado;
  final Map<String, dynamic> horometrosData;
  final Color primaryColor;
  final String nEquipo;

  const DialogoHorometro({
    Key? key,
    required this.operacionId,
    required this.estado,
    required this.horometrosData,
    required this.nEquipo,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<DialogoHorometro> createState() => _DialogoHorometroState();
}

class _DialogoHorometroState extends State<DialogoHorometro> {
  late List<Map<String, dynamic>> horometros;
  bool isLoading = true;
  bool isEditable = false;
  Map<int, String> erroresValidacion = {};
  bool _isSaving = false;
  
  // Controladores para manejar los textos
  late List<TextEditingController> inicialControllers;
  late List<TextEditingController> finalControllers;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarHorometros();
  }

  Future<void> _cargarHorometros() async {
    setState(() {
      // 🔥 CONDICIONAL: Si es J 6 mostrar 5 horómetros, sino mostrar solo 3
      if (widget.nEquipo.trim() == "J 6") {
        // Mostrar 5 horómetros para J 6
        horometros = [
          {
            'id': 1,
            'nombre': 'Diesel',
            'inicial': widget.horometrosData['diesel']?['inicio'] ?? 0,
            'final': widget.horometrosData['diesel']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['diesel']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['diesel']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 2,
            'nombre': 'Eléctrico',
            'inicial': widget.horometrosData['electrico']?['inicio'] ?? 0,
            'final': widget.horometrosData['electrico']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['electrico']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['electrico']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 3,
            'nombre': 'Percusión',
            'inicial': widget.horometrosData['percusion']?['inicio'] ?? 0,
            'final': widget.horometrosData['percusion']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['percusion']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['percusion']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 4,
            'nombre': 'Eléctrico 2',
            'inicial': widget.horometrosData['electrico2']?['inicio'] ?? 0,
            'final': widget.horometrosData['electrico2']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['electrico2']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['electrico2']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 5,
            'nombre': 'Percusión 2',
            'inicial': widget.horometrosData['percusion2']?['inicio'] ?? 0,
            'final': widget.horometrosData['percusion2']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['percusion2']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['percusion2']?['inop'] == true ? 1 : 0,
          },
        ];
      } else {
        // Mostrar solo 3 horómetros para cualquier otro equipo
        horometros = [
          {
            'id': 1,
            'nombre': 'Diesel',
            'inicial': widget.horometrosData['diesel']?['inicio'] ?? 0,
            'final': widget.horometrosData['diesel']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['diesel']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['diesel']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 2,
            'nombre': 'Eléctrico',
            'inicial': widget.horometrosData['electrico']?['inicio'] ?? 0,
            'final': widget.horometrosData['electrico']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['electrico']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['electrico']?['inop'] == true ? 1 : 0,
          },
          {
            'id': 3,
            'nombre': 'Percusión',
            'inicial': widget.horometrosData['percusion']?['inicio'] ?? 0,
            'final': widget.horometrosData['percusion']?['final'] ?? 0,
            'EstaOP': widget.horometrosData['percusion']?['op'] == true ? 1 : 0,
            'EstaINOP': widget.horometrosData['percusion']?['inop'] == true ? 1 : 0,
          },
        ];
      }
      
      _inicializarControladores();
      isLoading = false;
      _validarTodos();
    });
  }

  void _inicializarControladores() {
    inicialControllers = List.generate(horometros.length, (index) {
      return TextEditingController(
        text: horometros[index]["inicial"]?.toString() ?? ''
      );
    });
    
    finalControllers = List.generate(horometros.length, (index) {
      return TextEditingController(
        text: horometros[index]["final"]?.toString() ?? ''
      );
    });
  }

  @override
  void dispose() {
    for (var controller in inicialControllers) {
      controller.dispose();
    }
    for (var controller in finalControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  String? _validarHorometro(Map<String, dynamic> horometro, int index) {
    final inicial = horometro["inicial"] ?? 0;
    final finalHoro = horometro["final"] ?? 0;
    final estaOP = horometro["EstaOP"] == 1;
    final estaINOP = horometro["EstaINOP"] == 1;

    if (estaINOP) {
      if ((inicial != 0)) {
        return "INOP: El valor inicial debe estar vacío o 0";
      }
      if ((finalHoro != 0)) {
        return "INOP: El valor final debe estar vacío o 0";
      }
    }

    if (estaOP) {
      if (inicial == null) {
        return "OP: Debe tener valor inicial";
      }
    }

    if (estaOP && estaINOP) {
      return "No puede seleccionar OP e INOP";
    }

    if (!estaOP && !estaINOP) {
      return "Seleccione OP o INOP";
    }

    return null;
  }

  void _validarTodos() {
    erroresValidacion.clear();
    for (int i = 0; i < horometros.length; i++) {
      String? error = _validarHorometro(horometros[i], i);
      if (error != null) {
        erroresValidacion[i] = error;
      }
    }
    setState(() {});
  }

  bool _hayErrores() {
    return erroresValidacion.isNotEmpty;
  }

  // 🔥 NUEVO: Cerrar sin guardar
  void _cerrarSinGuardar() {
    Navigator.pop(context);
  }

  // 🔥 NUEVO: Guardar al cerrar (click fuera)
  Future<void> _guardarAlCerrar() async {
    if (_isSaving) return;
    
    _validarTodos();
    
    if (_hayErrores()) {
      String mensajeError = "No se puede cerrar porque hay errores:\n";
      erroresValidacion.forEach((index, error) {
        mensajeError += "• $error\n";
      });
      _mostrarSnackbar(mensajeError, Colors.red);
      return;
    }
    
    setState(() {
      _isSaving = true;
    });

    Map<String, dynamic> horometrosToSave = {};

    if (widget.nEquipo.trim() == "J 6") {
      horometrosToSave = {
        'diesel': {
          'inicio': horometros[0]['inicial'] ?? 0,
          'final': horometros[0]['final'] ?? 0,
          'op': horometros[0]['EstaOP'] == 1,
          'inop': horometros[0]['EstaINOP'] == 1,
        },
        'electrico': {
          'inicio': horometros[1]['inicial'] ?? 0,
          'final': horometros[1]['final'] ?? 0,
          'op': horometros[1]['EstaOP'] == 1,
          'inop': horometros[1]['EstaINOP'] == 1,
        },
        'percusion': {
          'inicio': horometros[2]['inicial'] ?? 0,
          'final': horometros[2]['final'] ?? 0,
          'op': horometros[2]['EstaOP'] == 1,
          'inop': horometros[2]['EstaINOP'] == 1,
        },
        'electrico2': {
          'inicio': horometros[3]['inicial'] ?? 0,
          'final': horometros[3]['final'] ?? 0,
          'op': horometros[3]['EstaOP'] == 1,
          'inop': horometros[3]['EstaINOP'] == 1,
        },
        'percusion2': {
          'inicio': horometros[4]['inicial'] ?? 0,
          'final': horometros[4]['final'] ?? 0,
          'op': horometros[4]['EstaOP'] == 1,
          'inop': horometros[4]['EstaINOP'] == 1,
        },
      };
    } else {
      horometrosToSave = {
        'diesel': {
          'inicio': horometros[0]['inicial'] ?? 0,
          'final': horometros[0]['final'] ?? 0,
          'op': horometros[0]['EstaOP'] == 1,
          'inop': horometros[0]['EstaINOP'] == 1,
        },
        'electrico': {
          'inicio': horometros[1]['inicial'] ?? 0,
          'final': horometros[1]['final'] ?? 0,
          'op': horometros[1]['EstaOP'] == 1,
          'inop': horometros[1]['EstaINOP'] == 1,
        },
        'percusion': {
          'inicio': horometros[2]['inicial'] ?? 0,
          'final': horometros[2]['final'] ?? 0,
          'op': horometros[2]['EstaOP'] == 1,
          'inop': horometros[2]['EstaINOP'] == 1,
        },
      };
    }

    bool guardado = await DatabaseHelper().updateHorometrosHorizontal(
      widget.operacionId,
      horometrosToSave,
    );

    setState(() {
      _isSaving = false;
    });

    if (guardado) {
      _mostrarSnackbar('Horómetros guardados correctamente', Colors.green);
      Navigator.pop(context, true);
    } else {
      _mostrarSnackbar('Error al guardar los horómetros', Colors.red);
    }
  }

  // 🔥 MODIFICADO: Guardar con indicador de carga
  Future<void> _guardarHorometros() async {
    if (_isSaving) return;
    
    _validarTodos();
    
    if (_hayErrores()) {
      String mensajeError = "Corrija los errores antes de guardar:\n";
      erroresValidacion.forEach((index, error) {
        mensajeError += "• $error\n";
      });
      _mostrarSnackbar(mensajeError, Colors.red);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    Map<String, dynamic> horometrosToSave = {};

    if (widget.nEquipo.trim() == "J 6") {
      horometrosToSave = {
        'diesel': {
          'inicio': horometros[0]['inicial'] ?? 0,
          'final': horometros[0]['final'] ?? 0,
          'op': horometros[0]['EstaOP'] == 1,
          'inop': horometros[0]['EstaINOP'] == 1,
        },
        'electrico': {
          'inicio': horometros[1]['inicial'] ?? 0,
          'final': horometros[1]['final'] ?? 0,
          'op': horometros[1]['EstaOP'] == 1,
          'inop': horometros[1]['EstaINOP'] == 1,
        },
        'percusion': {
          'inicio': horometros[2]['inicial'] ?? 0,
          'final': horometros[2]['final'] ?? 0,
          'op': horometros[2]['EstaOP'] == 1,
          'inop': horometros[2]['EstaINOP'] == 1,
        },
        'electrico2': {
          'inicio': horometros[3]['inicial'] ?? 0,
          'final': horometros[3]['final'] ?? 0,
          'op': horometros[3]['EstaOP'] == 1,
          'inop': horometros[3]['EstaINOP'] == 1,
        },
        'percusion2': {
          'inicio': horometros[4]['inicial'] ?? 0,
          'final': horometros[4]['final'] ?? 0,
          'op': horometros[4]['EstaOP'] == 1,
          'inop': horometros[4]['EstaINOP'] == 1,
        },
      };
    } else {
      horometrosToSave = {
        'diesel': {
          'inicio': horometros[0]['inicial'] ?? 0,
          'final': horometros[0]['final'] ?? 0,
          'op': horometros[0]['EstaOP'] == 1,
          'inop': horometros[0]['EstaINOP'] == 1,
        },
        'electrico': {
          'inicio': horometros[1]['inicial'] ?? 0,
          'final': horometros[1]['final'] ?? 0,
          'op': horometros[1]['EstaOP'] == 1,
          'inop': horometros[1]['EstaINOP'] == 1,
        },
        'percusion': {
          'inicio': horometros[2]['inicial'] ?? 0,
          'final': horometros[2]['final'] ?? 0,
          'op': horometros[2]['EstaOP'] == 1,
          'inop': horometros[2]['EstaINOP'] == 1,
        },
      };
    }

    bool guardado = await DatabaseHelper().updateHorometrosHorizontal(
      widget.operacionId,
      horometrosToSave,
    );

    setState(() {
      _isSaving = false;
    });

    if (guardado) {
      _mostrarSnackbar('Horómetros guardados correctamente', Colors.green);
      Navigator.pop(context, true);
    } else {
      _mostrarSnackbar('Error al guardar los horómetros', Colors.red);
    }
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOPChange(int index, bool value) {
    setState(() {
      horometros[index]["EstaOP"] = value ? 1 : 0;
      if (value) {
        horometros[index]["EstaINOP"] = 0;
      }
    });
    _validarTodos();
  }

  void _handleINOPChange(int index, bool value) {
    setState(() {
      horometros[index]["EstaINOP"] = value ? 1 : 0;
      if (value) {
        horometros[index]["EstaOP"] = 0;
        horometros[index]["inicial"] = null;
        horometros[index]["final"] = null;
        inicialControllers[index].text = '';
        finalControllers[index].text = '';
      }
    });
    _validarTodos();
  }

  void _handleInicialChange(int index, String value) {
    horometros[index]["inicial"] = _parseDouble(value);
    _validarTodos();
  }

  void _handleFinalChange(int index, String value) {
    horometros[index]["final"] = _parseDouble(value);
    _validarTodos();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 ENVOLVER con PopScope para interceptar el cierre
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        if (isEditable && !_isSaving) {
          await _guardarAlCerrar();
        } else if (!isEditable) {
          Navigator.pop(context);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.speed,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Horómetros',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_hayErrores())
                            Text(
                              '⚠️ ${erroresValidacion.length} error(es)',
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 11,
                              ),
                            ),
                        ],
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
                        isEditable ? 'EDITABLE' : 'SOLO LECTURA',
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

              // Body
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildTable(),
                    ),
                  ),
                ),

              // Footer
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
                      onPressed: _cerrarSinGuardar, // 🔥 Cancelar: solo cierra
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isEditable)
                      ElevatedButton(
                        onPressed: _isSaving ? null : _guardarHorometros, // 🔥 Guardar: guarda y cierra
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hayErrores() ? Colors.grey : widget.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSaving)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              Icon(
                                _hayErrores() ? Icons.error_outline : Icons.save,
                                size: 14,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              _isSaving ? 'Guardando...' : (_hayErrores() ? 'Corregir errores' : 'Guardar'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade200),
          verticalInside: BorderSide(color: Colors.grey.shade200),
        ),
        columnWidths: const {
          0: FixedColumnWidth(150),
          1: FixedColumnWidth(90),
          2: FixedColumnWidth(90),
          3: FixedColumnWidth(50),
          4: FixedColumnWidth(50),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
            ),
            children: [
              _buildHeaderCell('Nombre'),
              _buildHeaderCell('Inicial'),
              _buildHeaderCell('Final'),
              _buildHeaderCell('OP'),
              _buildHeaderCell('INOP'),
            ],
          ),
          for (int i = 0; i < horometros.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: erroresValidacion.containsKey(i) 
                    ? Colors.red.withOpacity(0.05) 
                    : null,
              ),
              children: [
                _buildCell(horometros[i]["nombre"], isBold: true),
                _buildEditableCell(
                  index: i,
                  controller: inicialControllers[i],
                  isEditable: isEditable && horometros[i]["EstaOP"] == 1,
                  onChanged: (value) => _handleInicialChange(i, value),
                  error: erroresValidacion.containsKey(i) 
                      ? erroresValidacion[i]
                      : null,
                ),
                _buildEditableCell(
                  index: i,
                  controller: finalControllers[i],
                  isEditable: isEditable && horometros[i]["EstaOP"] == 1,
                  onChanged: (value) => _handleFinalChange(i, value),
                  error: erroresValidacion.containsKey(i) 
                      ? erroresValidacion[i]
                      : null,
                ),
                _buildCheckboxCell(
                  value: horometros[i]["EstaOP"] == 1,
                  isEditable: isEditable,
                  onChanged: (value) => _handleOPChange(i, value),
                ),
                _buildCheckboxCell(
                  value: horometros[i]["EstaINOP"] == 1,
                  isEditable: isEditable,
                  onChanged: (value) => _handleINOPChange(i, value),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
          color: Colors.grey.shade900,
        ),
      ),
    );
  }

  Widget _buildEditableCell({
    required int index,
    required TextEditingController controller,
    required bool isEditable,
    required Function(String) onChanged,
    String? error,
  }) {
    bool isFinalEqual = false;
    if (!isEditable && horometros[index]["EstaOP"] == 1) {
      final inicial = horometros[index]["inicial"];
      final finalHoro = horometros[index]["final"];
      if (inicial != null && finalHoro != null && finalHoro == inicial) {
        isFinalEqual = true;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            enabled: isEditable,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 12,
              color: isFinalEqual ? Colors.orange.shade700 : null,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: error != null 
                      ? Colors.red 
                      : (isFinalEqual ? Colors.orange.shade300 : Colors.grey.shade300),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: error != null 
                      ? Colors.red 
                      : (isFinalEqual ? Colors.orange.shade300 : Colors.grey.shade300),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: error != null 
                      ? Colors.red 
                      : (isFinalEqual ? Colors.orange : widget.primaryColor),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              filled: !isEditable,
              fillColor: error != null 
                  ? Colors.red.withOpacity(0.05) 
                  : (isFinalEqual 
                      ? Colors.orange.withOpacity(0.05)
                      : (isEditable ? Colors.white : Colors.grey.shade50)),
              hintText: !isEditable ? 'INOP - Bloqueado' : null,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (isFinalEqual)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                '⚠️ Final igual a inicial',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckboxCell({
    required bool value,
    required bool isEditable,
    required Function(bool) onChanged,
  }) {
    return Center(
      child: Transform.scale(
        scale: 0.8,
        child: Checkbox(
          value: value,
          onChanged: isEditable 
              ? (bool? newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                }
              : null,
          activeColor: widget.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}