import 'package:flutter/material.dart';

class TablaOperaciones extends StatelessWidget {
  final List<Map<String, dynamic>> operaciones;
  final Function(Map<String, dynamic>) onVerDetalle;
  final Function(Map<String, dynamic>) onEditar;
  final Function(Map<String, dynamic>) onEliminar;
  final Color primaryColor;

  const TablaOperaciones({
    Key? key,
    required this.operaciones,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onEliminar,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

  // 🔥 Copia y ordena por numero
  final operacionesOrdenadas = List<Map<String, dynamic>>.from(operaciones);

  operacionesOrdenadas.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  print('ORDENADAS:');
  operacionesOrdenadas.forEach((e) => print(e));

  return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tabla (fijo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('N°', flex: 1),
                _buildHeaderCell('Estado', flex: 2),
                _buildHeaderCell('Código', flex: 2),
                _buildHeaderCell('Hora Inicio', flex: 2),
                _buildHeaderCell('Hora Fin', flex: 2),
                _buildHeaderCell('Acciones', flex: 3, align: Alignment.center),
              ],
            ),
          ),
          
          // Cuerpo de la tabla con scroll
          Expanded(
            child: operaciones.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: operacionesOrdenadas.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey[100],
                    ),
                    itemBuilder: (context, index) {
                      final operacion = operacionesOrdenadas[index];
                      return _buildFilaOperacion(
  operacion,
  operacion['numero'] ?? (index + 1),
);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String texto, {int flex = 1, Alignment align = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: align,
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildFilaOperacion(Map<String, dynamic> operacion, int numero) {
    // Determinar color e icono del estado
    final String estado = operacion['estado'] ?? 'OPERATIVO';
    Color estadoColor = _getEstadoColor(estado);
    IconData estadoIcon = _getEstadoIcon(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: numero.isOdd ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          // N°
          Expanded(
            flex: 1,
            child: Text(
              numero.toString(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)),
            ),
          ),
          
          // Estado
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(estadoIcon, size: 12, color: estadoColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      estado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: estadoColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Código
          Expanded(
            flex: 2,
            child: Text(
              operacion['codigo'] ?? '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          
          // Hora Inicio
          Expanded(
            flex: 2,
            child: Text(
              operacion['horaInicio'] ?? '--:--',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          
          // Hora Fin
          Expanded(
            flex: 2,
            child: Text(
              operacion['horaFin'] ?? '--:--',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          
          // Acciones
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAccionButton(
                  icon: Icons.visibility_outlined,
                  color: Colors.blue,
                  tooltip: 'Ver detalle',
                  onPressed: () => onVerDetalle(operacion),
                ),
                const SizedBox(width: 8),
                _buildAccionButton(
                  icon: Icons.edit_outlined,
                  color: Colors.orange,
                  tooltip: 'Editar',
                  onPressed: () => onEditar(operacion),
                ),
                const SizedBox(width: 8),
                _buildAccionButton(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: 'Eliminar',
                  onPressed: () => onEliminar(operacion),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 40,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 8),
          Text(
            'No hay operaciones registradas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete el formulario para crear una nueva operación',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'OPERATIVO':
        return const Color(0xFF4CAF50);
      case 'DEMORA':
        return const Color(0xFFFF9800);
      case 'MANTENIMIENTO':
        return const Color(0xFF2196F3);
      case 'RESERVA':
        return const Color(0xFF9C27B0);
      case 'FUERA DE PLAN':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'OPERATIVO':
        return Icons.check_circle_outline;
      case 'DEMORA':
        return Icons.access_time;
      case 'MANTENIMIENTO':
        return Icons.build;
      case 'RESERVA':
        return Icons.event_available;
      case 'FUERA DE PLAN':
        return Icons.warning_amber_rounded;
      default:
        return Icons.help_outline;
    }
  }
}