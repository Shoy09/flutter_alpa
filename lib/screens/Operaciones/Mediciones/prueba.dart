// import 'package:flutter/material.dart';
// import 'package:i_miner/config/data/database_helper.dart';

// class ExploracionesScreen extends StatefulWidget {
//   const ExploracionesScreen({Key? key}) : super(key: key);

//   @override
//   _ExploracionesScreenState createState() => _ExploracionesScreenState();
// }

// class _ExploracionesScreenState extends State<ExploracionesScreen> {
//   List<Map<String, dynamic>> _exploraciones = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _cargarExploraciones();
//   }

// Future<void> _cargarExploraciones() async {
//   try {
//     final dbHelper = DatabaseHelper();
//     final exploraciones = await dbHelper.obtenerExploracionesCompletas();
    
//     setState(() {
//       _exploraciones = exploraciones;
//       _isLoading = false;
//     });
//   } catch (e) {
//     setState(() {
//       _isLoading = false;
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Error al cargar exploraciones: $e')),
//     );
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Exploraciones')),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _exploraciones.length,
//               itemBuilder: (context, index) {
//                 final exploracion = _exploraciones[index];
//                 return ExpansionTile(
//                   title: Text('Exploración ${exploracion['idnube']} - ${exploracion['fecha']}'),
//                   subtitle: Text('Taladro: ${exploracion['taladro']} - Turno: ${exploracion['turno']}'),
//                   children: [
//                     // Aquí puedes mostrar los detalles, despachos y devoluciones
//                     _buildDespachosSection(exploracion['despachos']),
//                     _buildDevolucionesSection(exploracion['devoluciones']),
//                   ],
//                 );
//               },
//             ),
//     );
//   }

//   Widget _buildDespachosSection(List<dynamic> despachos) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(8.0),
//           child: Text('Despachos:', style: TextStyle(fontWeight: FontWeight.bold)),
//         ),
//         ...despachos.map((despacho) => _buildDespachoCard(despacho)).toList(),
//       ],
//     );
//   }

//   Widget _buildDespachoCard(Map<String, dynamic> despacho) {
//     return Card(
//       margin: const EdgeInsets.all(8.0),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Despacho ID: ${despacho['id']}'),
//             const SizedBox(height: 8),
//             const Text('Materiales:', style: TextStyle(fontWeight: FontWeight.bold)),
//             ...despacho['detalles'].map<Widget>((detalle) => 
//               Text('- ${detalle['nombre_material']}: ${detalle['cantidad']}')),
//             const SizedBox(height: 8),
//             const Text('Explosivos:', style: TextStyle(fontWeight: FontWeight.bold)),
//             ...despacho['detalles_explosivos'].map<Widget>((explosivo) => 
//               Text('- N°${explosivo['numero']}: MS ${explosivo['ms_cant1']}, LP ${explosivo['lp_cant1']}')),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDevolucionesSection(List<dynamic> devoluciones) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(8.0),
//           child: Text('Devoluciones:', style: TextStyle(fontWeight: FontWeight.bold)),
//         ),
//         ...devoluciones.map((devolucion) => _buildDevolucionCard(devolucion)).toList(),
//       ],
//     );
//   }

//   Widget _buildDevolucionCard(Map<String, dynamic> devolucion) {
//     return Card(
//       margin: const EdgeInsets.all(8.0),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Devolución ID: ${devolucion['id']}'),
//             const SizedBox(height: 8),
//             const Text('Materiales devueltos:', style: TextStyle(fontWeight: FontWeight.bold)),
//             ...devolucion['detalles'].map<Widget>((detalle) => 
//               Text('- ${detalle['nombre_material']}: ${detalle['cantidad']}')),
//             const SizedBox(height: 8),
//             const Text('Explosivos devueltos:', style: TextStyle(fontWeight: FontWeight.bold)),
//             ...devolucion['detalles_explosivos'].map<Widget>((explosivo) => 
//               Text('- N°${explosivo['numero']}: MS ${explosivo['ms_cant1']}, LP ${explosivo['lp_cant1']}')),
//           ],
//         ),
//       ),
//     );
//   }
// }