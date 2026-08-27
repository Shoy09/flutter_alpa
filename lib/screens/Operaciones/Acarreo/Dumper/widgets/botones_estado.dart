import 'package:flutter/material.dart';

class BotonesEstado extends StatelessWidget {
  final Function(String) onEstadoSeleccionado;

  const BotonesEstado({
    Key? key,
    required this.onEstadoSeleccionado,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          
          if (isSmallScreen) {
            // En pantallas pequeñas: mostrar de 2 en 2
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildEstadoButton('OPERATIVO', const Color(0xFF4CAF50), Icons.check_circle_outline)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildEstadoButton('DEMORA', const Color(0xFFFF9800), Icons.access_time)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildEstadoButton('MANTENIMIENTO', const Color(0xFF2196F3), Icons.build)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildEstadoButton('RESERVA', const Color(0xFF9C27B0), Icons.event_available)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildEstadoButton('FUERA DE PLAN', const Color(0xFFF44336), Icons.warning_amber_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: Container()), // Espacio vacío para mantener centrado
                  ],
                ),
              ],
            );
          } else {
            // En pantallas grandes: mostrar en una sola fila horizontal
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEstadoButton('OPERATIVO', const Color(0xFF4CAF50), Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  _buildEstadoButton('DEMORA', const Color(0xFFFF9800), Icons.access_time),
                  const SizedBox(width: 8),
                  _buildEstadoButton('MANTENIMIENTO', const Color(0xFF2196F3), Icons.build),
                  const SizedBox(width: 8),
                  _buildEstadoButton('RESERVA', const Color(0xFF9C27B0), Icons.event_available),
                  const SizedBox(width: 8),
                  _buildEstadoButton('FUERA DE PLAN', const Color(0xFFF44336), Icons.warning_amber_rounded),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEstadoButton(String estado, Color color, IconData icon) {
    return ElevatedButton(
      onPressed: () => onEstadoSeleccionado(estado),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              estado,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}