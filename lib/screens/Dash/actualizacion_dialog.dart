import 'package:flutter/material.dart';

class ActualizacionDialog extends StatefulWidget {
  final Map<String, bool> opcionesIniciales;
  final Color? primaryColor;

  const ActualizacionDialog({
    Key? key,
    required this.opcionesIniciales,
    this.primaryColor,
  }) : super(key: key);

  @override
  State<ActualizacionDialog> createState() => _ActualizacionDialogState();
}

class _ActualizacionDialogState extends State<ActualizacionDialog> {
  late Map<String, bool> opcionesSeleccionadas;
  late Color primaryColor;
  String busqueda = '';
  List<MapEntry<String, bool>> opcionesFiltradas = [];

  // Agrupación de opciones por categoría
  final Map<String, List<String>> categorias = {
    'Planificación': [
      'Plan Mensual',
      'Plan Metraje',
      'Plan Producción',
      'Toneladas',
    ],
    'Maestros': [
      'Horometros',
      'Empresas',
      'Equipos',
      'Secciones',
      'Tipos Equipo',
      'Accesorios',
      "Materiales",
      'Destinatarios',
      'origen-destino',
      'Longitud Barras',
      'Pernos',
      'Mallas',
      'Origen y Destino',
      'Guardias'
    ],
    'Perforación y Explosivos': [
      'Tipos Perforación',
      'Explosivos',
      'Explosivos Uni',
      'Accesorios',
      'Numero de retardos'
    ],
    'Sistema': ['Jefes Guardia', 'Estados', 'Checklist', 'Checklist Carguio'],

  };

  @override
  void initState() {
    super.initState();
    opcionesSeleccionadas = Map<String, bool>.from(widget.opcionesIniciales);
    primaryColor = widget.primaryColor ?? Colors.blue[700]!;
    _filtrarOpciones();
  }

  void _filtrarOpciones() {
    final entries = opcionesSeleccionadas.entries.toList();
    if (busqueda.isEmpty) {
      opcionesFiltradas = entries;
    } else {
      opcionesFiltradas = entries
          .where(
            (entry) => entry.key.toLowerCase().contains(busqueda.toLowerCase()),
          )
          .toList();
    }
  }

  void _toggleTodos(bool seleccionar) {
    setState(() {
      for (var key in opcionesSeleccionadas.keys) {
        opcionesSeleccionadas[key] = seleccionar;
      }
      _filtrarOpciones();
    });
  }

  void _toggleCategoria(String categoria, bool seleccionar) {
    if (!categorias.containsKey(categoria)) return;

    setState(() {
      for (var opcion in categorias[categoria]!) {
        if (opcionesSeleccionadas.containsKey(opcion)) {
          opcionesSeleccionadas[opcion] = seleccionar;
        }
      }
      _filtrarOpciones();
    });
  }

  int _getSeleccionadasCount() {
    return opcionesSeleccionadas.values.where((v) => v).length;
  }

  @override
  Widget build(BuildContext context) {
    final seleccionadas = _getSeleccionadasCount();
    final total = opcionesSeleccionadas.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con gradiente
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sync_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actualizar Datos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecciona los módulos a actualizar',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$seleccionadas/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar módulo...',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    busqueda = value;
                    _filtrarOpciones();
                  });
                },
              ),
            ),

            // Acciones rápidas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.select_all,
                      label: 'Seleccionar todos',
                      onPressed: () => _toggleTodos(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.deselect,
                      label: 'Deseleccionar todos',
                      onPressed: () => _toggleTodos(false),
                      isOutlined: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Lista de opciones por categorías (solo si no hay búsqueda)
            Expanded(
              child: busqueda.isEmpty
                  ? _buildCategoriasList()
                  : _buildResultadosBusqueda(),
            ),

            // Footer con acciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (seleccionadas > 0) {
                        Navigator.of(context).pop(opcionesSeleccionadas);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Selecciona al menos un módulo',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_download, size: 18),
                        const SizedBox(width: 8),
                        Text('Actualizar ($seleccionadas)'),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCategoriasList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final categoria = categorias.keys.elementAt(index);
        final opciones = categorias[categoria]!
            .where((o) => opcionesSeleccionadas.containsKey(o))
            .toList();

        if (opciones.isEmpty) return const SizedBox();

        final seleccionadasEnCategoria = opciones
            .where((o) => opcionesSeleccionadas[o] == true)
            .length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoria,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$seleccionadasEnCategoria/${opciones.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      onSelected: (value) {
                        if (value == 'select') {
                          _toggleCategoria(categoria, true);
                        } else if (value == 'deselect') {
                          _toggleCategoria(categoria, false);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'select',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_box,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text('Seleccionar todas'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'deselect',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_box_outline_blank,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text('Deseleccionar todas'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...opciones.map(
                (opcion) => CheckboxListTile(
                  title: Text(opcion, style: const TextStyle(fontSize: 13)),
                  value: opcionesSeleccionadas[opcion],
                  onChanged: (value) {
                    setState(() {
                      opcionesSeleccionadas[opcion] = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultadosBusqueda() {
    if (opcionesFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No se encontraron módulos',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: opcionesFiltradas.length,
      itemBuilder: (context, index) {
        final entry = opcionesFiltradas[index];
        return CheckboxListTile(
          title: Text(entry.key),
          value: entry.value,
          onChanged: (value) {
            setState(() {
              opcionesSeleccionadas[entry.key] = value ?? false;
              _filtrarOpciones();
            });
          },
          activeColor: primaryColor,
          dense: true,
        );
      },
    );
  }
}

// Diálogo de progreso mejorado
class ProgressDialog extends StatelessWidget {
  final String message;
  final double? progress;
  final String? subtitulo;

  const ProgressDialog({
    Key? key,
    required this.message,
    this.progress,
    this.subtitulo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress == null)
              const CircularProgressIndicator()
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    '${(progress! * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
