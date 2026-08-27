import 'package:flutter/material.dart';
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/AnfoChanger/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/Rompebancos/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/SCISSOR/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/Scalamin/lista_perforacion_sreen.dart';

class ServiciosAuxiliaresScreen extends StatelessWidget {
  final String? rolUsuario;
  final String? dniUsuario;

  const ServiciosAuxiliaresScreen({
    Key? key,
    this.rolUsuario,
    this.dniUsuario,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF1B5E6B);
    final Color accentColor = const Color(0xFF1B5E6B);

    return Scaffold(
      appBar: AppBar(
  elevation: 2,
  backgroundColor: primaryColor,
  foregroundColor: Colors.white,

  title: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.build_rounded, size: 16), // 🔥 icono acorde
      ),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'SERVICIOS AUXILIARES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Diseño responsivo: 2 columnas en móvil, 4 en tablet/escritorio
                int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtítulo corporativo
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            'Seleccione el equipo para gestionar sus operaciones',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 60,
                            height: 2,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),
                    
                    // Grid de botones corporativos
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        // SizedBox(
                        //   width: itemWidth,
                        //   child: CorporateButton(
                        //     title: 'ROMPEBANCO',
                        //     subtitle: 'Gestión de perforación',
                        //     icon: Icons.hardware,
                        //     backgroundColor: primaryColor,
                        //     accentColor: accentColor,
                        //     onPressed: () {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (_) => TaladroRompebancosScreen(
                        //             rolUsuario: rolUsuario,
                        //             dniUsuario: dniUsuario,
                        //           ),
                        //         ),
                        //       );
                        //     },
                        //   ),
                        // ),
                        SizedBox(
                          width: itemWidth,
                          child: CorporateButton(
                            title: 'ANFOCHARGER',
                            subtitle: 'Gestión de carga',
                            icon: Icons.construction,
                            backgroundColor: primaryColor,
                            accentColor: accentColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaladroAnfoChangerScreen(
                                    rolUsuario: rolUsuario,
                                    dniUsuario: dniUsuario,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: CorporateButton(
                            title: 'SCISSOR',
                            subtitle: 'Plataforma elevadora',
                            icon: Icons.elevator,
                            backgroundColor: primaryColor,
                            accentColor: accentColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaladroSCISSORScreen(
                                    rolUsuario: rolUsuario,
                                    dniUsuario: dniUsuario,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: CorporateButton(
                            title: 'SCALAMIN',
                            subtitle: 'Equipo de scaling',
                            icon: Icons.bolt,
                            backgroundColor: primaryColor,
                            accentColor: accentColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaladroScalaminScreen(
                                    rolUsuario: rolUsuario,
                                    dniUsuario: dniUsuario,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Footer informativo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Última actualización: Marzo 2026',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Nuevo componente corporativo sin afectar al ReportButton existente
class CorporateButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
  final VoidCallback onPressed;

  const CorporateButton({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: backgroundColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 2,
                color: accentColor.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Gestionar',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}