import 'package:flutter/material.dart';
import 'package:i_miner/screens/Operaciones/sostenimiento/widgets/registro_operacion_dialog.dart';

Future<Map<String, dynamic>?> showRegistroOperacionDialog({
  required BuildContext context,
  required List<Map<String, String>> codigoOperativos,
  required String turno,
  required String selectedState,
  required Map<String, List<Map<String, String>>> datadialog,
  String? ultimaHoraRegistrada, // Nuevo parámetro
  Map<String, String>? existingRecord,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext context) {
      return RegistroOperacionDialog(
        codigoOperativos: codigoOperativos,
        turno: turno,
        selectedState: selectedState,
        existingRecord: existingRecord,
        datadialog: datadialog,
        ultimaHoraRegistrada: ultimaHoraRegistrada, // Pasar el valor
        onConfirm: (data) => Navigator.of(context).pop(data),
      );
    },
  );
}