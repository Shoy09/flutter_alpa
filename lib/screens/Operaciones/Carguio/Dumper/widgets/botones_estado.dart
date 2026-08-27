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
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildEstadoButton(
                estado: 'OPERATIVO',
                color: const Color(0xFF4CAF50),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _buildEstadoButton(
                estado: 'DEMORA',
                color: const Color(0xFFFF9800),
                icon: Icons.access_time,
              ),
              const SizedBox(width: 8),
              _buildEstadoButton(
                estado: 'MANTENIMIENTO',
                color: const Color(0xFF2196F3),
                icon: Icons.build,
              ),
              const SizedBox(width: 8),
              _buildEstadoButton(
                estado: 'RESERVA',
                color: const Color(0xFF9C27B0),
                icon: Icons.event_available,
              ),
              const SizedBox(width: 8),
              _buildEstadoButton(
                estado: 'FUERA DE PLAN',
                color: const Color(0xFFF44336),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoButton({
    required String estado,
    required Color color,
    required IconData icon,
  }) {
    return ElevatedButton(
      onPressed: () => onEstadoSeleccionado(estado),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(140, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(estado),
        ],
      ),
    );
  }
}