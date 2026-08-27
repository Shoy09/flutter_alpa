import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class DialogoChecklistTelemando extends StatefulWidget {
  final int operacionId;
  final String estado;
  final List<Map<String, dynamic>> checklistData;
  final Color primaryColor;

  const DialogoChecklistTelemando({
    super.key,
    required this.operacionId,
    required this.estado,
    required this.checklistData,
    this.primaryColor = const Color(0xFF1B5E6B),
  });

  @override
  State<DialogoChecklistTelemando> createState() =>
      _DialogoChecklistTelemandoState();
}

class _DialogoChecklistTelemandoState extends State<DialogoChecklistTelemando> {
  late List<ChecklistItemTelemando> items;
  bool isEditable = false;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _initChecklist();
  }

  void _initChecklist() {
    items = [];

    for (int i = 0; i < widget.checklistData.length; i++) {
      var item = widget.checklistData[i];

      items.add(
        ChecklistItemTelemando(
          id: i + 1,
          descripcion: item['descripcion'] ?? '',
          value: item['decision'] == 1
              ? true
              : item['decision'] == 0
                  ? false
                  : null,
          observacion: item['observacion'] ?? '',
        ),
      );
    }
  }

  Future<void> _guardarChecklist() async {
    List<Map<String, dynamic>> datos = [];

    for (var item in items) {
      datos.add({
        'descripcion': item.descripcion,
        'decision': item.value == true ? 1 : 0,
        'observacion': item.observacion,
      });
    }

    bool ok = await DatabaseHelper()
        .updateCheckListTelemandoDumper(widget.operacionId, datos);

    if (ok) {
      _mostrarSnackbar('Checklist telemando guardado correctamente', Colors.green);
      Navigator.pop(context, true);
    } else {
      _mostrarSnackbar('Error al guardar el checklist', Colors.red);
    }
  }

  void _marcarTodosSi() {
    setState(() {
      for (var item in items) {
        item.value = true;
      }
    });
  }

  void _marcarTodosNo() {
    setState(() {
      for (var item in items) {
        item.value = false;
      }
    });
  }

  void _limpiarTodo() {
    setState(() {
      for (var item in items) {
        item.value = null;
        item.observacion = '';
      }
    });
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
    for (var item in items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
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
                      Icons.settings_remote,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Checklist Telemando',
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

            // Mensaje si no hay items en el checklist
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_remote,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay items en el checklist',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esta operación no tiene items de telemando definidos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Botones de acción rápida
                    if (isEditable && items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildAccionRapida(
                              label: 'Todos Sí',
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                              onPressed: _marcarTodosSi,
                            ),
                            const SizedBox(width: 8),
                            _buildAccionRapida(
                              label: 'Todos No',
                              icon: Icons.cancel_outlined,
                              color: Colors.red,
                              onPressed: _marcarTodosNo,
                            ),
                            const SizedBox(width: 8),
                            _buildAccionRapida(
                              label: 'Limpiar',
                              icon: Icons.remove_circle_outline,
                              color: Colors.grey,
                              onPressed: _limpiarTodo,
                            ),
                          ],
                        ),
                      ),

                    // Lista de items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildChecklistItem(items[index]),
                          );
                        },
                      ),
                    ),
                  ],
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
                    onPressed: () => Navigator.pop(context),
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
                  if (isEditable && items.isNotEmpty)
                    ElevatedButton(
                      onPressed: _guardarChecklist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Guardar',
                            style: TextStyle(
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
    );
  }

  Widget _buildAccionRapida({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItemTelemando item) {
    // Sincronizar controlador con el texto
    if (item.observacionesController.text != item.observacion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (item.observacionesController.text != item.observacion) {
          item.observacionesController.text = item.observacion;
        }
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${item.id}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ),
            ),
            title: Text(
              item.descripcion,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: isEditable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOpcionRadio(item, true, 'Sí'),
                      const SizedBox(width: 4),
                      _buildOpcionRadio(item, false, 'No'),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: item.observacion.isNotEmpty
                              ? widget.primaryColor
                              : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            item.showObservacion = !item.showObservacion;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getColorForValue(item.value),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTextForValue(item.value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          if (item.showObservacion && isEditable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: item.observacionesController,
                decoration: InputDecoration(
                  hintText: 'Escriba observaciones...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: widget.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLines: 2,
                minLines: 1,
                enabled: isEditable,
                onChanged: (text) {
                  item.observacion = text;
                },
              ),
            ),
          if (!isEditable && item.observacion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Observaciones:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.observacion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpcionRadio(ChecklistItemTelemando item, bool value, String text) {
    return GestureDetector(
      onTap: isEditable
          ? () {
              setState(() {
                item.value = value;
                if (value == false) {
                  item.showObservacion = true;
                }
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item.value == value 
              ? widget.primaryColor 
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.value == value 
                ? widget.primaryColor 
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: item.value == value ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Color _getColorForValue(bool? value) {
    if (value == true) return Colors.green;
    if (value == false) return Colors.red;
    return Colors.grey;
  }

  String _getTextForValue(bool? value) {
    if (value == true) return 'SÍ';
    if (value == false) return 'NO';
    return 'PENDIENTE';
  }
}

class ChecklistItemTelemando {
  final int id;
  final String descripcion;
  bool? value;
  String observacion;
  bool showObservacion;
  late final TextEditingController observacionesController;

  ChecklistItemTelemando({
    required this.id,
    required this.descripcion,
    this.value,
    String? observacion,
    this.showObservacion = false,
  }) : observacion = observacion ?? '' {
    observacionesController = TextEditingController(text: observacion ?? '');
  }

  void dispose() {
    observacionesController.dispose();
  }
}