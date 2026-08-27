// import 'package:app_seminco/database/database_helper_mina_2.dart';
// import 'package:app_seminco/mina%202/screens/Mediciones/listar_mediciones.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class RegistroExplosivoPage extends StatefulWidget {
//   @override
//   _RegistroExplosivoPageState createState() => _RegistroExplosivoPageState();
// }

// class _RegistroExplosivoPageState extends State<RegistroExplosivoPage> {
//   final TextEditingController mesController = TextEditingController();
//   final TextEditingController semanaController = TextEditingController();
//   List<Map<String, dynamic>> exploraciones = [];
//   List<Map<String, dynamic>> exploracionesFiltradas = [];
//   Map<String, Map<String, List<Map<String, dynamic>>>> datosEditables = {};
//   Map<String, TextEditingController> controllers = {};

//   // Función para crear una copia editable de los datos
//   Map<String, dynamic> _crearCopiaEditable(Map<String, dynamic> original) {
//     return {
//       'labor': original['labor'],
//       'kg': original['kg'],
//       'avance': original['avance'],
//       'ancho': original['ancho'],
//       'alto': original['alto'],
//       // Agrega aquí otros campos que necesites editar
//     };
//   }

//   // Función para calcular el número de semana ISO
//   int _calcularSemanaISO(DateTime date) {
//     final dayOfYear = _diaDelAnio(date);
//     final woy = ((dayOfYear - date.weekday + 10) / 7).floor();

//     if (woy < 1) {
//       return _calcularSemanaISO(DateTime(date.year - 1, 12, 31));
//     } else if (woy > 52 && DateTime(date.year, 12, 31).weekday < 4) {
//       return 1;
//     }
//     return woy;
//   }

//   int _diaDelAnio(DateTime date) {
//     final startOfYear = DateTime(date.year, 1, 1);
//     return date.difference(startOfYear).inDays + 1;
//   }

//   final List<String> meses = [
//     'Enero',
//     'Febrero',
//     'Marzo',
//     'Abril',
//     'Mayo',
//     'Junio',
//     'Julio',
//     'Agosto',
//     'Septiembre',
//     'Octubre',
//     'Noviembre',
//     'Diciembre'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     mesController.text = meses[now.month - 1];
//     semanaController.text = _calcularSemanaISO(now).toString();
//     _cargarExploracionesPendientes();
//   }

//   void _cargarExploracionesPendientes() async {
//     try {
//       print('Cargando exploraciones pendientes...');
//       exploraciones = await DatabaseHelper_Mina2().getExploraciones();
//       print('Registros encontrados: ${exploraciones.length}');

//       // Aplicar filtro inicial
//       _filtrarDatos();
//     } catch (e) {
//       print('Error al cargar exploraciones: $e');
//     }
//   }

//   void _filtrarDatos() {
//     final mesSeleccionado = mesController.text;
//     final semanaSeleccionada = semanaController.text;

//     // Convertir mes a número (1-12)
//     final mesNumero = meses.indexOf(mesSeleccionado) + 1;

//     // Filtrar por mes y semana
//     exploracionesFiltradas = exploraciones.where((registro) {
//       try {
//         final fecha = DateTime.parse(registro['fecha']);
//         final semanaRegistro = _calcularSemanaISO(fecha).toString();

//         return fecha.month == mesNumero && semanaRegistro == semanaSeleccionada;
//       } catch (e) {
//         print('Error al procesar fecha: ${registro['fecha']}');
//         return false;
//       }
//     }).toList();

//     // Crear estructura de datos editables
//     datosEditables = {};
//     for (var registro in exploracionesFiltradas) {
//       final tipo = registro['tipo_perforacion'] ?? 'Sin tipo';
//       final labor = registro['labor'] ?? 'Sin labor';

//       if (!datosEditables.containsKey(tipo)) {
//         datosEditables[tipo] = {};
//       }
//       if (!datosEditables[tipo]!.containsKey(labor)) {
//         datosEditables[tipo]![labor] = [];
//       }
//       datosEditables[tipo]![labor]!.add(_crearCopiaEditable(registro));
//     }

//     setState(() {});
//   }

//   void borrarCampos() {
//     mesController.clear();
//     semanaController.clear();
//     setState(() {});
//   }

//   Future<void> _enviarDatosPorTipo(String tipoPerforacion) async {
//     final detalles = datosEditables[tipoPerforacion]?.entries.map((laborEntry) {
//       final labor = laborEntry.key;
//       final registros = laborEntry.value;
//       final primerRegistro = registros.first;

//       return {
//         'labor': labor,
//         'cant_regis': registros.length,
//         'kg_explo': primerRegistro['kg'] ?? 0,
//         'avance': primerRegistro['avance'] ?? 0,
//         'ancho': primerRegistro['ancho'] ?? 0,
//         'alto': primerRegistro['alto'] ?? 0,
//       };
//     }).toList();

//     if (detalles == null || detalles.isEmpty) return;

//     final db = await DatabaseHelper_Mina2().database;
//     final success = await DatabaseHelper_Mina2().insertarPerforacionConDetalles(
//       db: db,
//       mes: mesController.text,
//       semana: semanaController.text,
//       tipoPerforacion: tipoPerforacion,
//       detalles: detalles,
//     );

//     if (success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Datos de $tipoPerforacion guardados correctamente'),
//           duration: Duration(seconds: 2),
//         ),
//       );

//       // Actualizar la lista de exploraciones para reflejar los cambios
//       _cargarExploracionesPendientes();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error al guardar datos de $tipoPerforacion'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   }

//   void buscarDatos() {
//     _filtrarDatos();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//             'Filtrando datos para ${mesController.text}, semana ${semanaController.text}'),
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }

//   void actualizarValor(String tipoPerforacion, String labor, int index,
//       String campo, String nuevoValor) {
//     setState(() {
//       // Convertimos a double solo si hay valor, sino null
//       final valor = nuevoValor.isEmpty ? null : double.tryParse(nuevoValor);

//       switch (campo) {
//         case "kg":
//           datosEditables[tipoPerforacion]![labor]![index]["kg"] = valor;
//           break;
//         case "avance":
//           datosEditables[tipoPerforacion]![labor]![index]["avance"] = valor;
//           break;
//         case "ancho":
//           datosEditables[tipoPerforacion]![labor]![index]["ancho"] = valor;
//           break;
//         case "alto":
//           datosEditables[tipoPerforacion]![labor]![index]["alto"] = valor;
//           break;
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Mediciones'),
//         backgroundColor: Color(0xFF21899C),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.list),
//             onPressed: () {
//               // Navigator.push(
//               //   context,
//               //   MaterialPageRoute(builder: (context) => ListaPantalla()),
//               // );
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Filtros
//             Row(
//               children: [
//                 Flexible(
//                   flex: 3,
//                   child: DropdownButtonFormField<String>(
//                     value:
//                         mesController.text.isEmpty ? null : mesController.text,
//                     decoration: InputDecoration(
//                       labelText: 'Mes',
//                       border: OutlineInputBorder(),
//                       isDense: true,
//                     ),
//                     items: meses.map((String mes) {
//                       return DropdownMenuItem<String>(
//                         value: mes,
//                         child: Text(mes),
//                       );
//                     }).toList(),
//                     onChanged: (String? newValue) {
//                       setState(() {
//                         mesController.text = newValue ?? '';
//                       });
//                     },
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 Flexible(
//                   flex: 1,
//                   child: TextField(
//                     controller: semanaController,
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(2),
//                     ],
//                     decoration: InputDecoration(
//                       labelText: 'Semana',
//                       border: OutlineInputBorder(),
//                       isDense: true,
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 ElevatedButton.icon(
//                   icon: Icon(Icons.search, size: 20),
//                   label: Text('Buscar'),
//                   onPressed: buscarDatos,
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 20),

//             // Tablas dinámicas por tipo de perforación
//             Expanded(
//               child: ListView(
//                 children: datosEditables.entries.map((tipoEntry) {
//                   final tipoPerforacion = tipoEntry.key;
//                   final labores = tipoEntry.value;

//                   return Card(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(15.0),
//                     ),
//                     elevation: 3,
//                     margin: EdgeInsets.only(bottom: 16),
//                     child: ExpansionTile(
//                       title: Text(
//                         tipoPerforacion,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       initiallyExpanded: false,
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                           child: Column(
//                             children: [
//                               // Tabla dinámica
//                               SingleChildScrollView(
//                                 scrollDirection: Axis.vertical,
//                                 child: Table(
//                                   border: TableBorder.all(
//                                     borderRadius: BorderRadius.circular(8),
//                                     color: Colors.grey,
//                                   ),
//                                   columnWidths: const {
//                                     0: FlexColumnWidth(2),
//                                     1: FlexColumnWidth(2),
//                                     2: FlexColumnWidth(2),
//                                     3: FlexColumnWidth(2),
//                                     4: FlexColumnWidth(2),
//                                   },
//                                   children: [
//                                     TableRow(
//                                       decoration: BoxDecoration(
//                                         color: Colors.grey[300],
//                                         borderRadius: BorderRadius.vertical(
//                                             top: Radius.circular(8)),
//                                       ),
//                                       children: [
//                                         tableCellBold(context,
//                                             tipoPerforacion.toUpperCase()),
//                                         tableCellBold(context, 'Cantidad'),
//                                         tableCellBold(context, 'Kg explosivo'),
//                                         tableCellBold(context, 'Avance'),
//                                         tableCellBold(context, 'Ancho'),
//                                         tableCellBold(context, 'Alto'),
//                                       ],
//                                     ),

//                                     // Filas agrupadas por labor
//                                     for (var laborEntry in labores.entries)
//                                       TableRow(children: [
//                                         tableCell(laborEntry.key),
//                                         tableCell(
//                                             laborEntry.value.length.toString()),
//                                         tableCellEditable(
//                                             tipoPerforacion,
//                                             laborEntry.key,
//                                             0,
//                                             'kg',
//                                             laborEntry.value[0]['kg']),
//                                         tableCellEditable(
//                                             tipoPerforacion,
//                                             laborEntry.key,
//                                             0,
//                                             'avance',
//                                             laborEntry.value[0]['avance']),
//                                         tableCellEditable(
//                                             tipoPerforacion,
//                                             laborEntry.key,
//                                             0,
//                                             'ancho',
//                                             laborEntry.value[0]['ancho']),
//                                         tableCellEditable(
//                                             tipoPerforacion,
//                                             laborEntry.key,
//                                             0,
//                                             'alto',
//                                             laborEntry.value[0]['alto']),
//                                       ]),
//                                   ],
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                               // Botones para esta tabla específica
//                               Padding(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 8.0),
//                                 child: Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceEvenly,
//                                   children: [
//                                     ElevatedButton.icon(
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.red,
//                                         padding: EdgeInsets.symmetric(
//                                             horizontal: 16, vertical: 12),
//                                       ),
//                                       icon: Icon(Icons.delete, size: 18),
//                                       onPressed: borrarCampos,
//                                       label: Text('BORRAR'),
//                                     ),
//                                     SizedBox(width: 10),
//                                     ElevatedButton.icon(
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.green,
//                                         padding: EdgeInsets.symmetric(
//                                             horizontal: 16, vertical: 12),
//                                       ),
//                                       icon: Icon(Icons.send, size: 18),
//                                       onPressed: () =>
//                                           _enviarDatosPorTipo(tipoPerforacion),
//                                       label: Text('ENVIAR'),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget tableCellEditable(String tipoPerforacion, String labor, int index,
//       String campo, dynamic valor) {
//     final key = '$tipoPerforacion-$labor-$index-$campo';

//     if (!controllers.containsKey(key)) {
//       controllers[key] = TextEditingController(text: valor?.toString() ?? '');
//     }

//     final controller = controllers[key]!;

//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: TextField(
//         controller: controller,
//         onChanged: (newValue) {
//           if (newValue.isEmpty || double.tryParse(newValue) != null) {
//             actualizarValor(tipoPerforacion, labor, index, campo, newValue);
//           } else {
//             controller.text = valor?.toString() ?? '';
//             controller.selection = TextSelection.fromPosition(
//                 TextPosition(offset: controller.text.length));
//           }
//         },
//         keyboardType: TextInputType.numberWithOptions(decimal: true),
//         decoration: InputDecoration(
//           border: OutlineInputBorder(),
//           isDense: true,
//           contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//         ),
//         inputFormatters: [
//           FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
//         ],
//       ),
//     );
//   }

//   Widget tableCell(String text) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Center(child: Text(text)),
//     );
//   }

//   Widget tableCellBold(BuildContext context, String text) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double fontSize =
//         screenWidth < 600 ? 10 : 16; // Ajusta el umbral y tamaños a gusto

//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Center(
//         child: Text(
//           text,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: fontSize,
//           ),
//         ),
//       ),
//     );
//   }
// }
