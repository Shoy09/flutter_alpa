import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class DialogoCondicionesEquipo extends StatefulWidget {
  final int operacionId;
  final String estado;
  final Map<String, dynamic>? condicionesData;
  final Color primaryColor;

  const DialogoCondicionesEquipo({
    Key? key,
    required this.operacionId,
    this.condicionesData,
    required this.estado,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<DialogoCondicionesEquipo> createState() => _DialogoCondicionesEquipoState();
}

class _DialogoCondicionesEquipoState extends State<DialogoCondicionesEquipo> {
  bool isEditable = false;
  bool isSmallScreen = false;
  
  // Checkboxes
  bool _opChecked = false;
  bool _noOpChecked = false;
  
  // Checkboxes para aceites
  bool _aceiteMotorChecked = false;
  bool _aceiteHidraulicoChecked = false;
  bool _aceiteTransmisionChecked = false;
  
  // Campos de texto
  final TextEditingController _lugarController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _combustibleController = TextEditingController();
  final TextEditingController _horaLlenadoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatosBD();
  }

  void _cargarDatosBD() {
    final datos = widget.condicionesData ??
        {
          'op': false,
          'noOp': false,
          'lugar': '',
          'descripcion': '',
          'aceiteMotor': false,
          'aceiteHidraulico': false,
          'aceiteTransmision': false,
          'combustible': '',
        };

    _opChecked = datos['op'] ?? false;
    _noOpChecked = datos['noOp'] ?? false;
    _lugarController.text = datos['lugar'] ?? '';
    _descripcionController.text = datos['descripcion'] ?? '';
    _aceiteMotorChecked = datos['aceiteMotor'] ?? false;
    _aceiteHidraulicoChecked = datos['aceiteHidraulico'] ?? false;
    _aceiteTransmisionChecked = datos['aceiteTransmision'] ?? false;
    _combustibleController.text = datos['combustible'] ?? '';
    _horaLlenadoController.text = datos['horaLlenado'] ?? '';
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> datosGuardar = {
      'op': _opChecked,
      'noOp': _noOpChecked,
      'lugar': _lugarController.text,
      'descripcion': _descripcionController.text,
      'aceiteMotor': _aceiteMotorChecked,
      'aceiteHidraulico': _aceiteHidraulicoChecked,
      'aceiteTransmision': _aceiteTransmisionChecked,
      'combustible': _combustibleController.text,
      'horaLlenado': _horaLlenadoController.text,
    };

    bool exito = await DatabaseHelper()
        .updateCondicionesEquipoCarguio(widget.operacionId, datosGuardar);

    if (exito) {
      _mostrarSnackbar('Datos guardados correctamente', Colors.green);
    } else {
      _mostrarSnackbar('Error al guardar los datos', Colors.red);
    }

    Navigator.pop(context);
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _lugarController.dispose();
    _descripcionController.dispose();
    _combustibleController.dispose();
    _horaLlenadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    isSmallScreen = screenWidth < 600;
    
    final dialogWidth = isSmallScreen 
        ? screenWidth * 0.95
        : screenWidth * 0.5;
    
    final dialogHeight = isSmallScreen
        ? MediaQuery.of(context).size.height * 0.85
        : 700.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: dialogHeight,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compacto
            _buildCompactHeader(),
            
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección OP/NO-OP y LUGAR
                    _buildSeccionEstadoYLugar(),
                    
                    const SizedBox(height: 16),
                    
                    // Descripción
                    _buildSeccionDescripcion(),
                    
                    const SizedBox(height: 20),
                    
                    // Sección Aceites
                    _buildSeccionAceitesCompacta(),
                    
                    const SizedBox(height: 20),
                    
                    // Sección Combustible
                    _buildSeccionCombustibleCompacta(),

                    const SizedBox(height: 20),
                    
                    // Sección Hora Llenado
                    _buildSeccionHoraLlenado(),
                  ],
                ),
              ),
            ),
            
            // Footer compacto
            _buildCompactFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.engineering,
              color: Colors.white,
              size: isSmallScreen ? 16 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSmallScreen ? 'Condiciones Equipo' : 'Condiciones del Equipo',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildCompactEstadoBadge(),
        ],
      ),
    );
  }

  Widget _buildCompactEstadoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEditable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEditable ? Colors.green : Colors.grey, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isEditable ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isEditable ? 'EDITABLE' : 'LECTURA',
            style: TextStyle(
              color: isEditable ? Colors.green : Colors.grey,
              fontSize: isSmallScreen ? 8 : 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEstadoYLugar() {
    if (isSmallScreen) {
      // Versión para móvil: apilada verticalmente
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado (OP/NO-OP)
            Text(
              'ESTADO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCheckboxCompacto(
                  label: 'OP',
                  value: _opChecked,
                  onChanged: (value) {
                    setState(() {
                      _opChecked = value ?? false;
                      if (_opChecked) _noOpChecked = false;
                    });
                  },
                ),
                const SizedBox(width: 16),
                _buildCheckboxCompacto(
                  label: 'NO-OP',
                  value: _noOpChecked,
                  onChanged: (value) {
                    setState(() {
                      _noOpChecked = value ?? false;
                      if (_noOpChecked) _opChecked = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Lugar
            _buildCampoCompacto(
              label: 'LUGAR',
              controller: _lugarController,
              hintText: 'Ubicación del equipo',
            ),
          ],
        ),
      );
    } else {
      // Versión para PC: horizontal
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTADO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCheckboxCompacto(
                        label: 'OP',
                        value: _opChecked,
                        onChanged: (value) {
                          setState(() {
                            _opChecked = value ?? false;
                            if (_opChecked) _noOpChecked = false;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildCheckboxCompacto(
                        label: 'NO-OP',
                        value: _noOpChecked,
                        onChanged: (value) {
                          setState(() {
                            _noOpChecked = value ?? false;
                            if (_noOpChecked) _opChecked = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 16),
            Expanded(
              flex: 3,
              child: _buildCampoCompacto(
                label: 'LUGAR',
                controller: _lugarController,
                hintText: 'Ubicación del equipo',
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSeccionDescripcion() {
    return _buildCampoCompacto(
      label: 'DESCRIPCIÓN',
      controller: _descripcionController,
      maxLines: isSmallScreen ? 3 : 2,
      hintText: 'Describa las condiciones observadas...',
    );
  }

  Widget _buildSeccionAceitesCompacta() {
    if (isSmallScreen) {
      // Versión para móvil: checkboxes apilados verticalmente
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.oil_barrel, size: 14, color: widget.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'ACEITES Y LUBRICANTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCheckboxCompacto(
              label: 'MOTOR',
              value: _aceiteMotorChecked,
              onChanged: (value) => setState(() => _aceiteMotorChecked = value ?? false),
            ),
            const SizedBox(height: 8),
            _buildCheckboxCompacto(
              label: 'HIDRÁULICO',
              value: _aceiteHidraulicoChecked,
              onChanged: (value) => setState(() => _aceiteHidraulicoChecked = value ?? false),
            ),
            const SizedBox(height: 8),
            _buildCheckboxCompacto(
              label: 'TRANSMISIÓN',
              value: _aceiteTransmisionChecked,
              onChanged: (value) => setState(() => _aceiteTransmisionChecked = value ?? false),
            ),
          ],
        ),
      );
    } else {
      // Versión para PC: horizontal en fila
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.oil_barrel, size: 14, color: widget.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'ACEITES Y LUBRICANTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCheckboxCompacto(
                    label: 'MOTOR',
                    value: _aceiteMotorChecked,
                    onChanged: (value) => setState(() => _aceiteMotorChecked = value ?? false),
                  ),
                ),
                Expanded(
                  child: _buildCheckboxCompacto(
                    label: 'HIDRÁULICO',
                    value: _aceiteHidraulicoChecked,
                    onChanged: (value) => setState(() => _aceiteHidraulicoChecked = value ?? false),
                  ),
                ),
                Expanded(
                  child: _buildCheckboxCompacto(
                    label: 'TRANSMISIÓN',
                    value: _aceiteTransmisionChecked,
                    onChanged: (value) => setState(() => _aceiteTransmisionChecked = value ?? false),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSeccionCombustibleCompacta() {
    if (isSmallScreen) {
      // Versión para móvil: apilada
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_gas_station, size: 14, color: widget.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'COMBUSTIBLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _combustibleController,
              enabled: isEditable,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ej: 1/2, 3/4, LLENO',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: widget.primaryColor),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                filled: !isEditable,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
      );
    } else {
      // Versión para PC: horizontal
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.local_gas_station, size: 14, color: widget.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'COMBUSTIBLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _combustibleController,
                enabled: isEditable,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ej: 1/2, 3/4, LLENO',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: widget.primaryColor),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  filled: !isEditable,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSeccionHoraLlenado() {
    if (isSmallScreen) {
      // Versión para móvil: apilada
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: widget.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'HORA DE LLENADO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _horaLlenadoController,
              readOnly: true,
              onTap: isEditable ? _seleccionarHora : null,
              decoration: InputDecoration(
                hintText: 'Seleccionar hora',
                suffixIcon: const Icon(Icons.schedule, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Versión para PC: horizontal
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 14, color: widget.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'HORA DE LLENADO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _horaLlenadoController,
                readOnly: true,
                onTap: isEditable ? _seleccionarHora : null,
                decoration: InputDecoration(
                  hintText: 'Seleccionar hora',
                  suffixIcon: const Icon(Icons.schedule, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCheckboxCompacto({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: isEditable ? onChanged : null,
            activeColor: widget.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w500,
            color: isEditable ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCampoCompacto({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: isEditable,
          maxLines: maxLines,
          style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: widget.primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: !isEditable,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isEditable)
            ElevatedButton(
              onPressed: _guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: isSmallScreen ? 12 : 14),
                  const SizedBox(width: 4),
                  Text(
                    'Guardar',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _seleccionarHora() async {
    TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (hora != null) {
      final horaFormateada =
          '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

      setState(() {
        _horaLlenadoController.text = horaFormateada;
      });
    }
  }
}