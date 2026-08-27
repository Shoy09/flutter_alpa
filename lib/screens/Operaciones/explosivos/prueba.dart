import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/Accesorio.dart';
import 'package:i_miner/models/Explosivo.dart';
import 'package:i_miner/screens/Operaciones/explosivos/explosivos_centralizados_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';


class Pruebacreen extends StatefulWidget { 
  final dynamic dni;

const Pruebacreen({Key? key, required this.dni}) : super(key: key);

  @override
  _PruebaScreenState createState() => _PruebaScreenState();
}

class _PruebaScreenState extends State<Pruebacreen> {
  List<Map<String, dynamic>> _datos = [];
  List<Accesorio> _accesorios = [];
  List<Explosivo> _explosivos = [];
  Set<int> _seleccionados = {}; // IDs de elementos seleccionados
String nombreUsuario = "";  // Variable para el nombre completo
  String? firmaUsuario;   // Variable para la ruta de la imagen de firma
  // Variables para los filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _turnoSeleccionado;
  bool _filtrosActivos = false;
  int? cantidadRetardos;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarUsuario();
    _cargarNumeroRetardos();
  }

  Future<void> _cargarNumeroRetardos() async {
  final dbHelper = DatabaseHelper();

  final result = await dbHelper.getUltimoNumeroRetardos();

  if (result != null) {
    setState(() {
      cantidadRetardos = result['cantidad'];
    });

    print("✅ Cantidad retardos: $cantidadRetardos");
  } else {
    print("⚠️ No hay datos en numero_retardos");
  }
}

    Future<void> _cargarUsuario() async {
    try {
      final dbHelper = DatabaseHelper();
      final usuario = await dbHelper.getUserByDni(widget.dni);

      if (usuario != null) {
        setState(() {
          // Concatenar nombres y apellidos
          nombreUsuario = "${usuario['nombres']} ${usuario['apellidos']}";
          // Guardar la ruta de la imagen de la firma
          firmaUsuario = usuario['firma'];
        });
      } else {
        setState(() {
          nombreUsuario = "Usuario no encontrado";
          firmaUsuario = "";
        });
      }
    } catch (e) {
      print('Error obteniendo usuario: $e');
      setState(() {
        nombreUsuario = "Error al cargar usuario";
        firmaUsuario = "";
      });
    }
  }


  void _cargarDatos() async {
    List<Map<String, dynamic>> registros = await DatabaseHelper().getExploraciones();
    List<Accesorio> accesorios = await DatabaseHelper().getAccesorios();
    List<Explosivo> explosivos = await DatabaseHelper().getExplosivos();

    setState(() {
      _datos = registros;
      _accesorios = accesorios;
      _explosivos = explosivos;
      _seleccionados.clear();
    });
  }

  void _crearExploracion() async {

    if (cantidadRetardos == null || cantidadRetardos == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Debe existir una cantidad de retardos válida antes de crear la exploración"),
      ),
    );
    return;
  }

    DateTime now = DateTime.now();
    String fecha = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String turno = (now.hour >= 7 && now.hour < 19) ? "Dia" : "Noche";

 int numeroSemana = obtenerNumeroSemana(now);
  String semanaDefault = "Semana $numeroSemana";
  
    // Crear mapas para materiales de despacho y devolución
    Map<String, String> materialesDespacho = {};
    Map<String, String> materialesDevolucion = {};

    // Agregar los tipos de accesorios como materiales con cantidad null
    for (var accesorio in _accesorios) {
      materialesDespacho[accesorio.tipoAccesorio] = '';
      materialesDevolucion[accesorio.tipoAccesorio] = '';
    }

    // Agregar los tipos de explosivos como materiales con cantidad null
    for (var explosivo in _explosivos) {
      materialesDespacho[explosivo.tipoExplosivo] = '';
      materialesDevolucion[explosivo.tipoExplosivo] = '';
    }

    // Llamar a insertExploracion con los materiales
    await DatabaseHelper().insertExploracion(fecha, turno, semanaDefault, cantidadRetardos!,materialesDespacho, materialesDevolucion);
    _cargarDatos();
  }
  
int obtenerNumeroSemana(DateTime fecha) {
  // Primer día del año
  final primerDiaDelAnio = DateTime(fecha.year, 1, 1);
  
  // Día de la semana del primer día del año (0 = lunes, 6 = domingo)
  final diasTranscurridos = fecha.difference(primerDiaDelAnio).inDays;

  // Número de semana (ISO 8601)
  final diaSemana = primerDiaDelAnio.weekday;
  return ((diasTranscurridos + diaSemana - 1) / 7).floor() + 1;
}

  void _eliminarSeleccionados() {
    if (_seleccionados.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Confirmar eliminación"),
            content: Text("¿Estás seguro de que quieres eliminar los registros seleccionados?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cerrar el diálogo sin eliminar
                },
                child: Text("Cancelar"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Cerrar el diálogo
                  await _eliminarRegistros(); // Llamar a la función para eliminar
                },
                child: Text("Eliminar", style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _eliminarRegistros() async {
    for (int id in _seleccionados) {
      bool resultado = await DatabaseHelper().eliminarEstructuraCompletaManual(id);
      if (resultado) {
        print("Eliminado correctamente: $id");
      } else {
        print("Error al eliminar: $id");
      }
    }

    setState(() {
      _seleccionados.clear();
      _cargarDatos(); // Recargar los datos después de eliminar
    });
  }

void _aplicarFiltros() {
  setState(() {
    _filtrosActivos = true;

    // Filtrar los datos
    _datos = _datos.where((item) {
      DateTime fechaItem = DateTime.parse(item['fecha']);
      
      // Verificar si la fecha está dentro del rango
      bool fechaEnRango = (_fechaInicio == null || fechaItem.isAfter(_fechaInicio!.subtract(Duration(days: 1)))) &&
                          (_fechaFin == null || fechaItem.isBefore(_fechaFin!.add(Duration(days: 1))));

      // Verificar si el turno coincide
      bool turnoCoincide = _turnoSeleccionado == null || item['turno'] == _turnoSeleccionado;

      return fechaEnRango && turnoCoincide;
    }).toList();
  });
}

void _exportarSeleccionados(BuildContext context, List<int> seleccionados) async {
  print("Exportando registros: $seleccionados");

  List<String> pdfPaths = [];

  for (var id in seleccionados) {
    String? filePath = await generatePdf(id); // Esperar la ruta del PDF generado
    if (filePath != null) {
      pdfPaths.add(filePath);
    }
  }

  // Si se generaron archivos, mostrar el diálogo
  if (pdfPaths.isNotEmpty) {
    _mostrarDialogoEnvio(context, pdfPaths);
  }
}

  Future<Uint8List?> _loadImageFromUrl(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print("Error al cargar la imagen: Código ${response.statusCode}");
      return null;
    }
  } catch (e) {
    print("Error al obtener la imagen: $e");
    return null;
  }
}


Future<String?> generatePdf(int exploracionId) async {
  final pdf = pw.Document();

  Uint8List? firmaBytes;
if (firmaUsuario != null && firmaUsuario!.isNotEmpty) {
  firmaBytes = await _loadImageFromUrl(firmaUsuario!);
}

  // Obtener datos desde la base de datos
  List<Map<String, dynamic>> datos = await DatabaseHelper()
    .obtenerEstructuraCompleta(exploracionId);

  if (datos.isEmpty) {
    print("No se encontraron datos.");
    return null;
  }

  Map<String, dynamic> trabajo = datos.first;

  // Extraer los valores
  String fecha = trabajo['fecha'] ?? '';
  String turno = trabajo['turno'] ?? '';
  String taladro = trabajo['taladro'] ?? '';
  String piesPorTaladro = trabajo['pies_por_taladro'] ?? '';
  String zona = trabajo['zona'] ?? '';
  String tipoLabor = trabajo['tipo_labor'] ?? '';
  String labor = trabajo['labor'] ?? '';
  String veta = trabajo['veta'] ?? '';
  String nivel = trabajo['nivel'] ?? '';
  String tipoPerforacion = trabajo['tipo_perforacion'] ?? '';

  // Obtener despachos y devoluciones
  List<Map<String, dynamic>> despachos = trabajo['despachos'] ?? [];
  List<Map<String, dynamic>> devoluciones = trabajo['devoluciones'] ?? [];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ENCABEZADO GENERAL
            pw.Text("VALE DE SALIDA - EXPLOSIVOS A LABORES",
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),

            pw.SizedBox(height: 10),

            // DATOS GENERALES
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Fecha: $fecha"),
                pw.Text("Turno: $turno"),
                pw.Text("Zona: $zona"),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Tipo de Labor: $tipoLabor"),
                pw.Text("Labor: $labor"),
                pw.Text("Veta: $veta"),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Nivel: $nivel"),
                pw.Text("Tipo de Perforación: $tipoPerforacion"),
                pw.Text("N° Tal Disp: $taladro"),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Pies por Taladro: $piesPorTaladro"),
              ],
            ),

            pw.SizedBox(height: 10),

            // SECCIÓN DESPACHO Y DEVOLUCIONES
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // DESPACHOS
                _buildSection1(
                  title: "DESPACHOS",
                  data: _extraerDatosExplosivos(despachos),
                ),

                pw.SizedBox(width: 16),

                // DEVOLUCIONES
                _buildSection1(
                  title: "DEVOLUCIONES",
                  data: _extraerDatosExplosivos(devoluciones),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Tablas de detalles de materiales
            pw.Text("MATERIALES",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: despachos.isNotEmpty
                      ? _buildMaterialesTable(despachos.first['detalles_materiales'] ?? [])
                      : pw.Container(),
                ),
                pw.SizedBox(width: 16), // Espacio entre las tablas
                pw.Expanded(
                  child: devoluciones.isNotEmpty
                      ? _buildMaterialesTable(devoluciones.first['detalles_materiales'] ?? [])
                      : pw.Container(),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Tablas de detalles de explosivos
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: despachos.isNotEmpty
                      ? _buildDetalleTable(despachos.first['detalles_explosivos'] ?? [])
                      : pw.Container(),
                ),
                pw.SizedBox(width: 16), // Espacio entre las tablas
                pw.Expanded(
                  child: devoluciones.isNotEmpty
                      ? _buildDetalleTable(devoluciones.first['detalles_explosivos'] ?? [])
                      : pw.Container(),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // FIRMAS
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Firma del Bodeguero
                  pw.Column(
                  children: [
                    if (firmaBytes != null)
                      pw.Image(
                        pw.MemoryImage(firmaBytes),
                        width: 150,
                        height: 100,
                      ),
                    pw.Text(nombreUsuario, style: pw.TextStyle(fontSize: 10)),
                    pw.Text("_______________________"),
                    pw.Text("Firma Bodeguero"),
                  ],
                ),

                  // Firma del Supervisor (solo línea de firma)
                  pw.Column(
                    children: [
                      pw.SizedBox(
                          height:
                              50), // Espacio similar a la firma del bodeguero
                      pw.Text("_______________________"),
                      pw.Text("Firma Supervisor"),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );

  // GUARDAR PDF
  final output = await getExternalStorageDirectory();
  String filePath = "${output!.path}/vale_salida_${exploracionId}.pdf";
  final file = File(filePath);
  await file.writeAsBytes(await pdf.save());
  // Mostrar mensaje de éxito
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('PDF exportado correctamente')),
  );
  return filePath;
}

// FUNCIÓN PARA CONVERTIR DATOS DE DESPACHO/DEVOLUCIÓN A MAPA
Map<String, String> _extraerDatosExplosivos(List<Map<String, dynamic>> lista) {
  if (lista.isEmpty) return {};

  Map<String, dynamic> datos = lista.first; // Tomamos solo el primer elemento

  return {
    "Milisegundo": datos["mili_segundo"]?.toString() ?? "0",
    "Medio Segundo": datos["medio_segundo"]?.toString() ?? "0",
    // Otros campos que puedan necesitarse
  };
}

// FUNCIÓN PARA CREAR SECCIÓN (DESPACHO / DEVOLUCIONES)
pw.Widget _buildSection1({required String title, required Map<String, String> data}) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        for (var entry in data.entries)
          pw.Text("${entry.key}: ${entry.value}", style: pw.TextStyle(fontSize: 12)),
      ],
    ),
  );
}

// FUNCIÓN PARA GENERAR TABLA DE DETALLES DE EXPLOSIVOS
pw.Widget _buildDetalleTable(List<Map<String, dynamic>> detalles) {
  return detalles.isEmpty
      ? pw.Container()
      : pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey),
          columnWidths: {
            0: pw.FlexColumnWidth(0.3),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(2.0),
          },
          children: [
            // ENCABEZADO DE LA TABLA
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildHeaderCell1("N°"),
                _buildHeaderCell1("Milisegundo (MS)"),
                _buildHeaderCell1("Medio Segundo (LP)"),
              ],
            ),
            // FILAS DINÁMICAS
            for (var detalle in detalles)
              pw.TableRow(
                children: [
                  _buildNumberCell1(detalle["numero"] ?? 0),
                  _buildInputCell1(detalle["ms_cant1"] ?? "0"),
                  _buildInputCell1(detalle["lp_cant1"] ?? "0"),
                ],
              ),
          ],
        );
}

// FUNCIÓN PARA GENERAR TABLA DE MATERIALES
pw.Widget _buildMaterialesTable(List<Map<String, dynamic>> materiales) {
  if (materiales.isEmpty) return pw.Container();

  // Dividir los materiales en grupos de 4 para mostrarlos en filas
  List<List<Map<String, dynamic>>> grupos = [];
  for (var i = 0; i < materiales.length; i += 4) {
    grupos.add(materiales.sublist(i, i + 4 > materiales.length ? materiales.length : i + 4));
  }

  return pw.Table(
  border: pw.TableBorder.all(color: PdfColors.grey),
  columnWidths: {
    0: pw.FlexColumnWidth(1.0),
    1: pw.FlexColumnWidth(1.0),
    2: pw.FlexColumnWidth(1.0),
    3: pw.FlexColumnWidth(1.0),
  },
  children: [
    // FILAS DINÁMICAS SIN ENCABEZADO
    for (var grupo in grupos) ...[
      // FILA DE NOMBRES
      pw.TableRow(
        children: [
          for (var material in grupo)
            _buildInputCell1(material["nombre_material"] ?? ""),
          for (var i = grupo.length; i < 4; i++) // Celdas vacías si faltan materiales
            _buildInputCell1(""),
        ],
      ),
      // FILA DE CANTIDADES
      pw.TableRow(
        children: [
          for (var material in grupo)
            _buildInputCell1("${material["cantidad"] ?? "0"}"),
          for (var i = grupo.length; i < 4; i++) // Celdas vacías si faltan cantidades
            _buildInputCell1(""),
        ],
      ),
      // Línea separadora (opcional)
      pw.TableRow(
        children: List.generate(4, (index) => pw.Container(height: 1, color: PdfColors.grey)),
      ),
    ],
  ],
);

}

// FUNCIÓN PARA CELDAS DE ENCABEZADO
pw.Widget _buildHeaderCell1(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  );
}

// FUNCIÓN PARA CELDAS NUMÉRICAS
pw.Widget _buildNumberCell1(dynamic number) {
  int num = number is int ? number : int.tryParse(number.toString()) ?? 0;
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      num.toString(),
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 8),
    ),
  );
}

// FUNCIÓN PARA CELDAS DE ENTRADA
pw.Widget _buildInputCell1(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 8),
    ),
  );
}

void _mostrarDialogoEnvio(BuildContext context, List<String> pdfPaths) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Enviar PDFs por correo"),
        content: Text("¿Quieres enviar los archivos exportados por correo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _enviarCorreo(pdfPaths);
            },
            child: Text("Sí"),
          ),
        ],
      );
    },
  );
}

void _enviarCorreo(List<String> pdfPaths) {
  List<XFile> files = pdfPaths.map((path) => XFile(path)).toList();

  try {
    Share.shareXFiles(files, text: "Adjunto los reportes en PDF.");
  } catch (e) {
    print("Error al compartir los archivos: $e");
  }
}
//--------------------------------------------------------------------------------------------------------------



  void _quitarFiltros() {
    setState(() {
      _filtrosActivos = false;
      _fechaInicio = null;
      _fechaFin = null;
      _turnoSeleccionado = null;
    });
    _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Vale de salida"),
        backgroundColor: Color(0xFF21899C),
      ),
      floatingActionButton: _seleccionados.isNotEmpty
    ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _eliminarSeleccionados,
            child: Icon(Icons.delete),
            backgroundColor: Colors.red,
            heroTag: "btnEliminar",
          ),
          SizedBox(width: 10), // Espaciado entre botones
          FloatingActionButton(
  onPressed: () {
    _exportarSeleccionados(context, _seleccionados.toList());
  },
  child: Icon(Icons.download),
  backgroundColor: Colors.blue,
  heroTag: "btnExportar",
),

        ],
      )
    : FloatingActionButton(
        onPressed: _crearExploracion,
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF21899C),
      ),

      body: Column(
        children: [
          Padding(
  padding: const EdgeInsets.all(8.0),
  child: Wrap(
    spacing: 12, // Más espacio entre elementos
    runSpacing: 8, // Espaciado si se ajusta en varias líneas
    alignment: WrapAlignment.center,
    children: [
      // Selector de fecha con ancho mayor
      Container(
        width: 280, // Ajusta el tamaño del botón de fecha
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: Container(
                    width: double.maxFinite,
                    child: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100),
                          focusedDay: DateTime.now(),
                          rangeStartDay: _fechaInicio,
                          rangeEndDay: _fechaFin,
                          rangeSelectionMode: RangeSelectionMode.toggledOn,
                          onRangeSelected: (start, end, focusedDay) {
                            setStateDialog(() {
                              _fechaInicio = start;
                              _fechaFin = end;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {}); // Actualiza la UI con las fechas seleccionadas
                        Navigator.pop(context);
                      },
                      child: Text("Aceptar"),
                    ),
                  ],
                );
              },
            );
          },
          child: Text(
            _fechaInicio == null || _fechaFin == null
                ? "Seleccionar fecha"
                : "${_fechaInicio!.toLocal().toString().split(' ')[0]} - ${_fechaFin!.toLocal().toString().split(' ')[0]}",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16), // Texto más grande
          ),
        ),
      ),

      // Dropdown para seleccionar turno con mayor ancho
      Container(
        width: 180, // Se agranda el ancho del dropdown
        child: DropdownButtonFormField<String>(
          value: _turnoSeleccionado,
          items: ["Día", "Noche"].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _turnoSeleccionado = value;
            });
          },
          decoration: InputDecoration(
            labelText: "Turno",
            border: OutlineInputBorder(),
          ),
        ),
      ),

      // Botón para aplicar filtros (solo si NO hay filtros activos)
      Visibility(
        visible: !_filtrosActivos,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _filtrosActivos = true;
            });
            _aplicarFiltros();
          },
          child: Text("Crear filtro", style: TextStyle(fontSize: 16)),
        ),
      ),

      // Botón para quitar filtros (solo si HAY filtros activos)
      Visibility(
        visible: _filtrosActivos,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _filtrosActivos = false;
            });
            _quitarFiltros();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text("Quitar filtros", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    ],
  ),
),



          Expanded(
            child: _datos.isEmpty
                ? Center(child: Text("No hay registros"))
                : ListView.builder(
                    itemCount: _datos.length,
                    itemBuilder: (context, index) {
                      var item = _datos[index];
                      int itemId = item['id'];

                      Color containerColor;
                      switch (item['estado']) {
                        case 'En proceso':
                          containerColor = Colors.red;
                          break;
                        case 'Finalizado':
                          containerColor = Colors.green;
                          break;
                        default:
                          containerColor = Colors.blue;
                      }

                      bool estaSeleccionado = _seleccionados.contains(itemId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: GestureDetector(
                          onLongPress: () {
                            setState(() {
                              _seleccionados.add(itemId);
                            });
                          },
                          onTap: () {
                            setState(() {
                              if (_seleccionados.contains(itemId)) {
                                _seleccionados.remove(itemId);
                              } else if (_seleccionados.isNotEmpty) {
                                _seleccionados.add(itemId);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExplosivosCentralizadosScreen(
                                      id: item['id'],
                                      dni: widget.dni,
                                      onEstadoActualizado: _cargarDatos,
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: containerColor,
                              borderRadius: BorderRadius.circular(30),
                              border: estaSeleccionado
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Fecha: ${item['fecha'] ?? 'N/A'}",
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Turno: ${item['turno'] ?? 'N/A'}",
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                                if (estaSeleccionado)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(Icons.check_circle, color: Colors.white, size: 24),
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