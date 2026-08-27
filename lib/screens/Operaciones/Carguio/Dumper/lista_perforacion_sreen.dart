import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/DialogoChecklistTelemando.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/DialogoProgramaTrabajo.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialog_check_imagen.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_checklist.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_condiciones_equipo.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_confirmar_cierre.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_formulario_perforacion.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_horometro.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/dialogo_no_operativo_formulario_perforacion.dart';
import 'package:i_miner/screens/Operaciones/Carguio/Dumper/widgets/show_registro_operacion.dart';

import 'widgets/operacion_card.dart';
import 'widgets/botones_estado.dart';
import 'widgets/tabla_operaciones.dart';
import 'widgets/botones_acciones_inferiores.dart'; // Asegúrate de importar el nuevo archivo

class TaladroDumperScreen2 extends StatefulWidget {
  final String? rolUsuario;
  final String? dniUsuario;

  const TaladroDumperScreen2({Key? key, this.rolUsuario, this.dniUsuario}) : super(key: key);

  @override
  State<TaladroDumperScreen2> createState() => _TaladroDumperScreen2State();
}

class _TaladroDumperScreen2State extends State<TaladroDumperScreen2> {
  final Color primaryColor = const Color(0xFF1B5E6B);

  String fechaActual = DateFormat('yyyy-MM-dd').format(DateTime.now());
String? selectedTurno;
  int? operacionId;
  List<Map<String, dynamic>> operaciones = [];
Map<String, dynamic>? operacionActual;

  // Datos de ejemplo para mostrar la tabla
List<Map<String, dynamic>> operacionesTabla = [];

  // Mapa de colores para cada estado
  final Map<String, Color> coloresEstado = {
    'OPERATIVO': const Color(0xFF4CAF50),
    'DEMORA': const Color(0xFFFF9800),
    'MANTENIMIENTO': const Color(0xFF2196F3),
    'RESERVA': const Color(0xFF9C27B0),
    'FUERA DE PLAN': const Color(0xFFF44336),
  };

  List<Map<String, dynamic>> estadosBD = [];

  final Map<String, List<Map<String, String>>> datadialog = {
    'OPERATIVO': [],
    'DEMORA': [],
    'MANTENIMIENTO': [],
    'RESERVA': [],
    'FUERA DE PLAN': [],
  };

  @override
void initState() {
  super.initState();
  selectedTurno = _getTurnoBasedOnTime();
  _fetchOperacionData();
  obtenerEstadosBD();
}

void obtenerEstadosBD() async {
  estadosBD = await DatabaseHelper().getEstadosBD('DUMPER');
  

  // Limpiamos la lista antes de actualizar
  datadialog.forEach((key, value) => value.clear());

  // Agregar los estados filtrados a la lista correcta
  for (var estado in estadosBD) {
    String estadoPrincipal = estado['estado_principal'];
    if (datadialog.containsKey(estadoPrincipal)) {
      datadialog[estadoPrincipal]?.add({
        "Nombre": estado['tipo_estado'],
        "Código": estado['codigo'].toString(),
      });
    }
  }

  setState(() {});
}

 String _getTurnoBasedOnTime() {
    final currentHour = DateTime.now().hour;
    if (currentHour >= 7 && currentHour < 19) {
      return 'DÍA'; // Turno Día
    } else {
      return 'NOCHE'; // Turno Noche
    }
  }


Future<void> _fetchOperacionData() async {
  if (selectedTurno == null) {
    print("No hay turno seleccionado aún");
    return;
  }

  DatabaseHelper dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> data;

  if (widget.rolUsuario == 'Master') {
    data = await dbHelper.getOperacionDumperByTurnoAndFechaMaster(
        selectedTurno!, fechaActual);
  } else {
    data = await dbHelper.getOperacionDumperByTurnoAndFecha(
        selectedTurno!, fechaActual);
  }

  print("Operaciones encontradas: $data");

  setState(() {
    operaciones = data;

    if (data.isNotEmpty) {
      operacionActual = data.first;
      operacionId = data.first['id'];
      print("ID de operación guardado: $operacionId");
    } else {
      operacionActual = null;
      operacionId = null;
      operacionesTabla = []; // Limpiar tabla si no hay operación
    }
  });

  // Cargar estados después de actualizar la UI
  await _cargarEstadosOperacion();
}

Future<void> _cargarEstadosOperacion() async {
  if (operacionId == null) {
    setState(() {
      operacionesTabla = [];
    });
    return;
  }

  List<Map<String, dynamic>> estados =
      await DatabaseHelper().getEstadosByOperacionIdDumper(operacionId!);

  print("Estados obtenidos del registro: $estados");

  // Ordenar los estados por hora de inicio para mostrarlos correctamente
  estados.sort((a, b) {
    // Función para convertir a minutos
    int horaToMinutes(String hora) {
      if (hora.isEmpty) return 0;
      try {
        if (hora.contains(' ')) {
          hora = hora.split(' ')[1];
        }
        List<String> parts = hora.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } catch (e) {
        return 0;
      }
    }
    
    int minutosA = horaToMinutes(a['hora_inicio']);
    int minutosB = horaToMinutes(b['hora_inicio']);
    return minutosA.compareTo(minutosB);
  });

  setState(() {
    operacionesTabla = estados.map((e) {
      return {
        'id': e['id'],
        'estado': e['estado'],
        'codigo': e['codigo'],
        'horaInicio': e['hora_inicio'],
        'horaFin': e['hora_final'],
        'numero': e['numero'],
      };
    }).toList();
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Card de nueva operación - tamaño fijo
            OperacionCard(
  fechaActual: fechaActual,
  selectedTurno: selectedTurno,
  dniUsuario: widget.dniUsuario,
  operacionExistente: operacionActual,
  onTurnoChanged: (value) {
    setState(() {
      selectedTurno = value;
    });
  },
  onFechaChanged: (value) {
    setState(() {
      fechaActual = value;
    });
  },
  onOperacionCreada: _handleNuevaOperacion,
  primaryColor: primaryColor,
),
            
            const SizedBox(height: 16),
            
            // Botones de estado - tamaño fijo
            BotonesEstado(
              onEstadoSeleccionado: _mostrarDialogoEstado,
            ),
            
            const SizedBox(height: 8),
            
            // Tabla de operaciones con altura limitada
            Expanded(
  flex: 1,
  child: Container(
    constraints: const BoxConstraints(
      maxHeight: 300,
    ),
    child: TablaOperaciones(
      operaciones: operacionesTabla,
      onVerDetalle: _verDetalleOperacion,
      onEditar: _editarOperacion,
      onEliminar: _eliminarRegistroEstado, // Nueva función
      primaryColor: primaryColor,
    ),
  ),
),
            
            const SizedBox(height: 8),
            
            // Botones inferiores (CheckList, Horómetro, Cerrar registros)
            // Botones inferiores (CheckList, Horómetro, Cerrar registros, Condiciones equipo, Presión llantas)
BotonesAccionesInferiores(
  onChecklistPressed: _handleChecklist,
  onChecklistTelemandoPressed: _handleChecklistTelemando,
  onCheckprogramaTrabajoPressed: _handleProgramaTrabajo,
  onHorometroPressed: _handleHorometro,
  onCerrarRegistrosPressed: _handleCerrarRegistros,
  onCondicionesEquipoPressed: _handleCondicionesEquipo,
  onPresionLlantasPressed: _handlePresionLlantas,
  primaryColor: primaryColor,
),
            
             //SEPARACION DE FINAL PARA TABLET
            const SizedBox(height: 50),
            // SEPARACION DE FINAL ANTES
            //const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
  return AppBar(
    elevation: 2,
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.horizontal_rule, size: 16),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'DUMPER',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        onPressed: _refrescarDatos,
        tooltip: 'Refrescar',
      ),
      IconButton(
        icon: const Icon(Icons.delete, size: 20),
        onPressed: _eliminarRegistro, // <- tu función de eliminar
        tooltip: 'Eliminar',
      ),
    ],
  );
}
void _eliminarRegistro() {
  if (operacionId == null) {
    // No hay registro actual
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.75,
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  'Atención',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // Body
              const Text(
                'No hay registro seleccionado para eliminar.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  // Hay registro, mostramos confirmación
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.75,
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'Confirmar eliminación',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Body
            const Text(
              '¿Deseas eliminar este registro?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // cerramos el diálogo primero

                    int filasAfectadas =
                        await DatabaseHelper().eliminarOperacionTalDumperFisico(operacionId!);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          filasAfectadas > 0
                              ? 'Registro eliminado correctamente.'
                              : 'No se pudo eliminar el registro.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );

                    _refrescarDatos();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
void _mostrarDialogoEstado(String estado) async {
  // Verificar que haya una operación seleccionada
  if (operacionActual == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay una operación seleccionada'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Obtener TODOS los estados para calcular la última hora
  List<Map<String, dynamic>> todosLosEstados = await DatabaseHelper()
      .getEstadosByOperacionIdDumper(operacionActual!['id']);
  
  // Ordenar por hora para encontrar el último
  todosLosEstados.sort((a, b) {
    int horaToMinutes(String hora) {
      if (hora.isEmpty) return 0;
      try {
        if (hora.contains(' ')) hora = hora.split(' ')[1];
        List<String> parts = hora.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } catch (e) {
        return 0;
      }
    }
    
    int minutosA = horaToMinutes(a['hora_inicio'] ?? '');
    int minutosB = horaToMinutes(b['hora_inicio'] ?? '');
    return minutosA.compareTo(minutosB);
  });

  // Obtener la última hora registrada (si existe)
  String? ultimaHora;
  if (todosLosEstados.isNotEmpty) {
    var ultimoEstado = todosLosEstados.last;
    ultimaHora = ultimoEstado['hora_inicio'];
    
    // Formatear para mostrar solo la hora si viene con fecha
    if (ultimaHora?.contains(' ') == true) {
      ultimaHora = ultimaHora!.split(' ')[1];
    }
  }

  // Obtener los códigos operativos para este estado
  List<Map<String, String>> codigosOperativos = [];
  
  if (operaciones.isNotEmpty) {
    codigosOperativos = operacionesTabla.where((op) => op['estado'] == estado)
        .map((op) => {
          'id': op['id'].toString(),
          'numero': op['numero']?.toString() ?? '0',
          'codigo': op['codigo']?.toString() ?? '',
          'hora_inicio': op['horaInicio']?.toString() ?? '',
          'hora_final': op['horaFin']?.toString() ?? '',
          'estado': op['estado']?.toString() ?? '',
        })
        .toList();
  }

  // Mostrar el diálogo de registro con la última hora
  final result = await showRegistroOperacionDialog(
    context: context,
    codigoOperativos: codigosOperativos,
    turno: operacionActual!['turno'] ?? selectedTurno ?? 'DÍA',
    selectedState: estado,
    datadialog: datadialog,
    ultimaHoraRegistrada: ultimaHora, // Nueva variable
    existingRecord: null,
  );

  if (result != null) {
    await _crearRegistroEstado(result, estado);
  }
}

void _verDetalleOperacion(Map<String, dynamic> operacion) async {
  // Verificar que haya una operación seleccionada
  if (operacionActual == null) {
    return;
  }

  // Obtener los códigos operativos para este estado
  List<Map<String, String>> codigosOperativos = operaciones
      .where((op) => op['estado'] == operacion['estado'])
      .map((op) => {
        'id': op['id'].toString(),
        'numero': op['numero']?.toString() ?? '0',
        'codigo': op['codigo']?.toString() ?? '',
        'hora_inicio': op['hora_inicio']?.toString() ?? '',
        'hora_final': op['hora_final']?.toString() ?? '',
        'estado': op['estado']?.toString() ?? '',
      })
      .toList();

  // Mostrar el diálogo de edición
  final result = await showRegistroOperacionDialog(
    context: context,
    codigoOperativos: codigosOperativos,
    turno: operacionActual!['turno'] ?? selectedTurno ?? 'DÍA',
    selectedState: operacion['estado'] ?? 'OPERATIVO',
    datadialog: datadialog,
    existingRecord: {
      'id': operacion['id'].toString(),
      'numero': operacion['numero']?.toString() ?? '0',
      'codigo': operacion['codigo']?.toString() ?? '',
      'hora_inicio': operacion['hora_inicio']?.toString() ?? '',
      'hora_final': operacion['hora_final']?.toString() ?? '',
    },
  );

  if (result != null) {
    // Actualizar registro existente
    await _actualizarRegistroEstado(result, operacion);
  }
}

Future<void> _crearRegistroEstado(Map<String, dynamic> data, String estado) async {
  try {
    if (operacionActual == null) return;

    // Obtener TODOS los registros (estados) de la operación actual
    List<Map<String, dynamic>> todosLosEstados = await DatabaseHelper()
        .getEstadosByOperacionIdDumper(operacionActual!['id']);
    
    // Función auxiliar para convertir hora a DateTime completo
    DateTime? parseHoraCompleta(String horaStr) {
      try {
        if (horaStr.contains(' ')) {
          return DateTime.parse(horaStr);
        } else {
          String fechaHora = '${fechaActual} ${horaStr}';
          return DateTime.parse(fechaHora);
        }
      } catch (e) {
        print('Error parseando hora: $horaStr');
        return null;
      }
    }

    // Ordenar por hora de inicio
    todosLosEstados.sort((a, b) {
      DateTime? horaA = parseHoraCompleta(a['hora_inicio']);
      DateTime? horaB = parseHoraCompleta(b['hora_inicio']);
      
      if (horaA == null) return 1;
      if (horaB == null) return -1;
      return horaA.compareTo(horaB);
    });

    // Encontrar el último estado activo (sin hora_final)
    Map<String, dynamic>? ultimoEstadoActivo;
    for (var i = todosLosEstados.length - 1; i >= 0; i--) {
      if (todosLosEstados[i]['hora_final'] == null || 
          todosLosEstados[i]['hora_final'] == '') {
        ultimoEstadoActivo = todosLosEstados[i];
        break;
      }
    }

    // Si hay un estado activo, lo cerramos
    if (ultimoEstadoActivo != null) {
      await DatabaseHelper().updateHoraFinalDumper(
        operacionActual!['id'],
        ultimoEstadoActivo['id'],
        data['hora_inicio']!,
      );
    }

    // Calcular el nuevo número para ESTE tipo específico
    List<Map<String, dynamic>> estadosDelMismoTipo = todosLosEstados
        .where((est) => est['estado'] == estado)
        .toList();
    
    int newNumber = estadosDelMismoTipo.isNotEmpty 
        ? (estadosDelMismoTipo.last['numero'] as int) + 1 
        : 1;
    
    // IMPORTANTE: Crear el objeto operacion con TODOS los campos de perforación
    Map<String, dynamic> operacionData = {
      'nivel': data['nivel'] ?? '',
      'tipo_labor': data['tipo_labor'] ?? '',
      'labor': data['labor'] ?? '',
      'ala': data['ala'] ?? '',
      'tal_prod': data['tal_prod'] ?? '',
      'tal_rimados': data['tal_rimados'] ?? '',
      'tal_alivio': data['tal_alivio'] ?? '',
      'tal_repaso': data['tal_repaso'] ?? '',
      'long_barras': data['long_barras'] ?? '',
      'num_barras': data['num_barras'] ?? '',
      'tipo_perforacion': data['tipo_perforacion'] ?? '',
    };
    
    // Crear nuevo estado con todos los campos de perforación
    Map<String, dynamic>? nuevoEstado = await DatabaseHelper().createEstadoDumper(
      operacionActual!['id'],
      estado,
      data['codigo']!,
      data['hora_inicio']!,
      operacion: operacionData, // Pasamos el objeto completo
    );
    
    if (nuevoEstado != null) {
      _mostrarSnackBar("Registro guardado correctamente.", Colors.green);
      
      // Recargar datos
      await _fetchOperacionData();
      
      // Mostrar diálogo secundario según el estado
      _mostrarDialogoSecundario(nuevoEstado['id'], estado);
    }
  } catch (e) {
    _mostrarSnackBar("Error al crear registro: $e", Colors.red);
  }
}

// También actualizar _actualizarRegistroEstado
Future<void> _actualizarRegistroEstado(Map<String, dynamic> data, Map<String, dynamic> operacionOriginal) async {
  try {
    if (operacionActual == null) return;

    // Función auxiliar para convertir hora a DateTime completo
    DateTime? parseHoraCompleta(String horaStr) {
      try {
        if (horaStr.contains(' ')) {
          return DateTime.parse(horaStr);
        } else {
          String fechaHora = '${fechaActual} ${horaStr}';
          return DateTime.parse(fechaHora);
        }
      } catch (e) {
        print('Error parseando hora: $horaStr');
        return null;
      }
    }

    // Obtener TODOS los registros
    List<Map<String, dynamic>> todosLosEstados = await DatabaseHelper()
        .getEstadosByOperacionIdDumper(operacionActual!['id']);

    // Ordenar por hora de inicio
    todosLosEstados.sort((a, b) {
      DateTime? horaA = parseHoraCompleta(a['hora_inicio']);
      DateTime? horaB = parseHoraCompleta(b['hora_inicio']);
      
      if (horaA == null) return 1;
      if (horaB == null) return -1;
      
      return horaA.compareTo(horaB);
    });

    // Actualizar el registro principal
    bool actualizado = await DatabaseHelper().updateEstadoDumper(
      operacionActual!['id'],
      data['id'],
      numero: data['numero'],
      estado: data['estado'],
      codigo: data['codigo'],
      horaInicio: data['hora_inicio'],
      horaFinal: data['hora_final'] ?? '',
      operacion: {
        'nivel': data['nivel'] ?? '',
        'labor': data['labor'] ?? '',
      },
    );

    if (actualizado) {
      // Re-obtener todos los estados después de la actualización
      todosLosEstados = await DatabaseHelper()
          .getEstadosByOperacionIdDumper(operacionActual!['id']);
      
      // Ordenar nuevamente por hora de inicio
      todosLosEstados.sort((a, b) {
        DateTime? horaA = parseHoraCompleta(a['hora_inicio']);
        DateTime? horaB = parseHoraCompleta(b['hora_inicio']);
        
        if (horaA == null) return 1;
        if (horaB == null) return -1;
        
        return horaA.compareTo(horaB);
      });
      
      // Reconstruir la secuencia de horas
      for (int i = 0; i < todosLosEstados.length; i++) {
        var estadoActual = todosLosEstados[i];
        
        if (i < todosLosEstados.length - 1) {
          var siguienteEstado = todosLosEstados[i + 1];
          
          if (estadoActual['hora_final'] != siguienteEstado['hora_inicio']) {
            await DatabaseHelper().updateHoraFinalDumper(
              operacionActual!['id'],
              estadoActual['id'],
              siguienteEstado['hora_inicio'],
            );
          }
        } else {
          if (estadoActual['hora_final'] != "") {
            await DatabaseHelper().updateHoraFinalDumper(
              operacionActual!['id'],
              estadoActual['id'],
              "",
            );
          }
        }
      }
      
      _mostrarSnackBar("Registro actualizado correctamente.", Colors.green);
      await _fetchOperacionData();
    }
  } catch (e) {
    _mostrarSnackBar("Error al actualizar: $e", Colors.red);
  }
}

// Función auxiliar para obtener la lista de operaciones (estados)
Future<List<Map<String, dynamic>>> _getOperaciones() async {
  if (operacionActual == null) return [];
  return await DatabaseHelper().getEstadosByOperacionIdDumper(operacionActual!['id']);
}


void _mostrarDialogoSecundario(int estadoId, String estado) async {
  if (operacionActual == null) return;

  Future.delayed(Duration.zero, () {
    if (estado == "OPERATIVO") {
      _abrirDialogoOperativoDumper(estadoId);
    } else {
      _abrirDialogoNoOperativoDumper(estadoId, estado);
    }
  });
}

Future<void> _abrirDialogoOperativoDumper(int estadoId) async {
  Map<String, dynamic> datos = await DatabaseHelper()
      .getOperacionByEstadoIdDumper(operacionActual!['id'], estadoId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoFormularioPerforacion(
        operacionId: operacionActual!['id'],
        estadoId: estadoId,
        datosIniciales: datos,
        estado: "OPERATIVO",
        primaryColor: primaryColor,
        onGuardar: (datosActualizados) async {
          bool guardado = await DatabaseHelper()
              .updateOperacionByEstadoIdDumper(
            operacionActual!['id'],
            estadoId,
            datosActualizados,
          );

          if (guardado) {
            _mostrarSnackBar("Datos guardados", Colors.green);
            await _fetchOperacionData();
          } else {
            _mostrarSnackBar("Error al guardar", Colors.red);
          }
        },
      );
    },
  );
}


void _abrirDialogoNoOperativoDumper(int estadoId, String estado) async {
  Map<String, dynamic> datos = await DatabaseHelper()
      .getOperacionByEstadoIdDumper(operacionActual!['id'], estadoId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoFormularioNoOpeDumper(
        operacionId: operacionActual!['id'],
        estadoId: estadoId,
        estado: estado,
        datosIniciales: datos,
        primaryColor: primaryColor,
        onGuardar: (datosActualizados) async {
          bool guardado = await DatabaseHelper()
              .updateOperacionByEstadoIdDumper(
            operacionActual!['id'],
            estadoId,
            datosActualizados,
          );

          if (guardado) {
            _mostrarSnackBar("Datos de $estado guardados", Colors.green);
            await _fetchOperacionData();
          } else {
            _mostrarSnackBar("Error al guardar", Colors.red);
          }
        },
      );
    },
  );
}

void _mostrarSnackBar(String mensaje, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}



Future<void> _handleNuevaOperacion(Map<String, dynamic> data) async {

  DatabaseHelper dbHelper = DatabaseHelper();

   print('📦 Datos recibidos en _handleNuevaOperacion:');
  print('   capacidad: ${data['capacidad']} (${data['capacidad'].runtimeType})');
  print('   tipo_equipo: ${data['tipo_equipo']}');

  // 🔥 1. OBTENER HORÓMETRO DE DUMPER
  List<Map<String, dynamic>> horometros =
      await dbHelper.getHorometrosPorOperacion('dumper');

  print("✅ Horómetro dumper:");
  for (var h in horometros) {
    print("Tipo: ${h['tipo_horometro']} - Final: ${h['final']}");
  }

  /// Checklist normal (CARGUÍO)
  List<Map<String, dynamic>> checklistItems =
      await DatabaseHelper().getCheckListByProceso('DUMPER');

  List<Map<String, dynamic>> checkListJson = checklistItems.map((item) {
    return {
      'descripcion': item['nombre'],
      'decision': 0,
      'observacion': '',
      'categoria': item['categoria'],
    };
  }).toList();

  /// ✅ Checklist telemando
  List<Map<String, dynamic>> checklistTelemandoItems =
      await DatabaseHelper().getChecklistTelemando();

  List<Map<String, dynamic>> checkListTelemandoJson =
      checklistTelemandoItems.map((item) {
    return {
      'descripcion': item['nombre'],
      'decision': 0,
      'observacion': '',
    };
  }).toList();

  /// Insertar operación
  await dbHelper.insertOperacionDumper(
    data['fecha'],
    data['turno'],
    data['seccion'],
    data['operador'],
    data['jefe_guardia'],
    data['equipo'],
    data['n_equipo'],
    data['capacidad'], 
    data['tipo_equipo'],

    checkListJson: checkListJson,
    checkListTelemandoJson: checkListTelemandoJson, // ✅ nuevo
    horometrosBase: horometros,
  );

  /// Refrescar UI
  await _fetchOperacionData();
}

void _editarOperacion(Map<String, dynamic> operacion) async {
  if (operacionActual == null) return;

  String estado = operacion['estado'] ?? 'OPERATIVO';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    if (Navigator.canPop(context)) Navigator.pop(context);

    if (estado == "OPERATIVO") {
      await _editarOperacionOperativoDumper(operacion);
    } else {
      await _editarOperacionNoOperativoDumper(operacion, estado);
    }
  } catch (e) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    _mostrarSnackBar("Error al cargar datos: $e", Colors.red);
  }
}
Future<void> _editarOperacionOperativoDumper(
    Map<String, dynamic> operacion) async {

  Map<String, dynamic> datos = await DatabaseHelper()
      .getOperacionByEstadoIdDumper(
          operacionActual!['id'], operacion['id']);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoFormularioPerforacion(
        operacionId: operacionActual!['id'],
        estadoId: operacion['id'],
        datosIniciales: datos,
        estado: "OPERATIVO",
        primaryColor: primaryColor,
        onGuardar: (datosActualizados) async {
          bool guardado = await DatabaseHelper()
              .updateOperacionByEstadoIdDumper(
            operacionActual!['id'],
            operacion['id'],
            datosActualizados,
          );

          if (guardado) {
            _mostrarSnackBar("Datos actualizados", Colors.green);
            await _fetchOperacionData();
          } else {
            _mostrarSnackBar("Error al actualizar", Colors.red);
          }
        },
      );
    },
  );
}
Future<void> _editarOperacionNoOperativoDumper(
    Map<String, dynamic> operacion, String estado) async {

  Map<String, dynamic> datos = await DatabaseHelper()
      .getOperacionByEstadoIdDumper(
          operacionActual!['id'], operacion['id']);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoFormularioNoOpeDumper(
        operacionId: operacionActual!['id'],
        estadoId: operacion['id'],
        estado: estado,
        datosIniciales: datos,
        primaryColor: primaryColor,
        onGuardar: (datosActualizados) async {
          bool guardado = await DatabaseHelper()
              .updateOperacionByEstadoIdDumper(
            operacionActual!['id'],
            operacion['id'],
            datosActualizados,
          );

          if (guardado) {
            _mostrarSnackBar("Datos de $estado actualizados", Colors.green);
            await _fetchOperacionData();
          } else {
            _mostrarSnackBar("Error al actualizar", Colors.red);
          }
        },
      );
    },
  );
}

void _refrescarDatos() async {
  // Mostrar indicador de carga
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    },
  );

  await _fetchOperacionData();
  await _cargarEstadosOperacion();

  // Cerrar indicador de carga
  Navigator.pop(context);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Datos actualizados'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Manejadores para los nuevos botones
void _handleChecklist() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Usar el ID real de la operación (igual que en _handleCondicionesEquipo)
  var operacionActual = operaciones.first;
  int operacionId = operacionActual['id']; // asumimos que tienes este campo
  String estado = operacionActual['estado'] ?? 'OPERATIVO';

  // Cargar el checklist existente
  List<Map<String, dynamic>> checklistData = await DatabaseHelper()
      .getCheckListByOperacionIdDumper(operacionId);

  showDialog(
    context: context,
    builder: (Buildertontext) {
      return DialogoChecklist(
        operacionId: operacionId,
        estado: estado,
        checklistData: checklistData, // ✅ pasamos los datos cargados
        primaryColor: primaryColor,
      );
    },
  );
}

void _handleChecklistTelemando() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Obtener operación actual
  var operacionActual = operaciones.first;
  int operacionId = operacionActual['id'];
  String estado = operacionActual['estado'] ?? 'OPERATIVO';

  // Cargar checklist telemando
  List<Map<String, dynamic>> checklistTelemandoData =
      await DatabaseHelper()
          .getCheckListTelemandoByOperacionIdDumper(operacionId);

  // Abrir diálogo
  showDialog(
    context: context,
    builder: (context) {
      return DialogoChecklistTelemando(
        operacionId: operacionId,
        estado: estado,
        checklistData: checklistTelemandoData,
        primaryColor: primaryColor,
      );
    },
  );
}

void _handleHorometro() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Usar el ID real de la operación, no el código
  int operacionId = operacionActual!['id'];
  String estado = operacionActual!['estado'] ?? 'OPERATIVO';

  // Cargar los horómetros existentes
  Map<String, dynamic> horometrosData = await DatabaseHelper()
      .getHorometrosByOperacionIdDumper(operacionId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoHorometro(
        operacionId: operacionId,
        estado: estado,
        horometrosData: horometrosData, // Pasar los datos cargados
        primaryColor: primaryColor,
      );
    },
  );
}

void _handleProgramaTrabajo() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  /// ID real de la operación
  int operacionId = operacionActual!['id'];
  String estado = operacionActual!['estado'] ?? 'OPERATIVO';

  /// Cargar programa de trabajo existente
  Map<String, dynamic> programaTrabajoData = await DatabaseHelper()
      .getProgramaTrabajoByOperacionIdDumper(operacionId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoProgramaTrabajo(
        operacionId: operacionId,
        estado: estado,
        programaTrabajoData: programaTrabajoData,
        primaryColor: primaryColor,
      );
    },
  );
}


void _handleCerrarRegistros() {
  if (operacionActual == null) {
    _mostrarSnackBar('No hay operación seleccionada', Colors.orange);
    return;
  }

  final parentContext = context; // ✅ guardar context de la pantalla

  showDialog(
    context: parentContext,
    builder: (BuildContext dialogContext) {
      return DialogoConfirmarCierreRegistros(
        primaryColor: primaryColor,
        onConfirmar: () async {
          // cerrar dialog
          Navigator.pop(dialogContext);

          // mostrar loader usando context correcto
          showDialog(
            context: parentContext,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            var ultimoEstado = await DatabaseHelper()
                .getUltimoEstadoByOperacionIdDumper(operacionActual!['id']);

            if (ultimoEstado == null) {
              // ✅ Verificar mounted antes de cerrar loader
              if (mounted) Navigator.pop(parentContext);
              _mostrarSnackBar(
                'No se puede cerrar: No hay estados registrados',
                Colors.red,
              );
              return;
            }

            String horaReservaInicio =
                (selectedTurno == 'DÍA') ? '17:30' : '05:30';

            bool actualizado = await DatabaseHelper().updateHoraFinalDumper(
              operacionActual!['id'],
              ultimoEstado['id'],
              horaReservaInicio,
            );

            if (!actualizado) {
              throw Exception('No se pudo actualizar la hora final');
            }

            List<Map<String, dynamic>> todosLosEstados =
                await DatabaseHelper()
                    .getEstadosByOperacionIdDumper(operacionActual!['id']);

            int newNumber = todosLosEstados.isNotEmpty
                ? (todosLosEstados.last['numero'] as int) + 1
                : 1;

            String horaReservaFinal =
                (selectedTurno == 'DÍA') ? '19:00' : '07:00';

            await DatabaseHelper().createReservaEstadoDumper(
              operacionActual!['id'],
              newNumber,
              horaReservaInicio,
              horaReservaFinal,
            );

            await DatabaseHelper().cerrarOperacionDumper(operacionActual!['id']);

            // ✅ Verificar mounted antes de cerrar loader
            if (mounted) Navigator.pop(parentContext);

            // ✅ Verificar mounted antes de mostrar SnackBar
            if (mounted) {
              _mostrarSnackBar(
                'Registro cerrado exitosamente. Se agregó estado RESERVA',
                Colors.green,
              );
            }

            // ✅ Verificar mounted antes de recargar datos
            if (mounted) {
              await _fetchOperacionData();
            }

          } catch (e) {
            // ✅ Verificar mounted antes de cerrar loader
            if (mounted) Navigator.pop(parentContext);

            // ✅ Verificar mounted antes de mostrar error
            if (mounted) {
              _mostrarSnackBar('Error al cerrar registro: $e', Colors.red);
            }
          }
        },
      );
    },
  );
}

  
void _handleCondicionesEquipo() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Usar el ID real de la operación
  var operacionActual = operaciones.first;
  int operacionId = operacionActual['id']; // asumimos que tienes este campo
  String estado = operacionActual['estado'] ?? 'OPERATIVO';

  // Cargar las condiciones de equipo existentes
  Map<String, dynamic> condicionesData = await DatabaseHelper()
      .getCondicionesEquipoByOperacionIdDumper(operacionId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoCondicionesEquipo(
        operacionId: operacionId,
        estado: estado,
        condicionesData: condicionesData, // ✅ pasamos los datos
        primaryColor: primaryColor,
      );
    },
  );
}

void _handlePresionLlantas() async {
  if (operaciones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No hay operación seleccionada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Usar el ID real de la operación
  var operacionActual = operaciones.first;
  int operacionId = operacionActual['id'];
  String estado = operacionActual['estado'] ?? 'OPERATIVO';

  // 🔹 Cargar control de llantas desde la BD
  Map<String, dynamic> controlLlantas = await DatabaseHelper()
      .getControlLlantasByOperacionIdDumper(operacionId);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return DialogoCheckImagen(
        operacionId: operacionId,
        estado: estado,
        controlLlantasData: controlLlantas, // ✅ enviamos el JSON
        primaryColor: primaryColor,
      );
    },
  );
}

Future<void> _eliminarRegistroEstado(Map<String, dynamic> estado) async {
  try {
    if (operacionActual == null) return;

    // Primero, obtener todos los estados para contar los que se eliminarán
    List<Map<String, dynamic>> todosLosEstados = await DatabaseHelper()
        .getEstadosByOperacionIdDumper(operacionActual!['id']);
    
    // Función para convertir hora a minutos con manejo de nulos
    int horaToMinutes(String? hora) {
      if (hora == null || hora.isEmpty) return 0;
      try {
        if (hora.contains(' ')) {
          hora = hora.split(' ')[1];
        }
        List<String> parts = hora.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } catch (e) {
        return 0;
      }
    }
    
    // Obtener hora del estado a eliminar con manejo de nulos
    String? horaEliminar = estado['hora_inicio']?.toString();
    int horaEliminarMinutos = horaToMinutes(horaEliminar);
    
    // Contar cuántos estados se eliminarán
    int estadosAEliminar = 0;
    List<Map<String, dynamic>> estadosPosteriores = [];
    
    for (var e in todosLosEstados) {
      String? horaEstado = e['hora_inicio']?.toString();
      int horaEstadoMinutos = horaToMinutes(horaEstado);
      
      if (horaEstadoMinutos >= horaEliminarMinutos) {
        estadosAEliminar++;
        if (e['id'] != estado['id']) {
          estadosPosteriores.add(e);
        }
      }
    }

    // Construir mensaje de confirmación
    String mensajeConfirmacion = '¿Eliminar ${estado['estado']} #${estado['numero']}';
    if (estadosPosteriores.isNotEmpty) {
      mensajeConfirmacion += '\n\ny TODOS los estados posteriores (${estadosPosteriores.length}):\n';
      for (var e in estadosPosteriores.take(3)) { // Mostrar max 3
        mensajeConfirmacion += '• ${e['estado']} #${e['numero']} (${e['hora_inicio']})\n';
      }
      if (estadosPosteriores.length > 3) {
        mensajeConfirmacion += '• ... y ${estadosPosteriores.length - 3} más\n';
      }
    }
    mensajeConfirmacion += '\nTotal: $estadosAEliminar registro(s)';

    // Confirmar eliminación
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Confirmar eliminación en cascada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción eliminará:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                
                const SizedBox(height: 16),
                const Text(
                  'Esta acción no se puede deshacer.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar todo'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Eliminar el estado y todos los posteriores
    bool eliminado = await DatabaseHelper().deleteEstadoDumper(
      operacionActual!['id'],
      estado['id'],
    );

    // Cerrar indicador de carga
    if (mounted) Navigator.pop(context);

    if (eliminado) {
      _mostrarSnackBar(
        "✅ Eliminados $estadosAEliminar registro(s) en cascada.", 
        Colors.green
      );
      
      // Recargar datos
      await _fetchOperacionData();
      
      if (mounted) {
        setState(() {});
      }
    } else {
      _mostrarSnackBar("❌ Error al eliminar los registros.", Colors.red);
    }
  } catch (e) {
    print('Error detallado: $e');
    _mostrarSnackBar("Error al eliminar: $e", Colors.red);
  }
}

}