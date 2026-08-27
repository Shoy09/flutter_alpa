import 'package:flutter/material.dart';

class OperacionCard extends StatelessWidget {
  final Map<String, dynamic> operacion;
  final bool isSelected;
  final bool isEnviado;
  final VoidCallback onTap;
  final Color? primaryColor;

  const OperacionCard({
    Key? key,
    required this.operacion,
    required this.isSelected,
    required this.isEnviado,
    required this.onTap,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    primaryColor!.withOpacity(0.1),
                    primaryColor!.withOpacity(0.05),
                  ]
                : [Colors.white, Colors.grey.shade50],
          ),
          border: Border.all(
            color: isSelected
                ? primaryColor!
                : isEnviado
                    ? Colors.green.shade200
                    : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con ID y estado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${operacion['id']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(operacion['estado']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getEstadoIcon(operacion['estado']),
                          size: 12,
                          color: _getEstadoColor(operacion['estado']),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          operacion['estado'] ?? 'activo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getEstadoColor(operacion['estado']),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isEnviado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done,
                            size: 12,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Enviado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Información principal
              Row(
                children: [
                  _buildInfoItem(
                    icon: Icons.calendar_today,
                    label: 'Fecha',
                    value: operacion['fecha'] ?? '-',
                  ),
                  const SizedBox(width: 16),
                  _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'Turno',
                    value: operacion['turno'] ?? '-',
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  _buildInfoItem(
                    icon: Icons.person,
                    label: 'Operador',
                    value: operacion['operador'] ?? '-',
                  ),
                  const SizedBox(width: 16),
                  _buildInfoItem(
                    icon: Icons.badge,
                    label: 'Jefe Guardia',
                    value: operacion['jefe_guardia'] ?? '-',
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  _buildInfoItem(
                    icon: Icons.precision_manufacturing,
                    label: 'Equipo',
                    value: operacion['n_equipo'] ?? '-',
                  ),
                  const SizedBox(width: 16),
                  _buildInfoItem(
                    icon: Icons.model_training,
                    label: 'Modelo',
                    value: operacion['modelo_equipo'] ?? '-',
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Footer con sección
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        operacion['seccion'] ?? 'Sin sección',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
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

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'cerrado':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getEstadoIcon(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'activo':
        return Icons.play_circle_outline;
      case 'cerrado':
        return Icons.lock_outline;
      default:
        return Icons.help_outline;
    }
  }
}