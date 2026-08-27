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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final operacionesOrdenadas = List<Map<String, dynamic>>.from(operaciones);

    operacionesOrdenadas.sort((a, b) {
      return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
    });

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
          /// HEADER
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 16,
              vertical: isMobile ? 10 : 12,
            ),
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
                _buildHeaderCell('Estado', flex: isMobile ? 1 : 2),
                _buildHeaderCell('Código', flex: 2),
                _buildHeaderCell('H. Ini', flex: isMobile ? 1 : 2),
                _buildHeaderCell('H. Fin', flex: isMobile ? 1 : 2),
                _buildHeaderCell('Acc.', flex: isMobile ? 2 : 3, align: Alignment.center),
              ],
            ),
          ),

          /// BODY
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
                        isMobile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String texto,
      {int flex = 1, Alignment align = Alignment.centerLeft}) {
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
          ),
        ),
      ),
    );
  }

  Widget _buildFilaOperacion(
      Map<String, dynamic> operacion, int numero, bool isMobile) {
    final String estado = operacion['estado'] ?? 'OPERATIVO';
    final String estadoInicial =
    estado.length > 2 ? estado.substring(0, 2) + '...' : estado;

    Color estadoColor = _getEstadoColor(estado);
    IconData estadoIcon = _getEstadoIcon(estado);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      color: numero.isOdd ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          /// N°
          Expanded(
            flex: 1,
            child: Text(
              numero.toString(),
              style: TextStyle(fontSize: isMobile ? 11 : 12),
            ),
          ),

          /// ESTADO (RESPONSIVE)
          Expanded(
            flex: isMobile ? 1 : 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 6 : 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    estadoIcon,
                    size: isMobile ? 10 : 12,
                    color: estadoColor,
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        estado,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: estadoColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 2),
                    Text(
                      estadoInicial,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: estadoColor,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          /// CÓDIGO
          Expanded(
            flex: 2,
            child: Text(
              operacion['codigo'] ?? '-',
              style: TextStyle(fontSize: isMobile ? 11 : 12),
            ),
          ),

          /// HORA INICIO
          Expanded(
            flex: isMobile ? 1 : 2,
            child: Text(
              operacion['horaInicio'] ?? '--:--',
              style: TextStyle(fontSize: isMobile ? 11 : 12),
            ),
          ),

          /// HORA FIN
          Expanded(
            flex: isMobile ? 1 : 2,
            child: Text(
              operacion['horaFin'] ?? '--:--',
              style: TextStyle(fontSize: isMobile ? 11 : 12),
            ),
          ),

          /// ACCIONES
          Expanded(
            flex: isMobile ? 2 : 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAccionButton(
                  icon: Icons.visibility_outlined,
                  color: Colors.blue,
                  onPressed: () => onVerDetalle(operacion),
                  size: isMobile ? 14 : 16,
                ),
                SizedBox(width: isMobile ? 4 : 8),
                _buildAccionButton(
                  icon: Icons.edit_outlined,
                  color: Colors.orange,
                  onPressed: () => onEditar(operacion),
                  size: isMobile ? 14 : 16,
                ),
                SizedBox(width: isMobile ? 4 : 8),
                _buildAccionButton(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onPressed: () => onEliminar(operacion),
                  size: isMobile ? 14 : 16,
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
    required VoidCallback onPressed,
    double size = 16,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(size == 14 ? 4 : 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: size,
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
          Icon(Icons.inbox, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'No hay operaciones registradas',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete el formulario para crear una nueva operación',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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