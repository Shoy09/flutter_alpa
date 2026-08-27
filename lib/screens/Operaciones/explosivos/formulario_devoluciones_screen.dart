import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/explosivos_uni.dart';

class FormularioDevolucionesScreen extends StatefulWidget {
  final int exploracionId;
  final dynamic dni;
  final VoidCallback? onEstadoActualizado;
  const FormularioDevolucionesScreen({
    Key? key,
    required this.exploracionId,
    this.onEstadoActualizado,
    required this.dni,
  }) : super(key: key);

  @override
  _FormularioDevolucionesScreenState createState() =>
      _FormularioDevolucionesScreenState();
}

class _FormularioDevolucionesScreenState
    extends State<FormularioDevolucionesScreen> {
  final _formKey = GlobalKey<FormState>();

  // 🔹 VARIABLES DINÁMICAS PARA EL NÚMERO DE FILAS
  int totalFilas = 0;
  int primeraMitad = 0;
  int segundaMitadDesde = 0;
  int segundaMitadHasta = 0;

  List<Map<String, dynamic>> _detallesDespacho = [];
  List<Map<String, dynamic>> _detallesDevoluciones = [];
  int? _DevolucionesId;
  int? _despachoId;
  String nombreUsuario = "";
  String? firmaUsuario;
  final Map<String, TextEditingController> _controllers = {};
  bool _registroCerrado = false;
  List<ExplosivosUni> milisegundosList = [];
  List<ExplosivosUni> medioSegundosList = [];

  List<Map<String, String>> _accesorios = [];
  List<Map<String, String>> _explosivos = [];

  final TextEditingController _observacionesController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetallesDevoluciones();
    _loadDetallesDespacho();
    _verificarEstadoRegistro();
    _cargarUsuario();
    fetchExplosivosuni();
    _cargarDatos();
  }

  void _configurarMitades() {
    if (totalFilas <= 0) return;
    
    if (totalFilas % 2 == 0) {
      primeraMitad = totalFilas ~/ 2;
      segundaMitadDesde = primeraMitad + 1;
      segundaMitadHasta = totalFilas;
    } else {
      primeraMitad = (totalFilas ~/ 2) + 1;
      segundaMitadDesde = primeraMitad + 1;
      segundaMitadHasta = totalFilas;
    }
  }

  void _cargarDatos() async {
    List<Map<String, String>> accesorios =
        await DatabaseHelper().getAccesoriosunidad();
    List<Map<String, String>> explosivos =
        await DatabaseHelper().getExplosivosunidad();

    setState(() {
      _accesorios = accesorios;
      _explosivos = explosivos;
    });
  }

  void fetchExplosivosuni() async {
    List<ExplosivosUni> explosivos = await DatabaseHelper().getExplosivosUni();

    milisegundosList.clear();
    medioSegundosList.clear();

    for (var explosivo in explosivos) {
      if (explosivo.tipo == "Milisegundo") {
        milisegundosList.add(explosivo);
      } else if (explosivo.tipo == "Medio Segundo") {
        medioSegundosList.add(explosivo);
      }
    }

    _visibleMsOptions = milisegundosList.map((e) => e.dato.toString()).toSet();
    _visibleLpOptions = medioSegundosList.map((e) => e.dato.toString()).toSet();

    setState(() {});
  }

  Future<void> _cargarUsuario() async {
    try {
      final dbHelper = DatabaseHelper();
      final usuario = await dbHelper.getUserByDni(widget.dni);

      if (usuario != null) {
        setState(() {
          nombreUsuario = "${usuario['nombres']} ${usuario['apellidos']}";
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

  Future<void> _verificarEstadoRegistro() async {
    bool cerrado =
        await DatabaseHelper().estaRegistroCerrado(widget.exploracionId);
    setState(() {
      _registroCerrado = cerrado;
    });
  }

  void _loadDetallesDevoluciones() async {
    List<Map<String, dynamic>> detalles = await DatabaseHelper()
        .getDetalleDevolucionesByExploracionId(widget.exploracionId);

    if (detalles.isNotEmpty) {
      var detail = detalles.first;

      _DevolucionesId = detail['id'];

      final obs = detail['observaciones'];
      if (obs != null) {
        _observacionesController.text = obs.toString();
      }

      // 🔹 OBTENER cantidad_retardos
      final cantidad = detail['cantidad_retardos'] ?? 0;
      print("🔥 cantidad_retardos BD (Devoluciones): $cantidad");

      totalFilas = cantidad;
      _configurarMitades();

      // 🔹 Crear controllers dinámicamente
      _controllers.clear();
      for (int i = 1; i <= totalFilas; i++) {
        _controllers['msCant1_$i'] = TextEditingController();
        _controllers['lpCant1_$i'] = TextEditingController();
      }

      setState(() {});

      if (_DevolucionesId != null) {
        _loadDetallesDevolucionesExplo(_DevolucionesId!);
        _loadDetalleDevolucionesMateriales(_DevolucionesId!);
      }
    }
  }

  void _loadDetallesDespacho() async {
    List<Map<String, dynamic>> detalles = await DatabaseHelper()
        .getDetalleDespachoByExploracionId(widget.exploracionId);

    if (detalles.isNotEmpty) {
      var detail = detalles.first;
      _despachoId = detail['id'];
      setState(() {});

      if (_despachoId != null) {
        _loadDetallesDespachoMateriales(_despachoId!);
      }
    }
  }

  void _loadDetalleDevolucionesMateriales(int DevolucionesId) async {
    List<Map<String, dynamic>> detalles = await DatabaseHelper()
        .getDetalleDevolucionByDevolucionId(DevolucionesId);

    setState(() {
      _detallesDevoluciones =
          detalles.where((d) => d['cantidad'] != null).toList();
      _initializeControllers();
    });
  }

  void _loadDetallesDespachoMateriales(int despachoId) async {
    List<Map<String, dynamic>> detalles = await DatabaseHelper()
        .getDetalleDespachoByDesapachoExposivosyAccesorios(despachoId);

    setState(() {
      _detallesDespacho = detalles.where((d) => d['cantidad'] != null).toList();
    });
  }

  void _initializeControllers() {
    for (var detalle in _detallesDevoluciones) {
      String key = detalle['nombre_material'];
      _controllers[key] =
          TextEditingController(text: detalle['cantidad']?.toString() ?? '');
    }
  }

  // Carga los detalles de Devoluciones desde la BD
  void _loadDetallesDevolucionesExplo(int DevolucionesId) async {
    List<Map<String, dynamic>> detalles = await DatabaseHelper()
        .getDetalleDevolucionesByDevolucionesId(DevolucionesId);

    for (var detail in detalles) {
      int numero = detail['numero'];
      if (numero >= 1 && numero <= totalFilas) {
        _controllers['msCant1_$numero']?.text = detail['ms_cant1'] ?? "";
        _controllers['lpCant1_$numero']?.text = detail['lp_cant1'] ?? "";
      }
    }

    setState(() {});
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

  Future<void> generatePdf() async {
    final pdf = pw.Document();

    Uint8List? firmaBytes;
    if (firmaUsuario != null && firmaUsuario!.isNotEmpty) {
      firmaBytes = await _loadImageFromUrl(firmaUsuario!);
    }

    List<Map<String, dynamic>> datos =
        await DatabaseHelper().obtenerEstructuraCompleta(widget.exploracionId);

    if (datos.isEmpty) {
      print("No se encontraron datos.");
      return;
    }

    Map<String, dynamic> trabajo = datos.first;

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

    List<Map<String, dynamic>> despachos = trabajo['despachos'] ?? [];
    List<Map<String, dynamic>> devoluciones = trabajo['devoluciones'] ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("VALE DE SALIDA - EXPLOSIVOS A LABORES",
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
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
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSection1(
                    title: "DESPACHOS",
                    data: _extraerDatosExplosivos(despachos),
                  ),
                  pw.SizedBox(width: 16),
                  _buildSection1(
                    title: "DEVOLUCIONES",
                    data: _extraerDatosExplosivos(devoluciones),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text("MATERIALES",
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: despachos.isNotEmpty
                        ? _buildMaterialesTable(
                            despachos.first['detalles_materiales'] ?? [])
                        : pw.Container(),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: devoluciones.isNotEmpty
                        ? _buildMaterialesTable(
                            devoluciones.first['detalles_materiales'] ?? [])
                        : pw.Container(),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: despachos.isNotEmpty
                        ? _buildDetalleTable(
                            despachos.first['detalles_explosivos'] ?? [])
                        : pw.Container(),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: devoluciones.isNotEmpty
                        ? _buildDetalleTable(
                            devoluciones.first['detalles_explosivos'] ?? [])
                        : pw.Container(),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
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
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 50),
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

    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/vale_salida.pdf");
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF exportado correctamente')),
    );
  }

  Map<String, String> _extraerDatosExplosivos(
      List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) return {};

    Map<String, dynamic> datos = lista.first;
    return {
      "Milisegundo": datos["mili_segundo"]?.toString() ?? "0",
      "Medio Segundo": datos["medio_segundo"]?.toString() ?? "0",
    };
  }

  pw.Widget _buildSection1(
      {required String title, required Map<String, String> data}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          for (var entry in data.entries)
            pw.Text("${entry.key}: ${entry.value}",
                style: pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

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
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildHeaderCell1("N°"),
                  _buildHeaderCell1("Milisegundo (MS)"),
                  _buildHeaderCell1("Medio Segundo (LP)"),
                ],
              ),
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

  pw.Widget _buildMaterialesTable(List<Map<String, dynamic>> materiales) {
    if (materiales.isEmpty) return pw.Container();

    List<List<Map<String, dynamic>>> grupos = [];
    for (var i = 0; i < materiales.length; i += 4) {
      grupos.add(materiales.sublist(
          i, i + 4 > materiales.length ? materiales.length : i + 4));
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
        for (var grupo in grupos) ...[
          pw.TableRow(
            children: [
              for (var material in grupo)
                _buildInputCell1(material["nombre_material"] ?? ""),
              for (var i = grupo.length; i < 4; i++)
                _buildInputCell1(""),
            ],
          ),
          pw.TableRow(
            children: [
              for (var material in grupo)
                _buildInputCell1("${material["cantidad"] ?? "0"}"),
              for (var i = grupo.length; i < 4; i++)
                _buildInputCell1(""),
            ],
          ),
          pw.TableRow(
            children: List.generate(
                4, (index) => pw.Container(height: 1, color: PdfColors.grey)),
          ),
        ],
      ],
    );
  }

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

  Future<bool> _actualizarDevoluciones() async {
    if (_DevolucionesId == null) {
      throw Exception('No hay un Devoluciones para actualizar');
    }

    int result = await DatabaseHelper()
        .updateDevoluciones(_DevolucionesId!, {});
    return result > 0;
  }

  Future<void> _actualizarTodosLosDetalles() async {
    try {
      if (_detallesDevoluciones.isEmpty) return;

      List<Future<void>> actualizaciones = [];

      for (var detalle in _detallesDevoluciones) {
        int id = detalle['id'];
        String key = detalle['nombre_material'];
        String cantidadStr = _controllers[key]?.text ?? "";
        double cantidadDevolucion = double.tryParse(cantidadStr) ?? 0.0;

        var detalleDespacho = _detallesDespacho.firstWhere(
          (d) => d['nombre_material'] == key,
          orElse: () => {},
        );

        double cantidadDespachada = double.tryParse(detalleDespacho.isNotEmpty
                ? detalleDespacho['cantidad'].toString()
                : "0") ??
            0.0;

        if (cantidadDevolucion > cantidadDespachada) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $key tiene una devolución mayor al despacho."),
              backgroundColor: Colors.red,
            ),
          );
          continue;
        }

        if (cantidadStr.isNotEmpty) {
          actualizaciones.add(
            DatabaseHelper()
                .updateDevolucionDetalle(id, {'cantidad': cantidadStr}),
          );
        }
      }

      await Future.wait(actualizaciones);
      print("Todos los detalles de la devolución fueron actualizados.");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al actualizar detalles: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _actualizarEstadoEnProceso() async {
    if (widget.exploracionId > 0) {
      await DatabaseHelper()
          .updateEstadoExploracion(widget.exploracionId, 'Finalizado');
      if (widget.onEstadoActualizado != null) {
        widget.onEstadoActualizado!();
      }
    }
  }

  Future<void> _actualizarTiempos() async {
    if (_DevolucionesId == null) {
      throw Exception('No se encontró un ID de devolución');
    }

    final selectedMs = _getSelectedMsOption();
    final selectedLp = _getSelectedLpOption();

    double? ms = selectedMs != null ? double.tryParse(selectedMs) : null;
    double? lp = selectedLp != null ? double.tryParse(selectedLp) : null;

    if (ms == null && lp == null) return;

    int filasActualizadas =
        await DatabaseHelper().actualizarTiemposDevoluciones(
      _DevolucionesId!,
      ms,
      lp,
    );

    if (filasActualizadas > 0) {
      print('Tiempos actualizados correctamente: MS=$ms, LP=$lp');
    }
  }

  void _mostrarDialogoConfirmacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar cierre'),
          content: const Text('¿Estás seguro de que deseas cerrar este registro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await DatabaseHelper().cerrarRegistro(widget.exploracionId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registro cerrado correctamente')),
                );
                if (widget.onEstadoActualizado != null) {
                  widget.onEstadoActualizado!();
                }
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _guardarFormulario() async {
    if (_DevolucionesId == null) {
      throw Exception('No se encontró un ID de Devoluciones');
    }

    List<Map<String, dynamic>> detallesDespacho =
        await DatabaseHelper().getDetalleDespachoByDespachoId(_despachoId!);

    Map<int, Map<String, dynamic>> despachoMap = {};
    for (var detalle in detallesDespacho) {
      despachoMap[detalle['numero']] = detalle;
    }

    List<Map<String, dynamic>> detalles = [];

    for (int i = 1; i <= totalFilas; i++) {
      final msCant1 = _controllers['msCant1_$i']?.text ?? '';
      final lpCant1 = _controllers['lpCant1_$i']?.text ?? '';

      if (msCant1.isNotEmpty || lpCant1.isNotEmpty) {
        double msDevolucion = double.tryParse(msCant1) ?? 0;
        double lpDevolucion = double.tryParse(lpCant1) ?? 0;

        double msDespacho =
            double.tryParse(despachoMap[i]?['ms_cant1'] ?? "0") ?? 0;
        double lpDespacho =
            double.tryParse(despachoMap[i]?['lp_cant1'] ?? "0") ?? 0;

        if (msDevolucion > msDespacho) {
          throw Exception(
              'Error: La cantidad de devolución en MS número $i es mayor que la del despacho.');
        }
        if (lpDevolucion > lpDespacho) {
          throw Exception(
              'Error: La cantidad de devolución en LP número $i es mayor que la del despacho.');
        }

        detalles.add({
          'numero': i,
          'ms_cant1': msCant1,
          'lp_cant1': lpCant1,
        });
      }
    }

    if (detalles.isNotEmpty) {
      await DatabaseHelper()
          .insertDetallesDevoluciones(_DevolucionesId!, detalles);
      return true;
    } else {
      throw Exception('No hay datos para guardar en el formulario');
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    _observacionesController.dispose();
    super.dispose();
  }

  Widget _buildInputRow(List<TextEditingController> controllers) {
    return Row(
      children: controllers
          .map(
            (controller) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: TextFormField(
                  controller: controller,
                  style: TextStyle(fontSize: 12),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  enabled: !_registroCerrado,
                  decoration: InputDecoration(
                    hintText: 'Cant',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNumberCell(int number) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        number.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTable(int start, int end) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(0.3),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(2.0),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Colors.black12),
          children: [
            _buildHeaderCell('N°'),
            _buildHeaderWithButtons(
              'Milisegundo (MS)',
              milisegundosList.map((e) => e.dato.toString()).toList(),
              _visibleMsOptions,
              _toggleMsOption,
            ),
            _buildHeaderWithButtons(
              'Medio Segundo (LP)',
              medioSegundosList.map((e) => e.dato.toString()).toList(),
              _visibleLpOptions,
              _toggleLpOption,
            ),
          ],
        ),
        for (int i = start; i <= end; i++)
          TableRow(
            children: [
              _buildNumberCell(i),
              _buildInputRow([_controllers['msCant1_$i']!]),
              _buildInputRow([_controllers['lpCant1_$i']!]),
            ],
          ),
      ],
    );
  }

  Widget _buildHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Set<String> _visibleMsOptions = {};
  Set<String> _visibleLpOptions = {};

  String? _getSelectedMsOption() {
    return _visibleMsOptions.length == 1 ? _visibleMsOptions.first : null;
  }

  String? _getSelectedLpOption() {
    return _visibleLpOptions.length == 1 ? _visibleLpOptions.first : null;
  }

  void _toggleMsOption(String option) {
    if (_registroCerrado) return;
    setState(() {
      if (_visibleMsOptions.length == 1 && _visibleMsOptions.contains(option)) {
        _visibleMsOptions =
            milisegundosList.map((e) => e.dato.toString()).toSet();
      } else {
        _visibleMsOptions = {option};
      }
    });
  }

  void _toggleLpOption(String option) {
    if (_registroCerrado) return;
    setState(() {
      if (_visibleLpOptions.length == 1 && _visibleLpOptions.contains(option)) {
        _visibleLpOptions =
            medioSegundosList.map((e) => e.dato.toString()).toSet();
      } else {
        _visibleLpOptions = {option};
      }
    });
  }

  Widget _buildHeaderWithButtons(String title, List<String> options,
      Set<String> visibleOptions, Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: options
                .where((option) => visibleOptions.contains(option))
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: _registroCerrado
                          ? null
                          : () => onTap(option),
                      style: _registroCerrado
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.grey[500],
                            )
                          : null,
                      child: Text(option),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarObservaciones() async {
    if (_DevolucionesId == null) {
      throw Exception('No se encontró un ID de devolución');
    }

    final observaciones = _observacionesController.text.trim();
    if (observaciones.isEmpty) return;

    await DatabaseHelper()
        .actualizarDetalleDevolucion(_DevolucionesId!, observaciones);
    print("Observaciones actualizadas correctamente.");
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loading mientras se carga totalFilas
    if (totalFilas == 0) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Cargando formulario de devoluciones...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Column(
                children: List.generate(
                  (_detallesDevoluciones.length / 2).ceil(),
                  (index) {
                    int startIndex = index * 2;
                    int endIndex = startIndex + 2;
                    List detallesFila = _detallesDevoluciones.sublist(
                      startIndex,
                      endIndex > _detallesDevoluciones.length
                          ? _detallesDevoluciones.length
                          : endIndex,
                    );

                    return Row(
                      children: detallesFila.map((detalle) {
                        String key = detalle['nombre_material'];
                        String unidadMedida = '';
                        var accesorio = _accesorios.firstWhere(
                          (a) => a['tipo'] == key,
                          orElse: () => {},
                        );
                        var explosivo = _explosivos.firstWhere(
                          (e) => e['tipo'] == key,
                          orElse: () => {},
                        );

                        if (accesorio.isNotEmpty) {
                          unidadMedida = accesorio['unidad_medida']!;
                        } else if (explosivo.isNotEmpty) {
                          unidadMedida = explosivo['unidad_medida']!;
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: TextFormField(
                              enabled: !_registroCerrado,
                              controller: _controllers[key],
                              decoration: InputDecoration(
                                labelText:
                                    '${detalle['nombre_material']} (${unidadMedida.isNotEmpty ? unidadMedida : ''})',
                                border: const OutlineInputBorder(),
                                filled: _registroCerrado,
                                fillColor: _registroCerrado
                                    ? Colors.grey[200]
                                    : null,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isSmallScreen = constraints.maxWidth < 600;

                  return isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTable(1, primeraMitad),
                            const SizedBox(height: 16),
                            if (segundaMitadDesde <= totalFilas)
                              _buildTable(segundaMitadDesde, segundaMitadHasta),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildTable(1, primeraMitad)),
                            const SizedBox(width: 16),
                            if (segundaMitadDesde <= totalFilas)
                              Expanded(
                                  child: _buildTable(
                                      segundaMitadDesde, segundaMitadHasta)),
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _observacionesController,
                enabled: !_registroCerrado,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Observaciones',
                  border: const OutlineInputBorder(),
                  filled: _registroCerrado,
                  fillColor: _registroCerrado ? Colors.grey[200] : null,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _registroCerrado
                          ? null
                          : () async {
                              try {
                                await Future.wait([
                                  _actualizarTodosLosDetalles(),
                                  _guardarFormulario(),
                                  _actualizarObservaciones(),
                                  _actualizarEstadoEnProceso(),
                                  _actualizarTiempos(),
                                ]);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Se guardaron correctamente')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error: ${e.toString()}')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _registroCerrado ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                          _registroCerrado ? 'Registro Cerrado' : 'Guardar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await generatePdf();
                      },
                      child: const Text('Exportar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _registroCerrado
                          ? null
                          : () {
                              _mostrarDialogoConfirmacion(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _registroCerrado ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_registroCerrado
                          ? 'Registro Cerrado'
                          : 'Cerrar Registro'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}