import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/medicion_horizontal.dart';
import 'package:i_miner/services/envio%20nube/Mediciones/api_service_mediciones_horizontal.dart';
import 'package:i_miner/services/envio%20nube/explosivos/ExploracionService_service.dart';


class ListaMedicionesScreen extends StatefulWidget {
  final String tipoPerforacion;

  ListaMedicionesScreen({required this.tipoPerforacion});

  @override
  _DetalleSeccionScreenState createState() => _DetalleSeccionScreenState();
}

class _DetalleSeccionScreenState extends State<ListaMedicionesScreen> {
  List<Map<String, dynamic>> medicionesData = [];
  Set<int> selectedItems = {};
  Timer? selectionTimer;
  bool isLoading = true;
  String mensajeUsuario = "Cargando registros...";

  @override
  void initState() {
    super.initState();
    _fetchMedicionesData();
  }

  @override
  void dispose() {
    selectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMedicionesData() async {
    setState(() => isLoading = true);
    
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> data = await dbHelper.obtenerTodasMedicionesHorizontal();

      setState(() {
        medicionesData = data;
        if (data.isEmpty) {
          mensajeUsuario = "No se encontraron registros de mediciones.";
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        mensajeUsuario = "Error al cargar los datos: ${e.toString()}";
      });
    }
  }

  void _handleItemTap(int index) {
    final medicion = medicionesData[index];
    final medicionId = medicion['id'];
    final yaEnviado = medicion['envio'] == 1;

    if (yaEnviado) {
      return;
    }

    selectionTimer?.cancel();

    if (selectedItems.contains(medicionId)) {
      setState(() {
        selectedItems.remove(medicionId);
      });
    } else {
      if (selectedItems.isNotEmpty) {
        setState(() {
          selectedItems.add(medicionId);
        });
      } else {
        selectionTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              selectedItems.add(medicionId);
            });
          }
        });
      }
    }
  }

  Future<void> _exportSelectedItems() async {
    if (selectedItems.isEmpty) return;

    DatabaseHelper dbHelper = DatabaseHelper();
    List<Map<String, dynamic>> jsonData = [];

    for (var id in selectedItems) {
      Map<String, dynamic>? medicion = await dbHelper.obtenerMedicionHorizontalPorId(id);

      if (medicion != null) {
        jsonData.add(medicion);
      }
    }

    await _showConfirmationDialog(jsonData);
  }

  Future<void> _showConfirmationDialog(List<Map<String, dynamic>> jsonData) async {
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
                  'Mediciones a enviar: ${jsonData.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
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

Future<void> _enviarDatosALaNube(List<Map<String, dynamic>> jsonData) async {
  final medicionService = ApiServiceMedicionesHorizontal();
  final exploracionService = ExploracionService();
  bool allSuccess = true;
  List<String> errores = [];
  List<int> idsNubeParaMarcar = [];

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Paso 1: Enviar todas las mediciones horizontales
    for (var medicionMap in jsonData) {
      try {
        final medicion = MedicionHorizontal.fromJson(medicionMap);
        bool success = await medicionService.postMedicionHorizontal(medicion.toApiJson());

        if (success) {
          await _actualizarEnvio(medicionMap['id']);
          
          // Si tiene idnube, lo agregamos a la lista para marcar
          if (medicionMap['idnube'] != null) {
            idsNubeParaMarcar.add(medicionMap['idnube']);
          }
        } else {
          allSuccess = false;
          errores.add("Error al enviar medición ID: ${medicionMap['id']}");
        }
      } catch (e) {
        allSuccess = false;
        errores.add("Error procesando medición ID: ${medicionMap['id']} - ${e.toString()}");
      }
    }

    // Paso 2: Marcar los registros como usados en mediciones (solo si hay ids)
    if (idsNubeParaMarcar.isNotEmpty) {
      bool marcadoExitoso = await exploracionService.marcarComoUsadosEnMediciones(idsNubeParaMarcar);
      
      if (!marcadoExitoso) {
        allSuccess = false;
        errores.add("Error al marcar registros como usados en mediciones");
      }
    }

  } catch (e) {
    allSuccess = false;
    errores.add("Error inesperado: ${e.toString()}");
  }

  Navigator.of(context).pop();
  await _showResultDialog(allSuccess, errores);
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
      int deletedCount = await dbHelper.eliminarMultiplesMedicionesHorizontal(selectedItems.toList());

      Navigator.of(context).pop();

      await _fetchMedicionesData();

      setState(() {
        selectedItems.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount registros eliminados correctamente'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<int> _actualizarEnvio(int medicionId) async {
    DatabaseHelper dbHelper = DatabaseHelper();
    return await dbHelper.actualizarEnvioMedicionesHorizontal([medicionId]);
  }

Future<void> _showResultDialog(bool success, List<String> errores) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(success ? 'Éxito' : 'Error'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              success
                  ? 'Los datos se enviaron correctamente a la nube y se marcaron los registros correspondientes.'
                  : 'Ocurrieron algunos errores durante el proceso:',
            ),
            if (errores.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Detalles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...errores.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('- $e', style: const TextStyle(fontSize: 14)),
              )).toList(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            if (success) {
              await _fetchMedicionesData();
              setState(() => selectedItems.clear());
            }
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mediciones de ${widget.tipoPerforacion}"),
        backgroundColor: const Color(0xFF21899C),
        actions: [
          if (selectedItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmarEliminacion,
              tooltip: "Eliminar seleccionados",
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportSelectedItems,
              tooltip: "Exportar seleccionados",
            ),
          ],
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    mensajeUsuario,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : medicionesData.isEmpty
              ? Center(
                  child: Text(
                    mensajeUsuario,
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Mediciones encontradas: ${medicionesData.length}",
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
                        itemCount: medicionesData.length,
                        itemBuilder: (context, index) {
                          final medicion = medicionesData[index];
                          final isSelected = selectedItems.contains(medicion['id']);
                          final yaEnviado = medicion['envio'] == 1;

                          return GestureDetector(
                            onTap: yaEnviado ? null : () => _handleItemTap(index),
                            child: Card(
                              margin: const EdgeInsets.all(8),
                              color: yaEnviado
                                  ? Colors.grey[300]
                                  : isSelected
                                      ? Colors.blue.withOpacity(0.2)
                                      : null,
                              child: ListTile(
                                title: Text("Medición ID: ${medicion['id']}"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Fecha: ${medicion['fecha']}"),
                                    Text("Turno: ${medicion['turno']}"),
                                    Text("Zona: ${medicion['zona']} - Labor: ${medicion['labor']}"),
                                    Text("Veta: ${medicion['veta']}"),
                                    Text("Avance programado: ${medicion['avance_programado']}m"),
                                    Text("Dimensiones: ${medicion['ancho']}m x ${medicion['alto']}m"),
                                    Text("Explosivos: ${medicion['kg_explosivos']}kg"),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (yaEnviado)
                                      const Icon(Icons.cloud_done, color: Colors.green),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
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