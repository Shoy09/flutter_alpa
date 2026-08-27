import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:i_miner/config/data/database_helper.dart';

class DialogoChecklist extends StatefulWidget {
  final int operacionId;
  final String estado;
  final List<Map<String, dynamic>> checklistData;
  final Color primaryColor;

  const DialogoChecklist({
    Key? key,
    required this.operacionId,
    required this.estado,
    required this.checklistData,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<DialogoChecklist> createState() => _DialogoChecklistState();
}

class _DialogoChecklistState extends State<DialogoChecklist> {
  late Map<String, List<ChecklistItem>> checklistPorCategoria;
  late List<String> categorias;
  late Map<String, bool> expandedState;
  bool isEditable = false;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _inicializarChecklist();
  }

  void _inicializarChecklist() {
    if (widget.checklistData.isEmpty) {
      checklistPorCategoria = {};
      categorias = [];
      expandedState = {};
      return;
    }

    // Agrupar items por categoría
    Map<String, List<ChecklistItem>> tempMap = {};
    
    for (int i = 0; i < widget.checklistData.length; i++) {
      var item = widget.checklistData[i];
      String categoria = item['categoria'] ?? 'Sin categoría';
      
      ChecklistItem checklistItem = ChecklistItem(
        i + 1,
        item['descripcion'] ?? 'Sin descripción',
        value: item['decision'] == 1
            ? true
            : item['decision'] == 0
                ? false
                : null,
        observaciones: item['observacion'] ?? '',
      );
      
      if (!tempMap.containsKey(categoria)) {
        tempMap[categoria] = [];
      }
      tempMap[categoria]!.add(checklistItem);
    }
    
    checklistPorCategoria = tempMap;
    categorias = tempMap.keys.toList();
    
    // Inicializar todos los estados como expandidos (abiertos)
    expandedState = {};
    for (var categoria in categorias) {
      expandedState[categoria] = true;
    }
  }

  Future<void> _guardarChecklist() async {
    // Crear una lista plana para guardar manteniendo el orden original
    List<Map<String, dynamic>> datosAGuardar =
        List<Map<String, dynamic>>.from(widget.checklistData);
    
    int index = 0;
    for (var categoria in categorias) {
      for (var item in checklistPorCategoria[categoria]!) {
        if (index < datosAGuardar.length) {
          datosAGuardar[index]['decision'] = item.value == true ? 1 : 0;
          datosAGuardar[index]['observacion'] = item.observaciones;
          index++;
        }
      }
    }

    bool guardado = await DatabaseHelper()
        .updateCheckListHorizontal(widget.operacionId, datosAGuardar);

    if (guardado) {
      _mostrarSnackbar('Checklist guardado correctamente', Colors.green);
      Navigator.pop(context, true);
    } else {
      _mostrarSnackbar('Error al guardar el checklist', Colors.red);
    }
  }

  void _marcarTodosSi() {
    setState(() {
      for (var categoria in categorias) {
        for (var item in checklistPorCategoria[categoria]!) {
          item.value = true;
          item.showObservaciones = false;
        }
      }
    });
  }

  void _marcarTodosNo() {
    setState(() {
      for (var categoria in categorias) {
        for (var item in checklistPorCategoria[categoria]!) {
          item.value = false;
          item.showObservaciones = true;
        }
      }
    });
  }

  void _limpiarTodo() {
    setState(() {
      for (var categoria in categorias) {
        for (var item in checklistPorCategoria[categoria]!) {
          item.value = null;
          item.showObservaciones = false;
          item.observaciones = '';
          item.observacionesController.text = '';
        }
      }
    });
  }

  void _toggleCategoria(String categoria) {
    setState(() {
      expandedState[categoria] = !(expandedState[categoria] ?? true);
    });
  }

  void _expandirTodas() {
    setState(() {
      for (var categoria in categorias) {
        expandedState[categoria] = true;
      }
    });
  }

  void _colapsarTodas() {
    setState(() {
      for (var categoria in categorias) {
        expandedState[categoria] = false;
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
    for (var categoria in categorias) {
      for (var item in checklistPorCategoria[categoria]!) {
        item.dispose();
      }
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
          maxWidth: 900,
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
                      Icons.checklist,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Checklist de Operación',
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
            if (checklistPorCategoria.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
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
                        'Esta operación no tiene items definidos',
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
                    // Botones de acción rápida y control de expansión
                    if (isEditable && checklistPorCategoria.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Botones para expandir/colapsar todas
                            Row(
                              children: [
                                _buildAccionRapida(
                                  label: 'Expandir todas',
                                  icon: Icons.expand_more,
                                  color: Colors.blue,
                                  onPressed: _expandirTodas,
                                ),
                                const SizedBox(width: 8),
                                _buildAccionRapida(
                                  label: 'Colapsar todas',
                                  icon: Icons.chevron_right,
                                  color: Colors.blue,
                                  onPressed: _colapsarTodas,
                                ),
                              ],
                            ),
                            // Botones de marcado rápido
                            Row(
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
                          ],
                        ),
                      ),

                    // Lista de categorías con checklist
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: ListView.separated(
                          itemCount: categorias.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final categoria = categorias[index];
                            final items = checklistPorCategoria[categoria]!;
                            final isExpanded = expandedState[categoria] ?? true;
                            
                            return _buildCategoriaCard(
                              categoria, 
                              items, 
                              isExpanded,
                            );
                          },
                        ),
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
                  if (isEditable && checklistPorCategoria.isNotEmpty)
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

  Widget _buildCategoriaCard(
    String categoria, 
    List<ChecklistItem> items, 
    bool isExpanded,
  ) {
    // Calcular progreso de la categoría
    int totalItems = items.length;
    int itemsCompletados = items.where((item) => item.value != null).length;
    double progreso = totalItems > 0 ? itemsCompletados / totalItems : 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de la categoría (clickeable)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleCategoria(categoria),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isExpanded ? Colors.grey.shade300 : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Icono de categoría
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Título de categoría y contador
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: widget.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$itemsCompletados de $totalItems completados',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Barra de progreso
                    Container(
                      width: 80,
                      height: 4,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progreso,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Botón de expandir/colapsar
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: widget.primaryColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Items del checklist (mostrar solo si está expandido)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildChecklistItem(item),
                  );
                }).toList(),
              ),
            ),
        ],
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

  Widget _buildChecklistItem(ChecklistItem item) {
    // Sincronizar controlador con el texto
    if (item.observacionesController.text != item.observaciones) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (item.observacionesController.text != item.observaciones) {
          item.observacionesController.text = item.observaciones;
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
              item.title,
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
                          color: item.observaciones.isNotEmpty
                              ? widget.primaryColor
                              : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            item.showObservaciones = !item.showObservaciones;
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
          if (item.showObservaciones && isEditable)
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
                  item.observaciones = text;
                },
              ),
            ),
          if (!isEditable && item.observaciones.isNotEmpty)
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
                      item.observaciones,
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

  Widget _buildOpcionRadio(ChecklistItem item, bool value, String text) {
    return GestureDetector(
      onTap: isEditable
          ? () {
              setState(() {
                item.value = value;
                if (value == false) {
                  item.showObservaciones = true;
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

// Clase ChecklistItem (adaptada del código original)
class ChecklistItem {
  final int id;
  final String title;
  bool? value;
  String observaciones;
  bool showObservaciones;
  late final TextEditingController observacionesController;

  ChecklistItem(
    this.id,
    this.title, {
    this.value,
    String? observaciones,
    this.showObservaciones = false,
  }) : observaciones = observaciones ?? '' {
    observacionesController = TextEditingController(text: observaciones ?? '');
  }

  void dispose() {
    observacionesController.dispose();
  }
}