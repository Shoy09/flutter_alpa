import 'package:flutter/material.dart';

class BotonesAccionesInferiores extends StatelessWidget {
  final VoidCallback onChecklistPressed;
  final VoidCallback onChecklistTelemandoPressed;
  final VoidCallback onHorometroPressed;
  final VoidCallback onCheckprogramaTrabajoPressed;
  final VoidCallback onCerrarRegistrosPressed;
  final VoidCallback onCondicionesEquipoPressed;
  final VoidCallback onPresionLlantasPressed;
  final Color primaryColor;

  const BotonesAccionesInferiores({
    Key? key,
    required this.onChecklistPressed,
    required this.onChecklistTelemandoPressed,
    required this.onCheckprogramaTrabajoPressed,
    required this.onHorometroPressed,
    required this.onCerrarRegistrosPressed,
    required this.onCondicionesEquipoPressed,
    required this.onPresionLlantasPressed,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Asegura que ocupe todo el ancho disponible
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Si el ancho es suficiente para mostrar todos los botones sin scroll
          if (constraints.maxWidth > 600) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAccionBoton(
                  icon: Icons.speed,
                  label: 'Horómetro',
                  onPressed: onHorometroPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.build,
                  label: 'Condiciones de equipo',
                  onPressed: onCondicionesEquipoPressed,
                ),
                  _buildAccionBoton(
                    icon: Icons.work,
                    label: 'Programa de trabajo',
                    onPressed: onCheckprogramaTrabajoPressed,
                  ),
                _buildAccionBoton(
                  icon: Icons.checklist,
                  label: 'CheckList',
                  onPressed: onChecklistPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.checklist,
                  label: 'CheckList Telemando',
                  onPressed: onChecklistTelemandoPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.tire_repair,
                  label: 'Presión de llantas',
                  onPressed: onPresionLlantasPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.lock_outline,
                  label: 'Cerrar registro',
                  onPressed: onCerrarRegistrosPressed,
                ),
              ],
            );
          } 
          // Si el ancho es menor, mostramos con scroll horizontal
          else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAccionBoton(
                    icon: Icons.checklist,
                    label: 'CheckList',
                    onPressed: onChecklistPressed,
                  ),
                  const SizedBox(width: 8),
                  _buildAccionBoton(
                    icon: Icons.speed,
                    label: 'Horómetro',
                    onPressed: onHorometroPressed,
                  ),
                  const SizedBox(width: 8),
                  _buildAccionBoton(
                    icon: Icons.lock_outline,
                    label: 'Cerrar',
                    onPressed: onCerrarRegistrosPressed,
                  ),
                  const SizedBox(width: 8),
                  _buildAccionBoton(
                    icon: Icons.build,
                    label: 'Condiciones',
                    onPressed: onCondicionesEquipoPressed,
                  ),
                  const SizedBox(width: 8),
                  _buildAccionBoton(
                    icon: Icons.tire_repair,
                    label: 'Presión',
                    onPressed: onPresionLlantasPressed,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildAccionBoton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}