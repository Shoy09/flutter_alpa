import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class ListaPantalla extends StatefulWidget {
  @override
  _ListaPantallaState createState() => _ListaPantallaState();
}

class _ListaPantallaState extends State<ListaPantalla> {
  List<Map<String, dynamic>> _mediciones = [];
  Set<int> _selectedIds = {};
  bool _isInSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _cargarMediciones();
  }

  void _cargarMediciones() async {
    try {
      print('Cargando mediciones...');
      final datos = await DatabaseHelper().obtenerTodasMedicionesLargo();
      print('Mediciones encontradas: ${datos.length}');

      setState(() {
        _mediciones = datos;
      });
    } catch (e) {
      print('Error al cargar mediciones: $e');
    }
  }

Future<void> _eliminarSeleccionadas() async {
  if (_selectedIds.isEmpty) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirmar eliminación'),
      content: Text('¿Estás seguro de que quieres eliminar las ${_selectedIds.length} mediciones seleccionadas?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      // ✅ Obtener los id_explosivo antes de eliminar
      List<Map<String, dynamic>> medicionesSeleccionadas = _mediciones
          .where((medicion) => _selectedIds.contains(medicion['id']))
          .toList();

      List<int> idsExplosivo = medicionesSeleccionadas
          .map((medicion) => medicion['id_explosivo'] as int)
          .where((id) => id != null)
          .toList();

      print('Ids de explosivo a actualizar a cero: $idsExplosivo');

      // ✅ Actualizar medicion de esos id_explosivo a 0 antes de eliminar
      await DatabaseHelper().actualizarMedicionExplosivoACero(idsExplosivo);

      // ✅ Eliminar las mediciones seleccionadas
      await DatabaseHelper().eliminarMultiplesMedicionesLargo(_selectedIds.toList());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedIds.length} mediciones eliminadas correctamente')),
      );

      _cargarMediciones();
      setState(() {
        _selectedIds.clear();
        _isInSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar las mediciones: $e')),
      );
    }
  }
}


  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isInSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isInSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(int firstSelectedId) {
    setState(() {
      _selectedIds.add(firstSelectedId);
      _isInSelectionMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isInSelectionMode 
            ? Text('${_selectedIds.length} seleccionadas')
            : Text('Mediciones Taladro Largo'),
        backgroundColor: Color(0xFF21899C),
        actions: [
          if (_isInSelectionMode)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _eliminarSeleccionadas,
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarMediciones,
          ),
        ],
      ),
      body: _mediciones.isEmpty
          ? Center(child: Text('No hay mediciones registradas'))
          : ListView.builder(
              itemCount: _mediciones.length,
              itemBuilder: (context, index) {
                final medicion = _mediciones[index];
                final isSelected = _selectedIds.contains(medicion['id']);

                return Card(
                  margin: EdgeInsets.all(8),
                  color: isSelected ? Colors.blue[50] : null,
                  child: InkWell(
                    onTap: () {
                      if (_isInSelectionMode) {
                        _toggleSelection(medicion['id']);
                      }
                    },
                    onLongPress: () {
                      if (!_isInSelectionMode) {
                        _enterSelectionMode(medicion['id']);
                      } else {
                        _toggleSelection(medicion['id']);
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isInSelectionMode)
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${medicion['labor'] ?? 'Sin labor'} - ${medicion['veta'] ?? 'Sin veta'}- ${medicion['id_explosivo'] ?? 'Sin id_explosivo'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Fecha: ${medicion['fecha']} | Turno: ${medicion['turno']} | Empresa: ${medicion['empresa']} | Zona: ${medicion['zona']}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Divider(),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoItem('toneladas', '${medicion['toneladas']?.toStringAsFixed(2) ?? '0'} m'),
                              
                              _buildInfoItem('Explosivos', '${medicion['kg_explosivos']?.toStringAsFixed(2) ?? '0'} kg'),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusChip(medicion['envio'] == 1),
                              Text(
                                'Tipo: ${medicion['tipo_perforacion'] ?? 'No especificado'}',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusChip(bool enviado) {
    return Chip(
      label: Text(enviado ? 'Enviado' : 'Pendiente'),
      backgroundColor: enviado ? Colors.green[100] : Colors.orange[100],
      labelStyle: TextStyle(
        color: enviado ? Colors.green[800] : Colors.orange[800],
      ),
    );
  }
}