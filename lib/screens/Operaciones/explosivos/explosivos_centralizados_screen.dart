import 'package:flutter/material.dart';
import 'package:i_miner/screens/Operaciones/explosivos/datos_trabajo_explosivos_screen.dart';
import 'package:i_miner/screens/Operaciones/explosivos/formulario_despacho_screen.dart';
import 'package:i_miner/screens/Operaciones/explosivos/formulario_devoluciones_screen.dart';

class ExplosivosCentralizadosScreen extends StatefulWidget {
  final int id;
  final dynamic dni;
  final VoidCallback onEstadoActualizado; // Agregamos el callback

  const ExplosivosCentralizadosScreen({
    Key? key,
    required this.id,
    required this.dni,
    required this.onEstadoActualizado, // Se requiere este parámetro
  }) : super(key: key);

  @override
  _ExplosivosCentralizadosScreenState createState() => _ExplosivosCentralizadosScreenState();
}

class _ExplosivosCentralizadosScreenState extends State<ExplosivosCentralizadosScreen> {
  bool estadoActualizado = false;

  void _manejarActualizacionEstado() {
    setState(() {
      estadoActualizado = true;
      print("Estado actualizado en ExplosivosCentralizadosScreen");
    });

    widget.onEstadoActualizado(); // Llamamos al callback para actualizar `PruebaScreen`
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Explosivos Centralizados"),
          backgroundColor: Color(0xFF21899C),
          bottom: TabBar(
            tabs: [
              Tab(text: "Datos de Trabajo"),
              Tab(text: "Despacho"),
              Tab(text: "Devoluciones"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FormularioDatosTrabajoScreen(
              exploracionId: widget.id,
              onEstadoActualizado: _manejarActualizacionEstado, // Pasamos el callback
            ),
            FormularioDespachoScreen(exploracionId: widget.id),
            FormularioDevolucionesScreen(
              exploracionId: widget.id,
              onEstadoActualizado: _manejarActualizacionEstado,
              dni: widget.dni
            ),
          ],
        ),
      ),
    );
  }
}
