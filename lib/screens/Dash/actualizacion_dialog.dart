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
      'Documentos',
      'Toneladas',
      'Operadores',
      'Usuarios'
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
      'Guardias',
      'Tipo Labor'
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

// Controlador reactivo del diálogo de progreso
class ProgressDialogController {
  _ProgressDialogState? _state;

  void _attach(_ProgressDialogState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void update({
    required String message,
    String? subtitulo,
    required int completadas,
    required int total,
  }) {
    _state?._update(
      message: message,
      subtitulo: subtitulo,
      completadas: completadas,
      total: total,
    );
  }
}

// Diálogo de progreso mejorado
class ProgressDialog extends StatefulWidget {
  final String message;
  final String? subtitulo;
  final int total;
  final ProgressDialogController controller;
  final Color? primaryColor;

  const ProgressDialog({
    Key? key,
    required this.message,
    required this.total,
    required this.controller,
    this.subtitulo,
    this.primaryColor,
  }) : super(key: key);

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog>
    with TickerProviderStateMixin {
  late String _message;
  String? _subtitulo;
  late int _total;
  int _completadas = 0;

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    _subtitulo = widget.subtitulo;
    _total = widget.total;

    widget.controller._attach(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    widget.controller._detach();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _update({
    required String message,
    String? subtitulo,
    required int completadas,
    required int total,
  }) {
    if (!mounted) return;
    final newProgress = total > 0 ? completadas / total : 0.0;
    setState(() {
      _message = message;
      _subtitulo = subtitulo;
      _completadas = completadas;
      _total = total;
    });
    _progressAnimation = Tween<double>(
      begin: _progressValue,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    _progressValue = newProgress;
    _progressController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? Colors.blue[700]!;
    final pct = _total > 0 ? (_completadas / _total * 100).toInt() : 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con gradiente
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actualizando datos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Por favor espera...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contador circular
                  Container(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (_, __) => CircularProgressIndicator(
                            value: _progressAnimation.value,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cuerpo
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Módulo actual
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Barra de progreso lineal animada
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (_, __) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _subtitulo ?? 'Iniciando...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '$_completadas / $_total',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progressAnimation.value,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Pasos completados como chips
                  if (_completadas > 0) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                        _total,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _completadas
                                ? color
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo de resultado de actualización ───────────────────────────────────

enum _TipoResultado { exitoso, parcial, fallido }

class ResultadoActualizacionDialog extends StatefulWidget {
  final int completadas;
  final int total;
  final List<String> errores;
  final Color? primaryColor;

  const ResultadoActualizacionDialog({
    Key? key,
    required this.completadas,
    required this.total,
    required this.errores,
    this.primaryColor,
  }) : super(key: key);

  @override
  State<ResultadoActualizacionDialog> createState() =>
      _ResultadoActualizacionDialogState();
}

class _ResultadoActualizacionDialogState
    extends State<ResultadoActualizacionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _mostrarErrores = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  _TipoResultado get _tipo {
    if (widget.errores.isEmpty && widget.completadas == widget.total) {
      return _TipoResultado.exitoso;
    } else if (widget.completadas > 0) {
      return _TipoResultado.parcial;
    }
    return _TipoResultado.fallido;
  }

  Color get _color {
    switch (_tipo) {
      case _TipoResultado.exitoso:
        return const Color(0xFF16A34A); // green-600
      case _TipoResultado.parcial:
        return const Color(0xFFD97706); // amber-600
      case _TipoResultado.fallido:
        return const Color(0xFFDC2626); // red-600
    }
  }

  IconData get _icon {
    switch (_tipo) {
      case _TipoResultado.exitoso:
        return Icons.check_circle_rounded;
      case _TipoResultado.parcial:
        return Icons.warning_rounded;
      case _TipoResultado.fallido:
        return Icons.cancel_rounded;
    }
  }

  String get _titulo {
    switch (_tipo) {
      case _TipoResultado.exitoso:
        return 'Actualización completada';
      case _TipoResultado.parcial:
        return 'Completada con errores';
      case _TipoResultado.fallido:
        return 'Actualización fallida';
    }
  }

  String get _descripcion {
    switch (_tipo) {
      case _TipoResultado.exitoso:
        return 'Todos los módulos se sincronizaron correctamente con el servidor.';
      case _TipoResultado.parcial:
        return '${widget.completadas - widget.errores.length} de ${widget.total} módulos se actualizaron. '
            '${widget.errores.length} ${widget.errores.length == 1 ? 'módulo falló' : 'módulos fallaron'}.';
      case _TipoResultado.fallido:
        return 'No se pudo completar ninguna actualización. Revisa tu conexión y vuelve a intentarlo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFailed = widget.errores.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _color.withOpacity(0.20),
                  blurRadius: 36,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_color, _color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titulo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _descripcion,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tarjetas de resumen ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Exitosos',
                        value:
                            '${widget.completadas - widget.errores.length}',
                        color: const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        icon: Icons.error_outline_rounded,
                        label: 'Fallidos',
                        value: '${widget.errores.length}',
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        icon: Icons.layers_rounded,
                        label: 'Total',
                        value: '${widget.total}',
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),

                // ── Barra de progreso resumen ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Módulos actualizados',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${widget.total > 0 ? ((widget.completadas - widget.errores.length) / widget.total * 100).toInt() : 0}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: widget.total > 0
                              ? (widget.completadas - widget.errores.length) /
                                  widget.total
                              : 0,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(_color),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Sección de errores desplegable ───────────────────────────
                if (hasFailed) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          setState(() => _mostrarErrores = !_mostrarErrores),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bug_report_rounded,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.errores.length} ${widget.errores.length == 1 ? 'módulo falló' : 'módulos fallaron'} — toca para ver detalles',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              _mostrarErrores
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: const Color(0xFFDC2626),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: _mostrarErrores
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(10),
                          shrinkWrap: true,
                          itemCount: widget.errores.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 10,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (_, i) {
                            final partes =
                                widget.errores[i].split(':');
                            final modulo = partes.first.trim();
                            final detalle = partes.length > 1
                                ? partes
                                    .sublist(1)
                                    .join(':')
                                    .trim()
                                : 'Error desconocido';
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$modulo  ',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        TextSpan(
                                          text: detalle,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Footer ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Entendido',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
