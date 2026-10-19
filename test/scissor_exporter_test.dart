import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';

void main() {
  test('Scissor payload includes guardia and Hora_envio', () async {
    final exporter = ExportarScissorService(DatabaseHelper());
    final payload = await exporter.prepararDatosParaExportar(
      {12},
      [
        {
          'id': 12,
          'guardia': 'Guardia A',
          'registros': '[]',
          'horometros': '{}',
          'check_list': '[]',
          'condiciones_equipo': '{}',
          'control_llantas': '{}',
        },
      ],
    );

    expect(payload, hasLength(1));
    expect(payload.single['guardia'], 'Guardia A');
    expect(payload.single['Hora_envio'], matches(RegExp(r'^\d{2}:\d{2}$')));
  });
}
