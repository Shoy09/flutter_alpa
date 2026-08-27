import 'package:flutter/material.dart';

class RegistroOperacionDialog extends StatefulWidget {
  final List<Map<String, String>> codigoOperativos;
  final String turno;
  final String selectedState;
  final Map<String, String>? existingRecord;
  final Map<String, List<Map<String, String>>> datadialog;
  final String? ultimaHoraRegistrada; // Nueva variable
  final Function(Map<String, dynamic>) onConfirm;

  const RegistroOperacionDialog({
    Key? key,
    required this.codigoOperativos,
    required this.turno,
    required this.selectedState,
    this.existingRecord,
    required this.datadialog,
    this.ultimaHoraRegistrada, // Nuevo parámetro
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<RegistroOperacionDialog> createState() => _RegistroOperacionDialogState();
}

class _RegistroOperacionDialogState extends State<RegistroOperacionDialog> {
  String? selectedCodigo;
  String? selectedTime;
  late bool isEditing;

   // Función auxiliar para comparar tiempos
  int _convertToShiftMinutes(String time) {
  final parts = time.split(':').map(int.parse).toList();
  int hour = parts[0];
  int minute = parts[1];

  int totalMinutes = hour * 60 + minute;

  // 🔥 CLAVE: ajustar para turno noche
  if (widget.turno != "DÍA") {
    if (hour < 7) {
      totalMinutes += 24 * 60; // sumar 24h
    }
  }

  return totalMinutes;
}

int _compareTimes(String time1, String time2) {
  try {
    return _convertToShiftMinutes(time1) - _convertToShiftMinutes(time2);
  } catch (e) {
    return 0;
  }
}

  // Función para generar intervalos de tiempo cada 5 minutos
  List<String> _generateTimeIntervals(String turno) {
  List<String> times = [];

  if (turno == "DÍA") {
    // Turno día: 07:00 - 17:25
    for (int hour = 7; hour <= 17; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        if (hour == 17 && minute > 25) break;

        times.add(
          "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}"
        );
      }
    }
  } else {
    // Turno noche: 19:00 - 05:25

    // Parte 1: 19:00 - 23:55
    for (int hour = 19; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        times.add(
          "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}"
        );
      }
    }

    // Parte 2: 00:00 - 05:25
    for (int hour = 0; hour <= 5; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        if (hour == 5 && minute > 25) break;

        times.add(
          "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}"
        );
      }
    }
  }

  return times;
}

  // Función para obtener el rango de horas válidas al editar
  List<String> _getValidTimeRangeForEdit() {
    if (!isEditing || widget.existingRecord == null) return [];
    
    // Encontrar el índice del registro actual
    int currentIndex = widget.codigoOperativos.indexWhere(
      (item) => item["id"] == widget.existingRecord!["id"],
    );
    
    if (currentIndex == -1) return [];
    
    String? minTime;
    String? maxTime;
    
    // Si hay registro anterior, su hora_inicio es el límite inferior
    if (currentIndex > 0) {
      minTime = widget.codigoOperativos[currentIndex - 1]["hora_inicio"];
      if (minTime?.contains(' ') == true) {
        minTime = minTime!.split(' ')[1];
      }
    }
    
    // Si hay registro siguiente, su hora_inicio es el límite superior
    if (currentIndex < widget.codigoOperativos.length - 1) {
      maxTime = widget.codigoOperativos[currentIndex + 1]["hora_inicio"];
      if (maxTime?.contains(' ') == true) {
        maxTime = maxTime!.split(' ')[1];
      }
    }
    
    // Generar todas las opciones de tiempo
    List<String> allTimes = _generateTimeIntervals(widget.turno);
    
    // Filtrar según los límites
    return allTimes.where((time) {
      if (minTime != null && _compareTimes(time, minTime) <= 0) return false;
      if (maxTime != null && _compareTimes(time, maxTime) >= 0) return false;
      return true;
    }).toList();
  }

  bool _isValidTimeForShift(String time, String shift) {
    try {
      final hour = int.parse(time.split(':')[0]);
      final minute = int.parse(time.split(':')[1]);
      if (shift == "DÍA") {
        // Validar entre 7:00 y 18:55
        if (hour < 7 || hour > 18) return false;
        if (hour == 18 && minute > 55) return false;
      } else {
        // Validar entre 19:00-23:55 y 00:00-06:55
        if (hour > 6 && hour < 19) return false;
        if (hour == 6 && minute > 55) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  List<DropdownMenuItem<String>> _obtenerOpcionesUnicas(
      List<Map<String, dynamic>> data) {
    final seen = <String>{};
    return data.where((e) => seen.add(e["Código"] as String? ?? "")).map((e) {
      String codigo = e["Código"] as String? ?? "";
      String tipoEstado = e["Nombre"] as String? ?? "";
      return DropdownMenuItem<String>(
        value: codigo,
        child: Text("$codigo - $tipoEstado", style: const TextStyle(fontSize: 14)),
      );
    }).toList();
  }

  bool _validateSelection() {
    if (selectedCodigo == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Faltan datos por seleccionar."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Validar hora duplicada
    bool horaExiste = widget.codigoOperativos
        .where((item) => !isEditing || item["id"] != widget.existingRecord!["id"])
        .any((item) {
          String horaItem = item["hora_inicio"] ?? '';
          if (horaItem.contains(' ')) horaItem = horaItem.split(' ')[1];
          return horaItem == selectedTime;
        });
    
    if (horaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: La Hora Inicio ya está registrada."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    if (!_isValidTimeForShift(selectedTime!, widget.turno)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("La hora no está dentro del turno ${widget.turno}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    // Validación específica para edición
    if (isEditing && !_getValidTimeRangeForEdit().contains(selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La hora debe estar entre el registro anterior y el siguiente"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Para creación nueva, validar que sea posterior a la última hora registrada
    if (!isEditing && widget.ultimaHoraRegistrada != null) {
      if (_compareTimes(selectedTime!, widget.ultimaHoraRegistrada!) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "La hora debe ser posterior a la última registrada (${widget.ultimaHoraRegistrada})"
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _handleConfirm() {
    if (!_validateSelection()) return;

    // Preparar los datos para enviar al padre
    final data = {
      'codigo': selectedCodigo,
      'hora_inicio': selectedTime,
      'estado': widget.selectedState,
      if (isEditing) 'id': widget.existingRecord!['id'],
      if (isEditing) 'numero': widget.existingRecord!['numero'],
      if (isEditing) 'hora_final': widget.existingRecord!['hora_final'],
    };

    widget.onConfirm(data);
  }

  void _handleClear() {
    setState(() {
      if (widget.existingRecord != null) {
        selectedCodigo = widget.existingRecord!['codigo'];
        selectedTime = widget.existingRecord!['hora_inicio'];
      } else {
        selectedCodigo = null;
        selectedTime = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    isEditing = widget.existingRecord != null;
    
    if (isEditing && widget.existingRecord != null) {
      selectedCodigo = widget.existingRecord!['codigo'];
      selectedTime = widget.existingRecord!['hora_inicio'];
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> currentDataDialog =
        widget.datadialog[widget.selectedState] ?? [];
    List<String> timeOptions = _generateTimeIntervals(widget.turno);
    
    // Filtrar horas disponibles
    List<String> availableTimeOptions;
    
    if (isEditing) {
      availableTimeOptions = _getValidTimeRangeForEdit();
      if (selectedTime != null && !availableTimeOptions.contains(selectedTime)) {
        availableTimeOptions = List.from(availableTimeOptions)..add(selectedTime!);
        availableTimeOptions.sort((a, b) => _compareTimes(a, b));
      }
    } else {
      // Para creación nueva, mostrar solo horas posteriores a la última registrada
      availableTimeOptions = timeOptions.where((hora) {
        if (!_isValidTimeForShift(hora, widget.turno)) return false;
        
        // Si hay última hora registrada, debe ser posterior
        if (widget.ultimaHoraRegistrada != null) {
          return _compareTimes(hora, widget.ultimaHoraRegistrada!) > 0;
        }
        
        return true;
      }).toList();
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Center(
        child: Column(
          children: [
            Text(
              isEditing ? "EDITAR OPERACIÓN" : "REGISTRAR OPERACIÓN",
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            if (!isEditing && widget.ultimaHoraRegistrada != null) ...[
              const SizedBox(height: 4),
              Text(
                "Última hora: ${widget.ultimaHoraRegistrada}",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Información del estado
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estado: ${widget.selectedState}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Dropdown de Código
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Código (*)",
                  contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  border: OutlineInputBorder(),
                ),
                value: selectedCodigo,
                items: _obtenerOpcionesUnicas(currentDataDialog),
                onChanged: (value) {
                  setState(() {
                    selectedCodigo = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Dropdown de Hora
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Hora Inicio (*)",
                  hintText: widget.ultimaHoraRegistrada != null && !isEditing
                      ? "Seleccione > ${widget.ultimaHoraRegistrada}"
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                  border: const OutlineInputBorder(),
                ),
                value: selectedTime,
                items: availableTimeOptions
                    .map((time) => DropdownMenuItem(
                          value: time,
                          child: Text(time, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTime = value;
                  });
                },
                menuMaxHeight: 200,
              ),
              
              // Mensaje informativo sobre la última hora
              if (!isEditing && widget.ultimaHoraRegistrada != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Solo horas posteriores a ${widget.ultimaHoraRegistrada}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Limpiar"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEditing ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isEditing ? "Actualizar" : "Crear"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Nota de campos obligatorios
              const Text(
                "(*) Los campos con asterisco son obligatorios.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}