import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/core/network/connection_provider.dart';
import 'package:i_miner/screens/Dash/actualizacion_dialog.dart';
import 'package:i_miner/screens/Envio%20a%20nube/operaciones_centralizada.dart';
import 'package:i_miner/screens/Operaciones/Acarreo/Dumper/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Scoop/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Mediciones/select_tipo_explosivo.dart';
import 'package:i_miner/screens/Operaciones/Servicio%20Auxiliares/ServiciosAuxiliaresScreen.dart';
import 'package:i_miner/screens/Operaciones/Tal%20horizontal/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/Volquetes/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/Operaciones/explosivos/prueba.dart';
import 'package:i_miner/screens/Operaciones/sostenimiento/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/widgets/ReportButton.dart';
import 'package:i_miner/screens/Operaciones/Tal%20largo/lista_perforacion_sreen.dart';
import 'package:i_miner/screens/login/login_screen.dart';
import 'package:i_miner/services/get%20nube/Plan%20mensual/api_service_FechasPlanMensualService.dart';
import 'package:i_miner/services/get%20nube/actualizacion_service.dart';
import 'package:provider/provider.dart';
import 'package:i_miner/services/get%20nube/registros%20nube/ApiServiceExploracion.dart';
class DashboardScreen extends StatefulWidget {
  final String dni;
  final String token;

  const DashboardScreen({
    Key? key,
    required this.dni,
    required this.token,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color navbarColor = const Color(0xFF1B5E6B); // Color único para todas las cards
  
  String nombreUsuario = "Cargando...";
  String rol = "Cargando...";
  Map<String, dynamic> operacionesAutorizadas = {};

  bool estaAutorizadoPara(String operacion) {
    return operacionesAutorizadas[operacion] == true;
  }

    @override
  void initState() {
    super.initState();
  _cargarNombreUsuario();

  }

    Future<void> _cargarNombreUsuario() async {
    try {
      final dbHelper = DatabaseHelper();
      final usuario = await dbHelper.getUserByDni(widget.dni);
      if (usuario != null) {
        setState(() {
          nombreUsuario = '${usuario['nombres']} ${usuario['apellidos']}';
          rol = usuario['rol'];

          final operacionesJson = usuario['operaciones_autorizadas'];
          if (operacionesJson != null && operacionesJson.isNotEmpty) {
            operacionesAutorizadas = jsonDecode(operacionesJson);
          }
        });
      } else {
        setState(() {
          nombreUsuario = "Usuario no encontrado";
          rol = "sin rol";
        });
      }
    } catch (e) {
      print('Error obteniendo usuario: $e');
      setState(() {
        nombreUsuario = "Error al cargar usuario";
        rol = "Error al cargar rol";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectionProvider>().isOnline;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 2,
        title: const Text(
          'Panel de Control',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
        backgroundColor: navbarColor,
        foregroundColor: Colors.white,
        actions: [
          // Botón de upload
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeccionesScreen(),
                  ),
                );
                
              },
              tooltip: 'Subir reportes',
            ),
          ),
          // Menú
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'actualizar') {
                await _actualizarDatos(context);
              } else if (value == 'mediciones') {
                await fetchExploracionesMina2();
              } else if (value == 'cerrar_sesion') {
                _showLogoutDialog(context);
              }
            },
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            itemBuilder: (context) => [
              _buildMenuItem(
                value: 'actualizar',
                icon: Icons.refresh,
                label: 'Actualizar datos',
                iconColor: Colors.blue,
              ),
              _buildMenuItem(
                value: 'mediciones',
                icon: Icons.science,
                label: 'Actualizar Mediciones',
                iconColor: Colors.purple,
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                value: 'cerrar_sesion',
                icon: Icons.exit_to_app,
                label: 'Cerrar sesión',
                iconColor: Colors.red,
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header compacto con información del usuario
              Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: navbarColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: 24,
          color: navbarColor,
        ),
      ),
      const SizedBox(width: 12),

      // 👇 INFO USUARIO
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreUsuario,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rol == null || rol.trim().isEmpty
                  ? 'Sin rol asignado'
                  : rol,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),

      // 👇 ESTADO INTERNET
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 14,
                  color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? "Online" : "Offline",
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 📅 Fecha
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getCurrentDate(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
              const SizedBox(height: 20),
              
              // Título de sección compacto
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Módulos disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    '${_getModuleCount()} módulos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Grid de botones
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;
                    int columns;

                    if (width > 1000) {
                      columns = 6;
                    } else if (width > 800) {
                      columns = 5;
                    } else if (width > 600) {
                      columns = 4;
                    } else if (width > 400) {
                      columns = 3;
                    } else {
                      columns = 2;
                    }

                    List<Widget> buttons = _buildModuleButtons();

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9, // Tarjetas más compactas
                      ),
                      itemCount: buttons.length,
                      itemBuilder: (context, index) => buttons[index],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildModuleButtons() {
    List<Widget> buttons = [];

    final modules = [
      if (estaAutorizadoPara('PERFORACIÓN TALADROS LARGOS'))
        {'title': 'PERFORACIÓN\nTALADROS LARGOS', 'image': 'assets/images/perforacion_taladros.png'},
      if (estaAutorizadoPara('PERFORACIÓN HORIZONTAL'))
        {'title': 'PERFORACIÓN\nHORIZONTAL', 'image': 'assets/images/perfo_horizontal.png'},
      if (estaAutorizadoPara('SOSTENIMIENTO'))
        {'title': 'SOSTENIMIENTO', 'image': 'assets/images/sostenimiento.png'},
      if (estaAutorizadoPara('SERVICIOS AUXILIARES'))
        {'title': 'SERVICIOS\nAUXILIARES', 'image': 'assets/images/servicio_auxiliares.png'},
      if (estaAutorizadoPara('EXPLOSIVOS'))
        {'title': 'EXPLOSIVOS', 'image': 'assets/images/explosivos.png'},
      if (estaAutorizadoPara('ACEROS DE PERFORACIÓN'))
        {'title': 'ACEROS DE\nPERFORACIÓN', 'image': 'assets/images/aceros_de_perforacion.png'},
      if (estaAutorizadoPara('CARGUÍO'))
        {'title': 'SCOOP', 'image': 'assets/images/carguio.png'},
      if (estaAutorizadoPara('ACARREO'))
        {'title': 'ACARREO', 'image': 'assets/images/acarreo.png'},
      if (estaAutorizadoPara('MEDICIONES'))
        {'title': 'MEDICIONES', 'image': 'assets/images/medicion.png'},
    ];

    for (var module in modules) {
      buttons.add(
        ReportButton(
          title: module['title']!,
          imagePath: module['image']!,
          backgroundColor: navbarColor, // MISMO COLOR PARA TODAS
          onPressed: () {
            // Acción según el módulo
            _handleModulePress(module['title']!);
          },
        ),
      );
    }

    return buttons;
  }

  void _handleModulePress(String title) {
  switch (title) {
    case 'PERFORACIÓN\nTALADROS LARGOS':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaladroLargoScreen(
            rolUsuario: '${rol}',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;

      case 'PERFORACIÓN\nHORIZONTAL':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaladroHorizontalScreen(
            rolUsuario: '$rol',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;

      case 'SOSTENIMIENTO':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaladroEmpernadorScreen(
            rolUsuario: '$rol',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;

      case 'SCOOP':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaladroCarguioScreen(
            rolUsuario: '$rol',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;
      case 'ACARREO':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaladroVolquetesScreen(
            rolUsuario: '$rol',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;


    case 'MEDICIONES':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Selecc_Tipo_explo(
          ),
        ),
      );
      break;


      case 'SERVICIOS\nAUXILIARES':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiciosAuxiliaresScreen(
            rolUsuario: '$rol',
            dniUsuario: '${widget.dni}',
          ),
        ),
      );
      break;

      case 'EXPLOSIVOS':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Pruebacreen(
            dni: widget.dni
          ),
        ),
      );
      break;

    default:
      print('Módulo no configurado');
  }
}

  int _getModuleCount() {
    int count = 0;
    if (estaAutorizadoPara('PERFORACIÓN TALADROS LARGOS')) count++;
    if (estaAutorizadoPara('PERFORACIÓN HORIZONTAL')) count++;
    if (estaAutorizadoPara('SOSTENIMIENTO')) count++;
    if (estaAutorizadoPara('SERVICIOS AUXILIARES')) count++;
    if (estaAutorizadoPara('EXPLOSIVOS')) count++;
    if (estaAutorizadoPara('ACEROS DE PERFORACIÓN')) count++;
    if (estaAutorizadoPara('CARGUÍO')) count++;
    if (estaAutorizadoPara('ACARREO')) count++;
    if (estaAutorizadoPara('MEDICIONES')) count++;
    return count;
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarDatos(BuildContext context) async {
  // Definir las opciones disponibles
  final opcionesDisponibles = {
    "Estados": true,
    "Checklist": true,
   "Tipos Perforación": true,
     "Equipos": true,
     "Secciones": true,
    "Tipos Equipo": true,
     "Plan Mensual": true,
    "Plan Metraje": true,
    "Plan Producción": true,
    "Jefes Guardia": true,
    "Checklist Carguio": true,
    "Longitud Barras": true,
  "Pernos": true,
  "Mallas": true,
  "Horometros": true,
  "Origen y Destino": true,
  "Accesorios": true,
  "Explosivos": true,
  "Explosivos Uni": true,
  "Numero de retardos": true,
  "Guardias": true,
  "Materiales": true,
  "Empresas": true,
  };

  // Mostrar diálogo de selección mejorado
  final opcionesSeleccionadas = await showDialog<Map<String, bool>>(
    context: context,
    builder: (context) => ActualizacionDialog(
      opcionesIniciales: opcionesDisponibles,
      primaryColor: navbarColor, // Tu color primario
    ),
  );

  // Si el usuario cancela o no selecciona nada, salir
  if (opcionesSeleccionadas == null || opcionesSeleccionadas.isEmpty) {
    return;
  }

  // Obtener el mes actual o el que necesites
  final fechasService = FechasPlanMensualService();
  final ultimaFecha = await fechasService.getUltimaFecha();
  
  if (ultimaFecha == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se encontró una fecha válida'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // Crear y ejecutar el servicio de actualización
  final actualizacionService = ActualizacionService(
  context: context,
  token: widget.token,
  anio: ultimaFecha.fechaIngreso!,
  mes: ultimaFecha.mes,
);

  await actualizacionService.ejecutarActualizacion(opcionesSeleccionadas);
}


  Future<void> fetchExploracionesMina2() async {
    try {
      final apiService = ApiServiceExploracion_Mina2(); // ✅ Crear una instancia

      final tipos = await apiService.fetchExploracionesMina2(widget.token);
      print("Tipos de Perforación cargados correctamente: $tipos");

      // Verificar si los datos se almacenaron correctamente
      final dbHelper = DatabaseHelper();
      final tiposBD = await dbHelper.getAll('TipoPerforacion');
      print("Tipos de Perforación en la base de datos local: $tiposBD");
    } catch (e) {
      print("Error al cargar los tipos de perforación: $e");
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Está seguro que desea cerrar la sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }
}