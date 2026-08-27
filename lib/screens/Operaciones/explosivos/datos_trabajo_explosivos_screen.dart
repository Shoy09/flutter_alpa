import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/PlanTrabajo.dart';
import 'package:i_miner/models/TipoPerforacion.dart';

class FormularioDatosTrabajoScreen extends StatefulWidget {
  final int
      exploracionId; // Se espera que se reciba el id; para un registro nuevo se puede pasar, por ejemplo, -1 o 0
  final VoidCallback? onEstadoActualizado;
  const FormularioDatosTrabajoScreen({
    Key? key,
    required this.exploracionId,
    this.onEstadoActualizado,
  }) : super(key: key);

  @override
  _FormularioDatosTrabajoScreenState createState() =>
      _FormularioDatosTrabajoScreenState();
}

class _FormularioDatosTrabajoScreenState
    extends State<FormularioDatosTrabajoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para campos de texto que se mantienen
  final _fechaController = TextEditingController();
  final _turnoController = TextEditingController();
  final _semanaDefaultController = TextEditingController();
  final _taladroController = TextEditingController();
  final _piesPorTaladroController = TextEditingController();
  final _seccionController = TextEditingController();
  bool _registroCerrado = false;


  // Variables para dropdowns (spinners) y listas de opciones
  String? _selectedTipoPlan;
  String? _selectedZona;
    String? _selectedEmpresa;
  String? _selectedTipoLabor;
  String? _selectedLabor;
  String? _selectedAla;
  String? _selectedVeta;
  String? _selectedNivel;
  String? _selectedTipoPerforacion;

  final List<String> _zonas = [];
  final List<String> _empresas = [];
  final List<String> _tiposLabor = [];
  final List<String> _labores = [];
  final List<String> _alas = [];
  final List<String> _vetas = [];
  final List<String> _niveles = [];
  final List<String> _tiposPerforacion = [];

  // Filtered lists for dropdowns
  List<String> _filteredTiposLabor = [];
  List<String> _filteredLabores = [];
  List<String> _filteredAlas = [];
  List<String> _filteredVetas = [];
  List<String> _filteredNiveles = [];

// Original plan data (keep this to filter against)
  List<PlanMensual> _planesCompletosmensual = [];
  List<PlanProduccion> _planesCompletosproduccion = [];
  List<PlanTrabajo> _planesCompletos = [];

String? seccion;

final DatabaseHelper dbHelper = DatabaseHelper();
  @override
  void dispose() {
    // Liberar recursos de controladores
    _fechaController.dispose();
    _turnoController.dispose();
    _semanaDefaultController.dispose();
    _taladroController.dispose();
    _piesPorTaladroController.dispose();
    _seccionController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData(widget.exploracionId);
    _verificarEstadoRegistro();
    _getPlanesCompletos();
    _getTiposPerforacion();
  }

  Future<void> _verificarEstadoRegistro() async {
    bool cerrado =
        await DatabaseHelper().estaRegistroCerrado(widget.exploracionId);
    setState(() {
      _registroCerrado = cerrado;
    });
  }

  Future<void> _actualizarEstadoEnProceso() async {
    if (widget.exploracionId > 0) {
      // Verifica que sea un ID válido
      await DatabaseHelper()
          .updateEstadoExploracion(widget.exploracionId, 'En proceso');

      // 🔹 Notificar al padre que el estado se actualizó
      if (widget.onEstadoActualizado != null) {
        widget.onEstadoActualizado!();
      }
    }
  }

  Future<void> _getTiposPerforacion() async {
    try {
      final dbHelper = DatabaseHelper();
      List<TipoPerforacion> tipos = await dbHelper.getTiposPerforacion();

      print("Tipos de Perforación obtenidos de la BD local: $tipos");

      // Usar un Set para evitar duplicados
      Set<String> tiposSet = {};

      for (var tipo in tipos) {
        var tipoMap = tipo.toMap();
        tiposSet.add(tipoMap['nombre'] ?? '');
      }

      // Actualizar el estado del widget con la lista filtrada
      setState(() {
        _tiposPerforacion.clear();
        _tiposPerforacion
            .addAll(tiposSet.where((element) => element.isNotEmpty));
      });
    } catch (e) {
      print("Error al obtener los tipos de perforación: $e");
    }
  }

  Future<void> _getPlanesCompletos() async {
    try {
      final List<PlanMensual> planesMensuales =
          await DatabaseHelper().getPlanes();
      final List<PlanProduccion> planesProduccion =
          await DatabaseHelper().getPlanesProduccion();

      List<PlanTrabajo> planesTrabajo = [];

      // Convertir PlanMensual a PlanTrabajo
      planesTrabajo.addAll(planesMensuales.map((plan) => PlanTrabajo(
            zona: plan.toMap()['zona'] ?? '',
            tipoLabor: plan.toMap()['tipo_labor'] ?? '',
            labor: plan.toMap()['labor'] ?? '',
            ala: plan.toMap()['ala'] ?? '',
            estructuraVeta: plan.toMap()['estructura_veta'] ?? '',
            nivel: plan.toMap()['nivel'] ?? '',
            empresa: plan.toMap()['empresa'],
          )));

      // Convertir PlanProduccion a PlanTrabajo
      planesTrabajo.addAll(planesProduccion.map((plan) => PlanTrabajo(
            zona: plan.toMap()['zona'] ?? '',
            tipoLabor: plan.toMap()['tipo_labor'] ?? '',
            labor: plan.toMap()['labor'] ?? '',
            ala: plan.toMap()['ala'] ?? '',
            estructuraVeta: plan.toMap()['estructura_veta'] ?? '',
            nivel: plan.toMap()['nivel'] ?? '',
          )));

      // Usar Sets para eliminar duplicados
      Set<String> zonasSet = {};
      Set<String> EmpresasSet = {};
      Set<String> tiposLaborSet = {};
      Set<String> laboresSet = {};
      Set<String> alaSet = {};
      Set<String> vetasSet = {};
      Set<String> nivelesSet = {};

      for (var plan in planesTrabajo) {
        zonasSet.add(plan.zona);
        EmpresasSet.addAll([if (plan.empresa != null) plan.empresa!]);
        tiposLaborSet.add(plan.tipoLabor);
        laboresSet.add(plan.labor);
        alaSet.add(plan.ala);
        vetasSet.add(plan.estructuraVeta);
        nivelesSet.add(plan.nivel);
      }

      // Actualizar estado
      setState(() {
        _planesCompletos = planesTrabajo;

        _zonas.clear();
        _zonas.addAll(zonasSet.where((e) => e.isNotEmpty));

        _empresas.clear();
        _empresas.addAll(EmpresasSet.where((e) => e.isNotEmpty));

        _tiposLabor.clear();
        _tiposLabor.addAll(tiposLaborSet.where((e) => e.isNotEmpty));

        _labores.clear();
        _labores.addAll(laboresSet.where((e) => e.isNotEmpty));

        _alas.clear();
        _alas.addAll(alaSet.where((e) => e.isNotEmpty));

        _vetas.clear();
        _vetas.addAll(vetasSet.where((e) => e.isNotEmpty));

        _niveles.clear();
        _niveles.addAll(nivelesSet.where((e) => e.isNotEmpty));

        _filteredTiposLabor = List.from(_tiposLabor);
        _filteredLabores = List.from(_labores);
        _filteredAlas = List.from(_alas);
        _filteredVetas = List.from(_vetas);
        _filteredNiveles = List.from(_niveles);
      });
    } catch (e) {
      print("Error al obtener los planes: $e");
    }
  }

  void _updateFilteredLists() {
    setState(() {
      // Filter Tipos Labor based on selected Zona
      if (_selectedZona != null) {
        _filteredTiposLabor = _planesCompletos
            .where((plan) => plan.zona == _selectedZona)
            .map((plan) => plan.tipoLabor)
            .where((tipoLabor) => tipoLabor != null && tipoLabor.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _filteredTiposLabor = List.from(_tiposLabor);
      }

      // If current selection is no longer valid, reset it
      if (_selectedTipoLabor != null &&
          !_filteredTiposLabor.contains(_selectedTipoLabor)) {
        _selectedTipoLabor = null;
      }

      // Filter Labores based on selected Zona and TipoLabor
      if (_selectedZona != null || _selectedTipoLabor != null) {
        _filteredLabores = _planesCompletos
            .where((plan) =>
                (_selectedZona == null || plan.zona == _selectedZona) &&
                (_selectedTipoLabor == null ||
                    plan.tipoLabor == _selectedTipoLabor))
            .map((plan) => plan.labor)
            .where((labor) => labor != null && labor.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _filteredLabores = List.from(_labores);
      }

      // Reset Labor if no longer valid
      if (_selectedLabor != null &&
          !_filteredLabores.contains(_selectedLabor)) {
        _selectedLabor = null;
      }

      // Filter Alas based on selected Zona, TipoLabor and Labor
      if (_selectedZona != null ||
          _selectedTipoLabor != null ||
          _selectedLabor != null) {
        _filteredAlas = _planesCompletos
            .where((plan) =>
                (_selectedZona == null || plan.zona == _selectedZona) &&
                (_selectedTipoLabor == null ||
                    plan.tipoLabor == _selectedTipoLabor) &&
                (_selectedLabor == null || plan.labor == _selectedLabor))
            .map((plan) => plan.ala)
            .where((ala) => ala != null && ala.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _filteredAlas = List.from(_alas);
      }

      // Reset Ala if no longer valid
      if (_selectedAla != null && !_filteredAlas.contains(_selectedAla)) {
        _selectedAla = null;
      }

      // Filter Vetas based on previous selections (including Ala)
      if (_selectedZona != null ||
          _selectedTipoLabor != null ||
          _selectedLabor != null ||
          _selectedAla != null) {
        _filteredVetas = _planesCompletos
            .where((plan) =>
                (_selectedZona == null || plan.zona == _selectedZona) &&
                (_selectedTipoLabor == null ||
                    plan.tipoLabor == _selectedTipoLabor) &&
                (_selectedLabor == null || plan.labor == _selectedLabor) &&
                (_selectedAla == null || plan.ala == _selectedAla))
            .map((plan) => plan.estructuraVeta)
            .where((veta) => veta != null && veta.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _filteredVetas = List.from(_vetas);
      }

      // Reset Veta if no longer valid
      if (_selectedVeta != null && !_filteredVetas.contains(_selectedVeta)) {
        _selectedVeta = null;
      }

      // Filter Niveles based on all previous selections (including Ala)
      if (_selectedZona != null ||
          _selectedTipoLabor != null ||
          _selectedLabor != null ||
          _selectedVeta != null ||
          _selectedAla != null) {
        _filteredNiveles = _planesCompletos
            .where((plan) =>
                (_selectedZona == null || plan.zona == _selectedZona) &&
                (_selectedTipoLabor == null ||
                    plan.tipoLabor == _selectedTipoLabor) &&
                (_selectedLabor == null || plan.labor == _selectedLabor) &&
                (_selectedVeta == null ||
                    plan.estructuraVeta == _selectedVeta) &&
                (_selectedAla == null || plan.ala == _selectedAla))
            .map((plan) => plan.nivel)
            .where((nivel) => nivel != null && nivel.isNotEmpty)
            .toSet()
            .toList();
      } else {
        _filteredNiveles = List.from(_niveles);
      }

      // Reset Nivel if no longer valid
      if (_selectedNivel != null &&
          !_filteredNiveles.contains(_selectedNivel)) {
        _selectedNivel = null;
      }
    });
  }

void obtenerPlanMensual() async {
  if (_selectedZona == null ||
      _selectedTipoLabor == null ||
      _selectedLabor == null ||
      _selectedVeta == null ||
      _selectedNivel == null) {
    print("Por favor, selecciona todos los campos necesarios.");
    return;
  }

  var resultado = await dbHelper.getPlanMensual(
    zona: _selectedZona!,
    tipoLabor: _selectedTipoLabor!,
    labor: _selectedLabor!,
    estructuraVeta: _selectedVeta!,
    nivel: _selectedNivel!,
  );

  print("RESULTADO COMPLETO: $resultado");

  if (resultado != null) {
    double ancho = resultado['ancho_m'];
    double alto = resultado['alto_m'];
    seccion = '${ancho.toStringAsFixed(2)}m x ${alto.toStringAsFixed(2)}m';
    _seccionController.text = seccion!;
    print("Dimensión: $seccion");
    setState(() {});
  } else {
    print("No se encontró ningún registro.");
    seccion = '';
    _seccionController.text = '';
    setState(() {});
  }
}

  // Cargar datos desde la BD para el id dado
  void _loadData(int id) async {
    var registro = await DatabaseHelper().getExploracionById(id);
    print('datos Explo, $registro');
    if (registro != null) {
      // Si se encontraron datos, se rellenan los campos con la información existente
      _fechaController.text = registro['fecha'] ?? "";
      _turnoController.text = registro['turno'] ?? "";
      _semanaDefaultController.text = registro['semanaDefault'] ?? "";
      _selectedEmpresa = registro['empresa'] ?? "";
      _taladroController.text = registro['taladro'] ?? "";
      _piesPorTaladroController.text = registro['pies_por_taladro'] ?? "";
      _seccionController.text = registro['seccion'] ?? "";

      _selectedZona = registro['zona'];
      _selectedTipoLabor = registro['tipo_labor'];
      _selectedLabor = registro['labor'];
      _selectedAla = registro['ala'];
      _selectedVeta = registro['veta'];
      _selectedNivel = registro['nivel'];
      _selectedTipoPerforacion = registro['tipo_perforacion'];
    }
    setState(() {});
  }

  // Método para guardar el formulario (insertar o actualizar según la existencia del registro)
Future<void> _guardarFormulario() async {
  if (_formKey.currentState!.validate()) {
    Map<String, dynamic> datos = {
      'fecha': _fechaController.text,
      'turno': _turnoController.text,
      'semanaDefault': _semanaDefaultController.text,
      'empresa': _selectedEmpresa,
      'taladro': _taladroController.text,
      'pies_por_taladro': _piesPorTaladroController.text,
      'zona': _selectedZona,
      'tipo_labor': _selectedTipoLabor,
      'labor': _selectedLabor,
      'ala': _selectedAla,
      'veta': _selectedVeta,
      'nivel': _selectedNivel,
      'seccion': _seccionController.text,
      'tipo_perforacion': _selectedTipoPerforacion,
    };

    // 🟨 Mostrar datos en consola
    print('📤 Datos a guardar/actualizar en la BD: $datos');

    // Si ya existe un registro para este id, se actualiza; de lo contrario, se inserta uno nuevo.
    var registroExistente =
        await DatabaseHelper().getExploracionById(widget.exploracionId);
    if (registroExistente != null) {
      print('🔄 Actualizando registro con ID: ${widget.exploracionId}');
      await DatabaseHelper().updateExploracion(widget.exploracionId, datos);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos actualizados correctamente')),
      );
    } else {
      print('🆕 Insertando nuevo registro');
      await DatabaseHelper().insertExploracionFull(datos);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos guardados correctamente')),
      );
    }
  }
}


  // Función para simplificar la decoración de los campos
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Definimos un punto de ruptura para cambiar el diseño
            bool isSmallScreen = constraints.maxWidth < 600; // Típico para móviles
            bool isMediumScreen = constraints.maxWidth >= 600 && constraints.maxWidth < 900; // Tablets
            bool isLargeScreen = constraints.maxWidth >= 900; // PC

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------- Campos principales ---------
                Column(
                  children: [
                    // Primera fila de campos (Fecha, Turno, Semana)
                    if (isLargeScreen)
                      _buildLargeScreenFirstRow()
                    else if (isMediumScreen)
                      _buildMediumScreenFirstRow()
                    else
                      _buildSmallScreenFirstRow(),

                    const SizedBox(height: 10),

                    // Segunda fila de campos (Empresa, Zona, Tipo de Labor)
                    if (isLargeScreen)
                      _buildLargeScreenSecondRow()
                    else if (isMediumScreen)
                      _buildMediumScreenSecondRow()
                    else
                      _buildSmallScreenSecondRow(),

                    const SizedBox(height: 10),

                    // Tercera fila de campos (Labor, Ala, Veta)
                    if (isLargeScreen)
                      _buildLargeScreenThirdRow()
                    else if (isMediumScreen)
                      _buildMediumScreenThirdRow()
                    else
                      _buildSmallScreenThirdRow(),

                    const SizedBox(height: 10),

                    // Cuarta fila de campos (Nivel, Tipo Perforación, Taladros)
                    if (isLargeScreen)
                      _buildLargeScreenFourthRow()
                    else if (isMediumScreen)
                      _buildMediumScreenFourthRow()
                    else
                      _buildSmallScreenFourthRow(),

                    const SizedBox(height: 10),

                    // Quinta fila de campos (Pies por taladro)
                    if (isLargeScreen || isMediumScreen)
                      _buildNormalScreenFifthRow()
                    else
                      _buildSmallScreenFifthRow(),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _guardarFormulario();
                      await _actualizarEstadoEnProceso();
                    },
                    child: Text('Guardar'),
                  ),
                ),
                SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    ),
  );
}

// Métodos para construir las filas según el tamaño de pantalla

Widget _buildLargeScreenFirstRow() {
  return Row(
    children: [
      Expanded(child: _buildFechaField()),
      const SizedBox(width: 10),
      Expanded(child: _buildTurnoField()),
      const SizedBox(width: 10),
      Expanded(child: _buildSemanaDefaultField()),
    ],
  );
}

Widget _buildMediumScreenFirstRow() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _buildFechaField()),
          const SizedBox(width: 10),
          Expanded(child: _buildTurnoField()),
        ],
      ),
      const SizedBox(height: 10),
      _buildSemanaDefaultField(),
    ],
  );
}

Widget _buildSmallScreenFirstRow() {
  return Column(
    children: [
      _buildFechaField(),
      const SizedBox(height: 10),
      _buildTurnoField(),
      const SizedBox(height: 10),
      _buildSemanaDefaultField(),
    ],
  );
}

Widget _buildLargeScreenSecondRow() {
  return Row(
    children: [
      Expanded(child: _buildEmpresaDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildZonaDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildTipoLaborDropdown()),
    ],
  );
}

Widget _buildMediumScreenSecondRow() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _buildEmpresaDropdown()),
          const SizedBox(width: 10),
          Expanded(child: _buildZonaDropdown()),
        ],
      ),
      const SizedBox(height: 10),
      _buildTipoLaborDropdown(),
    ],
  );
}

Widget _buildSmallScreenSecondRow() {
  return Column(
    children: [
      _buildEmpresaDropdown(),
      const SizedBox(height: 10),
      _buildZonaDropdown(),
      const SizedBox(height: 10),
      _buildTipoLaborDropdown(),
    ],
  );
}

Widget _buildLargeScreenThirdRow() {
  return Row(
    children: [
      Expanded(child: _buildLaborDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildAlaDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildVetaDropdown()),
    ],
  );
}

Widget _buildMediumScreenThirdRow() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _buildLaborDropdown()),
          const SizedBox(width: 10),
          Expanded(child: _buildAlaDropdown()),
        ],
      ),
      const SizedBox(height: 10),
      _buildVetaDropdown(),
    ],
  );
}

Widget _buildSmallScreenThirdRow() {
  return Column(
    children: [
      _buildLaborDropdown(),
      const SizedBox(height: 10),
      _buildAlaDropdown(),
      const SizedBox(height: 10),
      _buildVetaDropdown(),
    ],
  );
}

Widget _buildLargeScreenFourthRow() {
  return Row(
    children: [
      Expanded(child: _buildNivelDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildSeccionfaultField()),
      const SizedBox(width: 10),
      Expanded(child: _buildTipoPerforacionDropdown()),
      const SizedBox(width: 10),
      Expanded(child: _buildTaladroField()),
    ],
  );
}

Widget _buildMediumScreenFourthRow() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _buildNivelDropdown()),
          const SizedBox(width: 10),
          Expanded(child: _buildSeccionfaultField()),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _buildTipoPerforacionDropdown()),
          const SizedBox(width: 10),
          Expanded(child: _buildTaladroField()),
        ],
      ),
    ],
  );
}

Widget _buildSmallScreenFourthRow() {
  return Column(
    children: [
      _buildNivelDropdown(),
      const SizedBox(height: 10),
      _buildSeccionfaultField(),
      const SizedBox(height: 10),
      _buildTipoPerforacionDropdown(),
      const SizedBox(height: 10),
      _buildTaladroField(),
    ],
  );
}

// Mueve el quinto campo (Pies por taladro) a una nueva fila (ahora sería la sexta fila)
Widget _buildNormalScreenFifthRow() {
  return Row(
    children: [
      Expanded(child: _buildPiesPorTaladroField()),
      const SizedBox(width: 10),
      Expanded(child: Container()), // Espacio vacío para mantener el diseño
      const SizedBox(width: 10),
      Expanded(child: Container()), // Espacio vacío para mantener el diseño
    ],
  );
}

Widget _buildSmallScreenFifthRow() {
  return Column(
    children: [
      _buildPiesPorTaladroField(),
    ],
  );
}
// Métodos para construir los campos individuales (reutilizables)

Widget _buildFechaField() {
  return TextFormField(
    controller: _fechaController,
    enabled: !_registroCerrado,
    decoration: const InputDecoration(
      labelText: 'Fecha',
      hintText: 'YYYY-MM-DD',  // Indicamos claramente el formato esperado
    ),
    onChanged: (value) {
      try {
        DateTime? parsedDate;
        
        // Intenta parsear como YYYY-MM-DD (formato deseado)
        if (value.contains('-') && value.length >= 10) {
          final parts = value.split('-');
          if (parts.length == 3) {
            parsedDate = DateTime(
              int.parse(parts[0]),  // Año
              int.parse(parts[1]),  // Mes
              int.parse(parts[2]),  // Día
            );
          }
        }
        // Intenta parsear como DD/MM/YYYY (formato alternativo)
        else if (value.contains('/') && value.length >= 10) {
          final parts = value.split('/');
          if (parts.length == 3) {
            parsedDate = DateTime(
              int.parse(parts[2]),  // Año
              int.parse(parts[1]),  // Mes
              int.parse(parts[0]),  // Día
            );
          }
        }

        // Si se pudo parsear, actualiza el campo en formato YYYY-MM-DD
        if (parsedDate != null) {
          final formattedDate = 
            '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
          
          // Evita un bucle infinito de onChanged
          if (_fechaController.text != formattedDate) {
            _fechaController.text = formattedDate;
            _fechaController.selection = TextSelection.fromPosition(
              TextPosition(offset: formattedDate.length),
            );
          }

          // Calcula la semana
          final semana = obtenerNumeroSemana(parsedDate);
          _semanaDefaultController.text = "Semana $semana";
        }
      } catch (e) {
        print('Error al procesar la fecha: $e');
      }
    },
  );
}

// Función mejorada para calcular la semana ISO
int obtenerNumeroSemana(DateTime fecha) {
  // Ajustar la fecha para que la semana comience en lunes (ISO 8601)
  final adjustedDate = fecha.weekday == 7 ? fecha.add(const Duration(days: 1)) : fecha;
  
  // Primer día del año
  final startOfYear = DateTime(fecha.year, 1, 1);
  
  // Diferencia en días
  final difference = adjustedDate.difference(startOfYear).inDays;
  
  // Calcular el número de semana
  return ((difference + startOfYear.weekday + 6) / 7).floor();
}

Widget _buildTurnoField() {
  return TextFormField(
    controller: _turnoController,
    enabled: !_registroCerrado,
    decoration: const InputDecoration(
      labelText: 'Turno',
    ),
  );
}

Widget _buildSemanaDefaultField() {
  return TextFormField(
    controller: _semanaDefaultController,
    enabled: !_registroCerrado,
    decoration: const InputDecoration(
      labelText: 'Semana por defecto',
    ),
  );
}

Widget _buildSeccionfaultField() {
  return TextFormField(
    controller: _seccionController,
    readOnly: true,
    enabled: false, // hace que se vea "deshabilitado"
    decoration: const InputDecoration(
      labelText: 'Sección',
    ),
  );
}


Widget _buildEmpresaDropdown() {
  final isValueValid = _empresas.contains(_selectedEmpresa);
  
  return DropdownButtonFormField<String>(
    value: isValueValid ? _selectedEmpresa : null,
    decoration:  InputDecoration(
      labelText: 'Empresa',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _empresas.map((empresa) {
      return DropdownMenuItem<String>(
        value: empresa,
        child: Text(empresa),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedEmpresa = value;
      });
    },
  );
}


Widget _buildZonaDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedZona,
    decoration: InputDecoration(
    labelText: 'Zona',
    filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _zonas.map((zona) {
      return DropdownMenuItem<String>(
        value: zona,
        child: Text(zona),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedZona = value;
        // Reset dependent fields
        _selectedTipoLabor = null;
        _selectedLabor = null;
        _selectedAla = null;
        _selectedVeta = null;
        _selectedNivel = null;
        // Update filtered lists
        _updateFilteredLists();
      });
    },
  );
}

Widget _buildTipoLaborDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedTipoLabor,
    decoration: InputDecoration(
      labelText: 'Tipo de Labor',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _filteredTiposLabor.map((tipo) {
      return DropdownMenuItem<String>(
        value: tipo,
        child: Text(tipo),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedTipoLabor = value;
        // Reset dependent fields
        _selectedLabor = null;
        _selectedAla = null;
        _selectedVeta = null;
        _selectedNivel = null;
        // Update filtered lists
        _updateFilteredLists();
      });
    },
  );
}

Widget _buildLaborDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedLabor,
    decoration: InputDecoration(
      labelText: 'Labor',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _filteredLabores.map((labor) {
      return DropdownMenuItem<String>(
        value: labor,
        child: Text(labor),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedLabor = value;
        // Reset dependent fields
        _selectedAla = null;
        _selectedVeta = null;
        _selectedNivel = null;
        // Update filtered lists
        _updateFilteredLists();
      });
    },
  );
}

Widget _buildAlaDropdown() {
  return DropdownButtonFormField<String>(
    value: _filteredAlas.contains(_selectedAla) ? _selectedAla : null,
    decoration: InputDecoration(
      labelText: 'Ala',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _filteredAlas.map((ala) {
      return DropdownMenuItem<String>(
        value: ala,
        child: Text(ala),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedAla = value;
        _selectedVeta = null;
        _selectedNivel = null;
        _updateFilteredLists();
      });
    },
  );
}

Widget _buildVetaDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedVeta,
    decoration: InputDecoration(
      labelText: 'Veta',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _filteredVetas.map((veta) {
      return DropdownMenuItem<String>(
        value: veta,
        child: Text(veta),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedVeta = value;
        // Reset dependent fields
        _selectedNivel = null;
        // Update filtered lists
        _updateFilteredLists();
      });
    },
  );
}

Widget _buildNivelDropdown() {
  return DropdownButtonFormField<String>(
    value: _filteredNiveles.contains(_selectedNivel) ? _selectedNivel : null,
    decoration: InputDecoration(
      labelText: 'Nivel',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _filteredNiveles.map((nivel) {
      return DropdownMenuItem<String>(
        value: nivel,
        child: Text(nivel),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedNivel = value;
        // Ejecutamos la búsqueda al seleccionar el nivel
        if (_selectedZona != null &&
            _selectedTipoLabor != null &&
            _selectedLabor != null &&
            _selectedVeta != null &&
            _selectedNivel != null) {
          obtenerPlanMensual();
        }
      });
    },
  );
}


Widget _buildTipoPerforacionDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedTipoPerforacion,
    decoration: InputDecoration(
      labelText: 'Tipo de Perforación',
      filled: _registroCerrado,
      fillColor: _registroCerrado ? Colors.grey[200] : null,
    ),
    items: _tiposPerforacion.map((tipo) {
      return DropdownMenuItem<String>(
        value: tipo,
        child: Text(tipo),
      );
    }).toList(),
    onChanged: _registroCerrado ? null : (value) {
      setState(() {
        _selectedTipoPerforacion = value;
      });
    },
  );
}

Widget _buildTaladroField() {
  return TextFormField(
    controller: _taladroController,
    enabled: !_registroCerrado,
    decoration: const InputDecoration(
      labelText: 'N° TAL DISP.',
    ),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  );
}

Widget _buildPiesPorTaladroField() {
  return TextFormField(
    controller: _piesPorTaladroController,
    enabled: !_registroCerrado,
    decoration: const InputDecoration(
      labelText: 'Pies por taladro',
    ),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  );
}
}
