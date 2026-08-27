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

int _compareTimes(String time1_12h, String time2_12h) {
  try {
    String time1_24h = _formatTo24Hour(time1_12h);
    String time2_24h = _formatTo24Hour(time2_12h);
    return _convertToShiftMinutes(time1_24h) - _convertToShiftMinutes(time2_24h);
  } catch (e) {
    return 0;
  }
}

  // Función para generar intervalos de tiempo cada 5 minutos
List<String> _generateTimeIntervals(String turno) {
  List<String> times = [];

  if (turno == "DÍA") {
    // Turno día: 07:00 - 17:55
    for (int hour = 7; hour <= 17; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        if (hour == 17 && minute > 55) break;

        String time24 =
            "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

        times.add(_formatTo12Hour(time24));
      }
    }
  } else {
    // Turno noche: 19:00 - 05:55

    // Parte 1: 19:00 - 23:55
    for (int hour = 19; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        String time24 =
            "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

        times.add(_formatTo12Hour(time24));
      }
    }

    // Parte 2: 00:00 - 05:55
    for (int hour = 0; hour <= 5; hour++) {
      for (int minute = 0; minute < 60; minute += 5) {
        if (hour == 5 && minute > 55) break;

        String time24 =
            "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

        times.add(_formatTo12Hour(time24));
      }
    }
  }

  return times;
}

// Convierte de formato 24h a 12h con AM/PM
String _formatTo12Hour(String time24) {
  try {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    
    final period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  } catch (e) {
    return time24;
  }
}

// Convierte de formato 12h a 24h (para la lógica interna)
String _formatTo24Hour(String time12) {
  try {
    final parts = time12.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    final period = parts[1];
    
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return time12;
  }
}

  // Función para obtener el rango de horas válidas al editar
// Función para obtener el rango de horas válidas al editar
List<String> _getValidTimeRangeForEdit() {
  if (!isEditing || widget.existingRecord == null) return [];
  
  int currentIndex = widget.codigoOperativos.indexWhere(
    (item) => item["id"] == widget.existingRecord!["id"],
  );
  
  if (currentIndex == -1) return [];
  
  String? minTime;
  String? maxTime;
  
  // Si hay registro anterior, su hora_inicio es el límite inferior
  if (currentIndex > 0) {
    minTime = widget.codigoOperativos[currentIndex - 1]["hora_inicio"];
    // Convertir de 24h a 12h para comparar
    if (minTime != null) minTime = _formatTo12Hour(minTime);
  }
  
  // Si hay registro siguiente, su hora_inicio es el límite superior
  if (currentIndex < widget.codigoOperativos.length - 1) {
    maxTime = widget.codigoOperativos[currentIndex + 1]["hora_inicio"];
    // Convertir de 24h a 12h para comparar
    if (maxTime != null) maxTime = _formatTo12Hour(maxTime);
  }
  
  // Generar todas las opciones de tiempo (ya en 12h)
  List<String> allTimes = _generateTimeIntervals(widget.turno);
  
  // Filtrar según los límites
  return allTimes.where((time) {
    if (minTime != null && _compareTimes(time, minTime) <= 0) return false;
    if (maxTime != null && _compareTimes(time, maxTime) >= 0) return false;
    return true;
  }).toList();
}

bool _isValidTimeForShift(String time12h, String shift) {
  try {
    String time24h = _formatTo24Hour(time12h);

    final hour = int.parse(time24h.split(':')[0]);
    final minute = int.parse(time24h.split(':')[1]);

    if (shift == "DÍA") {
      // 07:00 AM - 05:55 PM
      if (hour < 7 || hour > 17) return false;

      if (hour == 17 && minute > 55) return false;
    } else {
      // 07:00 PM - 05:55 AM

      // Bloquear rango inválido 06:00 AM -> 06:59 PM
      if (hour > 5 && hour < 19) return false;

      if (hour == 19 && minute < 0) return false;

      if (hour == 5 && minute > 55) return false;
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
    'hora_inicio': _formatTo24Hour(selectedTime!), // Convertir a 24h para guardar
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
      selectedTime = _formatTo12Hour(widget.existingRecord!['hora_inicio']!);
    } else {
      selectedCodigo = null;
      selectedTime = null;
    }
  });
}

  @override
  void initState() {
    super.initState();

     print('=== ÚLTIMA HORA REGISTRADA ===');
    print('Valor: ${widget.ultimaHoraRegistrada}');
    print('Turno actual: ${widget.turno}');
    print('===============================');
    
    isEditing = widget.existingRecord != null;
    
    if (isEditing && widget.existingRecord != null) {
      selectedCodigo = widget.existingRecord!['codigo'];
      selectedTime = _formatTo12Hour(widget.existingRecord!['hora_inicio']!);
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
    "Última hora: ${_formatTo12Hour(widget.ultimaHoraRegistrada!)}",
    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
  ),
],
if (!isEditing && widget.ultimaHoraRegistrada != null)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Solo horas posteriores a ${_formatTo12Hour(widget.ultimaHoraRegistrada!)}',
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
    ? "Seleccione > ${_formatTo12Hour(widget.ultimaHoraRegistrada!)}"
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