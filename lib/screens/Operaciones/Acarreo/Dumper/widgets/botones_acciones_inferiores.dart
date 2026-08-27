import 'package:flutter/material.dart';

class BotonesAccionesInferiores extends StatelessWidget {
  final VoidCallback onChecklistPressed;
  // final VoidCallback onChecklistTelemandoPressed;
  final VoidCallback onHorometroPressed;
  final VoidCallback onCheckprogramaTrabajoPressed;
  final VoidCallback onCerrarRegistrosPressed;
  final VoidCallback onCondicionesEquipoPressed;
  final VoidCallback onPresionLlantasPressed;
  final Color primaryColor;

  const BotonesAccionesInferiores({
    Key? key,
    required this.onChecklistPressed,
    // required this.onChecklistTelemandoPressed,
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
      width: double.infinity,
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
          // Para pantallas grandes (PC/Tablet): mostrar en una fila horizontal
          if (constraints.maxWidth > 800) {
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
                // _buildAccionBoton(
                //   icon: Icons.checklist,
                //   label: 'CheckList Telemando',
                //   onPressed: onChecklistTelemandoPressed,
                // ),
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
          // Para pantallas medianas (Tablet pequeña): mostrar en filas de 3-4 botones
          else if (constraints.maxWidth > 550) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildAccionBoton(
                  icon: Icons.speed,
                  label: 'Horómetro',
                  onPressed: onHorometroPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.build,
                  label: 'Condiciones',
                  onPressed: onCondicionesEquipoPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.work,
                  label: 'Programa',
                  onPressed: onCheckprogramaTrabajoPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.checklist,
                  label: 'CheckList',
                  onPressed: onChecklistPressed,
                ),
                // _buildAccionBoton(
                //   icon: Icons.checklist,
                //   label: 'Telemando',
                //   onPressed: onChecklistTelemandoPressed,
                // ),
                _buildAccionBoton(
                  icon: Icons.tire_repair,
                  label: 'Presión',
                  onPressed: onPresionLlantasPressed,
                ),
                _buildAccionBoton(
                  icon: Icons.lock_outline,
                  label: 'Cerrar',
                  onPressed: onCerrarRegistrosPressed,
                ),
              ],
            );
          }
          // Para pantallas pequeñas (Teléfono): mostrar en filas de 2 botones
          else {
            return Column(
              children: [
                // Primera fila: 2 botones
                Row(
                  children: [
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.checklist,
                        label: 'CheckList',
                        onPressed: onChecklistPressed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.speed,
                        label: 'Horómetro',
                        onPressed: onHorometroPressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Segunda fila: 2 botones
                Row(
                  children: [
                    // Expanded(
                    //   child: _buildAccionBoton(
                    //     icon: Icons.checklist,
                    //     label: 'Telemando',
                    //     onPressed: onChecklistTelemandoPressed,
                    //   ),
                    // ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.work,
                        label: 'Programa',
                        onPressed: onCheckprogramaTrabajoPressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tercera fila: 2 botones
                Row(
                  children: [
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.build,
                        label: 'Condiciones',
                        onPressed: onCondicionesEquipoPressed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.tire_repair,
                        label: 'Presión',
                        onPressed: onPresionLlantasPressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Cuarta fila: 1 botón centrado
                Row(
                  children: [
                    Expanded(
                      child: _buildAccionBoton(
                        icon: Icons.lock_outline,
                        label: 'Cerrar registro',
                        onPressed: onCerrarRegistrosPressed,
                      ),
                    ),
                  ],
                ),
              ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: primaryColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}