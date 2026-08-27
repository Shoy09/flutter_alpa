import 'package:flutter/material.dart';
import 'package:i_miner/config/data/database_helper.dart';

class DialogoCheckImagen extends StatefulWidget {
  final int operacionId;
  final Map<String, dynamic> controlLlantasData;
  final String estado;
  
  final Color primaryColor;

  const DialogoCheckImagen({
    Key? key,
    required this.operacionId,
    required this.estado,
    required this.controlLlantasData,
    this.primaryColor = const Color(0xFF1B5E6B),
  }) : super(key: key);

  @override
  State<DialogoCheckImagen> createState() => _DialogoCheckImagenState();
}

class _DialogoCheckImagenState extends State<DialogoCheckImagen> {
  bool isEditable = false;
  
  // Valores para las 4 posiciones (true = check, false = x)
  bool value1 = false;
  bool value2 = false;
  bool value3 = false;
  bool value4 = false;

  @override
  void initState() {
    super.initState();
    isEditable = widget.estado.toLowerCase() != "cerrado";
    _cargarDatos();
  }

  void _cargarDatos() {
    value1 = widget.controlLlantasData['numero1'] ?? false;
    value2 = widget.controlLlantasData['numero2'] ?? false;
    value3 = widget.controlLlantasData['numero3'] ?? false;
    value4 = widget.controlLlantasData['numero4'] ?? false;
  }

  Future<void> _guardarDatos() async {
    Map<String, dynamic> controlLlantas = {
      'numero1': value1,
      'numero2': value2,
      'numero3': value3,
      'numero4': value4,
    };

    bool guardado = await DatabaseHelper()
        .updateControlLlantasRompeBaco(widget.operacionId, controlLlantas);

    if (guardado) {
      _mostrarSnackbar('Inspección guardada correctamente', Colors.green);
      Navigator.pop(context);
    } else {
      _mostrarSnackbar('Error al guardar', Colors.red);
    }
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 450,
        constraints: const BoxConstraints(
          maxHeight: 500,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compacto
            _buildHeader(),
            
            // Cuerpo con la imagen y los botones
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Imagen central
                    Image.asset(
                      "assets/images/img_llantas.PNG",
                      height: 250,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 250,
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Imagen no encontrada',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Botones en las 4 esquinas
                    // Arriba izquierda → 3
                    _buildBotonPosicionado(
                      top: 0,
                      left: 0,
                      label: "3",
                      value: value3,
                      onCheck: () => setState(() => value3 = true),
                      onUncheck: () => setState(() => value3 = false),
                    ),

                    // Arriba derecha → 1
                    _buildBotonPosicionado(
                      top: 0,
                      right: 0,
                      label: "1",
                      value: value1,
                      onCheck: () => setState(() => value1 = true),
                      onUncheck: () => setState(() => value1 = false),
                    ),

                    // Abajo izquierda → 4
                    _buildBotonPosicionado(
                      bottom: 0,
                      left: 0,
                      label: "4",
                      value: value4,
                      onCheck: () => setState(() => value4 = true),
                      onUncheck: () => setState(() => value4 = false),
                    ),

                    // Abajo derecha → 2
                    _buildBotonPosicionado(
                      bottom: 0,
                      right: 0,
                      label: "2",
                      value: value2,
                      onCheck: () => setState(() => value2 = true),
                      onUncheck: () => setState(() => value2 = false),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer compacto
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: const Icon(
              Icons.image_search,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Inspección Visual',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildEstadoBadge(),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge() {
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
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPosicionado({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required String label,
    required bool value,
    required VoidCallback onCheck,
    required VoidCallback onUncheck,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: value ? widget.primaryColor : Colors.grey.shade300,
            width: value ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: value ? widget.primaryColor : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            if (!isEditable)
              // Modo lectura: mostrar el ícono actual
              value 
                ? Icon(Icons.check_circle, color: widget.primaryColor, size: 28)
                : Icon(Icons.cancel, color: Colors.grey.shade400, size: 28)
            else
              // Modo edición: mostrar ambos botones
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón Check (✓)
                  InkWell(
                    onTap: () => onCheck(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: value 
                          ? widget.primaryColor 
                          : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 20,
                        color: value 
                          ? Colors.white 
                          : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón X
                  InkWell(
                    onTap: () => onUncheck(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: !value 
                          ? Colors.red.shade400 
                          : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: !value 
                          ? Colors.white 
                          : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                fontSize: 13,
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Guardar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}