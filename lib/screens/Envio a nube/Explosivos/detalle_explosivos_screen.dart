import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/services/envio%20nube/explosivos/ExploracionService_service.dart';

class DetalleExplosivos extends StatefulWidget {
  final String tipoOperacion;

  DetalleExplosivos({required this.tipoOperacion});

  @override
  _DetalleSeccionScreenState createState() => _DetalleSeccionScreenState();
}

class _DetalleSeccionScreenState extends State<DetalleExplosivos> {
  List<Map<String, dynamic>> exploracionesData = [];
  Set<int> selectedItems = {};
  Timer? selectionTimer;
  bool isLoading = true;
  String mensajeUsuario = "Cargando registros...";
  String? selectedTurno;
  String? selectedFecha;
  String? selectedTaladro;
  String? selectedZona;
  String? selectedLabor;
  String? selectedEstado;
  int? exploracionId;
  String? tipo_perforacion;

  @override
  void initState() {
    super.initState();
    _fetchExploracionesData();
  }

  @override
  void dispose() {
    selectionTimer?.cancel();
    super.dispose();
  }

Future<void> _fetchExploracionesData() async {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> data = await dbHelper.getExploraciones();

  print('Datos de exploraciones recibidos: $data');

  setState(() {
    exploracionesData = data; // Siempre actualiza la lista, incluso si está vacía
    isLoading = false;

    // Si hay datos, establece los valores por defecto
    if (data.isNotEmpty) {
      selectedFecha = data[0]['fecha'];
      selectedTurno = data[0]['turno'];
      selectedTaladro = data[0]['taladro'];
      selectedZona = data[0]['zona'];
      selectedLabor = data[0]['labor'];
      selectedEstado = data[0]['estado'];
      exploracionId = data[0]['id'];
      tipo_perforacion = data[0]['tipo_perforacion'];
    } else {
      // Si no hay datos, limpia los filtros/selecciones
      selectedFecha = null;
      selectedTurno = null;
      selectedTaladro = null;
      selectedZona = null;
      selectedLabor = null;
      selectedEstado = null;
      exploracionId = null;
      tipo_perforacion = null;
      mensajeUsuario = "No se encontraron registros de exploraciones.";
    }
  });
}

  void _handleItemTap(int index) {
    final item = exploracionesData[index];
    final itemId = item['id'];
    final yaEnviado = item['envio'] == 1;

    // Si ya fue enviado, no permitir selección
    if (yaEnviado) {
      return; // Salir sin hacer nada
    }

    // Cancelar temporizador anterior si existe
    selectionTimer?.cancel();

    if (selectedItems.contains(itemId)) {
      // Si ya está seleccionado, deseleccionar inmediatamente
      setState(() {
        selectedItems.remove(itemId);
      });
    } else if (selectedItems.isNotEmpty) {
      // Si ya hay seleccionados, seleccionar inmediatamente
      setState(() {
        selectedItems.add(itemId);
      });
    } else {
      // Si no hay seleccionados, iniciar temporizador de 1 segundo
      selectionTimer = Timer(const Duration(seconds: 1), () {
        setState(() {
          selectedItems.add(itemId);
        });
      });
    }
  }

  Future<void> _exportSelectedItems() async {
    if (selectedItems.isEmpty) return;

    DatabaseHelper dbHelper = DatabaseHelper();
    List<Map<String, dynamic>> jsonData = [];

    for (var id in selectedItems) {
      List<Map<String, dynamic>> estructuraCompleta = await dbHelper
          .obtenerEstructuraCompleta(id);

      // Como `obtenerEstructuraCompleta` devuelve una lista, pero solo hay un dato por ID, tomamos el primer elemento.
      if (estructuraCompleta.isNotEmpty) {
        jsonData.add(estructuraCompleta.first);
      }
    }

    // Mostrar diálogo de confirmación antes de enviar
    await _showConfirmationDialog(jsonData);
  }
  
Future<void> _showConfirmationDialog(
  List<Map<String, dynamic>> jsonData,
) async {
  String prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);

  bool? confirmado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmar envío'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro que deseas enviar los siguientes datos a la nube?'),
              const SizedBox(height: 16),
              Text(
                'Operaciones a enviar: ${jsonData.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text('Enviar'),
          ),
        ],
      );
    },
  );

  if (confirmado == true) {
    await _enviarDatosALaNube(jsonData);
  }
}

  void _confirmarEliminacion() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Estás seguro de eliminar los ${selectedItems.length} registros seleccionados?'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              _eliminarRegistrosSeleccionados();
            },
          ),
        ],
      );
    },
  );
}

Future<void> _eliminarRegistrosSeleccionados() async {
  if (selectedItems.isEmpty) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    DatabaseHelper dbHelper = DatabaseHelper();
    int totalEliminados = 0;

    for (var id in selectedItems) {
      // Esto activará el DELETE CASCADE en todas las tablas relacionadas
      int result = await dbHelper.deleteDatosTrabajo(id);
      if (result > 0) totalEliminados++;
    }

    Navigator.of(context).pop(); // Cierra el loading

    // Actualiza la lista después de eliminar
    await _fetchExploracionesData();

    setState(() {
      selectedItems.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$totalEliminados registros eliminados correctamente'),
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    Navigator.of(context).pop(); // Cierra el loading si hay error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al eliminar: ${e.toString()}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _enviarDatosALaNube(List<Map<String, dynamic>> jsonData) async {
    final operacionService = ExploracionService();
    bool allSuccess = true;

    // Mostrar indicador de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var operacion in jsonData) {
        bool success = await operacionService.crearExploracionCompleta(
          operacion,
        );

        if (success) {
          // Si la operación fue exitosa, actualizar el estado de envío en la base de datos
          int operacionId = operacion['id'];
          await _actualizarEnvio(operacionId); // Actualizar el campo 'envio'
        } else {
          allSuccess = false;
          print('Error al enviar operación: ${operacion['id']}');
        }
      }
    } catch (e) {
      allSuccess = false;
      print('Error durante el envío: $e');
    }

    // Cerrar el diálogo de progreso
    Navigator.of(context).pop();

    // Mostrar resultado al usuario
    _showResultDialog(allSuccess);
  }

  Future<int> _actualizarEnvio(int operacionId) async {
    DatabaseHelper dbHelper = DatabaseHelper();

    // Llamada a la función que actualizará el estado de 'envio' en la base de datos
    return await dbHelper.actualizarEnvioDatos_trabajo_exploraciones(
      operacionId, 1
    );
  }

  Future<void> _showResultDialog(bool success) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(success ? 'Éxito' : 'Error'),
            content: Text(
              success
                  ? 'Los datos se enviaron correctamente a la nube. La pantalla se actualizará.'
                  : 'Ocurrió un error al enviar algunos datos. Por favor revisa los logs.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Cierra el diálogo de resultado

                  if (success) {
                    // Muestra loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (context) =>
                              const Center(child: CircularProgressIndicator()),
                    );

                    // Limpiar selecciones + recargar datos
                    await _fetchExploracionesData(); // Espera a que se completen los datos

                    Navigator.of(context).pop(); // Cierra el loading

                    setState(() {
                      selectedItems
                          .clear(); // Limpia selecciones y actualiza UI en un solo setState
                    });
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
  }

  // ... (mantén los demás métodos existentes sin cambios)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de ${widget.tipoOperacion}"),
        backgroundColor: Color(0xFF21899C),
        actions: [
          if (selectedItems.isNotEmpty)
          IconButton(
        icon: Icon(Icons.delete),
        onPressed: _confirmarEliminacion,
        tooltip: "Eliminar seleccionados",
      ),
            IconButton(
              icon: Icon(Icons.file_download),
              onPressed: _exportSelectedItems,
              tooltip: "Exportar seleccionados",
            ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(mensajeUsuario, style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
              : exploracionesData.isEmpty
              ? Center(
                child: Text(mensajeUsuario, style: TextStyle(fontSize: 16)),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Operaciones encontradas:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (selectedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "${selectedItems.length} elemento(s) seleccionado(s)",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exploracionesData.length,
                      itemBuilder: (context, index) {
                        var item = exploracionesData[index];
                        final isSelected = selectedItems.contains(item['id']);
                        final yaEnviado = item['envio'] == 1;

                        return GestureDetector(
                          onTap:
                              yaEnviado
                                  ? null
                                  : () => _handleItemTap(
                                    index,
                                  ), // Deshabilitar tap si ya fue enviado
                          child: Card(
                            margin: EdgeInsets.all(8),
                            color:
                                yaEnviado
                                    ? Colors
                                        .grey[300] // Color gris para items ya enviados
                                    : isSelected
                                    ? Colors.blue.withOpacity(0.2)
                                    : null,
                            child: ListTile(
                              title: Text("Operación ID: ${item['id']}"),
                              subtitle: Text(
                                "Turno: ${item['turno']}, taladro: ${item['taladro']}, Fecha: ${item['fecha']}",
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Estado: ${item['estado']}"),
                                  if (yaEnviado)
                                    Icon(Icons.cloud_done, color: Colors.green),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
